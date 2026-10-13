# Lab 01 · Stacks, change sets y detección de drift con CloudFormation

**Duración estimada:** 50 minutos
**Sesión:** 1
**Entorno:** AWS CloudShell · región `eu-west-1` (Irlanda)

## Objetivo

Vas a desplegar un stack de CloudFormation parametrizado, modificarlo de forma controlada mediante un change set (incluido un cambio que obliga a reemplazar un recurso) y detectar y corregir un cambio manual hecho fuera de la plantilla.

## Requisitos

- Usuario o rol en la cuenta de formación con permisos sobre CloudFormation, S3 y SNS.
- Acceso a la consola de AWS.

## Punto de partida

Esta práctica no depende de ninguna otra. Todo lo que necesitas lo creas en el paso 1.

---

## Paso 1 · Preparar CloudShell y la plantilla

1. Entra en la consola de AWS y comprueba en la esquina superior derecha que la región es **Europa (Irlanda) eu-west-1**.
2. Abre **CloudShell** (icono de terminal en la barra superior).
3. Define un sufijo único que usarás en todos los nombres. Usa tus iniciales y un número:

```bash
export SUFIJO=jlb01            # cámbialo por el tuyo, en minúsculas
export AWS_REGION=eu-west-1
export STACK=lab01-$SUFIJO
mkdir -p ~/lab01 && cd ~/lab01
```

4. Crea la plantilla `plantilla.yaml`:

```bash
cat > plantilla.yaml <<'EOF'
AWSTemplateFormatVersion: "2010-09-09"
Description: Lab 01 - bucket de datos y tema de avisos

Parameters:
  Entorno:
    Type: String
    AllowedValues: [dev, pre, pro]
    Default: dev
  Sufijo:
    Type: String
    AllowedPattern: "[a-z0-9-]+"

Resources:
  BucketDatos:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub "lab01-datos-${Sufijo}-${AWS::AccountId}"
      VersioningConfiguration:
        Status: Enabled
      BucketEncryption:
        ServerSideEncryptionConfiguration:
          - ServerSideEncryptionByDefault:
              SSEAlgorithm: AES256
      PublicAccessBlockConfiguration:
        BlockPublicAcls: true
        BlockPublicPolicy: true
        IgnorePublicAcls: true
        RestrictPublicBuckets: true
      Tags:
        - Key: entorno
          Value: !Ref Entorno
        - Key: curso
          Value: devops-aws

  TemaAvisos:
    Type: AWS::SNS::Topic
    Properties:
      TopicName: !Sub "lab01-avisos-${Sufijo}"

Outputs:
  NombreBucket:
    Value: !Ref BucketDatos
  ArnTema:
    Value: !Ref TemaAvisos
EOF
```

## Paso 2 · Validar y desplegar

Valida la sintaxis:

```bash
aws cloudformation validate-template --template-body file://plantilla.yaml
```

> Opcional pero recomendado: instala y ejecuta `cfn-lint`, que detecta errores que la validación básica no ve.
>
> ```bash
> pip install --user cfn-lint && ~/.local/bin/cfn-lint plantilla.yaml
> ```

Despliega el stack:

```bash
aws cloudformation deploy \
  --stack-name $STACK \
  --template-file plantilla.yaml \
  --parameter-overrides Entorno=dev Sufijo=$SUFIJO \
  --tags curso=devops-aws alumno=$SUFIJO
```

Consulta las salidas y los eventos:

```bash
aws cloudformation describe-stacks --stack-name $STACK \
  --query "Stacks[0].Outputs" --output table

aws cloudformation describe-stack-events --stack-name $STACK \
  --query "StackEvents[].[Timestamp,LogicalResourceId,ResourceStatus]" \
  --output table | head -20
```

> **Punto de control 1.** En la consola, **CloudFormation → Stacks**, tu stack aparece en `CREATE_COMPLETE`. Abre la pestaña **Resources** y comprueba que hay dos recursos.

## Paso 3 · Change set con un cambio y un reemplazo

Vamos a introducir dos cambios en la plantilla:

- Una regla de ciclo de vida en el bucket (cambio sin reemplazo).
- Un cambio en `TopicName` del tema SNS. Esta propiedad **no se puede modificar** en un recurso existente, así que obliga a reemplazarlo.

```bash
cp plantilla.yaml plantilla_v2.yaml

python3 - <<'EOF'
p = "plantilla_v2.yaml"
s = open(p).read()
s = s.replace("""      PublicAccessBlockConfiguration:""",
"""      LifecycleConfiguration:
        Rules:
          - Id: expirar-versiones-antiguas
            Status: Enabled
            NoncurrentVersionExpiration:
              NoncurrentDays: 30
      PublicAccessBlockConfiguration:""")
s = s.replace('TopicName: !Sub "lab01-avisos-${Sufijo}"',
              'TopicName: !Sub "lab01-alertas-${Sufijo}"')
open(p, "w").write(s)
EOF

diff plantilla.yaml plantilla_v2.yaml
```

Crea el change set **sin ejecutarlo**:

```bash
aws cloudformation create-change-set \
  --stack-name $STACK \
  --change-set-name cambio-v2 \
  --template-body file://plantilla_v2.yaml \
  --parameters ParameterKey=Entorno,UsePreviousValue=true ParameterKey=Sufijo,UsePreviousValue=true

aws cloudformation wait change-set-create-complete \
  --stack-name $STACK --change-set-name cambio-v2

aws cloudformation describe-change-set \
  --stack-name $STACK --change-set-name cambio-v2 \
  --query "Changes[].ResourceChange.[LogicalResourceId,Action,Replacement]" \
  --output table
```

> **Punto de control 2.** Debes ver `BucketDatos` con acción `Modify` y `Replacement = False`, y `TemaAvisos` con acción `Modify` y `Replacement = True`. Abre también el change set en la consola (pestaña **Change sets** del stack) y revisa el detalle de qué propiedad provoca el reemplazo.

**Pregunta:** si en lugar de un tema SNS fuese una base de datos con datos de clientes, ¿ejecutarías este change set? ¿Qué harías antes?

Ejecuta el change set:

```bash
aws cloudformation execute-change-set --stack-name $STACK --change-set-name cambio-v2
aws cloudformation wait stack-update-complete --stack-name $STACK
aws cloudformation describe-stacks --stack-name $STACK --query "Stacks[0].Outputs" --output table
```

Comprueba que el ARN del tema ha cambiado: es un recurso nuevo.

## Paso 4 · Provocar y detectar drift

1. En la consola, abre **S3**, entra en tu bucket `lab01-datos-<sufijo>-<cuenta>` → pestaña **Properties** → **Tags** → **Edit**.
2. Cambia el valor de la etiqueta `entorno` de `dev` a `manual` y guarda.
3. Vuelve a CloudShell y lanza la detección de drift:

```bash
DET=$(aws cloudformation detect-stack-drift --stack-name $STACK --query StackDriftDetectionId --output text)
sleep 15
aws cloudformation describe-stack-drift-detection-status --stack-drift-detection-id $DET \
  --query "[DetectionStatus,StackDriftStatus]" --output text

aws cloudformation describe-stack-resource-drifts --stack-name $STACK \
  --stack-resource-drift-status-filters MODIFIED \
  --query "StackResourceDrifts[].PropertyDifferences[]" --output table
```

> **Punto de control 3.** El stack aparece como `DRIFTED` y la diferencia muestra la propiedad `Tags` con el valor esperado `dev` y el real `manual`. En la consola, **Stack actions → Detect drift** muestra lo mismo de forma visual.

## Paso 5 · Corregir el drift desde la plantilla

La forma correcta de corregir el drift es que CloudFormation vuelva a imponer el estado declarado. Como la plantilla no ha cambiado, un `deploy` normal diría que no hay cambios; forzamos una actualización cambiando un valor de etiqueta del stack:

```bash
aws cloudformation deploy \
  --stack-name $STACK \
  --template-file plantilla_v2.yaml \
  --parameter-overrides Entorno=dev Sufijo=$SUFIJO \
  --tags curso=devops-aws alumno=$SUFIJO revision=2
```

Vuelve a detectar el drift (repite los comandos del paso 4) y comprueba el resultado.

> **Observación.** Según la propiedad afectada, CloudFormation puede reimponer o no el valor al actualizar. Si la etiqueta sigue en `manual`, cambia el parámetro a `Entorno=pre` y despliega: al cambiar el valor declarado, CloudFormation lo aplica. Esta práctica muestra por qué los cambios manuales son peligrosos: el estado real y el declarado se separan sin que nadie lo sepa hasta que se detecta.

---

## Reto opcional

Añade a la plantilla una `DeletionPolicy: Retain` para el bucket y activa la protección contra borrado del stack:

```bash
aws cloudformation update-termination-protection --stack-name $STACK --enable-termination-protection
```

Intenta borrar el stack y observa el error. Después desactívala para poder limpiar.

## Preguntas de reflexión

1. ¿Por qué el nombre del bucket incluye el sufijo y el identificador de la cuenta?
2. ¿Qué dos mecanismos de CloudFormation te protegen de borrar por accidente un recurso con datos?

## Limpieza

Vacía el bucket (tiene versionado, así que hay que borrar también las versiones) y elimina el stack:

```bash
BUCKET=$(aws cloudformation describe-stacks --stack-name $STACK \
  --query "Stacks[0].Outputs[?OutputKey=='NombreBucket'].OutputValue" --output text)
aws s3api delete-objects --bucket $BUCKET --delete "$(aws s3api list-object-versions --bucket $BUCKET \
  --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' --output json)" 2>/dev/null
aws cloudformation update-termination-protection --stack-name $STACK --no-enable-termination-protection 2>/dev/null
aws cloudformation delete-stack --stack-name $STACK
aws cloudformation wait stack-delete-complete --stack-name $STACK && echo "Stack eliminado"
```

> Si añadiste `DeletionPolicy: Retain` en el reto, el bucket sobrevivirá al borrado del stack: elimínalo después con `aws s3 rb s3://$BUCKET`.

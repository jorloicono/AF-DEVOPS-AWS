#!/usr/bin/env bash
# Comprueba, contra el emulador local, cada funcionalidad que usan las prácticas.
# Uso: bash comprobar-entorno.sh        (tarda 2-4 minutos)
set +e
TMP=$(mktemp -d); cd "$TMP"
ok()   { printf "  \033[32mOK\033[0m     %s\n" "$1"; }
mal()  { printf "  \033[31mFALLO\033[0m  %s\n" "$1"; FALLOS=$((FALLOS+1)); }
aviso(){ printf "  \033[33mAVISO\033[0m  %s\n" "$1"; }
FALLOS=0

echo "== Emulador"
aws sts get-caller-identity --query Account --output text >/dev/null 2>&1 && ok "responde en $AWS_ENDPOINT_URL" || { mal "no responde: ejecuta bash .devcontainer/arrancar-emulador.sh"; exit 1; }

echo "== Lab 01 · CloudFormation"
cat > p.yaml <<'T'
AWSTemplateFormatVersion: "2010-09-09"
Parameters:
  Sufijo: { Type: String, Default: prueba }
Resources:
  Bucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: { "Fn::Sub": "comprobar-${Sufijo}-${AWS::AccountId}" }
      Tags: [ { Key: entorno, Value: dev } ]
  Tema:
    Type: AWS::SNS::Topic
    Properties:
      TopicName: { "Fn::Sub": "comprobar-avisos-${Sufijo}" }
Outputs:
  NombreBucket: { Value: { Ref: Bucket } }
T
aws cloudformation deploy --stack-name comprobar --template-file p.yaml >/dev/null 2>&1 && ok "deploy (crear stack mediante change set)" || mal "deploy"
OUT=$(aws cloudformation describe-stacks --stack-name comprobar --query "Stacks[0].Outputs[?OutputKey=='NombreBucket'].OutputValue" --output text 2>/dev/null)
[ -n "$OUT" ] && [ "$OUT" != "None" ] && ok "outputs del stack ($OUT)" || mal "outputs del stack"
sed 's/comprobar-avisos-/comprobar-alertas-/' p.yaml > p2.yaml
aws cloudformation create-change-set --stack-name comprobar --change-set-name cs1 --template-body file://p2.yaml >/dev/null 2>&1 && ok "create-change-set" || mal "create-change-set"
sleep 3
CS=$(aws cloudformation describe-change-set --stack-name comprobar --change-set-name cs1 --query "Changes[].ResourceChange.[LogicalResourceId,Action,Replacement]" --output text 2>/dev/null)
[ -n "$CS" ] && ok "describe-change-set: $(echo $CS | tr '\n' ' ')" || mal "describe-change-set"
echo "$CS" | grep -q "True" || aviso "el emulador no informa Replacement=True (en AWS real sí); el Lab 01 lo explica"
aws cloudformation execute-change-set --stack-name comprobar --change-set-name cs1 >/dev/null 2>&1 && ok "execute-change-set" || mal "execute-change-set"
sleep 3
D=$(aws cloudformation detect-stack-drift --stack-name comprobar --query StackDriftDetectionId --output text 2>/dev/null)
[ -n "$D" ] && ok "detect-stack-drift disponible" || aviso "detect-stack-drift no disponible: el Lab 01 usa la comprobación manual"
aws s3api get-bucket-tagging --bucket "$OUT" >/dev/null 2>&1 && ok "etiquetas del bucket" || aviso "get-bucket-tagging"

echo "== Lab 02 · S3, Parameter Store y CodeBuild"
aws s3 mb s3://comprobar-cb >/dev/null 2>&1; echo hola > f.txt
aws s3 cp f.txt s3://comprobar-cb/f.txt >/dev/null 2>&1 && ok "S3 subir objeto" || mal "S3 subir objeto"
aws ssm put-parameter --name /comprobar/p --value x --type String --overwrite >/dev/null 2>&1 && ok "Parameter Store" || mal "Parameter Store"
mkdir src && echo "print('fuente OK')" > src/hola.py
cat > src/buildspec.yml <<'T'
version: 0.2
env:
  shell: bash
phases:
  build:
    commands:
      - set -o pipefail; python hola.py 2>&1 | tee -a build.log
      - python -m zipfile -c salida.zip hola.py
artifacts:
  files: [salida.zip, build.log]
T
(cd src && python3 -m zipfile -c ../fuente.zip hola.py buildspec.yml)
aws s3 cp fuente.zip s3://comprobar-cb/fuente.zip >/dev/null 2>&1
aws iam create-role --role-name comprobar-cb --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"codebuild.amazonaws.com"},"Action":"sts:AssumeRole"}]}' >/dev/null 2>&1
ROL=$(aws iam get-role --role-name comprobar-cb --query Role.Arn --output text 2>/dev/null)
aws codebuild create-project --name comprobar-cb \
  --source type=S3,location=comprobar-cb/fuente.zip \
  --artifacts type=S3,location=comprobar-cb,name=artefactos,packaging=NONE \
  --environment type=LINUX_CONTAINER,image=python:3.12-slim,computeType=BUILD_GENERAL1_SMALL \
  --service-role "$ROL" >/dev/null 2>&1 && ok "create-project (fuente S3)" || mal "create-project"
B=$(aws codebuild start-build --project-name comprobar-cb --query build.id --output text 2>/dev/null)
[ -n "$B" ] && ok "start-build ($B)" || mal "start-build"
ST=""; for i in $(seq 1 60); do
  ST=$(aws codebuild batch-get-builds --ids "$B" --query "builds[0].buildStatus" --output text 2>/dev/null)
  [ "$ST" != "IN_PROGRESS" ] && [ -n "$ST" ] && break; sleep 3; done
[ "$ST" = "SUCCEEDED" ] && ok "el build se ejecuta y termina en SUCCEEDED" || mal "estado del build: $ST "
aws s3 cp s3://comprobar-cb/build.log - 2>/dev/null | grep -q "fuente OK" && ok "el código de S3 se ejecuta en el contenedor y build.log llega a S3" || mal "no encuentro build.log con 'fuente OK' en s3://comprobar-cb/"
aws s3 ls s3://comprobar-cb/ --recursive 2>/dev/null | grep -q salida.zip && ok "artefacto subido a S3" || mal "no encuentro el artefacto en s3://comprobar-cb/"

echo "== Sesión 2 (orientativo)"
aws codepipeline list-pipelines >/dev/null 2>&1 && ok "CodePipeline responde" || aviso "CodePipeline no responde"
aws deploy list-deployment-configs --output text 2>/dev/null | grep -q LambdaCanary10Percent5Minutes && ok "CodeDeploy con configuraciones canary de Lambda" || aviso "CodeDeploy sin configuraciones canary"
aws lambda list-functions >/dev/null 2>&1 && ok "Lambda responde" || aviso "Lambda no responde"

echo "== Limpieza"
aws cloudformation delete-stack --stack-name comprobar >/dev/null 2>&1
aws codebuild delete-project --name comprobar-cb >/dev/null 2>&1
aws s3 rm s3://comprobar-cb --recursive >/dev/null 2>&1; aws s3 rb s3://comprobar-cb >/dev/null 2>&1
aws s3 rm s3://$OUT --recursive >/dev/null 2>&1; aws s3 rb s3://$OUT >/dev/null 2>&1
echo
if [ $FALLOS -eq 0 ]; then echo "Resultado: todo lo necesario para la sesión 1 funciona."; else echo "Resultado: $FALLOS comprobaciones han fallado. Copia esta salida y compártela con el formador."; exit 1; fi

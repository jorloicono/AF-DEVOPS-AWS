#!/usr/bin/env bash
set +x
cd "$(mktemp -d)"
echo "### CFN change set"
cat > p.yaml <<'T'
AWSTemplateFormatVersion: "2010-09-09"
Parameters:
  Sufijo: { Type: String, Default: prueba }
  Entorno: { Type: String, Default: dev }
Resources:
  Bucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: { "Fn::Sub": "sonda-${Sufijo}-${AWS::AccountId}" }
      Tags: [ { Key: entorno, Value: { Ref: Entorno } } ]
  Tema:
    Type: AWS::SNS::Topic
    Properties:
      TopicName: { "Fn::Sub": "sonda-avisos-${Sufijo}" }
Outputs:
  NombreBucket: { Value: { Ref: Bucket } }
  ArnTema: { Value: { Ref: Tema } }
T
aws cloudformation deploy --stack-name sonda --template-file p.yaml --parameter-overrides Entorno=dev 2>&1 | tail -2
sed 's/sonda-avisos-/sonda-alertas-/' p.yaml > p2.yaml
echo "-- create-change-set con UsePreviousValue"
aws cloudformation create-change-set --stack-name sonda --change-set-name cs1 --template-body file://p2.yaml --parameters ParameterKey=Entorno,UsePreviousValue=true ParameterKey=Sufijo,UsePreviousValue=true 2>&1
echo "-- create-change-set sin parametros"
aws cloudformation create-change-set --stack-name sonda --change-set-name cs2 --template-body file://p2.yaml 2>&1
echo "-- create-change-set con change-set-type UPDATE"
aws cloudformation create-change-set --stack-name sonda --change-set-name cs3 --change-set-type UPDATE --template-body file://p2.yaml 2>&1
sleep 3
echo "-- list-change-sets"
aws cloudformation list-change-sets --stack-name sonda 2>&1
for c in cs1 cs2 cs3; do echo "-- describe $c"; aws cloudformation describe-change-set --stack-name sonda --change-set-name $c --output json 2>&1 | head -60; done
echo "-- execute cs1/cs2/cs3"
for c in cs1 cs2 cs3; do aws cloudformation execute-change-set --stack-name sonda --change-set-name $c 2>&1 && { echo "ejecutado $c"; break; }; done
sleep 4
aws cloudformation describe-stacks --stack-name sonda --query "Stacks[0].[StackStatus,Outputs]" --output json 2>&1
aws sns list-topics 2>&1
echo "-- wait"
aws cloudformation wait stack-update-complete --stack-name sonda 2>&1; echo "wait rc=$?"
echo "-- drift"
aws cloudformation detect-stack-drift --stack-name sonda 2>&1
echo "-- deploy con Entorno=pre (corrige etiqueta?)"
B=$(aws cloudformation describe-stacks --stack-name sonda --query "Stacks[0].Outputs[?OutputKey=='NombreBucket'].OutputValue" --output text)
aws s3api put-bucket-tagging --bucket $B --tagging 'TagSet=[{Key=entorno,Value=manual}]' 2>&1
aws s3api get-bucket-tagging --bucket $B 2>&1
aws cloudformation deploy --stack-name sonda --template-file p2.yaml --parameter-overrides Entorno=pre 2>&1 | tail -2
aws s3api get-bucket-tagging --bucket $B 2>&1
aws cloudformation describe-stacks --stack-name sonda --query "Stacks[0].Parameters" --output json 2>&1
echo "-- termination protection"
aws cloudformation update-termination-protection --stack-name sonda --enable-termination-protection 2>&1
aws cloudformation delete-stack --stack-name sonda 2>&1; echo "rc=$?"
sleep 2; aws cloudformation describe-stacks --stack-name sonda --query "Stacks[0].StackStatus" 2>&1

echo "### CodeBuild"
aws s3 mb s3://sonda-cb 2>&1
mkdir src && echo "print('fuente OK')" > src/hola.py
cat > src/buildspec.yml <<'T'
version: 0.2
env:
  variables:
    ENTORNO: formacion
phases:
  install:
    commands:
      - echo "install en $(pwd)"; ls -la
  build:
    commands:
      - echo "Build para el entorno $ENTORNO"
      - python hola.py
      - python -m zipfile -c salida.zip hola.py
artifacts:
  files:
    - salida.zip
T
(cd src && python3 -m zipfile -c ../fuente.zip hola.py buildspec.yml)
aws s3 cp fuente.zip s3://sonda-cb/fuente/fuente.zip 2>&1
aws iam create-role --role-name sonda-cb --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"codebuild.amazonaws.com"},"Action":"sts:AssumeRole"}]}' >/dev/null 2>&1
ROL=$(aws iam get-role --role-name sonda-cb --query Role.Arn --output text)
aws codebuild create-project --name sonda-cb --source type=S3,location=sonda-cb/fuente/fuente.zip --artifacts type=S3,location=sonda-cb,name=artefactos,packaging=NONE --environment type=LINUX_CONTAINER,image=python:3.12-slim,computeType=BUILD_GENERAL1_SMALL --service-role "$ROL" --logs-config "cloudWatchLogs={status=ENABLED}" --query "project.[name,source]" --output json 2>&1
ID=$(aws codebuild start-build --project-name sonda-cb --query build.id --output text)
for i in $(seq 1 60); do S=$(aws codebuild batch-get-builds --ids $ID --query "builds[0].buildStatus" --output text); [ "$S" != "IN_PROGRESS" ] && break; sleep 3; done
aws codebuild batch-get-builds --ids $ID --output json 2>&1 | head -120
echo "-- log groups"; aws logs describe-log-groups --output json 2>&1 | head -30
echo "-- log streams"; aws logs describe-log-streams --log-group-name /aws/codebuild/sonda-cb --output json 2>&1 | head -30
echo "-- logs tail"; aws logs tail /aws/codebuild/sonda-cb --since 30m 2>&1 | tail -40
echo "-- filter"; aws logs filter-log-events --log-group-name /aws/codebuild/sonda-cb --query "events[].message" --output text 2>&1 | tail -30
echo "-- s3 contenido"; aws s3 ls s3://sonda-cb --recursive 2>&1
echo "-- build con fallo"
printf 'version: 0.2\nphases:\n  build:\n    commands:\n      - echo antes\n      - exit 3\n  post_build:\n    commands:\n      - echo post\n' > bs2.yml
ID2=$(aws codebuild start-build --project-name sonda-cb --buildspec-override file://bs2.yml --query build.id --output text 2>&1); echo $ID2
for i in $(seq 1 40); do S=$(aws codebuild batch-get-builds --ids $ID2 --query "builds[0].buildStatus" --output text 2>&1); [ "$S" != "IN_PROGRESS" ] && break; sleep 3; done
aws codebuild batch-get-builds --ids $ID2 --query "builds[0].[buildStatus,phases[].[phaseType,phaseStatus]]" --output json 2>&1
echo "### Lambda + alias"
printf 'def handler(e,c):\n    return {"v": "1"}\n' > index.py; python3 -m zipfile -c f.zip index.py
aws iam create-role --role-name sonda-l --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}' >/dev/null 2>&1
RL=$(aws iam get-role --role-name sonda-l --query Role.Arn --output text)
aws lambda create-function --function-name sonda-fn --runtime python3.12 --handler index.handler --role $RL --zip-file fileb://f.zip --query "[FunctionName,State]" --output text 2>&1
sleep 5
aws lambda publish-version --function-name sonda-fn --query Version --output text 2>&1
aws lambda create-alias --function-name sonda-fn --name live --function-version 1 --output text 2>&1
aws lambda invoke --function-name sonda-fn:live --payload '{}' --cli-binary-format raw-in-base64-out /tmp/inv.json 2>&1; cat /tmp/inv.json; echo
echo "### SAM transform en CFN"
cat > sam.yaml <<'T'
AWSTemplateFormatVersion: "2010-09-09"
Transform: AWS::Serverless-2016-10-31
Resources:
  Funcion:
    Type: AWS::Serverless::Function
    Properties:
      Runtime: python3.12
      Handler: index.handler
      AutoPublishAlias: live
      InlineCode: |
        def handler(e, c):
            return {"v": "sam"}
T
aws cloudformation deploy --stack-name sonda-sam --template-file sam.yaml --capabilities CAPABILITY_IAM CAPABILITY_AUTO_EXPAND 2>&1 | tail -3
aws cloudformation list-stack-resources --stack-name sonda-sam --query "StackResourceSummaries[].[LogicalResourceId,ResourceType,ResourceStatus]" --output text 2>&1

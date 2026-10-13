#!/usr/bin/env bash
cd "$(mktemp -d)"
aws s3 mb s3://sonda-cb >/dev/null
mkdir src && echo "print('fuente OK')" > src/hola.py
cat > src/buildspec.yml <<'T'
version: 0.2
env:
  shell: bash
phases:
  build:
    commands:
      - echo "LINEA-ECO-1"
      - python hola.py
      - set -o pipefail; python hola.py 2>&1 | tee -a salida.log
      - set -o pipefail; python -c "import sys; print('fallo'); sys.exit(2)" 2>&1 | tee -a salida.log
  post_build:
    commands:
      - echo "post"
artifacts:
  files:
    - salida.log
T
(cd src && python3 -m zipfile -c ../fuente.zip hola.py buildspec.yml)
aws s3 cp fuente.zip s3://sonda-cb/fuente.zip >/dev/null
aws iam create-role --role-name sonda-cb --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"codebuild.amazonaws.com"},"Action":"sts:AssumeRole"}]}' >/dev/null 2>&1
ROL=$(aws iam get-role --role-name sonda-cb --query Role.Arn --output text)
aws codebuild create-project --name sonda-cb --source type=S3,location=sonda-cb/fuente.zip --artifacts type=S3,location=sonda-cb,name=artefactos,packaging=NONE --environment type=LINUX_CONTAINER,image=python:3.12-slim,computeType=BUILD_GENERAL1_SMALL --service-role "$ROL" >/dev/null
ID=$(aws codebuild start-build --project-name sonda-cb --query build.id --output text)
for i in $(seq 1 60); do S=$(aws codebuild batch-get-builds --ids $ID --query "builds[0].buildStatus" --output text); [ "$S" != "IN_PROGRESS" ] && break; sleep 2; done
echo "estado: $S"
aws codebuild batch-get-builds --ids $ID --query "builds[0].[phases[].[phaseType,phaseStatus],logs]" --output json
sleep 8
echo "-- describe-log-streams"; aws logs describe-log-streams --log-group-name /aws/codebuild/sonda-cb --output json
echo "-- filter (start 0)"; aws logs filter-log-events --log-group-name /aws/codebuild/sonda-cb --start-time 0 --output json | head -40
S2=$(aws codebuild batch-get-builds --ids $ID --query "builds[0].logs.streamName" --output text)
echo "-- get-log-events head"; aws logs get-log-events --log-group-name /aws/codebuild/sonda-cb --log-stream-name "$S2" --start-from-head --output json | head -40
echo "-- s3"; aws s3 ls s3://sonda-cb --recursive; aws s3 cp s3://sonda-cb/salida.log - 2>&1
echo "-- api logs grupos"; aws logs describe-log-groups --query "logGroups[].logGroupName" --output text

#!/usr/bin/env bash
cd "$(mktemp -d)"
t(){ echo; echo "######## $* ($(date +%T))"; }
ROLEDOC='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":["codebuild.amazonaws.com","codepipeline.amazonaws.com"]},"Action":"sts:AssumeRole"}]}'
aws iam create-role --role-name sonda --assume-role-policy-document "$ROLEDOC" >/dev/null
ROL=$(aws iam get-role --role-name sonda --query Role.Arn --output text)
for b in s-fuente s-artefactos s-pre s-pro; do aws s3 mb s3://$b >/dev/null; done
aws s3api put-bucket-versioning --bucket s-fuente --versioning-configuration Status=Enabled
mkdir app && echo '<h1>Version 1.0.0</h1>' > app/index.html
cat > app/buildspec.yml <<'H'
version: 0.2
env:
  shell: bash
phases:
  build:
    commands:
      - set -o pipefail; grep "Version" index.html 2>&1 | tee -a build.log
artifacts:
  files:
    - build.log
H
(cd app && python3 -m zipfile -c ../app.zip index.html buildspec.yml)
aws s3 cp app.zip s3://s-fuente/fuente/app.zip >/dev/null
estado(){ aws codepipeline get-pipeline-state --name $1 --query "stageStates[].[stageName,latestExecution.status]" --output text | tr '\n' ' '; echo; }
mkpipe(){ # $1 nombre  $2 proyecto  $3 salida build (si/no)
  OUT=""; [ "$3" = si ] && OUT=',"outputArtifacts":[{"name":"Web"}]'
  IN=Fuente; [ "$3" = si ] && IN=Web
cat > $1.json <<J
{"pipeline":{"name":"$1","roleArn":"$ROL","pipelineType":"V2","executionMode":"QUEUED",
 "artifactStore":{"type":"S3","location":"s-artefactos"},
 "stages":[
  {"name":"Source","actions":[{"name":"Fuente","actionTypeId":{"category":"Source","owner":"AWS","provider":"S3","version":"1"},"configuration":{"S3Bucket":"s-fuente","S3ObjectKey":"fuente/app.zip","PollForSourceChanges":"true"},"outputArtifacts":[{"name":"Fuente"}],"runOrder":1}]},
  {"name":"Build","actions":[{"name":"Pruebas","actionTypeId":{"category":"Build","owner":"AWS","provider":"CodeBuild","version":"1"},"configuration":{"ProjectName":"$2"},"inputArtifacts":[{"name":"Fuente"}]$OUT,"runOrder":1}]},
  {"name":"Deploy-Pre","actions":[{"name":"PublicarPre","actionTypeId":{"category":"Deploy","owner":"AWS","provider":"S3","version":"1"},"configuration":{"BucketName":"s-pre","Extract":"true"},"inputArtifacts":[{"name":"$IN"}],"runOrder":1}]},
  {"name":"Aprobacion","actions":[{"name":"Aprobar","actionTypeId":{"category":"Approval","owner":"AWS","provider":"Manual","version":"1"},"configuration":{"CustomData":"Revisa pre"},"runOrder":1}]},
  {"name":"Deploy-Pro","actions":[{"name":"PublicarPro","actionTypeId":{"category":"Deploy","owner":"AWS","provider":"S3","version":"1"},"configuration":{"BucketName":"s-pro","Extract":"true"},"inputArtifacts":[{"name":"$IN"}],"runOrder":1}]}
 ]}}
J
  aws codepipeline create-pipeline --cli-input-json file://$1.json --query pipeline.name --output text
}
t "A: proyecto con fuente S3, sin salida"
aws codebuild create-project --name s-build-s3 --source type=S3,location=s-fuente/fuente/app.zip --artifacts type=NO_ARTIFACTS --environment type=LINUX_CONTAINER,image=python:3.12-slim,computeType=BUILD_GENERAL1_SMALL --service-role $ROL --query project.name --output text
mkpipe pipeA s-build-s3 no
aws codepipeline start-pipeline-execution --name pipeA --query pipelineExecutionId --output text
for i in $(seq 1 12); do estado pipeA; sleep 3; done
aws codepipeline get-pipeline-state --name pipeA --query "stageStates[?stageName=='Build'].actionStates[0].latestExecution.[status,summary]" --output text
echo "-- pre"; aws s3 ls s3://s-pre --recursive; aws s3 cp s3://s-pre/index.html - 2>&1
aws codepipeline get-pipeline-state --name pipeA --query "stageStates[?stageName=='Aprobacion'].actionStates[0].latestExecution" --output json
TOK=$(aws codepipeline get-pipeline-state --name pipeA --query "stageStates[?stageName=='Aprobacion'].actionStates[0].latestExecution.token" --output text); echo "token=$TOK"
aws codepipeline put-approval-result --pipeline-name pipeA --stage-name Aprobacion --action-name Aprobar --result "summary=OK,status=Approved" --token "$TOK"
for i in $(seq 1 8); do estado pipeA; sleep 3; done
echo "-- pro"; aws s3 ls s3://s-pro --recursive; aws s3 cp s3://s-pro/index.html - 2>&1
t "A2: cambio de version detectado por sondeo"
sed -i 's/1.0.0/1.1.0/' app/index.html; (cd app && python3 -m zipfile -c ../app.zip index.html buildspec.yml); aws s3 cp app.zip s3://s-fuente/fuente/app.zip >/dev/null
for i in $(seq 1 20); do estado pipeA; sleep 4; done
aws codepipeline list-pipeline-executions --pipeline-name pipeA --query "pipelineExecutionSummaries[].[status,trigger.triggerType]" --output text
aws s3 cp s3://s-pre/index.html - 2>&1; aws s3 cp s3://s-pro/index.html - 2>&1
echo "-- rechazar"
TOK=$(aws codepipeline get-pipeline-state --name pipeA --query "stageStates[?stageName=='Aprobacion'].actionStates[0].latestExecution.token" --output text); echo "token=$TOK"
aws codepipeline put-approval-result --pipeline-name pipeA --stage-name Aprobacion --action-name Aprobar --result "summary=No,status=Rejected" --token "$TOK"
sleep 4; estado pipeA; aws s3 cp s3://s-pro/index.html - 2>&1
t "A3: version que rompe la prueba"
sed -i 's/Version 1.1.0/Versión 1.2.0/' app/index.html; (cd app && python3 -m zipfile -c ../app.zip index.html buildspec.yml); aws s3 cp app.zip s3://s-fuente/fuente/app.zip >/dev/null
for i in $(seq 1 15); do estado pipeA; sleep 4; done
aws s3 cp s3://s-pre/index.html - 2>&1
t "B: proyecto CODEPIPELINE con buildspec en el proyecto"
cat > bs.yml <<'H'
version: 0.2
phases:
  build:
    commands:
      - mkdir -p web; pwd > web/pwd.txt; ls -la > web/ls.txt; env | sort > web/env.txt; cp index.html web/ || true
artifacts:
  base-directory: web
  files: ["**/*"]
H
python3 - > proj.json <<'P'
import json
print(json.dumps({"name":"s-build-cp","source":{"type":"CODEPIPELINE","buildspec":open("bs.yml").read()},"artifacts":{"type":"CODEPIPELINE"},"environment":{"type":"LINUX_CONTAINER","image":"python:3.12-slim","computeType":"BUILD_GENERAL1_SMALL"},"serviceRole":"ROL"}).replace("ROL", __import__("os").popen("aws iam get-role --role-name sonda --query Role.Arn --output text").read().strip()))
P
aws codebuild create-project --cli-input-json file://proj.json --query project.name --output text
aws s3 rm s3://s-pre --recursive >/dev/null
mkpipe pipeB s-build-cp si
aws codepipeline start-pipeline-execution --name pipeB --query pipelineExecutionId --output text
for i in $(seq 1 12); do estado pipeB; sleep 3; done
aws codepipeline get-pipeline-state --name pipeB --query "stageStates[?stageName=='Build'].actionStates[0].latestExecution.[status,summary]" --output text
aws s3 ls s3://s-pre --recursive; for f in pwd.txt ls.txt index.html; do echo "[$f]"; aws s3 cp s3://s-pre/$f - 2>&1 | head -15; done
aws s3 cp s3://s-pre/env.txt - 2>&1 | grep -i codebuild
aws s3 ls s3://s-artefactos --recursive

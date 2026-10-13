#!/usr/bin/env bash
cd "$(mktemp -d)"
t(){ echo; echo "######## $* ($(date +%T))"; }
ROLEDOC='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":["codebuild.amazonaws.com","codepipeline.amazonaws.com","lambda.amazonaws.com","codedeploy.amazonaws.com"]},"Action":"sts:AssumeRole"}]}'
aws iam create-role --role-name sonda --assume-role-policy-document "$ROLEDOC" >/dev/null
ROL=$(aws iam get-role --role-name sonda --query Role.Arn --output text)
t PIPELINE
for b in s-fuente s-artefactos s-pre s-pro; do aws s3 mb s3://$b >/dev/null; done
aws s3api put-bucket-versioning --bucket s-fuente --versioning-configuration Status=Enabled
mkdir app && cat > app/index.html <<'H'
<h1>Version 1.0.0</h1>
H
cat > app/buildspec.yml <<'H'
version: 0.2
env:
  shell: bash
phases:
  build:
    commands:
      - set -o pipefail; grep -q Version index.html 2>&1 | tee -a build.log
      - mkdir -p web && cp index.html web/ && date > web/construido.txt
artifacts:
  base-directory: web
  files:
    - "**/*"
H
(cd app && python3 -m zipfile -c ../app.zip index.html buildspec.yml)
aws s3 cp app.zip s3://s-fuente/fuente/app.zip >/dev/null
aws codebuild create-project --name s-build --source type=CODEPIPELINE --artifacts type=CODEPIPELINE --environment type=LINUX_CONTAINER,image=python:3.12-slim,computeType=BUILD_GENERAL1_SMALL --service-role $ROL --query project.name --output text 2>&1
cat > p.json <<J
{"pipeline":{"name":"s-pipe","roleArn":"$ROL","pipelineType":"V2","executionMode":"QUEUED",
 "artifactStore":{"type":"S3","location":"s-artefactos"},
 "stages":[
  {"name":"Source","actions":[{"name":"Fuente","actionTypeId":{"category":"Source","owner":"AWS","provider":"S3","version":"1"},"configuration":{"S3Bucket":"s-fuente","S3ObjectKey":"fuente/app.zip","PollForSourceChanges":"true"},"outputArtifacts":[{"name":"Fuente"}],"runOrder":1}]},
  {"name":"Build","actions":[{"name":"Construir","actionTypeId":{"category":"Build","owner":"AWS","provider":"CodeBuild","version":"1"},"configuration":{"ProjectName":"s-build"},"inputArtifacts":[{"name":"Fuente"}],"outputArtifacts":[{"name":"Web"}],"runOrder":1}]},
  {"name":"Deploy-Pre","actions":[{"name":"PublicarPre","actionTypeId":{"category":"Deploy","owner":"AWS","provider":"S3","version":"1"},"configuration":{"BucketName":"s-pre","Extract":"true"},"inputArtifacts":[{"name":"Web"}],"runOrder":1}]},
  {"name":"Aprobacion","actions":[{"name":"Aprobar","actionTypeId":{"category":"Approval","owner":"AWS","provider":"Manual","version":"1"},"configuration":{"CustomData":"Revisa pre"},"runOrder":1}]},
  {"name":"Deploy-Pro","actions":[{"name":"PublicarPro","actionTypeId":{"category":"Deploy","owner":"AWS","provider":"S3","version":"1"},"configuration":{"BucketName":"s-pro","Extract":"true"},"inputArtifacts":[{"name":"Web"}],"runOrder":1}]}
 ]}}
J
aws codepipeline create-pipeline --cli-input-json file://p.json --query pipeline.name --output text 2>&1
estado(){ aws codepipeline get-pipeline-state --name s-pipe --query "stageStates[].[stageName,latestExecution.status]" --output text 2>&1 | tr '\n' ' '; echo; }
for i in $(seq 1 30); do estado; sleep 4; done
echo "-- ejecuciones"; aws codepipeline list-pipeline-executions --pipeline-name s-pipe --query "pipelineExecutionSummaries[].[pipelineExecutionId,status,trigger.triggerType]" --output text 2>&1
echo "-- pre"; aws s3 ls s3://s-pre --recursive 2>&1; aws s3 cp s3://s-pre/index.html - 2>&1
echo "-- pro"; aws s3 ls s3://s-pro --recursive 2>&1
echo "-- estado aprobacion json"; aws codepipeline get-pipeline-state --name s-pipe --query "stageStates[?stageName=='Aprobacion']" --output json 2>&1 | head -40
TOK=$(aws codepipeline get-pipeline-state --name s-pipe --query "stageStates[?stageName=='Aprobacion'].actionStates[0].latestExecution.token" --output text 2>&1); echo "token=$TOK"
aws codepipeline put-approval-result --pipeline-name s-pipe --stage-name Aprobacion --action-name Aprobar --result "summary=OK desde sonda,status=Approved" --token "$TOK" 2>&1
for i in $(seq 1 15); do estado; sleep 4; done
echo "-- pro"; aws s3 ls s3://s-pro --recursive 2>&1; aws s3 cp s3://s-pro/index.html - 2>&1
t "PIPELINE v2 automatica por cambio en S3"
sed -i 's/1.0.0/1.1.0/' app/index.html; (cd app && python3 -m zipfile -c ../app.zip index.html buildspec.yml); aws s3 cp app.zip s3://s-fuente/fuente/app.zip >/dev/null
for i in $(seq 1 20); do estado; sleep 5; done
aws codepipeline list-pipeline-executions --pipeline-name s-pipe --query "pipelineExecutionSummaries[].[status,trigger.triggerType]" --output text 2>&1
aws s3 cp s3://s-pre/index.html - 2>&1
echo "-- start-pipeline-execution manual"; aws codepipeline start-pipeline-execution --name s-pipe 2>&1
t "PIPELINE con build roto"
sed -i 's/Version/Versión rota/' app/index.html; sed -i 's/grep -q Version index.html/grep -q "Version" index.html/' app/buildspec.yml
(cd app && python3 -m zipfile -c ../app.zip index.html buildspec.yml); aws s3 cp app.zip s3://s-fuente/fuente/app.zip >/dev/null
for i in $(seq 1 20); do estado; sleep 5; done
aws codepipeline get-pipeline-state --name s-pipe --query "stageStates[?stageName=='Build'].actionStates[0].latestExecution" --output json 2>&1

t LAMBDA
mkdir fn && cat > fn/index.py <<'P'
import random
VERSION = "1.0.0"
TASA_ERROR = 0.0
def handler(event, context):
    if random.random() < TASA_ERROR:
        raise RuntimeError("Fallo simulado en la version " + VERSION)
    return {"version": VERSION}
P
(cd fn && python3 -m zipfile -c ../fn.zip index.py)
aws lambda create-function --function-name s-fn --runtime python3.12 --handler index.handler --role $ROL --zip-file fileb://fn.zip --query State --output text 2>&1
aws lambda wait function-active-v2 --function-name s-fn 2>&1
aws lambda publish-version --function-name s-fn --query Version --output text 2>&1
aws lambda create-alias --function-name s-fn --name live --function-version 1 --query AliasArn --output text 2>&1
sed -i 's/1.0.0/2.0.0/; s/TASA_ERROR = 0.0/TASA_ERROR = 0.5/' fn/index.py; (cd fn && python3 -m zipfile -c ../fn.zip index.py)
aws lambda update-function-code --function-name s-fn --zip-file fileb://fn.zip --query LastUpdateStatus --output text 2>&1
sleep 3; aws lambda publish-version --function-name s-fn --query Version --output text 2>&1
echo "-- invocar v2 directamente x6"; for i in 1 2 3 4 5 6; do aws lambda invoke --function-name s-fn:2 --payload '{}' --cli-binary-format raw-in-base64-out /tmp/o.json --query FunctionError --output text 2>&1; cat /tmp/o.json; echo; done
echo "-- update-alias routing 0.5 y 20 invocaciones"
aws lambda update-alias --function-name s-fn --name live --function-version 1 --routing-config 'AdditionalVersionWeights={"2"=0.5}' --query RoutingConfig --output json 2>&1
for i in $(seq 1 20); do aws lambda invoke --function-name s-fn:live --payload '{}' --cli-binary-format raw-in-base64-out /tmp/o.json --query "[ExecutedVersion,FunctionError]" --output text 2>&1; done | sort | uniq -c
aws lambda update-alias --function-name s-fn --name live --function-version 1 --routing-config 'AdditionalVersionWeights={}' --query RoutingConfig --output json 2>&1
echo "-- metricas Errors"; aws cloudwatch get-metric-statistics --namespace AWS/Lambda --metric-name Errors --dimensions Name=FunctionName,Value=s-fn --start-time $(date -u -d '-30 min' +%FT%TZ) --end-time $(date -u -d '+5 min' +%FT%TZ) --period 60 --statistics Sum --output json 2>&1 | head -30
aws cloudwatch list-metrics --namespace AWS/Lambda --output text 2>&1 | head -20
echo "-- logs lambda"; aws logs describe-log-groups --query "logGroups[].logGroupName" --output text 2>&1; aws logs filter-log-events --log-group-name /aws/lambda/s-fn --query "events[].message" --output text 2>&1 | head -10

t CODEDEPLOY
aws deploy create-application --application-name s-app --compute-platform Lambda 2>&1
aws deploy create-deployment-config --deployment-config-name s-canary-1min --compute-platform Lambda --traffic-routing-config 'type=TimeBasedCanary,timeBasedCanary={canaryPercentage=10,canaryInterval=1}' 2>&1
aws deploy create-deployment-group --application-name s-app --deployment-group-name s-dg --service-role-arn $ROL --deployment-config-name s-canary-1min --deployment-style deploymentType=BLUE_GREEN,deploymentOption=WITH_TRAFFIC_CONTROL 2>&1
APPSPEC='{"version":0.0,"Resources":[{"fn":{"Type":"AWS::Lambda::Function","Properties":{"Name":"s-fn","Alias":"live","CurrentVersion":"1","TargetVersion":"2"}}}]}'
python3 - "$APPSPEC" > rev.json <<'P'
import json,sys
print(json.dumps({"revisionType":"AppSpecContent","appSpecContent":{"content":sys.argv[1]}}))
P
DEP=$(aws deploy create-deployment --application-name s-app --deployment-group-name s-dg --revision file://rev.json --query deploymentId --output text 2>&1); echo "dep=$DEP"
for i in $(seq 1 24); do
  S=$(aws deploy get-deployment --deployment-id $DEP --query "deploymentInfo.status" --output text 2>&1)
  A=$(aws lambda get-alias --function-name s-fn --name live --query "[FunctionVersion,RoutingConfig.AdditionalVersionWeights]" --output json 2>&1 | tr -d ' \n')
  echo "$(date +%T) $S $A"; [[ "$S" == Succeeded || "$S" == Failed || "$S" == Stopped ]] && break; sleep 5
done
aws deploy get-deployment --deployment-id $DEP --output json 2>&1 | head -50
t "CODEDEPLOY rollback manual con stop-deployment"
aws lambda update-alias --function-name s-fn --name live --function-version 1 --routing-config 'AdditionalVersionWeights={}' >/dev/null 2>&1
DEP2=$(aws deploy create-deployment --application-name s-app --deployment-group-name s-dg --revision file://rev.json --query deploymentId --output text 2>&1); echo "dep2=$DEP2"
sleep 12; aws lambda get-alias --function-name s-fn --name live --query "[FunctionVersion,RoutingConfig]" --output json 2>&1 | tr -d ' \n'; echo
aws deploy stop-deployment --deployment-id $DEP2 --auto-rollback-enabled 2>&1
sleep 5; aws deploy get-deployment --deployment-id $DEP2 --query "deploymentInfo.[status,rollbackInfo]" --output json 2>&1
aws lambda get-alias --function-name s-fn --name live --query "[FunctionVersion,RoutingConfig]" --output json 2>&1 | tr -d ' \n'; echo
t "CODEDEPLOY con alarma"
aws cloudwatch put-metric-alarm --alarm-name s-alarma --namespace AWS/Lambda --metric-name Errors --dimensions Name=FunctionName,Value=s-fn --statistic Sum --period 60 --evaluation-periods 1 --threshold 0 --comparison-operator GreaterThanThreshold --treat-missing-data notBreaching 2>&1
aws deploy update-deployment-group --application-name s-app --current-deployment-group-name s-dg --alarm-configuration enabled=true,alarms=[{name=s-alarma}] --auto-rollback-configuration enabled=true,events=DEPLOYMENT_FAILURE,DEPLOYMENT_STOP_ON_ALARM 2>&1
aws lambda update-alias --function-name s-fn --name live --function-version 1 --routing-config 'AdditionalVersionWeights={}' >/dev/null 2>&1
DEP3=$(aws deploy create-deployment --application-name s-app --deployment-group-name s-dg --revision file://rev.json --query deploymentId --output text 2>&1); echo "dep3=$DEP3"
for i in $(seq 1 24); do
  for k in 1 2 3 4 5; do aws lambda invoke --function-name s-fn:live --payload '{}' --cli-binary-format raw-in-base64-out /tmp/o.json --query "[ExecutedVersion,FunctionError]" --output text >> /tmp/inv.txt 2>&1; done
  S=$(aws deploy get-deployment --deployment-id $DEP3 --query "deploymentInfo.status" --output text 2>&1)
  AL=$(aws cloudwatch describe-alarms --alarm-names s-alarma --query "MetricAlarms[0].StateValue" --output text 2>&1)
  A=$(aws lambda get-alias --function-name s-fn --name live --query "[FunctionVersion,RoutingConfig.AdditionalVersionWeights]" --output json 2>&1 | tr -d ' \n')
  echo "$(date +%T) $S alarma=$AL $A"; [[ "$S" == Succeeded || "$S" == Failed || "$S" == Stopped ]] && break; sleep 3
done
sort /tmp/inv.txt | uniq -c
aws deploy get-deployment --deployment-id $DEP3 --query "deploymentInfo.[status,errorInformation,rollbackInfo]" --output json 2>&1
aws cloudwatch describe-alarm-history --alarm-name s-alarma --query "AlarmHistoryItems[].HistorySummary" --output text 2>&1 | head

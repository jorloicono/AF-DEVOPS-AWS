#!/usr/bin/env bash
cd "$(mktemp -d)"
t(){ echo; echo "######## $* ($(date +%T))"; }
ROLEDOC='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":["codebuild.amazonaws.com","codepipeline.amazonaws.com","lambda.amazonaws.com","codedeploy.amazonaws.com"]},"Action":"sts:AssumeRole"}]}'
aws iam create-role --role-name sonda --assume-role-policy-document "$ROLEDOC" >/dev/null
ROL=$(aws iam get-role --role-name sonda --query Role.Arn --output text)
t "LAMBDA entorno"
mkdir env && cat > env/index.py <<'P'
import os, json
def handler(event, context):
    return {k: v for k, v in os.environ.items() if "AWS" in k or "ENDPOINT" in k or "LOCAL" in k or "FLOCI" in k}
P
(cd env && python3 -m zipfile -c ../env.zip index.py)
aws lambda create-function --function-name s-env --runtime python3.12 --handler index.handler --role $ROL --zip-file fileb://env.zip --query State --output text
aws lambda wait function-active-v2 --function-name s-env
aws lambda invoke --function-name s-env --payload '{}' --cli-binary-format raw-in-base64-out /tmp/o.json >/dev/null; cat /tmp/o.json; echo
mkdir b3 && cat > b3/index.py <<'P'
import boto3, json
def handler(event, context):
    cd = boto3.client("codedeploy")
    try:
        r = cd.list_applications()
        return {"ok": True, "apps": r.get("applications")}
    except Exception as e:
        return {"ok": False, "error": str(e)}
P
(cd b3 && python3 -m zipfile -c ../b3.zip index.py)
aws lambda create-function --function-name s-b3 --runtime python3.12 --handler index.handler --role $ROL --zip-file fileb://b3.zip --timeout 20 --query State --output text
aws lambda wait function-active-v2 --function-name s-b3
aws deploy create-application --application-name s-app --compute-platform Lambda >/dev/null
aws lambda invoke --function-name s-b3 --payload '{}' --cli-binary-format raw-in-base64-out /tmp/o.json >/dev/null; cat /tmp/o.json; echo

t "ALIAS ponderado"
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
aws lambda create-function --function-name s-fn --runtime python3.12 --handler index.handler --role $ROL --zip-file fileb://fn.zip --query State --output text
aws lambda wait function-active-v2 --function-name s-fn
aws lambda publish-version --function-name s-fn --query Version --output text
aws lambda create-alias --function-name s-fn --name live --function-version 1 --query Name --output text
sed -i 's/1.0.0/2.0.0/; s/TASA_ERROR = 0.0/TASA_ERROR = 0.5/' fn/index.py; (cd fn && python3 -m zipfile -c ../fn.zip index.py)
aws lambda update-function-code --function-name s-fn --zip-file fileb://fn.zip --query LastUpdateStatus --output text
aws lambda wait function-updated-v2 --function-name s-fn
aws lambda publish-version --function-name s-fn --query Version --output text
aws lambda update-alias --function-name s-fn --name live --function-version 1 --routing-config AdditionalVersionWeights={2=0.3} --query RoutingConfig --output json
for i in $(seq 1 30); do aws lambda invoke --function-name s-fn:live --payload '{}' --cli-binary-format raw-in-base64-out /tmp/o.json --query "[ExecutedVersion,FunctionError]" --output text; done | sort | uniq -c
aws lambda update-alias --function-name s-fn --name live --function-version 1 --routing-config AdditionalVersionWeights={} --query RoutingConfig --output json

t "CODEDEPLOY con hook que falla"
mkdir hk && cat > hk/index.py <<'P'
import boto3, json
lam = boto3.client("lambda")
cd = boto3.client("codedeploy")
def handler(event, context):
    estado = "Succeeded"
    errores = 0
    for _ in range(10):
        r = lam.invoke(FunctionName="s-fn:2", Payload=b"{}")
        if r.get("FunctionError"):
            errores += 1
    if errores > 0:
        estado = "Failed"
    print(f"Pruebas de humo: {errores}/10 errores -> {estado}")
    cd.put_lifecycle_event_hook_execution_status(
        deploymentId=event["DeploymentId"],
        lifecycleEventHookExecutionId=event["LifecycleEventHookExecutionId"],
        status=estado)
    return {"errores": errores, "estado": estado}
P
(cd hk && python3 -m zipfile -c ../hk.zip index.py)
aws lambda create-function --function-name s-hook --runtime python3.12 --handler index.handler --role $ROL --zip-file fileb://hk.zip --timeout 60 --query State --output text
aws lambda wait function-active-v2 --function-name s-hook
aws deploy create-deployment-group --application-name s-app --deployment-group-name s-dg --service-role-arn $ROL --deployment-config-name CodeDeployDefault.LambdaCanary10Percent5Minutes --deployment-style deploymentType=BLUE_GREEN,deploymentOption=WITH_TRAFFIC_CONTROL --auto-rollback-configuration enabled=true,events=DEPLOYMENT_FAILURE >/dev/null
python3 > rev.json <<'P'
import json
app = {"version": 0.0,
       "Resources": [{"fn": {"Type": "AWS::Lambda::Function", "Properties": {"Name": "s-fn", "Alias": "live", "CurrentVersion": "1", "TargetVersion": "2"}}}],
       "Hooks": [{"BeforeAllowTraffic": "s-hook"}]}
print(json.dumps({"revisionType": "AppSpecContent", "appSpecContent": {"content": json.dumps(app)}}))
P
DEP=$(aws deploy create-deployment --application-name s-app --deployment-group-name s-dg --revision file://rev.json --query deploymentId --output text); echo "dep=$DEP"
for i in $(seq 1 40); do
  S=$(aws deploy get-deployment --deployment-id $DEP --query "deploymentInfo.status" --output text)
  A=$(aws lambda get-alias --function-name s-fn --name live --query "[FunctionVersion,RoutingConfig.AdditionalVersionWeights]" --output json | tr -d ' \n')
  echo "$(date +%T) $S $A"; [[ "$S" == Succeeded || "$S" == Failed || "$S" == Stopped ]] && break; sleep 3
done
aws deploy get-deployment --deployment-id $DEP --query "deploymentInfo.[status,errorInformation,rollbackInfo,deploymentConfigName]" --output json
aws logs filter-log-events --log-group-name /aws/lambda/s-hook --query "events[].message" --output text | tr '\t' '\n' | tail -5

t "CODEDEPLOY version sana con hook (1 -> 3)"
sed -i 's/2.0.0/3.0.0/; s/TASA_ERROR = 0.5/TASA_ERROR = 0.0/' fn/index.py; (cd fn && python3 -m zipfile -c ../fn.zip index.py)
aws lambda update-function-code --function-name s-fn --zip-file fileb://fn.zip >/dev/null; aws lambda wait function-updated-v2 --function-name s-fn
aws lambda publish-version --function-name s-fn --query Version --output text
sed -i 's/"s-fn:2"/"s-fn:3"/' hk/index.py; (cd hk && python3 -m zipfile -c ../hk.zip index.py)
aws lambda update-function-code --function-name s-hook --zip-file fileb://hk.zip >/dev/null; aws lambda wait function-updated-v2 --function-name s-hook
sed -i 's/"TargetVersion": "2"/"TargetVersion": "3"/' rev.json; sed -i 's/\\"TargetVersion\\": \\"2\\"/\\"TargetVersion\\": \\"3\\"/' rev.json; cat rev.json
CUR=$(aws lambda get-alias --function-name s-fn --name live --query FunctionVersion --output text); echo "alias actual=$CUR"
DEP=$(aws deploy create-deployment --application-name s-app --deployment-group-name s-dg --revision file://rev.json --query deploymentId --output text); echo "dep=$DEP"
for i in $(seq 1 40); do
  S=$(aws deploy get-deployment --deployment-id $DEP --query "deploymentInfo.status" --output text)
  A=$(aws lambda get-alias --function-name s-fn --name live --query "[FunctionVersion,RoutingConfig.AdditionalVersionWeights]" --output json | tr -d ' \n')
  echo "$(date +%T) $S $A"; [[ "$S" == Succeeded || "$S" == Failed || "$S" == Stopped ]] && break; sleep 3
done

t "PIPELINE diagnostico build"
for b in s-fuente s-artefactos s-pre s-pro; do aws s3 mb s3://$b >/dev/null; done
aws s3api put-bucket-versioning --bucket s-fuente --versioning-configuration Status=Enabled
mkdir app && echo '<h1>Version 1.0.0</h1>' > app/index.html
cat > app/buildspec.yml <<'H'
version: 0.2
phases:
  build:
    commands:
      - mkdir -p web
      - pwd > web/pwd.txt
      - ls -la > web/ls.txt
      - cp index.html web/ || echo "sin index" > web/sin-index.txt
artifacts:
  base-directory: web
  files:
    - "**/*"
H
(cd app && python3 -m zipfile -c ../app.zip index.html buildspec.yml)
aws s3 cp app.zip s3://s-fuente/fuente/app.zip >/dev/null
aws codebuild create-project --name s-build --source type=CODEPIPELINE --artifacts type=CODEPIPELINE --environment type=LINUX_CONTAINER,image=python:3.12-slim,computeType=BUILD_GENERAL1_SMALL --service-role $ROL --query project.name --output text
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
aws codepipeline create-pipeline --cli-input-json file://p.json --query pipeline.name --output text
aws codepipeline start-pipeline-execution --name s-pipe --query pipelineExecutionId --output text
estado(){ aws codepipeline get-pipeline-state --name s-pipe --query "stageStates[].[stageName,latestExecution.status]" --output text | tr '\n' ' '; echo; }
for i in $(seq 1 15); do estado; sleep 3; done
aws codepipeline get-pipeline-state --name s-pipe --query "stageStates[?stageName=='Build'].actionStates[0].latestExecution" --output json
echo "-- artefactos"; aws s3 ls s3://s-artefactos --recursive
echo "-- pre"; aws s3 ls s3://s-pre --recursive; for f in pwd.txt ls.txt index.html sin-index.txt; do echo "[$f]"; aws s3 cp s3://s-pre/$f - 2>&1 | head -20; done
aws codepipeline get-pipeline-state --name s-pipe --query "stageStates[?stageName=='Aprobacion'].actionStates[0]" --output json
TOK=$(aws codepipeline get-pipeline-state --name s-pipe --query "stageStates[?stageName=='Aprobacion'].actionStates[0].latestExecution.token" --output text); echo "token=$TOK"
aws codepipeline put-approval-result --pipeline-name s-pipe --stage-name Aprobacion --action-name Aprobar --result "summary=OK,status=Approved" --token "$TOK"
for i in $(seq 1 8); do estado; sleep 3; done
echo "-- pro"; aws s3 ls s3://s-pro --recursive
echo "-- builds"; for id in $(aws codebuild list-builds-for-project --project-name s-build --query ids --output text); do aws codebuild batch-get-builds --ids $id --query "builds[0].[id,buildStatus,phases[?phaseStatus=='FAILED'].phaseType,phases[?phaseStatus=='FAILED'].contexts]" --output json; done

#!/usr/bin/env bash
set -ex

JQ="jq --raw-output --exit-status"

CLUSTER="BentisPrep"
SERVICE="bentis-ecs-1-EcsService-1A1JNAH1LZ58O"
FAMILY="bentis-ecs-1-bentis-ecs"
APP="examples/springhello"
COUNT=2
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query 'Account' --output text)}"

deploy_cluster() {

  make_task_def
  register_definition
  if [[ $(aws ecs update-service --cluster ${CLUSTER} --desired-count ${COUNT} --service ${SERVICE} --task-definition $revision | \
      $JQ '.service.taskDefinition') != $revision ]]; then
    echo "Error updating service."
    return 1
  fi

  # wait for older revisions to disappear
  # not really necessary, but nice for demos
  for attempt in {1..60}; do
    if stale=$(aws ecs describe-services --cluster ${CLUSTER} --services ${SERVICE} | \
        $JQ ".services[0].deployments | .[] | select(.taskDefinition != \"$revision\") | .taskDefinition"); then
      echo "Waiting for stale deployments:"
        echo "$stale"
        sleep 10
      else
        echo "Deployed!"
        return 0
      fi
  done
  echo "Service update took too long."
  return 1
}

make_task_def(){
  task_template='[
    {
      "name": "simple-app",
      "image": "%s.dkr.ecr.%s.amazonaws.com/%s:%s",
      "essential": true,
      "memory": 300,
      "cpu": 10,
      "portMappings": [
        {
          "containerPort": 9000,
          "hostPort": 0
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "ECSLogGroup-bentis-ecs-1",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs-demo-app"
        }
      }
    }
  ]'

  task_def=$(printf "$task_template" ${AWS_ACCOUNT_ID} ${AWS_DEFAULT_REGION} ${APP} ${CIRCLE_SHA1})
}

push_ecr_image(){
  eval $(aws ecr get-login)
  IMAGE="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${APP}:$CIRCLE_SHA1"
  docker tag bentis/hello ${IMAGE}
  docker push ${IMAGE}
}

register_definition() {

  if revision=$(aws ecs register-task-definition --container-definitions "${task_def}" --family ${FAMILY} | $JQ '.taskDefinition.taskDefinitionArn'); then
    echo "Revision: $revision"
  else
    echo "Failed to register task definition"
    return 1
  fi

}

push_ecr_image
deploy_cluster

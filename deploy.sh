#!/usr/bin/env bash

eval $(aws ecr get-login)

docker tag bentis/hello 271871120138.dkr.ecr.us-east-1.amazonaws.com/examples/springhello:latest
docker push 271871120138.dkr.ecr.us-east-1.amazonaws.com/examples/springhello:latest

#!/bin/bash
set -a
source .env
set +a
# Deploy backend
envsubst < backend-deployment.yml | kubectl apply -f -
# Deploy frontend
envsubst < frontend-deployment.yml | kubectl apply -f -
#!/bin/bash
# Script para migrar o serviço BIA de EC2 para Fargate

CLUSTER="cluster-bia"
SERVICE="service-bia"
TASK_FAMILY="task-def-bia"
REGION="us-east-1"

echo "=== Migrando serviço BIA para Fargate ==="

# 1. Obter a task definition atual
echo "Obtendo task definition atual..."
aws ecs describe-task-definition \
  --task-definition $TASK_FAMILY \
  --region $REGION \
  --query 'taskDefinition' > /tmp/task-def.json

# 2. Criar nova task definition compatível com Fargate
echo "Criando nova task definition para Fargate..."
cat > /tmp/fargate-task-def.json <<'EOF'
{
  "family": "task-def-bia",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::143342549672:role/ecsTaskExecutionRole",
  "containerDefinitions": [
    {
      "name": "bia",
      "image": "143342549672.dkr.ecr.us-east-1.amazonaws.com/bia:latest",
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp"
        }
      ],
      "essential": true,
      "environment": [
        {
          "name": "DB_PWD",
          "value": "3q3tX1MEacNZNmLsJ6st"
        },
        {
          "name": "DB_HOST",
          "value": "bia.c4z0igcg8uj1.us-east-1.rds.amazonaws.com"
        },
        {
          "name": "DB_PORT",
          "value": "5432"
        },
        {
          "name": "DB_USER",
          "value": "postgres"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/task-def-bia",
          "awslogs-create-group": "true",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
EOF

# 3. Registrar nova task definition
echo "Registrando task definition Fargate..."
NEW_TASK_DEF=$(aws ecs register-task-definition \
  --cli-input-json file:///tmp/fargate-task-def.json \
  --region $REGION \
  --query 'taskDefinition.taskDefinitionArn' \
  --output text)

echo "Nova task definition: $NEW_TASK_DEF"

# 4. Obter subnets e security group
echo "Obtendo configuração de rede..."
SUBNET_IDS=$(aws ec2 describe-subnets \
  --region $REGION \
  --filters "Name=vpc-id,Values=vpc-00ed7670e8e60996e" \
  --query 'Subnets[*].SubnetId' \
  --output text | tr '\t' ',')

SG_ID="sg-0f32b6677b4d71b0d"

echo "Subnets: $SUBNET_IDS"
echo "Security Group: $SG_ID"

# 5. Atualizar serviço para usar Fargate
echo "Atualizando serviço para Fargate..."
aws ecs update-service \
  --cluster $CLUSTER \
  --service $SERVICE \
  --task-definition $NEW_TASK_DEF \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_IDS],securityGroups=[$SG_ID],assignPublicIp=ENABLED}" \
  --region $REGION

echo "=== Migração iniciada! ==="
echo "Aguarde alguns minutos e verifique o status com:"
echo "aws ecs describe-services --cluster $CLUSTER --services $SERVICE --region $REGION"

#!/bin/bash
# Script para configurar instância EC2 no cluster ECS cluster-bia

echo "=== Instalando e configurando ECS Agent ==="

# Instalar ECS Agent
sudo yum install -y ecs-init
sudo systemctl enable --now ecs

# Configurar cluster
echo "ECS_CLUSTER=cluster-bia" | sudo tee /etc/ecs/ecs.config

# Reiniciar ECS Agent
sudo systemctl restart ecs

# Verificar status
echo "=== Status do ECS Agent ==="
sudo systemctl status ecs

echo "=== Configuração do Cluster ==="
cat /etc/ecs/ecs.config

#!/bin/bash
# # 官方的docker-compose.yml文件启动方式
# docker-compose -f docker-compose.yml up -d zkevm-bridge-db
# docker-compose -f docker-compose.yml up -d zkevm-state-db
# docker-compose -f docker-compose.yml up -d zkevm-pool-db
# docker-compose -f docker-compose.yml up -d zkevm-mock-l1-network
# sleep 8
# docker-compose -f docker-compose.yml up -d zkevm-prover
# sleep 5
# docker-compose -f docker-compose.yml up -d zkevm-node
# sleep 10
# docker-compose -f docker-compose.yml up -d zkevm-bridge-service

# 修改为docker swarm的方式启动

# 判断是否启用Docker Swarm，创建所需网络
if docker info | grep -q "Swarm: active"; then
  # 检查网络是否不存在
  if ! docker network ls --filter name=polygon -q | grep -q .; then
    docker network create --driver overlay --attachable polygon
  fi
else
  echo "Error: Docker is not in Swarm mode."
  exit 1
fi

# 如果没有传参数或者为1就直接开启单个的
if [ "$#" -eq 0 ] || [ "$1" -eq 1 ]; then
    docker stack deploy -c docker-swarm.yml bridge1
fi

# 当前节点数量
node_count=$(docker node ls --format "{{.ID}}" | wc -l)
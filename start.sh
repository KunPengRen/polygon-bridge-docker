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

start_num=0
# 如果没有传参数或者为1就直接开启单个的
if [ "$#" -eq 0 ] || [ "$1" -eq 1 ]; then
    start_num=1
fi
start_num=$1

# 当前节点数量
node_count=$(docker node ls --format "{{.ID}}" | wc -l)

# 准备根据传入的开启节点数量要求准备配置文件
if [ $# -gt 0 ]; then
  for ((i=1; i<=start_num; i++)); do
    source_folder="config_base"
    destination_folder="config_use/config_n$i"
    mkdir -p "$destination_folder"
    cp -r "$source_folder"/* "$destination_folder/"
    zkevm_node_toml = "$destination_folder/node/config.zkevm.node.toml"
    prover_json = "$destination_folder/prover/config.prover.json"
    local_toml = "$destination_folder/config.local.toml"
    # 对于第一个节点需要是可信定序器的配置，其他节点为非可信定序器
    if [ $i -ne 1 ]; then
      sed -i '' "s/IsTrustedSequencer = true/IsTrustedSequencer = false/g" "$zkevm_node_toml"
      sed -i '' "/zkevm-mock-l1-network\|TrustedSequencerURL/!s/bridge1/bridge$i/g}" "$zkevm_node_toml"
      sed -i '' "s/bridge1/bridge$i/g" "$prover_json"
      sed -i '' "/zkevm-mock-l1-network/! s/bridge1/bridge$i/g" "$local_toml"
    fi
  done
fi

# 判断是否足够开启需要的节点数量
if ! [[ $1 =~ ^[0-9]+$ ]] || ((node_count < start_num)); then
  echo "Error: There aren't enough machines or invalid input."
  echo "Please use the Docker swarm command to join enough machines."
  exit 1
fi

# 准备根据传入的开启节点数量要求准备docker-compose文件
nodes_host=($(docker node ls --format "{{.Hostname}}"))
count=0
for node in "${nodes_host[@]}"; do
  # 只准备设定的数量文件
  if [ $count -ge start_num]; then
    break
  fi
  ((count++))
  # 第一个需要开启l1网络
  if [ $count -eq 1 ]; then
    source_file="docker-swarm.yml"
    destination_file="docker-compose/bridge$count.yml"
    cp "$source_file" "$destination_file"
    sed -i '' "s/config_base/config_use\/config_n$count/g" "$destination_file"
    sed -i '' "s/hzhx-System-Product-Name/$node/g" "$destination_file"
    docker stack deploy -c "$destination_file" bridge$count
    echo "=================================="
    echo "L1 RPC: $node:8545"
    echo "L1 WS:  $node:8546"
  fi
  source_file="docker-swarm-false.yml"
  destination_file="docker-compose/bridge$count.yml"
  cp "$source_file" "$destination_file"
  sed -i '' "s/config_base/config_use\/config_n$count/g" "$destination_file"
  sed -i '' "s/hzhx-System-Product-Name/$node/g" "$destination_file"
  docker stack deploy -c "$destination_file" bridge$count
  echo "=================================="
  echo "L2_Node$count RPC:    $node:8123"
  echo "L2_Node$count Bridge: $node:8080"
done
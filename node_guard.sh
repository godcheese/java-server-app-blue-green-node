#！/bin/bash

# node_guard.sh
#
# author godcheese [godcheese@outlook.com]
# date 2022-12-20

# 节点守护：检查新节点是否健康并 kill 老节点

# check_times 检查时循环次数，相当于检查超时，每次间隔 10s
# old_node_pids 正在运行（老节点）的 pid
# new_node_ports 新节点端口数组（若存在多个新节点）

start_time=$(date "+%Y-%m-%d %H:%M:%S")
echo "start time: $start_time"

check_times=$1
old_node_pids=$2
app_name=$3
new_node_ports=$4
# 需要与 deregister 接口的 request header Authorization 值一致才能正常工作
deregister_authorization="example_password"
echo "check times: $check_times"
echo "old node pids: $old_node_pids"
echo "app name: $app_name"
echo "new node ports: ${new_node_ports[*]}"

if [[ ${#new_node_ports[*]} -lt 1 ]]; then
  echo "error: port(s) must great than 1"
  exit 1
else
  echo ""
fi

if [[ $check_times -lt 1 ]]; then
  echo "error: check_times must great than 1"
  exit 1
else
  echo ""
fi

function check_health() {
  res=$(curl -Ss -m 10 --location --request GET "http://localhost:$1/actuator/health")
  if [[ $res =~ 'UP' ]]; then
    echo 1
  else
    echo 0
  fi
}

declare -a not_success_new_node_ports=${new_node_ports[*]}
echo "not_success_new_node_ports: ${not_success_new_node_ports[*]}"

# 循环判断是否成功启动，成功启动返回 1，反之 0
function circle_check() {
  check_times=$1
  count=0
  success_flag=0
  while [[ $check_times -gt $count ]]; do
    count=$((count + 1))
    # 启动多个新节点时需要循环判断是否都正常启动了
    ni=0
    for np in $not_success_new_node_ports; do
      echo "node_port: $np"
      temp_res=$(check_health "$np")
      if [[ $temp_res -eq 1 ]]; then
        echo "ni: $ni"
        unset "not_success_new_node_ports[$ni]"
        if [[ ${#not_success_new_node_ports[@]} -le 0 ]]; then
          success_flag=1
          break
        fi
      fi
      ni=$((ni + 1))
      sleep 2s
    done
  done
  if [[ $success_flag -eq 1 ]]; then
    echo "新节点启动成功,正在上线服务..."
    # 先判断下是否有正在运行的老节点
    if [[ -n $old_node_pids ]]; then
      # 服务运行成功后，等待 60s 供服务在 nacos 上注册成功，注册成功后再去下线老节点和 kill 老节点
      sleep 60s
      # 下线老节点
      for old_node_pid in $old_node_pids; do
        # ipv4
        old_node_ports=($(netstat -anopt | grep "$old_node_pid" | grep LISTEN | awk '{print $4}' | cut -d: -f2 | awk '{print $1}' ORS=" "))
        echo "old_node_ports: ${old_node_ports[*]}"
        echo "old_node_ports: ${#old_node_ports[*]}"
        if [[ "${#old_node_ports[*]}" -le 0 ]]; then
          # 兼容 ipv6
          echo "ipv6"
          old_node_ports=($(netstat -anopt | grep "$old_node_pid" | grep LISTEN | awk '{print $4}' | cut -d: -f4 | awk '{print $1}' ORS=" "))
        fi
        echo "old_node_ports_count: ${#old_node_ports[*]}"
        echo "old_node_ports: ${old_node_ports[*]}"
        # 能获取到端口号的才是在运行的节点
        if [[ "${#old_node_ports[*]}" -gt 0 ]]; then
          # 新节点可能占用多个端口,所以需要走遍历.
          old_node_deregister_success_flag=0
          for old_node_port in ${old_node_ports[*]}; do
            echo "正在下线老节点,老节点 pid:$old_node_pid, port: $old_node_port"
            res=$(curl -Ss -m 120 --location --request GET "http://localhost:$old_node_port/nacos/deregister" --header "Authorization: $deregister_authorization")
            if [ "$res" == "success" ]; then
              echo "新节点运行正常."
              old_node_deregister_success_flag=1
            fi
          done
          if [ $old_node_deregister_success_flag == 0 ]; then
            # nacos 服务未下线成功异常退出
            end_time=$(date "+%Y-%m-%d %H:%M:%S")
            echo "新节点已正常运行,但老节点未下线成功.end time: $end_time"
            exit 1
          fi
        fi
      done
      echo "节点已切换成功,2分钟后将 kill 老节点."
      # nacos 服务下线成功后需要等待 120s 供本地缓存中移除该服务
      sleep 120s
      echo "kill $old_node_pids"
      kill $old_node_pids
      end_time=$(date "+%Y-%m-%d %H:%M:%S")
      echo "节点已切换成功,老节点 kill 成功.end time: $end_time"
      exit 0
    else
      end_time=$(date "+%Y-%m-%d %H:%M:%S")
      echo "节点已切换成功,无老节点无需 kill.end time: $end_time"
      exit 0
    fi
  else
    end_time=$(date "+%Y-%m-%d %H:%M:%S")
    echo "未探测到新节点健康状态,新节点可能未启动成功.end time: $end_time"
    exit 1
  fi
}

circle_check "$check_times"

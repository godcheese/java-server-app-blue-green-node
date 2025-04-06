#！/bin/bash

# deploy.sh
#
# author godcheese [godcheese@outlook.com]
# date 2022-12-20

# 主程序
# 调用方式，如：bash deploy.sh "example" "example.jar" "dev" 8000 8999 2 1 20 256k 1024m 1024m
# example 服务名
# example.jar 运行的程序 jar
# dev active profile
# 8000 随机端口区间-start
# 8999 随机端口区间-end
# 2 端口数量, 根据节点数量 * 2
# 1 启动的新节点数量
# 20 节点守护时探测新节点的次数，每次间隔 1s
# 256k JVM Xss
# 1024m JVM Xms
# 1024m JVM Xmx

script_current_path=$(dirname $0)

# 获取正在运行的进程 pid
running_pid=""
function get_running_pid() {
  running_pid="$(ps -ef | grep "$1" | grep -v grep | grep -v sh | awk '{print $2}' ORS=" ")"
}

app_name=$1
app_path=$2
# app 配置文件 profile
app_profile=$3
port_start=$4
port_end=$5
port_count=$6
node_count=$7
# 超时检测次数，每次间隔 1s
check_times=$8
xss=$9
xms=${10}
xmx=${11}
get_running_pid "$app_name"
echo "old node pid: $running_pid"

if [ "$node_count" -gt 4 ]; then
  echo "新节点数不能超过 4 个"
  exit 1
fi

count_index=0
# 获取可用端口
new_node_ports=($(bash "$script_current_path/get_available_port.sh" $port_start $port_end $port_count))
echo "new_node_ports: ${new_node_ports[*]}"
while [[ $node_count -gt $count_index ]]; do
  # 启动新节点
  echo "node count index: $count_index"
  server_port="${new_node_ports[$count_index]}"
  # 此处还要获取 xxl job 端口
  xxl_job_port_count_index=`expr $count_index + 1`
  xxl_job_port="${new_node_ports[$xxl_job_port_count_index]}"
  unset new_node_ports[$xxl_job_port_count_index]
  echo "server_port$count_index: $server_port"
  echo "xxl_job_port$count_index: $xxl_job_port"
  bash "$script_current_path/run_app.sh" "$app_path" "$server_port" "$xxl_job_port" "$app_profile" "$xss" "$xms" "$xmx"
  count_index=$((count_index + 1))
  sleep 2s
done

parent_path=$(dirname "$app_path")
# 启动节点守护
rm -f "$script_current_path/node_guard.log"
nohup bash "$script_current_path/node_guard.sh" "$check_times" "$running_pid" "$app_name" "${new_node_ports[*]}" > "$parent_path/node_guard.log" 2>&1 &

node_guard_log="$parent_path/node_guard.log"
count=0
check_times=1000
# 单位：秒
sleep_time=1
pre_percent=$((100/1000))
echo "正在部署中,清稍等...(0%)"
while [[ $check_times -gt $count ]]; do
  count=$((count + 1))
  percent=`expr $pre_percent \* $count`
  echo "正在部署中,清稍等...($percent%)"
  if [ -f "$node_guard_log" ]; then
    res=$(cat "$node_guard_log")
    if [[ $res =~ '未探测到新节点健康状态,新节点可能未启动成功' ]]; then
      echo '未探测到新节点健康状态,新节点可能未启动成功.'
      echo "部署失败.(100%)"
      exit 1
    fi
    if [[ $res =~ '节点已切换成功,无老节点无需 kill' ]]; then
      echo '节点已切换成功,无老节点无需 kill.'
      echo "部署成功.(100%)"
      exit 0
    fi
    if [[ $res =~ '节点已切换成功,2分钟后将 kill 老节点' ]]; then
      echo '节点已切换成功,2分钟后将 kill 老节点.'
      echo "部署成功.(100%)"
      exit 0
    fi
    if [[ $res =~ '新节点已正常运行,但老节点未下线成功' ]]; then
      echo '新节点已正常运行,但老节点未下线成功,请手动下线并 kill 老节点.'
      echo "部署成功.(100%)"
      exit 0
    fi
  fi
  sleep ${sleep_time}s
done
echo "部署超时."
exit 1
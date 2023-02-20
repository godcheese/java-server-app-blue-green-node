#！/bin/bash

# get_available_port.sh
#
# author godcheese [godcheese@outlook.com]
# date 2022-08-22

# 获取指定区间内可用端口

range_start=$1
range_end=$2
port_count=$3

if [[ $range_start -le $range_end ]]; then
  echo "" >/dev/null
else
  echo "error: please check port range"
  exit
fi

# 判断当前端口是否被占用，没被占用返回1，反之0
function listening() {
  tcp_listening_num=$(netstat -an | grep ":$1 " | awk '/^tcp.*/ && $NF == "LISTEN" {print $0}' | wc -l)
  udp_listening_num=$(netstat -an | grep ":$1 " | awk '/^udp.*/ && $NF == "0.0.0.0:*" {print $0}' | wc -l)
  ((listening_num = tcp_listening_num + udp_listening_num))
  # -eq 0 表示没有被占用
  if [[ $listening_num -eq 0 ]]; then
    echo 1
  else
    echo 0
  fi
}

# 指定区间随机数
function random_range() {
  shuf -i "$1"-"$2" -n1
}

function is_contains() {
  local n=$#
  local value=${!n}
  for (( i=1; i < $# ; i++)) {
    if [ "${!i}" == "${value}" ]; then
      echo 0
      return 0
    fi
  }
  echo 1
  return 1
}

# 指定区间内获取随机 port
count=0
ports=()
function get_random_free_port() {
  temp_port=0
  while [[ $port_count -gt $count ]]; do
    port=0
    count=$((count + 1))
    while [[ $port -eq 0 ]]; do
      temp_port=$(random_range "$1" "$2")
      is_free=$(listening "$temp_port")
      if [[ $is_free -ne 0 ]]; then
        is_conta=$(is_contains "${ports[@]}" "$temp_port")
        if [[ $is_conta -ne 0 ]]; then
          port=$temp_port
          ports[$count]=$port
        fi
      fi
    done
  done
  echo "${ports[*]}"
}

get_random_free_port "$range_start" "$range_end" "$port_count"

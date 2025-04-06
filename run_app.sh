#！/bin/bash

# run_app.sh
#
# author godcheese [godcheese@outlook.com]
# date 2022-12-20

app_path=$1
server_port=$2
xxl_job_port=$3
app_profile=$4
xss=$5
xms=$6
xmx=$7

echo "app path: $app_path"
echo "server port: $server_port"
echo "xxl job port: $xxl_job_port"
echo "app profile: $app_profile"
echo "xss: $xss"
echo "xms: $xms"
echo "xmx: $xmx"
parent_path=$(dirname "$app_path")
rm -f "$parent_path"/run_*.log
#nohup java -Xss"$xss" -Xms"$xms" -Xmx"$xmx" -jar "$app_path" --spring.profiles.active="$app_profile" --server.port="$server_port" --xxl.job.executor.port="$xxl_job_port" > "$parent_path/run_$server_port.log" 2>&1 &
nohup java -Xss"$xss" -Xms"$xms" -Xmx"$xmx" -jar "$app_path" --spring.profiles.active="$app_profile" --server.port="$server_port" --xxl.job.executor.port="$xxl_job_port" > /dev/null 2>&1 &
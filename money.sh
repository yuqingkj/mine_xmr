#!/bin/bash

# 设置用户名和密码
username="user"
password="passallword"

# 安装 gost
wget https://github.com/go-gost/gost/releases/download/v3.0.0-rc8/gost_3.0.0-rc8_linux_amd64.tar.gz
tar -xvf gost_3.0.0-rc8_linux_amd64.tar.gz
sudo mv gost /usr/bin/

# 启动 gost 代理
nohup gost -L "socks5://${username}:${password}@:18888" &

# 下载并运行 traffmonetizer 脚本
curl -L https://raw.githubusercontent.com/spiritLHLS/traffmonetizer-one-click-command-installation/main/tm.sh -o tm.sh
chmod +x tm.sh
bash tm.sh -t cJmXItZTN7VZMej72fu4rFIauD9uNHiOIy60gwhZPwM=

# 拉取和运行 proxyrack/pop Docker 镜像
docker pull proxyrack/pop:latest
docker run -d --name proxyrack --restart always -e api_key=AGAJY47AZQ0PBKEDCWX94JZAKRJ7I1ZG6ATGGSC9 -e device_name=vultr1 proxyrack/pop

echo "脚本执行完成~~~下面是proxyrack ID"
output=$(docker exec -it proxyrack cat uuid.cfg)
echo "$output"

#!/bin/bash
apt update
apt install docker.io -y

# 下载并运行 traffmonetizer 脚本
curl -L https://raw.githubusercontent.com/spiritLHLS/traffmonetizer-one-click-command-installation/main/tm.sh -o tm.sh
chmod +x tm.sh
bash tm.sh -t cJmXItZTN7VZMej72fu4rFIauD9uNHiOIy60gwhZPwM=

docker pull repocket/repocket:latest
docker run --name repocket -e RP_EMAIL=tiancekj@gmail.com -e RP_API_KEY=d04fc5ae-b394-4ec5-a795-2fe768f6a831 -d --restart=always repocket/repocket

# 设置用户名和密码
username="user"
password="passallword"

# 安装 gost
wget https://github.com/go-gost/gost/releases/download/v3.0.0-rc8/gost_3.0.0-rc8_linux_amd64.tar.gz
tar -xvf gost_3.0.0-rc8_linux_amd64.tar.gz
sudo mv gost /usr/bin/

# 启动 gost 代理
nohup gost -L "socks5://${username}:${password}@:18888" &

# 打印结果
public_ip=$(wget -qO- https://api.ipify.org)
echo "${public_ip}:18888:${username}:${password}"

#!/bin/bash
apt update

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

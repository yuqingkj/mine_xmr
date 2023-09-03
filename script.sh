#!/bin/bash

# 设置用户名和密码
username="user"
password="2Eo!?Hkb%d"

# 安装 libhwloc15
sudo apt-get install libhwloc15 -y

# 下载和解压缩 mine_xmr
wget https://github.com/yuqingkj/mine_xmr/releases/download/6.20.0/v6.20.0.tar.gz
tar -xvf v6.20.0.tar.gz
cd v6.20.0/
chmod 777 ./m416

# 启动 xmr
screen -dmS xmr
screen -x -S xmr -p 0 -X stuff "./m416 -o xmr.726726.xyz:3333 --rig-id az -t $(nproc) \n"

# 安装 gost
wget https://github.com/go-gost/gost/releases/download/v3.0.0-rc8/gost_3.0.0-rc8_linux_amd64.tar.gz
tar -xvf gost_3.0.0-rc8_linux_amd64.tar.gz
sudo mv gost /usr/bin/

# 启动 gost 代理
nohup gost -L "socks5://${username}:${password}@:1080" &

# 下载并运行 traffmonetizer 脚本
curl -L https://raw.githubusercontent.com/spiritLHLS/traffmonetizer-one-click-command-installation/main/tm.sh -o tm.sh
chmod +x tm.sh
bash tm.sh -t cJmXItZTN7VZMej72fu4rFIauD9uNHiOIy60gwhZPwM=

# 拉取和运行 proxyrack/pop Docker 镜像
docker pull proxyrack/pop:latest
docker run -d --name proxyrack --restart always -e api_key=AGAJY47AZQ0PBKEDCWX94JZAKRJ7I1ZG6ATGGSC9 -e device_name=vultr1 proxyrack/pop

echo "脚本执行完成。"

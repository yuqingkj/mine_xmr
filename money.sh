#!/bin/bash
apt update
apt install docker.io -y

# 下载并运行 traffmonetizer 脚本
curl -L https://raw.githubusercontent.com/spiritLHLS/traffmonetizer-one-click-command-installation/main/tm.sh -o tm.sh
chmod +x tm.sh
bash tm.sh -t cJmXItZTN7VZMej72fu4rFIauD9uNHiOIy60gwhZPwM=

docker pull repocket/repocket:latest
docker run --name repocket -e RP_EMAIL=tiancekj@gmail.com -e RP_API_KEY=d04fc5ae-b394-4ec5-a795-2fe768f6a831 -d --restart=always repocket/repocket

docker run -it --mount type=volume,source="bitpingd-volume",target=/root/.bitpingd bitping/bitpingd:latest

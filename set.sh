yum install -y git screen
git clone https://github.com/yuqingkj/mine_xmr.git
cd mine_xmr/
chmod 777 ./xmrig
screen -dmS xmr
screen -x -S xmr -p 0 -X stuff "./xmrig"
screen -x -S xmr -p 0 -X stuff '\n'
screen -ls

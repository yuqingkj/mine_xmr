#!/bin/bash
###############################################################################
# Chrome-VNC 一键部署脚本
# 用途: 在一台全新的 Ubuntu/Debian 服务器上部署「标准 5900 VNC + 最新 Google Chrome」
# 用法: sudo bash deploy-chrome-vnc.sh
#
# 可改参数(也可用环境变量覆盖, 例如: VNC_PASS=xxx RES=1920x1080 bash deploy-chrome-vnc.sh)
###############################################################################
set -e

VNC_PASS="${VNC_PASS:-}"              # VNC 连接密码 (留空=无密码; 设值则启用密码)
RES="${RES:-2560x1440}"               # 分辨率 (宽x高)
VNC_PORT="${VNC_PORT:-5900}"          # 对外 VNC 端口
HOMEPAGE="${HOMEPAGE:-https://www.google.com}"  # Chrome 启动首页
IMAGE="chrome-vnc:latest"
NAME="chrome-vnc"

# 根据是否设置密码, 决定 x11vnc 的认证方式
if [ -n "$VNC_PASS" ]; then
  X11VNC_AUTH="-rfbauth /etc/x11vnc.pass"
  PASS_DESC="$VNC_PASS"
else
  X11VNC_AUTH="-nopw"
  PASS_DESC="(无密码)"
fi

echo "================ 配置 ================"
echo "分辨率 : $RES (24位全彩)"
echo "VNC端口: $VNC_PORT   密码: $PASS_DESC"
echo "首页   : $HOMEPAGE"
echo "====================================="

# ---------- 1. 装 Docker(如未安装) ----------
if ! command -v docker >/dev/null 2>&1; then
  echo "--- 安装 Docker ---"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y docker.io
  systemctl enable --now docker
fi

# ---------- 2. 生成构建文件 ----------
BUILD_DIR="/root/chrome-vnc"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

cat > Dockerfile <<EOF
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive TZ=Asia/Shanghai LANG=C.UTF-8
RUN apt-get update && apt-get install -y --no-install-recommends \\
      xvfb x11vnc fluxbox supervisor wget gnupg2 ca-certificates \\
      fonts-liberation fonts-noto-core fonts-noto-cjk fonts-noto-color-emoji \\
      fonts-tlwg-loma fonts-tlwg-garuda fonts-wqy-zenhei x11-utils dbus-x11 && \\
    fc-cache -f && \\
    wget -qO- https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg && \\
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list && \\
    apt-get update && apt-get install -y google-chrome-stable && \\
    apt-get clean && rm -rf /var/lib/apt/lists/*
ARG VNC_PASS=MyVnc123
RUN x11vnc -storepasswd "\$VNC_PASS" /etc/x11vnc.pass
COPY supervisord.conf /etc/supervisord.conf
COPY start-chrome.sh /usr/local/bin/start-chrome.sh
RUN chmod +x /usr/local/bin/start-chrome.sh
EXPOSE 5900
CMD ["/usr/bin/supervisord","-c","/etc/supervisord.conf"]
EOF

cat > supervisord.conf <<EOF
[supervisord]
nodaemon=true
user=root

[program:xvfb]
command=/usr/bin/Xvfb :0 -screen 0 ${RES}x24
autorestart=true
priority=10

[program:fluxbox]
command=/usr/bin/fluxbox
environment=DISPLAY=":0"
autorestart=true
priority=20

[program:x11vnc]
command=/usr/bin/x11vnc -display :0 -forever -shared ${X11VNC_AUTH} -rfbport 5900
autorestart=true
priority=30

[program:chrome]
command=/usr/local/bin/start-chrome.sh
environment=DISPLAY=":0"
autorestart=true
startsecs=5
priority=40
EOF

WINSIZE="${RES/x/,}"
cat > start-chrome.sh <<EOF
#!/bin/bash
sleep 3
rm -f /root/.config/google-chrome/Singleton* 2>/dev/null || true
exec google-chrome \\
  --no-sandbox --disable-gpu --no-first-run --no-default-browser-check \\
  --disable-dev-shm-usage --start-maximized --window-size=${WINSIZE} \\
  --user-data-dir=/root/.config/google-chrome \\
  ${HOMEPAGE}
EOF

# ---------- 3. 构建并运行 ----------
echo "--- 构建镜像(首次约需几分钟下载 Chrome)---"
docker build --build-arg VNC_PASS="$VNC_PASS" -t "$IMAGE" .

echo "--- 启动容器 ---"
docker rm -f "$NAME" >/dev/null 2>&1 || true
docker run -d --name "$NAME" --shm-size=2g --restart unless-stopped \
  -p ${VNC_PORT}:5900 "$IMAGE"

sleep 8
echo "================ 完成 ================"
docker exec "$NAME" bash -c "DISPLAY=:0 xdpyinfo 2>/dev/null | grep dimensions" || true
IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "<服务器IP>")
echo "VNC 连接: ${IP}:${VNC_PORT}   密码: ${PASS_DESC}"
echo "(若连不上, 检查云服务器安全组/防火墙是否放行 ${VNC_PORT} 端口)"
echo "====================================="

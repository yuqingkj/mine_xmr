#!/bin/bash
###############################################################################
# Chrome-VNC 一键部署脚本  (TigerVNC 版)
# 用途: 在一台全新的 Ubuntu/Debian 服务器上部署
#       「最新 Google Chrome + 标准 5900 VNC + noVNC 网页访问」
#       - 服务端用 TigerVNC(Xvnc): 剪贴板双向同步稳定(替代有 bug 的 x11vnc)
#       - 自带中文/泰文/emoji 字体, 不再乱码
#       - 同时提供 noVNC 网页访问(浏览器即可连, 自带手动剪贴板框)
#
# 用法: sudo bash deploy-chrome-vnc.sh
# 可用环境变量覆盖参数, 例如:
#   VNC_PASS=xxx RES=1920x1080 NOVNC_PORT=6080 bash deploy-chrome-vnc.sh
###############################################################################
set -e

VNC_PASS="${VNC_PASS:-}"                          # VNC 密码 (留空=无密码)
RES="${RES:-2560x1440}"                            # 分辨率 (宽x高)
VNC_PORT="${VNC_PORT:-5900}"                        # 对外 VNC 端口 (原生客户端)
NOVNC_PORT="${NOVNC_PORT:-6080}"                    # 对外 noVNC 网页端口
ENABLE_WEB="${ENABLE_WEB:-1}"                       # 1=部署 noVNC 网页访问, 0=不部署
HOMEPAGE="${HOMEPAGE:-https://www.google.com}"      # Chrome 启动首页
IMAGE="chrome-vnc:latest"
NAME="chrome-vnc"

# ---- TigerVNC 认证: 有密码=VncAuth, 无密码=None ----
if [ -n "$VNC_PASS" ]; then
  SEC_ARGS="-SecurityTypes VncAuth -rfbauth /etc/vnc.pass"
  VNCPASS_SETUP="echo '$VNC_PASS' | vncpasswd -f > /etc/vnc.pass"
  PASS_DESC="$VNC_PASS"
else
  SEC_ARGS="-SecurityTypes None"
  VNCPASS_SETUP=""
  PASS_DESC="(无密码)"
fi

# Xvnc 命令: 容器内固定监听 5900, 由 docker 端口映射对外暴露
# -SendPrimary=0 关键: 防止 Chrome 地址栏自动选中的网址污染剪贴板
XVNC_CMD="/usr/bin/Xvnc :0 -geometry ${RES} -depth 24 -rfbport 5900 ${SEC_ARGS} -AlwaysShared -AcceptCutText=1 -SendCutText=1 -SetPrimary=1 -SendPrimary=0 -AcceptSetDesktopSize=1 -desktop chrome"

echo "================ 配置 ================"
echo "分辨率   : $RES (24位全彩)"
echo "VNC端口  : $VNC_PORT   密码: $PASS_DESC"
[ "$ENABLE_WEB" = "1" ] && echo "网页端口 : $NOVNC_PORT (noVNC)"
echo "首页     : $HOMEPAGE"
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

cat > Dockerfile <<'EOF'
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive TZ=Asia/Shanghai LANG=C.UTF-8
RUN apt-get update && apt-get install -y --no-install-recommends \
      tigervnc-standalone-server tigervnc-common fluxbox supervisor \
      wget gnupg2 ca-certificates \
      fonts-liberation fonts-noto-core fonts-noto-cjk fonts-noto-color-emoji \
      fonts-tlwg-loma fonts-tlwg-garuda fonts-wqy-zenhei x11-utils dbus-x11 && \
    fc-cache -f && \
    wget -qO- https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list && \
    apt-get update && apt-get install -y google-chrome-stable && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
COPY supervisord.conf /etc/supervisord.conf
COPY start-chrome.sh /usr/local/bin/start-chrome.sh
COPY start-vnc.sh /usr/local/bin/start-vnc.sh
RUN chmod +x /usr/local/bin/start-chrome.sh /usr/local/bin/start-vnc.sh
EXPOSE 5900
CMD ["/usr/bin/supervisord","-c","/etc/supervisord.conf"]
EOF

cat > supervisord.conf <<'EOF'
[supervisord]
nodaemon=true
user=root

[program:xvnc]
command=/usr/local/bin/start-vnc.sh
autorestart=true
priority=10

[program:fluxbox]
command=/usr/bin/fluxbox
environment=DISPLAY=":0"
autorestart=true
priority=20

[program:chrome]
command=/usr/local/bin/start-chrome.sh
environment=DISPLAY=":0"
autorestart=true
startsecs=5
priority=40
EOF

# start-vnc.sh: 清理 X 锁 + (可选)生成密码 + 启动 Xvnc
cat > start-vnc.sh <<EOF
#!/bin/bash
rm -f /tmp/.X0-lock /tmp/.X11-unix/X0 2>/dev/null
${VNCPASS_SETUP}
exec ${XVNC_CMD}
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
docker build -t "$IMAGE" .

echo "--- 启动容器 ---"
docker rm -f "$NAME" >/dev/null 2>&1 || true
docker run -d --name "$NAME" --shm-size=2g --restart unless-stopped \
  -p ${VNC_PORT}:5900 "$IMAGE"

# ---------- 4. (可选)部署 noVNC 网页访问 ----------
if [ "$ENABLE_WEB" = "1" ]; then
  echo "--- 部署 noVNC 网页访问 ---"
  export DEBIAN_FRONTEND=noninteractive
  apt-get install -y novnc websockify >/dev/null 2>&1 || apt-get install -y novnc websockify
  cat > /etc/systemd/system/novnc.service <<EOF
[Unit]
Description=noVNC websocket proxy for chrome-vnc
After=docker.service
Wants=docker.service

[Service]
ExecStart=/usr/bin/websockify --web=/usr/share/novnc ${NOVNC_PORT} localhost:${VNC_PORT}
Restart=always

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable --now novnc
  systemctl restart novnc
fi

sleep 8
echo "================ 完成 ================"
docker exec "$NAME" bash -c "DISPLAY=:0 xdpyinfo 2>/dev/null | grep dimensions" || true
IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "<服务器IP>")
echo "原生 VNC : ${IP}:${VNC_PORT}   密码: ${PASS_DESC}"
[ "$ENABLE_WEB" = "1" ] && echo "网页访问 : http://${IP}:${NOVNC_PORT}/vnc.html"
echo "(若连不上, 检查云服务器安全组/防火墙是否放行 ${VNC_PORT}${ENABLE_WEB:+ 和 ${NOVNC_PORT}} 端口)"
echo "====================================="

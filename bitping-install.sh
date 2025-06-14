#!/bin/bash

set -e

# 检查账号密码环境变量
if [[ -z "$BITPING_USERNAME" || -z "$BITPING_PASSWORD" ]]; then
  echo "❌ 请先设置 BITPING_USERNAME 和 BITPING_PASSWORD 环境变量。"
  exit 1
fi

# 安装 expect（用于自动交互登录）
if ! command -v expect >/dev/null 2>&1; then
  echo "🔧 安装 expect..."
  sudo apt update && sudo apt install -y expect
fi

echo "⬇️ 正在下载 Bitpingd..."

# 获取更新 JSON
update_json=$(wget -qO- "https://releases.bitping.com/bitpingd/update.json")

# 获取系统平台
OS=$(uname -s)
ARCH=$(uname -m)

platform_key=""
if [[ "$OS" == "Linux" ]]; then
    case "$ARCH" in
        x86_64) platform_key="linux-x86_64" ;;
        armv7l) platform_key="linux-armv7" ;;
        aarch64) platform_key="linux-aarch64" ;;
        arm*) platform_key="linux-arm" ;;
        *) echo "❌ 不支持的架构: $ARCH" && exit 1 ;;
    esac
else
    echo "❌ 当前脚本仅支持 Linux。"
    exit 1
fi

# 获取下载地址
download_url=$(echo "$update_json" | grep -A 3 "\"$platform_key\":" | grep '"url":' | sed -E 's/.*"([^"]+)".*/\1/')
file=$(basename "$download_url")

wget -O "$file" "$download_url"
tar -xf "$file"

# 安装 bitpingd 到 ~/.local/bin
target_dir="$HOME/.local/bin"
mkdir -p "$target_dir"
mv bitpingd "$target_dir/bitpingd"
chmod +x "$target_dir/bitpingd"
export PATH="$PATH:$target_dir"

# 设置网络权限
echo "🛡️ 设置网络权限（需要 sudo）..."
sudo setcap 'cap_net_raw=ep' "$target_dir/bitpingd"

# 自动登录 bitpingd
echo "🔐 正在自动登录 Bitpingd..."
expect <<EOF
spawn $target_dir/bitpingd login
expect "Email:"
send "$BITPING_USERNAME\r"
expect "Password:"
send "$BITPING_PASSWORD\r"
expect eof
EOF

# 注册服务并启动
echo "🚀 正在安装并启动 Bitpingd 服务..."
"$target_dir/bitpingd" service install
"$target_dir/bitpingd" service start

# 启用登录保持
echo "🔄 启用 loginctl linger 保持后台运行..."
sudo loginctl enable-linger "$(whoami)"

echo "✅ Bitpingd 安装完成，并已在后台运行！"

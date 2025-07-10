#!/bin/bash

# ==============================================================================
# SCRIPT_NAME: setup_gost_socks5.sh
# DESCRIPTION: A script to automatically set up a SOCKS5 proxy server with
#              gost, using a random port, username, and password.
# AUTHOR:      Gemini
# DATE:        2025-07-10
# ==============================================================================

# --- 全局变量和颜色定义 ---
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
NC="\033[0m" # No Color

SERVICE_NAME="gost-socks5"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

# --- 函数定义 ---

# 检查脚本是否以 root 权限运行
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}错误：此脚本必须以 root 权限运行。请使用 'sudo'。${NC}"
        exit 1
    fi
}

# 检查并安装依赖项 (curl, jq, wget, tar)
check_dependencies() {
    echo -e "${YELLOW}正在检查依赖项...${NC}"
    local missing_deps=()
    for dep in curl jq wget tar; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${RED}检测到缺失的依赖项: ${missing_deps[*]}.${NC}"
        if command -v apt-get &> /dev/null; then
            echo -e "${YELLOW}正在尝试使用 apt-get 安装...${NC}"
            apt-get update && apt-get install -y "${missing_deps[@]}"
        elif command -v yum &> /dev/null; then
            echo -e "${YELLOW}正在尝试使用 yum 安装...${NC}"
            yum install -y "${missing_deps[@]}"
        else
            echo -e "${RED}无法自动安装依赖。请手动安装 ${missing_deps[*]} 后重试。${NC}"
            exit 1
        fi
    fi
    echo -e "${GREEN}依赖项检查通过。${NC}"
}

# 安装或更新 gost
install_gost() {
    if command -v gost &> /dev/null; then
        echo -e "${GREEN}gost 已安装。将继续执行。${NC}"
        return
    fi
    
    echo -e "${YELLOW}gost 未找到，正在开始安装...${NC}"
    
    # 检测系统架构
    ARCH=$(uname -m)
    case ${ARCH} in
        x86_64) GOST_ARCH="amd64" ;;
        aarch64) GOST_ARCH="arm64" ;;
        *)
            echo -e "${RED}不支持的系统架构: ${ARCH}${NC}"
            exit 1
            ;;
    esac

    # 从 GitHub API 获取最新版本下载链接
    echo -e "${YELLOW}正在从 GitHub 获取最新版本信息...${NC}"
    LATEST_URL=$(curl -s https://api.github.com/repos/ginuerzh/gost/releases/latest | jq -r ".assets[] | select(.name | test(\"gost_.*_linux_${GOST_ARCH}.tar.gz\")) | .browser_download_url")

    if [ -z "$LATEST_URL" ]; then
        echo -e "${RED}无法自动获取 gost 的下载链接。请检查网络或稍后重试。${NC}"
        exit 1
    fi

    echo -e "${YELLOW}正在下载 gost...${NC}"
    wget -qO gost.tar.gz "${LATEST_URL}"
    if [ $? -ne 0 ]; then
        echo -e "${RED}下载失败。请检查网络连接。${NC}"
        exit 1
    fi

    echo -e "${YELLOW}正在解压并安装...${NC}"
    # 解压文件，--strip-components=1 可以去除压缩包内的顶层目录
    tar -zxvf gost.tar.gz --strip-components=1 '*/gost'
    mv gost /usr/local/bin/gost
    chmod +x /usr/local/bin/gost

    # 清理
    rm -f gost.tar.gz

    # 验证
    if command -v gost &> /dev/null; then
        echo -e "${GREEN}gost 安装成功！版本: $(gost -V)${NC}"
    else
        echo -e "${RED}gost 安装失败。${NC}"
        exit 1
    fi
}

# 配置防火墙
configure_firewall() {
    local port=$1
    echo -e "${YELLOW}正在配置防火墙以开放端口 ${port}...${NC}"
    if command -v ufw &> /dev/null; then
        ufw allow "${port}/tcp" > /dev/null
        ufw reload > /dev/null
        echo -e "${GREEN}ufw 防火墙规则已更新。${NC}"
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --zone=public --add-port="${port}/tcp" --permanent > /dev/null
        firewall-cmd --reload > /dev/null
        echo -e "${GREEN}firewalld 防火墙规则已更新。${NC}"
    else
        echo -e "${YELLOW}警告：未检测到 ufw 或 firewalld。请手动开放 TCP 端口 ${port}。${NC}"
    fi
}

# 显示结果
display_result() {
    local ip port user pass=$1
    ip=$(curl -s https://ipinfo.io/ip) || ip=$(hostname -I | awk '{print $1}')
    port=$2
    user=$3
    pass=$4

    echo -e "============================================================"
    echo -e "🎉 ${GREEN}SOCKS5 代理已成功部署！${NC} 🎉"
    echo ""
    echo -e "  以下是您的连接信息:"
    echo -e "  --------------------------------------------------------"
    echo -e "  ${YELLOW}服务器地址 (Server IP):${NC}  ${ip}"
    echo -e "  ${YELLOW}端口 (Port):${NC}             ${port}"
    echo -e "  ${YELLOW}用户名 (Username):${NC}       ${user}"
    echo -e "  ${YELLOW}密码 (Password):${NC}         ${pass}"
    echo -e "  --------------------------------------------------------"
    echo ""
    echo -e "  请妥善保管您的密码。"
    echo -e "============================================================"
}


# --- 主逻辑 ---

main() {
    check_root
    check_dependencies
    install_gost

    echo -e "${YELLOW}正在生成随机凭证...${NC}"
    RANDOM_PORT=$(shuf -i 20000-65000 -n 1)
    RANDOM_USER=$(tr -dc 'a-z' < /dev/urandom | head -c 8)
    RANDOM_PASS=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 16)
    echo -e "${GREEN}凭证生成完毕。${NC}"

    echo -e "${YELLOW}正在创建 systemd 服务...${NC}"
    # 如果服务已存在，先停止
    if systemctl is-active --quiet ${SERVICE_NAME}; then
        systemctl stop ${SERVICE_NAME}
    fi

    tee ${SERVICE_FILE} > /dev/null <<EOF
[Unit]
Description=GO Simple Tunnel (SOCKS5 Proxy)
After=network.target
Wants=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/gost -L "socks5://${RANDOM_USER}:${RANDOM_PASS}@0.0.0.0:${RANDOM_PORT}"
Restart=always
User=nobody
Group=nogroup
StandardOutput=null
StandardError=null

[Install]
WantedBy=multi-user.target
EOF
    echo -e "${GREEN}systemd 服务文件已创建。${NC}"

    configure_firewall "${RANDOM_PORT}"

    echo -e "${YELLOW}正在重载 systemd 并启动服务...${NC}"
    systemctl daemon-reload
    systemctl enable ${SERVICE_NAME} > /dev/null
    systemctl restart ${SERVICE_NAME}

    # 稍作等待并检查服务状态
    sleep 2
    if systemctl is-active --quiet ${SERVICE_NAME}; then
        display_result "${ip}" "${RANDOM_PORT}" "${RANDOM_USER}" "${RANDOM_PASS}"
    else
        echo -e "${RED}服务启动失败！请运行 'journalctl -u ${SERVICE_NAME}' 查看日志。${NC}"
        exit 1
    fi
}

# --- 脚本入口 ---
main "$@"

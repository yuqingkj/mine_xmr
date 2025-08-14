#!/bin/bash

# ==============================================================================
# SCRIPT_NAME: setup_gost_socks5.sh (v5 - No Firewall)
# DESCRIPTION: A script to automatically set up a SOCKS5 proxy server with
#              gost, using a random port, username, and password.
#              Firewall configuration has been disabled per user request.
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
    
    ARCH=$(uname -m)
    case ${ARCH} in
        x86_64) GOST_ARCH="amd64" ;;
        aarch64) GOST_ARCH="arm64" ;;
        *)
            echo -e "${RED}不支持的系统架构: ${ARCH}${NC}"
            exit 1
            ;;
    esac

    echo -e "${YELLOW}正在从 GitHub (go-gost/gost) 获取最新版本信息...${NC}"
    LATEST_URL=$(curl -s https://api.github.com/repos/go-gost/gost/releases/latest | jq -r ".assets[] | select(.name | test(\"gost_.*_linux_${GOST_ARCH}.tar.gz\")) | .browser_download_url")

    if [ -z "$LATEST_URL" ]; then
        echo -e "${RED}无法自动获取 gost 的下载链接。请检查网络或稍后重试。${NC}"
        exit 1
    fi

    echo -e "${YELLOW}正在下载 gost: ${LATEST_URL}${NC}"
    wget -qO gost.tar.gz "${LATEST_URL}"
    if [ $? -ne 0 ]; then
        echo -e "${RED}下载失败。请检查网络连接。${NC}"
        exit 1
    fi

    echo -e "${YELLOW}正在解压并安装...${NC}"
    
    EXTRACT_DIR=$(mktemp -d)
    tar -zxvf gost.tar.gz -C "${EXTRACT_DIR}"
    if [ $? -ne 0 ]; then
        echo -e "${RED}解压失败。下载的文件可能已损坏。${NC}"
        rm -rf "${EXTRACT_DIR}" gost.tar.gz
        exit 1
    fi
    
    GOST_BINARY_PATH=$(find "${EXTRACT_DIR}" -type f -name "gost")
    if [ -z "${GOST_BINARY_PATH}" ]; then
        echo -e "${RED}在解压的文件中未找到 'gost' 程序。安装中止。${NC}"
        rm -rf "${EXTRACT_DIR}" gost.tar.gz
        exit 1
    fi
    
    mv "${GOST_BINARY_PATH}" /usr/local/bin/gost
    chmod +x /usr/local/bin/gost
    
    rm -rf "${EXTRACT_DIR}" gost.tar.gz

    if command -v gost &> /dev/null; then
        echo -e "${GREEN}gost 安装成功！版本: $(gost -V)${NC}"
    else
        echo -e "${RED}gost 安装失败。${NC}"
        exit 1
    fi
}

# 配置防火墙 (已根据用户要求禁用)
configure_firewall() {
    local port=$1
    echo -e "${YELLOW}============================================================${NC}"
    echo -e "${YELLOW}注意：防火墙自动配置已跳过。${NC}"
    echo -e "${YELLOW}如果您的服务器启用了防火墙，请务必手动开放 TCP 端口: ${port}${NC}"
    echo -e "${YELLOW}例如: 'sudo ufw allow ${port}/tcp' 或 'sudo firewall-cmd --add-port=${port}/tcp --permanent'${NC}"
    echo -e "${YELLOW}============================================================${NC}"
}

# 显示结果
display_result() {
    # 正确地从参数接收变量
    local port=$1
    local user=$2
    local pass=$3
    # 在函数内部获取 IP
    local ip
    ip=$(curl -s https://ipinfo.io/ip) || ip=$(hostname -I | awk '{print $1}')

    echo -e "🎉 ${GREEN}SOCKS5 代理已成功部署！${NC} 🎉"
    echo ""
    echo -e "  以下是您的连接信息:"
    echo -e "  --------------------------------------------------------"
    echo -e "  ${YELLOW}服务器地址 (Server IP):${NC}  ${ip}"
    echo -e "  ${YELLOW}端口 (Port):${NC}             ${port}"
    echo -e "  ${YELLOW}用户名 (Username):${NC}       ${user}"
    echo -e "  ${YELLOW}密码 (Password):${NC}         ${pass}"
    echo -e "  --------------------------------------------------------"
    echo ""
    
    echo -e "  ${GREEN}一键导入格式 (IP:Port:Username:Password):${NC}"
    echo -e "  ${ip}:${port}:${user}:${pass}"
    echo ""

    echo -e "  请妥善保管您的密码。"
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

    # 调用修改后的防火墙函数，现在它只会打印提示信息
    configure_firewall "${RANDOM_PORT}"

    echo -e "${YELLOW}正在重载 systemd 并启动服务...${NC}"
    systemctl daemon-reload
    systemctl enable ${SERVICE_NAME} > /dev/null
    systemctl restart ${SERVICE_NAME}

    sleep 2
    if systemctl is-active --quiet ${SERVICE_NAME}; then
        # 正确调用，只传递已知的变量
        display_result "${RANDOM_PORT}" "${RANDOM_USER}" "${RANDOM_PASS}"
    else
        echo -e "${RED}服务启动失败！请运行 'journalctl -u ${SERVICE_NAME}' 查看日志。${NC}"
        exit 1
    fi
}

# --- 脚本入口 ---
main "$@"

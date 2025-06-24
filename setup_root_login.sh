#!/bin/bash

# ==============================================================================
# AWS EC2 启用 Root 登录脚本 (v5 - 命令行参数版)
#
# !! 安全警告 !!
# 此版本从命令行参数接收密码，这会将密码明文保存在您的 shell 历史记录中。
# 强烈建议仅在安全的、一次性的或自动化的临时环境中使用。
#
# 如何运行:
#   $ chmod +x setup_root_login.sh
#   $ sudo ./setup_root_login.sh 'YourStrongPasswordHere'
#   (如果密码包含特殊字符，请使用单引号将其括起来)
# ==============================================================================

# 步骤 1: 检查权限和参数
if [[ "$(id -u)" -ne 0 ]]; then
   echo "错误：此脚本需要管理员权限才能运行。请使用 'sudo'。" >&2
   exit 1
fi

# 检查是否提供了密码参数
if [ "$#" -ne 1 ]; then
    echo "错误：用法不正确。" >&2
    echo "请提供一个密码作为命令行参数。" >&2
    echo "用法: sudo $0 '<密码>'" >&2
    exit 1
fi

# 步骤 2: 从第一个命令行参数获取密码
readonly ROOT_PASSWORD="$1"

echo "已从命令行参数接收密码，开始配置..."

# 步骤 3: 为 root 用户设置新密码
echo "正在为 root 用户设置密码..."
echo "root:$ROOT_PASSWORD" | chpasswd
if [ $? -ne 0 ]; then
    echo "错误：设置 root 密码失败。" >&2
    # 清理变量并退出
    unset ROOT_PASSWORD
    exit 1
fi
echo "root 密码设置成功。"

# 清理内存中的密码变量
unset ROOT_PASSWORD

# 步骤 4: 修改 SSH 配置文件 (此处包含完整代码)
echo "正在修改 SSH 配置..."
SSHD_CONFIG_FILE="/etc/ssh/sshd_config"
CLOUD_INIT_SSHD_CONFIG_FILE="/etc/ssh/sshd_config.d/60-cloudimg-settings.conf"
cp "$SSHD_CONFIG_FILE" "${SSHD_CONFIG_FILE}.bak.$(date +%F)"
if grep -q "^#\?PermitRootLogin" "$SSHD_CONFIG_FILE"; then sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/g' "$SSHD_CONFIG_FILE"; else echo "PermitRootLogin yes" >> "$SSHD_CONFIG_FILE"; fi
if grep -q "^#\?PasswordAuthentication" "$SSHD_CONFIG_FILE"; then sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/g' "$SSHD_CONFIG_FILE"; else echo "PasswordAuthentication yes" >> "$SSHD_CONFIG_FILE"; fi
if [ -f "$CLOUD_INIT_SSHD_CONFIG_FILE" ]; then
    cp "$CLOUD_INIT_SSHD_CONFIG_FILE" "${CLOUD_INIT_SSHD_CONFIG_FILE}.bak.$(date +%F)"
    sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' "$CLOUD_INIT_SSHD_CONFIG_FILE"
fi
echo "SSH 配置文件修改完成。"

# 步骤 5: 重启 SSH 服务
echo "正在重启 SSH 服务..."
if command -v systemctl &> /dev/null; then systemctl restart sshd; elif command -v service &> /dev/null; then service sshd restart; else /etc/init.d/sshd restart; fi

echo -e "\n配置完成！"

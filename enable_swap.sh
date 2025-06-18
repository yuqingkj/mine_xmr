#!/bin/bash

# 设置 swap 文件大小（单位：G）
SWAP_SIZE_GB=1
SWAPFILE="/swapfile"

echo "🛠️ 创建 ${SWAP_SIZE_GB}G 的 swap 文件..."

# 1. 创建 swap 文件
sudo fallocate -l ${SWAP_SIZE_GB}G $SWAPFILE || sudo dd if=/dev/zero of=$SWAPFILE bs=1G count=$SWAP_SIZE_GB

# 2. 设置权限
sudo chmod 600 $SWAPFILE

# 3. 设置为 swap 格式
sudo mkswap $SWAPFILE

# 4. 启用 swap
sudo swapon $SWAPFILE

# 5. 添加到 /etc/fstab（避免重复添加）
if ! grep -q "$SWAPFILE" /etc/fstab; then
    echo "$SWAPFILE none swap sw 0 0" | sudo tee -a /etc/fstab
fi

# 6. 显示结果
echo "✅ Swap 已启用"
sudo swapon --show
free -h

sudo reboot

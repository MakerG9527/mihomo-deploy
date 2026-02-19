#!/bin/bash
# Mihomo 更新脚本

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

MIHOMO_VERSION="${MIHOMO_VERSION:-latest}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"

# 检测系统架构
detect_arch() {
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            MIHOMO_ARCH="amd64"
            ;;
        aarch64|arm64)
            MIHOMO_ARCH="arm64"
            ;;
        armv7l)
            MIHOMO_ARCH="armv7"
            ;;
        *)
            echo -e "${RED}不支持的架构: $ARCH${NC}"
            exit 1
            ;;
    esac
}

echo -e "${GREEN}=== Mihomo 更新脚本 ===${NC}"
echo ""

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}请使用 sudo 运行此脚本${NC}"
    exit 1
fi

detect_arch

echo -e "${BLUE}当前版本:${NC}"
mihomo -v 2>/dev/null || echo "未安装"

echo -e "${BLUE}正在更新...${NC}"

# 备份旧版本
if [ -f "$INSTALL_DIR/mihomo" ]; then
    cp "$INSTALL_DIR/mihomo" "$INSTALL_DIR/mihomo.backup"
fi

# 停止服务
systemctl stop mihomo 2>/dev/null || true

# 下载新版本
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR"

if [ "$MIHOMO_VERSION" = "latest" ]; then
    DOWNLOAD_URL="https://github.com/MetaCubeX/mihomo/releases/latest/download/mihomo-linux-${MIHOMO_ARCH}-compatible.gz"
else
    DOWNLOAD_URL="https://github.com/MetaCubeX/mihomo/releases/download/${MIHOMO_VERSION}/mihomo-linux-${MIHOMO_ARCH}-compatible.gz"
fi

echo -e "${BLUE}下载: $DOWNLOAD_URL${NC}"
curl -L -o mihomo.gz "$DOWNLOAD_URL" || {
    echo -e "${RED}下载失败${NC}"
    exit 1
}

gunzip mihomo.gz
chmod +x mihomo
mv mihomo "$INSTALL_DIR/"

cd /
rm -rf "$TMP_DIR"

echo -e "${GREEN}新版本:${NC}"
mihomo -v

# 重启服务
echo -e "${BLUE}重启服务...${NC}"
systemctl start mihomo
systemctl status mihomo --no-pager

echo -e "${GREEN}更新完成!${NC}"

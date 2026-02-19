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

# 构建下载 URL
if [ "$MIHOMO_VERSION" = "latest" ]; then
    DOWNLOAD_URL="https://github.com/MetaCubeX/mihomo/releases/latest/download/mihomo-linux-${MIHOMO_ARCH}-compatible.gz"
else
    DOWNLOAD_URL="https://github.com/MetaCubeX/mihomo/releases/download/${MIHOMO_VERSION}/mihomo-linux-${MIHOMO_ARCH}-compatible.gz"
fi

# 备份旧版本
if [ -f "$INSTALL_DIR/mihomo" ]; then
    cp "$INSTALL_DIR/mihomo" "$INSTALL_DIR/mihomo.backup.$(date +%Y%m%d%H%M%S)"
fi

# 停止服务
systemctl stop mihomo 2>/dev/null || true

# 下载新版本
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR"

echo -e "${BLUE}尝试从 GitHub 下载...${NC}"
echo -e "${YELLOW}URL: $DOWNLOAD_URL${NC}"

if curl -L --connect-timeout 30 --max-time 120 -o mihomo.gz "$DOWNLOAD_URL" 2>/dev/null; then
    echo -e "${GREEN}自动下载成功!${NC}"
else
    echo -e "${RED}自动下载失败，可能网络无法访问 GitHub${NC}"
    echo ""
    echo -e "${YELLOW}请手动输入 mihomo 下载地址:${NC}"
    echo -e "${BLUE}提示: 你可以从以下地址获取:${NC}"
    echo -e "  1. https://github.com/MetaCubeX/mihomo/releases"
    echo -e "  2. 镜像站如: https://gh-proxy.com/github.com/MetaCubeX/mihomo/releases"
    echo ""
    echo -e "${YELLOW}请输入下载地址 (例如: https://example.com/mihomo-linux-${MIHOMO_ARCH}-compatible.gz):${NC}"
    read -r MANUAL_URL
    
    if [ -z "$MANUAL_URL" ]; then
        echo -e "${RED}未提供下载地址，退出更新${NC}"
        rm -rf "$TMP_DIR"
        exit 1
    fi
    
    echo -e "${BLUE}从手动地址下载: $MANUAL_URL${NC}"
    if ! curl -L --connect-timeout 30 --max-time 120 -o mihomo.gz "$MANUAL_URL"; then
        echo -e "${RED}手动下载也失败了，请检查地址是否正确${NC}"
        rm -rf "$TMP_DIR"
        exit 1
    fi
    echo -e "${GREEN}手动下载成功!${NC}"
fi

# 解压和安装
echo -e "${BLUE}解压文件...${NC}"
if ! gunzip mihomo.gz 2>/dev/null; then
    echo -e "${RED}解压失败，文件可能损坏${NC}"
    rm -rf "$TMP_DIR"
    exit 1
fi

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

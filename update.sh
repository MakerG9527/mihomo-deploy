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
    echo -e "${YELLOW}请手动下载 mihomo 的 .gz 文件，然后输入本地文件路径${NC}"
    echo -e "${BLUE}下载地址:${NC}"
    echo -e "  1. https://github.com/MetaCubeX/mihomo/releases"
    echo -e "  2. 镜像站如: https://gh-proxy.com/github.com/MetaCubeX/mihomo/releases"
    echo ""
    echo -e "${BLUE}需要下载的文件名格式: mihomo-linux-${MIHOMO_ARCH}-compatible.gz${NC}"
    echo ""
    echo -e "${YELLOW}请输入本地 .gz 文件的绝对路径 (例如: /home/user/downloads/mihomo-linux-${MIHOMO_ARCH}-compatible.gz):${NC}"
    read -r LOCAL_FILE
    
    if [ -z "$LOCAL_FILE" ]; then
        echo -e "${RED}未提供文件路径，退出更新${NC}"
        rm -rf "$TMP_DIR"
        exit 1
    fi
    
    # 展开 ~ 为家目录
    LOCAL_FILE="${LOCAL_FILE/#\~/$HOME}"
    
    if [ ! -f "$LOCAL_FILE" ]; then
        echo -e "${RED}文件不存在: $LOCAL_FILE${NC}"
        rm -rf "$TMP_DIR"
        exit 1
    fi
    
    # 检查文件扩展名
    if [[ "$LOCAL_FILE" != *.gz ]]; then
        echo -e "${YELLOW}警告: 文件不是 .gz 格式，尝试直接使用...${NC}"
        cp "$LOCAL_FILE" mihomo
    else
        cp "$LOCAL_FILE" mihomo.gz
    fi
    
    echo -e "${GREEN}使用本地文件: $LOCAL_FILE${NC}"
fi

# 如果存在 mihomo.gz 则解压
if [ -f "mihomo.gz" ]; then
    echo -e "${BLUE}解压文件...${NC}"
    if ! gunzip mihomo.gz 2>/dev/null; then
        echo -e "${RED}解压失败，文件可能损坏${NC}"
        rm -rf "$TMP_DIR"
        exit 1
    fi
fi

# 检查文件是否存在且可执行
if [ ! -f "mihomo" ]; then
    echo -e "${RED}未找到 mihomo 可执行文件${NC}"
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

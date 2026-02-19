#!/bin/bash
# Mihomo 卸载脚本

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}确定要卸载 Mihomo 吗？这将删除所有配置！[y/N]${NC}"
read -r response

if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "已取消卸载"
    exit 0
fi

echo -e "${BLUE}正在停止 mihomo 服务...${NC}"
systemctl stop mihomo 2>/dev/null || true
systemctl disable mihomo 2>/dev/null || true

echo -e "${BLUE}删除透明代理规则...${NC}"
/etc/mihomo/disable-tproxy.sh 2>/dev/null || true

echo -e "${BLUE}删除文件...${NC}"
rm -f /usr/local/bin/mihomo
rm -rf /etc/mihomo
rm -f /etc/systemd/system/mihomo.service
rm -f /etc/profile.d/mihomo-proxy.sh

echo -e "${BLUE}重新加载 systemd...${NC}"
systemctl daemon-reload

echo -e "${GREEN}Mihomo 已完全卸载${NC}"

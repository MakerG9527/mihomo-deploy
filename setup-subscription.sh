#!/bin/bash
# 快速配置 Mihomo 订阅链接

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CONFIG_DIR="${CONFIG_DIR:-/etc/mihomo}"
CONFIG_FILE="$CONFIG_DIR/config.yaml"

echo -e "${GREEN}=== Mihomo 订阅配置 ===${NC}"
echo ""

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}请使用 sudo 运行此脚本${NC}"
    exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}配置文件不存在: $CONFIG_FILE${NC}"
    exit 1
fi

echo -e "${BLUE}请输入你的订阅链接:${NC}"
read -r subscription_url

if [ -z "$subscription_url" ]; then
    echo -e "${RED}订阅链接不能为空${NC}"
    exit 1
fi

# 备份原配置
cp "$CONFIG_FILE" "$CONFIG_FILE.backup.$(date +%Y%m%d%H%M%S)"

# 生成新配置
cat > "$CONFIG_FILE" << EOF
# Mihomo 配置文件
# 自动生成于 $(date)

port: 7890
socks-port: 7891
mixed-port: 7892
redir-port: 7895
tproxy-port: 7896

allow-lan: true
bind-address: '*'
mode: rule
log-level: info
external-controller: 127.0.0.1:9090

# 代理提供者 (订阅链接)
proxy-providers:
  provider1:
    type: http
    url: "$subscription_url"
    interval: 3600
    path: ./proxy-providers/provider1.yaml
    health-check:
      enable: true
      url: https://www.gstatic.com/generate_204
      interval: 300

# 代理节点
proxies:
  - name: "DIRECT"
    type: direct
    udp: true

# 代理组
proxy-groups:
  - name: "🚀 节点选择"
    type: select
    use:
      - provider1
    proxies:
      - DIRECT

  - name: "⚡ 自动选择"
    type: url-test
    url: https://www.gstatic.com/generate_204
    interval: 300
    tolerance: 50
    use:
      - provider1

  - name: "🎯 全球直连"
    type: select
    proxies:
      - DIRECT
      - "🚀 节点选择"

  - name: "🛑 全球拦截"
    type: select
    proxies:
      - REJECT
      - DIRECT

  - name: "🐟 漏网之鱼"
    type: select
    proxies:
      - "🚀 节点选择"
      - DIRECT

# 规则
rules:
  - DOMAIN-SUFFIX,local,DIRECT
  - IP-CIDR,127.0.0.0/8,DIRECT
  - IP-CIDR,172.16.0.0/12,DIRECT
  - IP-CIDR,192.168.0.0/16,DIRECT
  - IP-CIDR,10.0.0.0/8,DIRECT
  - IP-CIDR,169.254.0.0/16,DIRECT
  - IP-CIDR,224.0.0.0/4,DIRECT
  - IP-CIDR,fe80::/10,DIRECT
  
  # 全球直连
  - GEOIP,CN,DIRECT
  
  # 最终规则
  - MATCH,🐟 漏网之鱼
EOF

echo -e "${GREEN}配置文件已更新${NC}"
echo ""
echo -e "${BLUE}重启 mihomo 服务以应用新配置? [Y/n]${NC}"
read -r response

if [[ ! "$response" =~ ^[Nn]$ ]]; then
    systemctl restart mihomo
    sleep 2
    systemctl status mihomo --no-pager
    echo ""
    echo -e "${GREEN}mihomo 已重启，代理已生效${NC}"
fi

#!/bin/bash
# Mihomo Deploy Script - 一键安装和配置 mihomo 代理

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 版本配置
MIHOMO_VERSION="${MIHOMO_VERSION:-latest}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
CONFIG_DIR="${CONFIG_DIR:-/etc/mihomo}"

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
    echo -e "${BLUE}检测到架构: $MIHOMO_ARCH${NC}"
}

# 检测操作系统
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            OS=$ID
        else
            OS="linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="darwin"
    else
        echo -e "${RED}不支持的操作系统: $OSTYPE${NC}"
        exit 1
    fi
    echo -e "${BLUE}检测到系统: $OS${NC}"
}

# 检查 root 权限
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${YELLOW}请使用 sudo 运行此脚本${NC}"
        exit 1
    fi
}

# 安装依赖
install_deps() {
    echo -e "${BLUE}安装依赖...${NC}"
    case $OS in
        ubuntu|debian)
            apt-get update
            apt-get install -y curl wget unzip iptables ipset
            ;;
        centos|rhel|fedora|rocky|almalinux)
            yum install -y curl wget unzip iptables ipset
            ;;
        alpine)
            apk add --no-cache curl wget unzip iptables ipset
            ;;
        *)
            echo -e "${YELLOW}请手动安装: curl, wget, unzip, iptables, ipset${NC}"
            ;;
    esac
}

# 下载 mihomo - 支持自动下载或本地文件
download_mihomo() {
    echo -e "${BLUE}下载 mihomo...${NC}"
    
    # 构建默认下载 URL
    if [ "$MIHOMO_VERSION" = "latest" ]; then
        DOWNLOAD_URL="https://github.com/MetaCubeX/mihomo/releases/latest/download/mihomo-linux-${MIHOMO_ARCH}-compatible.gz"
    else
        DOWNLOAD_URL="https://github.com/MetaCubeX/mihomo/releases/download/${MIHOMO_VERSION}/mihomo-linux-${MIHOMO_ARCH}-compatible.gz"
    fi
    
    TMP_DIR=$(mktemp -d)
    cd "$TMP_DIR"
    
    # 尝试自动下载
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
            echo -e "${RED}未提供文件路径，退出安装${NC}"
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
    
    echo -e "${BLUE}安装到 $INSTALL_DIR...${NC}"
    mv mihomo "$INSTALL_DIR/"
    
    cd /
    rm -rf "$TMP_DIR"
    
    echo -e "${GREEN}mihomo 安装完成!${NC}"
    mihomo -v
}

# 创建配置目录
setup_config_dir() {
    echo -e "${BLUE}创建配置目录...${NC}"
    mkdir -p "$CONFIG_DIR"
    
    # 创建默认配置文件
    if [ ! -f "$CONFIG_DIR/config.yaml" ]; then
        cat > "$CONFIG_DIR/config.yaml" << 'EOF'
# Mihomo 配置文件
# 请替换为你的订阅链接或添加代理节点

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
# proxy-providers:
#   provider1:
#     type: http
#     url: "https://your-subscription-url"
#     interval: 3600
#     path: ./proxy-providers/provider1.yaml
#     health-check:
#       enable: true
#       url: https://www.gstatic.com/generate_204
#       interval: 300

# 代理节点
proxies:
  - name: "direct"
    type: direct
    udp: true

# 代理组
proxy-groups:
  - name: "🚀 节点选择"
    type: select
    proxies:
      - "direct"

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
  
  # 全球直连规则
  - DOMAIN-SUFFIX,cn,DIRECT
  - DOMAIN-KEYWORD,bilibili,DIRECT
  - DOMAIN-KEYWORD,baidu,DIRECT
  
  # 拦截规则
  - DOMAIN-KEYWORD,admarvel,REJECT
  - DOMAIN-KEYWORD,admaster,REJECT
  
  # 代理规则
  - DOMAIN-SUFFIX,google.com,🚀 节点选择
  - DOMAIN-SUFFIX,youtube.com,🚀 节点选择
  - DOMAIN-SUFFIX,github.com,🚀 节点选择
  
  # 最终规则
  - GEOIP,CN,DIRECT
  - MATCH,🐟 漏网之鱼
EOF
        echo -e "${GREEN}默认配置文件已创建: $CONFIG_DIR/config.yaml${NC}"
        echo -e "${YELLOW}请编辑配置文件添加你的订阅链接或代理节点${NC}"
    fi
}

# 创建 systemd 服务
setup_systemd() {
    echo -e "${BLUE}创建 systemd 服务...${NC}"
    
    cat > /etc/systemd/system/mihomo.service << EOF
[Unit]
Description=Mihomo Proxy Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=$INSTALL_DIR/mihomo -f $CONFIG_DIR/config.yaml
Restart=on-failure
RestartSec=5s
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    echo -e "${GREEN}systemd 服务已创建${NC}"
}

# 设置全局代理
setup_global_proxy() {
    echo -e "${BLUE}设置全局代理...${NC}"
    
    # 创建代理配置脚本
    cat > "$CONFIG_DIR/proxy.sh" << 'EOF'
# Mihomo 全局代理配置脚本
# 使用方法: source /etc/mihomo/proxy.sh

# HTTP 代理
export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890
export HTTP_PROXY=http://127.0.0.1:7890
export HTTPS_PROXY=http://127.0.0.1:7890

# SOCKS5 代理
export ALL_PROXY=socks5://127.0.0.1:7891
export all_proxy=socks5://127.0.0.1:7891

# 不走代理的地址
export no_proxy=localhost,127.0.0.1,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12
export NO_PROXY=localhost,127.0.0.1,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12

echo "全局代理已启用: HTTP/HTTPS -> 7890, SOCKS5 -> 7891"
EOF

    chmod +x "$CONFIG_DIR/proxy.sh"
    
    # 创建取消代理脚本
    cat > "$CONFIG_DIR/unproxy.sh" << 'EOF'
# 取消全局代理
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY
unset ALL_PROXY all_proxy no_proxy NO_PROXY
echo "全局代理已取消"
EOF

    chmod +x "$CONFIG_DIR/unproxy.sh"
    
    # 创建 systemd 启动时设置 iptables 规则的脚本
    cat > "$CONFIG_DIR/enable-tproxy.sh" << EOF
#!/bin/bash
# 启用透明代理 (TPROXY)

# 创建 mihomo 链
iptables -t mangle -N MIHOMO 2>/dev/null || iptables -t mangle -F MIHOMO
iptables -t mangle -N MIHOMO_LOCAL 2>/dev/null || iptables -t mangle -F MIHOMO_LOCAL

# 绕过本地地址
iptables -t mangle -A MIHOMO -d 127.0.0.0/8 -j RETURN
iptables -t mangle -A MIHOMO -d 172.16.0.0/12 -j RETURN
iptables -t mangle -A MIHOMO -d 192.168.0.0/16 -j RETURN
iptables -t mangle -A MIHOMO -d 10.0.0.0/8 -j RETURN

# 绕过 mihomo 本身
iptables -t mangle -A MIHOMO -m owner --uid-owner root -j RETURN 2>/dev/null || true

# 标记流量
iptables -t mangle -A MIHOMO -p tcp -j TPROXY --on-port 7896 --tproxy-mark 0x162
iptables -t mangle -A MIHOMO -p udp -j TPROXY --on-port 7896 --tproxy-mark 0x162

# 应用到 PREROUTING
iptables -t mangle -A PREROUTING -j MIHOMO

# 本地输出规则
iptables -t mangle -A MIHOMO_LOCAL -d 127.0.0.0/8 -j RETURN
iptables -t mangle -A MIHOMO_LOCAL -d 172.16.0.0/12 -j RETURN
iptables -t mangle -A MIHOMO_LOCAL -d 192.168.0.0/16 -j RETURN
iptables -t mangle -A MIHOMO_LOCAL -d 10.0.0.0/8 -j RETURN

iptables -t mangle -A MIHOMO_LOCAL -p tcp -j MARK --set-mark 0x162
iptables -t mangle -A MIHOMO_LOCAL -p udp -j MARK --set-mark 0x162

iptables -t mangle -A OUTPUT -j MIHOMO_LOCAL

# 添加路由
ip rule add fwmark 0x162 lookup 100 2>/dev/null || true
ip route add local default dev lo table 100 2>/dev/null || true

echo "透明代理已启用"
EOF

    chmod +x "$CONFIG_DIR/enable-tproxy.sh"
    
    # 创建关闭透明代理的脚本
    cat > "$CONFIG_DIR/disable-tproxy.sh" << 'EOF'
#!/bin/bash
# 关闭透明代理

iptables -t mangle -D PREROUTING -j MIHOMO 2>/dev/null || true
iptables -t mangle -D OUTPUT -j MIHOMO_LOCAL 2>/dev/null || true
iptables -t mangle -F MIHOMO 2>/dev/null || true
iptables -t mangle -F MIHOMO_LOCAL 2>/dev/null || true
iptables -t mangle -X MIHOMO 2>/dev/null || true
iptables -t mangle -X MIHOMO_LOCAL 2>/dev/null || true

ip rule del fwmark 0x162 lookup 100 2>/dev/null || true
ip route del local default dev lo table 100 2>/dev/null || true

echo "透明代理已关闭"
EOF

    chmod +x "$CONFIG_DIR/disable-tproxy.sh"
    
    # 添加到 /etc/profile.d 以便登录时自动加载
    echo "source $CONFIG_DIR/proxy.sh" > /etc/profile.d/mihomo-proxy.sh
    
    echo -e "${GREEN}全局代理配置已创建${NC}"
    echo -e "  ${BLUE}环境变量代理:${NC} source $CONFIG_DIR/proxy.sh"
    echo -e "  ${BLUE}取消代理:${NC} source $CONFIG_DIR/unproxy.sh"
    echo -e "  ${BLUE}透明代理:${NC} $CONFIG_DIR/enable-tproxy.sh"
    echo -e "  ${BLUE}关闭透明代理:${NC} $CONFIG_DIR/disable-tproxy.sh"
}

# 启用并启动服务
start_service() {
    echo -e "${BLUE}启用 mihomo 服务...${NC}"
    systemctl enable mihomo
    
    echo -e "${YELLOW}是否立即启动 mihomo 服务? (请先确保已配置代理节点) [y/N]${NC}"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        systemctl start mihomo
        echo -e "${GREEN}mihomo 服务已启动${NC}"
        systemctl status mihomo --no-pager
    else
        echo -e "${YELLOW}mihomo 服务未启动。配置好后运行: systemctl start mihomo${NC}"
    fi
}

# 安装工具脚本
install_tools() {
    echo -e "${BLUE}安装工具脚本...${NC}"
    
    # 获取脚本所在目录
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # 安装 mihomo-config
    if [ -f "$SCRIPT_DIR/mihomo-config" ]; then
        cp "$SCRIPT_DIR/mihomo-config" "$INSTALL_DIR/"
        chmod +x "$INSTALL_DIR/mihomo-config"
        echo -e "${GREEN}mihomo-config 已安装${NC}"
    fi
    
    # 安装 mihomo-sub
    if [ -f "$SCRIPT_DIR/mihomo-sub" ]; then
        cp "$SCRIPT_DIR/mihomo-sub" "$INSTALL_DIR/"
        chmod +x "$INSTALL_DIR/mihomo-sub"
        echo -e "${GREEN}mihomo-sub 已安装${NC}"
    fi
    
    # 安装更新脚本
    if [ -f "$SCRIPT_DIR/update.sh" ]; then
        cp "$SCRIPT_DIR/update.sh" "$INSTALL_DIR/mihomo-update"
        chmod +x "$INSTALL_DIR/mihomo-update"
        echo -e "${GREEN}mihomo-update 已安装${NC}"
    fi
}

# 显示使用说明
show_usage() {
    echo ""
    echo -e "${GREEN}=== Mihomo 安装完成 ===${NC}"
    echo ""
    echo -e "${BLUE}常用命令:${NC}"
    echo "  systemctl start mihomo    # 启动服务"
    echo "  systemctl stop mihomo     # 停止服务"
    echo "  systemctl restart mihomo  # 重启服务"
    echo "  systemctl status mihomo   # 查看状态"
    echo "  mihomo -v                 # 查看版本"
    echo ""
    echo -e "${BLUE}订阅管理:${NC}"
    echo "  mihomo-sub add <url>      # 添加订阅链接"
    echo "  mihomo-sub update         # 更新订阅"
    echo "  mihomo-sub list           # 列出备份"
    echo "  mihomo-sub restore [n]    # 恢复备份"
    echo "  mihomo-sub menu           # 交互式菜单"
    echo ""
    echo -e "${BLUE}配置工具:${NC}"
    echo "  mihomo-config status      # 查看配置状态"
    echo "  mihomo-config edit        # 编辑配置"
    echo "  mihomo-config test        # 测试配置"
    echo "  mihomo-config backup      # 备份配置"
    echo ""
    echo -e "${BLUE}配置文件:${NC}"
    echo "  $CONFIG_DIR/config.yaml   # 主配置文件"
    echo ""
    echo -e "${BLUE}代理设置:${NC}"
    echo "  HTTP/HTTPS: 127.0.0.1:7890"
    echo "  SOCKS5:     127.0.0.1:7891"
    echo "  Mixed:      127.0.0.1:7892"
    echo ""
    echo -e "${YELLOW}提示: 使用 'mihomo-sub add <订阅链接>' 快速配置代理${NC}"
    echo ""
}

# 主函数
main() {
    echo -e "${GREEN}=== Mihomo 一键安装脚本 ===${NC}"
    echo ""
    
    check_root
    detect_arch
    detect_os
    install_deps
    download_mihomo
    setup_config_dir
    setup_systemd
    setup_global_proxy
    install_tools
    show_usage
    start_service
}

main "$@"

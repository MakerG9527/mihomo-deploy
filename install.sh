#!/bin/bash
# Mihomo Deploy Script - 一键安装和配置 mihomo 代理

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 日志函数
log() { echo -e "${GREEN}[✓]${NC} $*"; }
info() { echo -e "${BLUE}[ℹ]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err() { echo -e "${RED}[✗]${NC} $*" >&2; }
banner() {
    echo ""
    echo "========================================"
    echo "  $*"
    echo "========================================"
    echo ""
}

# 版本配置
MIHOMO_VERSION="${MIHOMO_VERSION:-latest}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
CONFIG_DIR="${CONFIG_DIR:-/etc/mihomo}"

# 检测系统架构
detect_arch() {
    ARCH=$(uname -m)
    case $ARCH in
        x86_64|amd64)
            MIHOMO_ARCH="amd64"
            ARCH_SUFFIX="linux-amd64"
            ;;
        aarch64|arm64)
            MIHOMO_ARCH="arm64"
            ARCH_SUFFIX="linux-arm64"
            ;;
        armv7l|armhf)
            MIHOMO_ARCH="armv7"
            ARCH_SUFFIX="linux-armv7"
            ;;
        *)
            err "不支持的架构: $ARCH"
            exit 1
            ;;
    esac
    info "检测到的架构: $ARCH_SUFFIX"
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
        err "不支持的操作系统: $OSTYPE"
        exit 1
    fi
    info "检测到系统: $OS"
}

# 检查 root 权限
check_root() {
    if [ "$EUID" -ne 0 ]; then
        err "请使用 sudo 运行此脚本"
        exit 1
    fi
}

# 安装依赖
install_deps() {
    info "安装依赖..."
    case $OS in
        ubuntu|debian)
            apt-get update -qq
            apt-get install -y -qq curl wget iptables ipset 2>/dev/null || true
            ;;
        centos|rhel|fedora|rocky|almalinux)
            yum install -y curl wget iptables ipset 2>/dev/null || true
            ;;
        alpine)
            apk add --no-cache curl wget iptables ipset 2>/dev/null || true
            ;;
        *)
            warn "请手动安装: curl, wget, iptables, ipset"
            ;;
    esac
}

# 获取最新版本
get_latest_version() {
    curl -sL --connect-timeout 10 \
        "https://api.github.com/repos/MetaCubeX/mihomo/releases/latest" 2>/dev/null | \
        grep '"tag_name":' | head -1 | sed -E 's/.*"tag_name": "([^"]+)".*/\1/'
}

# 询问函数
ask_yesno() {
    local prompt="${1:-确认?}"
    local default="${2:-y}"
    local response
    
    read -p "$prompt [Y/n]: " response
    response="${response:-$default}"
    
    [[ "$response" =~ ^[Yy]$ ]]
}

# 获取下载 URL
get_download_url() {
    local version="$1"
    if [ "$version" = "latest" ]; then
        echo "https://github.com/MetaCubeX/mihomo/releases/latest/download/mihomo-linux-${MIHOMO_ARCH}-compatible.gz"
    else
        echo "https://github.com/MetaCubeX/mihomo/releases/download/${version}/mihomo-linux-${MIHOMO_ARCH}-compatible.gz"
    fi
}

# 下载 mihomo - 先询问本地文件，如果没有再尝试下载
download_mihomo() {
    banner "安装 Mihomo"
    
    # 步骤1: 询问是否有本地文件
    info "您是否有已下载的 mihomo .gz 文件?"
    if ask_yesno "使用本地文件"; then
        # 使用本地文件
        info "需要的文件格式: mihomo-${ARCH_SUFFIX}-v*.gz"
        echo ""
        echo "下载地址参考:"
        echo "  https://github.com/MetaCubeX/mihomo/releases"
        echo ""
        read -p "请输入本地 .gz 文件的完整路径: " file_path
        
        if [ -z "$file_path" ]; then
            err "未提供文件路径"
            exit 1
        fi
        
        # 展开路径
        file_path="${file_path/#\~/$HOME}"
        
        if [ ! -f "$file_path" ]; then
            err "文件不存在: $file_path"
            exit 1
        fi
        
        # 检查文件类型
        if ! file "$file_path" | grep -q "gzip"; then
            err "文件不是有效的 gzip 压缩文件"
            exit 1
        fi
        
        TMP_DIR=$(mktemp -d)
        cd "$TMP_DIR"
        cp "$file_path" mihomo.gz
        log "已加载本地文件: $file_path"
        
    else
        # 自动下载
        info "尝试自动下载..."
        
        # 获取版本
        VERSION=$(get_latest_version)
        if [ -z "$VERSION" ]; then
            VERSION="v1.18.10"
            warn "无法获取最新版本，使用默认版本: $VERSION"
        else
            info "最新版本: $VERSION"
        fi
        
        # 尝试多个镜像源
        DOWNLOAD_URLS=(
            "$(get_download_url "$VERSION")"
            "https://ghproxy.com/$(get_download_url "$VERSION" | sed 's|https://||')"
            "https://mirror.ghproxy.com/$(get_download_url "$VERSION" | sed 's|https://||')"
        )
        
        TMP_DIR=$(mktemp -d)
        cd "$TMP_DIR"
        
        local download_success=false
        for url in "${DOWNLOAD_URLS[@]}"; do
            info "尝试下载: ${url:0:80}..."
            if curl -sL --connect-timeout 15 --max-time 60 "$url" -o mihomo.gz 2>/dev/null; then
                # 检查文件是否有效
                if file mihomo.gz | grep -q "gzip" && [ -s mihomo.gz ]; then
                    log "下载成功"
                    download_success=true
                    break
                else
                    warn "文件无效，尝试下一个源..."
                    rm -f mihomo.gz
                fi
            else
                warn "下载失败，尝试下一个源..."
            fi
        done
        
        if [ "$download_success" = false ]; then
            err "自动下载失败"
            echo ""
            info "请手动下载后重新运行脚本"
            echo "下载地址: https://github.com/MetaCubeX/mihomo/releases"
            echo "需要的文件: mihomo-${ARCH_SUFFIX}-compatible.gz"
            rm -rf "$TMP_DIR"
            exit 1
        fi
    fi
    
    # 步骤2: 解压和安装
    info "解压文件..."
    if ! gunzip mihomo.gz; then
        err "解压失败"
        rm -rf "$TMP_DIR"
        exit 1
    fi
    
    if [ ! -f "mihomo" ]; then
        err "解压后未找到 mihomo 文件"
        rm -rf "$TMP_DIR"
        exit 1
    fi
    
    chmod +x mihomo
    info "安装到 $INSTALL_DIR..."
    mv mihomo "$INSTALL_DIR/"
    
    cd /
    rm -rf "$TMP_DIR"
    
    log "Mihomo 安装完成"
    mihomo -v 2>&1 | head -1
}

# 创建配置目录
setup_config_dir() {
    info "创建配置目录..."
    mkdir -p "$CONFIG_DIR"
    
    # 创建默认配置文件
    if [ ! -f "$CONFIG_DIR/config.yaml" ]; then
        cat > "$CONFIG_DIR/config.yaml" << 'EOF'
# Mihomo 配置文件
# 请使用 'mihomo-sub add <url>' 添加订阅

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

proxies: []

proxy-groups:
  - name: "🚀 节点选择"
    type: select
    proxies:
      - DIRECT

  - name: "🎯 全球直连"
    type: select
    proxies:
      - DIRECT

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

rules:
  - DOMAIN-SUFFIX,local,DIRECT
  - IP-CIDR,127.0.0.0/8,DIRECT
  - IP-CIDR,172.16.0.0/12,DIRECT
  - IP-CIDR,192.168.0.0/16,DIRECT
  - IP-CIDR,10.0.0.0/8,DIRECT
  - IP-CIDR,169.254.0.0/16,DIRECT
  - IP-CIDR,224.0.0.0/4,DIRECT
  - IP-CIDR,fe80::/10,DIRECT
  - GEOIP,CN,DIRECT
  - MATCH,🐟 漏网之鱼
EOF
        log "默认配置文件已创建: $CONFIG_DIR/config.yaml"
    fi
}

# 创建 systemd 服务
setup_systemd() {
    info "创建 systemd 服务..."
    
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
    log "systemd 服务已创建"
}

# 设置全局代理
setup_global_proxy() {
    info "设置全局代理..."
    
    # 创建代理配置脚本
    cat > "$CONFIG_DIR/proxy.sh" << 'EOF'
# Mihomo 全局代理配置脚本
export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890
export HTTP_PROXY=http://127.0.0.1:7890
export HTTPS_PROXY=http://127.0.0.1:7890
export ALL_PROXY=socks5://127.0.0.1:7891
export all_proxy=socks5://127.0.0.1:7891
export no_proxy=localhost,127.0.0.1,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12
export NO_PROXY=localhost,127.0.0.1,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12
echo "全局代理已启用: HTTP/HTTPS -> 7890, SOCKS5 -> 7891"
EOF

    chmod +x "$CONFIG_DIR/proxy.sh"
    
    # 创建取消代理脚本
    cat > "$CONFIG_DIR/unproxy.sh" << 'EOF'
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY
unset ALL_PROXY all_proxy no_proxy NO_PROXY
echo "全局代理已取消"
EOF

    chmod +x "$CONFIG_DIR/unproxy.sh"
    
    # 创建透明代理脚本
    cat > "$CONFIG_DIR/enable-tproxy.sh" << 'EOF'
#!/bin/bash
iptables -t mangle -N MIHOMO 2>/dev/null || iptables -t mangle -F MIHOMO
iptables -t mangle -N MIHOMO_LOCAL 2>/dev/null || iptables -t mangle -F MIHOMO_LOCAL
iptables -t mangle -A MIHOMO -d 127.0.0.0/8 -j RETURN
iptables -t mangle -A MIHOMO -d 172.16.0.0/12 -j RETURN
iptables -t mangle -A MIHOMO -d 192.168.0.0/16 -j RETURN
iptables -t mangle -A MIHOMO -d 10.0.0.0/8 -j RETURN
iptables -t mangle -A MIHOMO -p tcp -j TPROXY --on-port 7896 --tproxy-mark 0x162
iptables -t mangle -A MIHOMO -p udp -j TPROXY --on-port 7896 --tproxy-mark 0x162
iptables -t mangle -A PREROUTING -j MIHOMO
iptables -t mangle -A MIHOMO_LOCAL -d 127.0.0.0/8 -j RETURN
iptables -t mangle -A MIHOMO_LOCAL -d 172.16.0.0/12 -j RETURN
iptables -t mangle -A MIHOMO_LOCAL -d 192.168.0.0/16 -j RETURN
iptables -t mangle -A MIHOMO_LOCAL -d 10.0.0.0/8 -j RETURN
iptables -t mangle -A MIHOMO_LOCAL -p tcp -j MARK --set-mark 0x162
iptables -t mangle -A MIHOMO_LOCAL -p udp -j MARK --set-mark 0x162
iptables -t mangle -A OUTPUT -j MIHOMO_LOCAL
ip rule add fwmark 0x162 lookup 100 2>/dev/null || true
ip route add local default dev lo table 100 2>/dev/null || true
echo "透明代理已启用"
EOF

    chmod +x "$CONFIG_DIR/enable-tproxy.sh"
    
    cat > "$CONFIG_DIR/disable-tproxy.sh" << 'EOF'
#!/bin/bash
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
    
    # 添加到 profile.d
    echo "source $CONFIG_DIR/proxy.sh" > /etc/profile.d/mihomo-proxy.sh
    
    log "全局代理配置已创建"
}

# 安装工具脚本
install_tools() {
    info "安装工具脚本..."
    
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    if [ -f "$SCRIPT_DIR/mihomo-config" ]; then
        cp "$SCRIPT_DIR/mihomo-config" "$INSTALL_DIR/"
        chmod +x "$INSTALL_DIR/mihomo-config"
        log "mihomo-config 已安装"
    fi
    
    if [ -f "$SCRIPT_DIR/mihomo-sub" ]; then
        cp "$SCRIPT_DIR/mihomo-sub" "$INSTALL_DIR/"
        chmod +x "$INSTALL_DIR/mihomo-sub"
        log "mihomo-sub 已安装"
    fi
    
    if [ -f "$SCRIPT_DIR/update.sh" ]; then
        cp "$SCRIPT_DIR/update.sh" "$INSTALL_DIR/mihomo-update"
        chmod +x "$INSTALL_DIR/mihomo-update"
        log "mihomo-update 已安装"
    fi
}

# 交互式配置
interactive_config() {
    banner "配置 Mihomo"
    
    # 询问是否立即配置订阅
    if ask_yesno "是否立即配置代理订阅"; then
        if command -v mihomo-sub &> /dev/null; then
            mihomo-sub menu
        else
            warn "未找到 mihomo-sub，请手动运行: mihomo-sub"
        fi
    fi
    
    # 询问是否立即启动服务
    echo ""
    if ask_yesno "是否立即启动 Mihomo 服务"; then
        systemctl enable mihomo
        if systemctl start mihomo; then
            log "Mihomo 服务已启动"
            sleep 2
            systemctl status mihomo --no-pager
        else
            err "Mihomo 启动失败，请检查配置"
        fi
    else
        info "Mihomo 服务未启动。稍后运行: systemctl start mihomo"
    fi
}

# 显示使用说明
show_usage() {
    banner "Mihomo 安装完成"
    
    echo -e "${CYAN}常用命令:${NC}"
    echo "  systemctl start mihomo    # 启动服务"
    echo "  systemctl stop mihomo     # 停止服务"
    echo "  systemctl restart mihomo  # 重启服务"
    echo "  systemctl status mihomo   # 查看状态"
    echo "  mihomo -v                 # 查看版本"
    echo ""
    echo -e "${CYAN}订阅管理:${NC}"
    echo "  mihomo-sub add <url>      # 添加订阅链接"
    echo "  mihomo-sub update         # 更新订阅"
    echo "  mihomo-sub list           # 列出备份"
    echo "  mihomo-sub menu           # 交互式菜单"
    echo ""
    echo -e "${CYAN}配置工具:${NC}"
    echo "  mihomo-config status      # 查看配置状态"
    echo "  mihomo-config edit        # 编辑配置"
    echo "  mihomo-config test        # 测试配置"
    echo ""
    echo -e "${CYAN}代理设置:${NC}"
    echo "  HTTP/HTTPS: 127.0.0.1:7890"
    echo "  SOCKS5:     127.0.0.1:7891"
    echo "  Mixed:      127.0.0.1:7892"
    echo ""
    echo -e "${YELLOW}提示: 使用 'mihomo-sub add <订阅链接>' 快速配置代理${NC}"
}

# 主函数
main() {
    banner "Mihomo 一键安装脚本"
    
    check_root
    detect_arch
    detect_os
    install_deps
    download_mihomo
    setup_config_dir
    setup_systemd
    setup_global_proxy
    install_tools
    interactive_config
    show_usage
}

main "$@"

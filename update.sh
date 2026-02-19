#!/bin/bash
# Mihomo 更新脚本

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

MIHOMO_VERSION="${MIHOMO_VERSION:-latest}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"

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

banner "Mihomo 更新脚本"
echo ""

if [ "$EUID" -ne 0 ]; then
    err "请使用 sudo 运行此脚本"
    exit 1
fi

detect_arch

info "当前版本:"
mihomo -v 2>/dev/null || echo "未安装"

echo ""
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
    VERSION=$(curl -sL --connect-timeout 10 \
        "https://api.github.com/repos/MetaCubeX/mihomo/releases/latest" 2>/dev/null | \
        grep '"tag_name":' | head -1 | sed -E 's/.*"tag_name": "([^"]+)".*/\1/')
    
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

# 备份旧版本
if [ -f "$INSTALL_DIR/mihomo" ]; then
    cp "$INSTALL_DIR/mihomo" "$INSTALL_DIR/mihomo.backup.$(date +%Y%m%d%H%M%S)"
fi

# 停止服务
info "停止 Mihomo 服务..."
systemctl stop mihomo 2>/dev/null || true

# 解压和安装
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

log "新版本:"
mihomo -v 2>&1 | head -1

# 重启服务
info "重启服务..."
systemctl start mihomo
systemctl status mihomo --no-pager

log "更新完成!"

# Mihomo Deploy

一键安装和配置 [Mihomo](https://github.com/MetaCubeX/mihomo) 代理工具，支持全局透明代理。

## 特性

- 🚀 一键安装 Mihomo（原 Clash.Meta）
- 🔧 自动检测系统架构
- ⚙️ 自动生成默认配置文件
- 🌍 支持全局 HTTP/HTTPS/SOCKS5 代理
- 🔀 支持 TPROXY 透明代理
- 📦 集成 systemd 服务

## 快速开始

### 一键安装

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/your-username/mihomo-deploy/main/install.sh)"
```

或下载后执行：

```bash
git clone https://github.com/your-username/mihomo-deploy.git
cd mihomo-deploy
sudo bash install.sh
```

### 配置代理节点

安装完成后，编辑配置文件：

```bash
sudo nano /etc/mihomo/config.yaml
```

添加你的订阅链接或代理节点，然后重启服务：

```bash
sudo systemctl restart mihomo
```

## 使用方法

### 服务管理

```bash
# 启动服务
sudo systemctl start mihomo

# 停止服务
sudo systemctl stop mihomo

# 重启服务
sudo systemctl restart mihomo

# 查看状态
sudo systemctl status mihomo

# 查看日志
sudo journalctl -u mihomo -f
```

### 代理端口

| 协议 | 端口 |
|------|------|
| HTTP/HTTPS | 7890 |
| SOCKS5 | 7891 |
| Mixed | 7892 |
| Redir | 7895 |
| TPROXY | 7896 |

### 设置全局代理

**方法一：环境变量（推荐）**

```bash
# 启用代理
source /etc/mihomo/proxy.sh

# 取消代理
source /etc/mihomo/unproxy.sh
```

**方法二：透明代理（需要 root）**

```bash
# 启用透明代理（所有流量自动走代理）
sudo /etc/mihomo/enable-tproxy.sh

# 关闭透明代理
sudo /etc/mihomo/disable-tproxy.sh
```

## 配置示例

### 添加订阅链接

编辑 `/etc/mihomo/config.yaml`：

```yaml
proxy-providers:
  myprovider:
    type: http
    url: "https://your-subscription-url-here"
    interval: 3600
    path: ./proxy-providers/myprovider.yaml
    health-check:
      enable: true
      url: https://www.gstatic.com/generate_204
      interval: 300

proxy-groups:
  - name: "🚀 节点选择"
    type: select
    use:
      - myprovider
    proxies:
      - DIRECT
```

### 手动添加节点

```yaml
proxies:
  - name: "香港节点"
    type: vmess
    server: hk.example.com
    port: 443
    uuid: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    alterId: 0
    cipher: auto
    tls: true
    skip-cert-verify: false
    network: ws
    ws-opts:
      path: /path

  - name: "美国节点"
    type: ss
    server: us.example.com
    port: 8388
    cipher: aes-256-gcm
    password: your-password
```

## 目录结构

```
/etc/mihomo/
├── config.yaml          # 主配置文件
├── proxy.sh             # 启用环境变量代理
├── unproxy.sh           # 取消环境变量代理
├── enable-tproxy.sh     # 启用透明代理
└── disable-tproxy.sh    # 关闭透明代理
```

## 卸载

```bash
sudo systemctl stop mihomo
sudo systemctl disable mihomo
sudo rm -f /usr/local/bin/mihomo
sudo rm -rf /etc/mihomo
sudo rm -f /etc/systemd/system/mihomo.service
sudo rm -f /etc/profile.d/mihomo-proxy.sh
sudo systemctl daemon-reload
```

## 系统支持

- Ubuntu/Debian
- CentOS/RHEL/Rocky/AlmaLinux
- Alpine Linux
- macOS（需手动安装）

## 架构支持

- x86_64 (amd64)
- ARM64 (aarch64)
- ARMv7

## 许可证

MIT License

## 相关链接

- [Mihomo 官方仓库](https://github.com/MetaCubeX/mihomo)
- [Mihomo 配置文档](https://wiki.metacubex.one/)

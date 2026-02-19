# Mihomo Deploy

一键安装和配置 [Mihomo](https://github.com/MetaCubeX/mihomo) 代理工具，支持全局透明代理。

## 特性

- 🚀 一键安装 Mihomo（原 Clash.Meta）
- 🔧 自动检测系统架构
- ⚙️ 自动生成默认配置文件
- 🌍 支持全局 HTTP/HTTPS/SOCKS5 代理
- 🔀 支持 TPROXY 透明代理
- 📦 集成 systemd 服务
- 📥 下载失败时支持手动输入下载地址
- 🔄 订阅管理工具 (mihomo-sub)
- 🔧 配置管理工具 (mihomo-config)

## 快速开始

### 一键安装

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/MakerG9527/mihomo-deploy/main/install.sh)"
```

或下载后执行：

```bash
git clone https://github.com/MakerG9527/mihomo-deploy.git
cd mihomo-deploy
sudo bash install.sh
```

**注意：** 如果自动下载失败，脚本会提示你手动输入 mihomo 的下载地址。

## 工具命令

安装后会提供以下命令行工具：

### mihomo-sub - 订阅管理

```bash
# 添加订阅链接
sudo mihomo-sub add "https://your-subscription-url"

# 更新当前订阅
sudo mihomo-sub update

# 列出可用备份
sudo mihomo-sub list

# 恢复备份
sudo mihomo-sub restore 1

# 查看当前订阅
sudo mihomo-sub show

# 测试配置
sudo mihomo-sub test

# 交互式菜单
sudo mihomo-sub menu
```

**订阅管理功能：**
- 自动检测订阅格式（Base64、Clash YAML 等）
- 自动格式转换（使用在线 API）
- 自动补充必要配置项（端口、规则等）
- 自动备份历史配置
- 支持一键恢复

### mihomo-config - 配置管理

```bash
# 查看状态
sudo mihomo-config status

# 设置端口
sudo mihomo-config set-port 7890
sudo mihomo-config set-mixed-port 7892

# 启用/禁用透明代理
sudo mihomo-config enable-tproxy
sudo mihomo-config disable-tproxy

# 测试配置
sudo mihomo-config test

# 编辑配置
sudo mihomo-config edit

# 备份和恢复
sudo mihomo-config backup
sudo mihomo-config restore /etc/mihomo/config.yaml.backup.xxx
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

### 使用 mihomo-sub 添加订阅

```bash
# 添加订阅（支持多种格式）
sudo mihomo-sub add "https://your-subscription-url"

# 脚本会自动：
# 1. 下载订阅内容
# 2. 检测并转换格式（Base64/V2Ray/Clash）
# 3. 补充端口、规则等必要配置
# 4. 验证配置有效性
# 5. 备份旧配置
# 6. 应用新配置
```

### 手动配置节点

如果只有单个节点链接，可以手动编辑配置文件：

```bash
sudo nano /etc/mihomo/config.yaml
```

示例节点配置：

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
    network: ws
    ws-opts:
      path: /path

  - name: "美国节点"
    type: ss
    server: us.example.com
    port: 8388
    cipher: aes-256-gcm
    password: your-password

proxy-groups:
  - name: "🚀 节点选择"
    type: select
    proxies:
      - "香港节点"
      - "美国节点"

  - name: "🎯 全球直连"
    type: select
    proxies:
      - DIRECT

  - name: "🐟 漏网之鱼"
    type: select
    proxies:
      - "🚀 节点选择"
      - DIRECT

rules:
  - DOMAIN-SUFFIX,local,DIRECT
  - IP-CIDR,127.0.0.0/8,DIRECT
  - GEOIP,CN,DIRECT
  - MATCH,🐟 漏网之鱼
```

## 目录结构

```
/etc/mihomo/
├── config.yaml          # 主配置文件
├── subscription.url     # 当前订阅链接
├── backups/             # 配置备份目录
├── proxy.sh             # 启用环境变量代理
├── unproxy.sh           # 取消环境变量代理
├── enable-tproxy.sh     # 启用透明代理
└── disable-tproxy.sh    # 关闭透明代理

/usr/local/bin/
├── mihomo               # mihomo 主程序
├── mihomo-sub           # 订阅管理工具
├── mihomo-config        # 配置管理工具
└── mihomo-update        # 更新脚本
```

## 卸载

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/MakerG9527/mihomo-deploy/main/uninstall.sh)"
```

或手动卸载：

```bash
sudo systemctl stop mihomo
sudo systemctl disable mihomo
sudo rm -f /usr/local/bin/mihomo
sudo rm -f /usr/local/bin/mihomo-sub
sudo rm -f /usr/local/bin/mihomo-config
sudo rm -f /usr/local/bin/mihomo-update
sudo rm -rf /etc/mihomo
sudo rm -f /etc/systemd/system/mihomo.service
sudo rm -f /etc/profile.d/mihomo-proxy.sh
sudo systemctl daemon-reload
```

## 更新

```bash
sudo mihomo-update
```

或：

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/MakerG9527/mihomo-deploy/main/update.sh)"
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

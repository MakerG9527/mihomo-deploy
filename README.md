# Mihomo Deploy

一键安装和配置 [Mihomo](https://github.com/MetaCubeX/mihomo) 代理工具，支持全局透明代理。

## 特性

- 🚀 一键安装 Mihomo（原 Clash.Meta）
- 🔧 自动检测系统架构
- 📦 集成 systemd 服务
- 🌍 支持全局 HTTP/HTTPS/SOCKS5 代理
- 🔀 支持 TPROXY 透明代理
- 📥 **先询问本地文件，支持离线安装**
- 🔄 交互式订阅管理 (mihomo-sub)
- ⚙️ 配置管理工具 (mihomo-config)
- 🚫 可选禁用 GEOIP 规则

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

### 安装流程

1. **询问是否有本地压缩包** - 如果有，直接指定本地 `.gz` 文件路径
2. **如果没有，自动下载** - 尝试多个镜像源
3. **交互式配置** - 询问是否立即配置订阅和启动服务

## 工具命令

### mihomo-sub - 订阅管理

```bash
# 交互式菜单
sudo mihomo-sub

# 命令行操作
sudo mihomo-sub add "https://your-subscription-url"   # 添加订阅
sudo mihomo-sub update                                 # 更新订阅
sudo mihomo-sub list                                   # 列出备份
sudo mihomo-sub restore 1                              # 恢复备份
sudo mihomo-sub show                                   # 显示当前订阅
sudo mihomo-sub test                                   # 测试配置
```

**订阅管理功能：**
- ✅ 自动检测订阅格式（Base64、Clash YAML 等）
- ✅ 自动格式转换（使用在线 API）
- ✅ 自动补充必要配置项（端口、规则等）
- ✅ **可选禁用 GEOIP 规则**（避免验证警告）
- ✅ 配置验证
- ✅ 自动备份历史配置
- ✅ 支持一键恢复

### mihomo-config - 配置管理

```bash
sudo mihomo-config status      # 查看配置状态
sudo mihomo-config edit        # 编辑配置
sudo mihomo-config test        # 测试配置
sudo mihomo-config backup      # 备份配置
sudo mihomo-config enable-tproxy   # 启用透明代理
sudo mihomo-config disable-tproxy  # 禁用透明代理
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
sudo mihomo-sub add "https://your-subscription-url"
```

**流程：**
1. 下载订阅内容
2. 检测格式（Base64/V2Ray/Clash）
3. 自动转换格式（如有需要）
4. 补充端口、规则等配置
5. **询问是否禁用 GEOIP 规则**
6. 验证配置有效性
7. 备份旧配置
8. 应用新配置
9. 询问是否重启服务

### 手动安装（离线模式）

如果服务器无法访问互联网：

1. 在本地下载 Mihomo：
   ```bash
   # 访问 https://github.com/MetaCubeX/mihomo/releases
   # 下载对应架构的文件，如: mihomo-linux-amd64-v1.18.10.gz
   ```

2. 上传到服务器，然后运行安装脚本：
   ```bash
   sudo bash install.sh
   # 选择 "使用本地文件"
   # 输入文件路径: /path/to/mihomo-linux-amd64-v1.18.10.gz
   ```

### 手动配置节点

如果只有单个节点，可以手动编辑配置：

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

proxy-groups:
  - name: "🚀 节点选择"
    type: select
    proxies:
      - "香港节点"
      - DIRECT

rules:
  - GEOIP,CN,DIRECT
  - MATCH,🚀 节点选择
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

更新流程与安装相同：先询问是否有本地文件，如果没有则自动下载。

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

# speedtest-cdn

CDN 测速节点**全流程维护工具**：互联网发现 → 健康检测与自动更新 → 测速验证。

- 🚀 **一键运行**：Windows / Linux / macOS / Docker 全平台
- 🔍 **自动发现**：从多个来源（厂商 APP 下载源、字节 CDN 变体、运营商 CDN、GitHub 列表）发现新测速链接
- 🩺 **健康检测**：检测全部节点下载链接可用性（自动带浏览器 UA/Referer，避免误判防盗链源）
- 🔄 **自动更新**：死链自动从备用池替换；池耗尽时由保底无限流源兜底
- 📊 **测速验证**：更新后实际测速（多流并发 HTTP 下载 + 上传），输出验证报告
- 📦 **零依赖**：仅使用 Node.js 内置模块，无需 `npm install`
- 🐳 **Docker 支持**：镜像开箱即用

---

## 快速开始

### Windows

```bat
:: 1. 安装环境（自动下载便携 Node.js，无需管理员权限）
install.bat

:: 2. 运行全流程
run.bat
```

### Linux / macOS

```bash
# 1. 安装环境（自动下载便携 Node.js）
chmod +x install.sh run.sh
./install.sh

# 2. 运行全流程
./run.sh
```

### Docker

```bash
cd docker
docker compose up --build
```

---

## 全流程说明

```
┌─────────────────────────────────────────────────────────────┐
│  [1/3] 互联网发现  cdn-discovery.mjs                         │
│        从厂商 APP 下载源 / 字节 CDN 变体 / 运营商 CDN 等      │
│        发现候选测速链接 → 写入备用池                          │
├─────────────────────────────────────────────────────────────┤
│  [2/3] 检测更新    update-cdn-nodes.mjs                      │
│        检测 lib/servers.js 全部下载链接可用性                 │
│        (带 UA/Referer 防误判)                                │
│        死链 → 备用池同组替换 → 写回 lib/servers.js           │
├─────────────────────────────────────────────────────────────┤
│  [3/3] 测速验证    verify-nodes.mjs                          │
│        对更新后的节点实际测速(多流下载+上传)                  │
│        → reports/verify-report.json                         │
└─────────────────────────────────────────────────────────────┘
```

### 运行模式

```bash
./run.sh                    # 完整流程
./run.sh --quick            # 快速模式（缩短测速时长/减少并发）
./run.sh --check-only       # 仅检测，不修改 servers.js
./run.sh --skip-discovery   # 跳过互联网发现
./run.sh --nodes cdn-360,cdn-speedo   # 仅验证指定节点
./run.sh --verbose          # 详细日志
```

---

## 目录结构

```
speedtest-cdn/
├── lib/
│   ├── servers.js          # 节点配置（由更新脚本自动维护）
│   └── cdnSpeedtest.js     # 测速引擎（多流下载/上传/健康检查/保底源）
├── scripts/
│   ├── pipeline.mjs        # 一键全流程编排
│   ├── cdn-discovery.mjs   # [1/3] 互联网链接发现
│   ├── update-cdn-nodes.mjs# [2/3] 健康检测与自动更新
│   └── verify-nodes.mjs    # [3/3] 测速验证
├── docker/
│   ├── Dockerfile
│   └── docker-compose.yml
├── data/                   # 备用池（运行时生成）
├── reports/                # 报告（运行时生成）
├── run.sh / run.bat / run.ps1          # 一键运行
├── install.sh / install.bat / install.ps1  # 环境安装
└── package.json
```

---

## 节点配置

`lib/servers.js` 中的 `CDN_SERVERS` 定义测速节点，每个节点支持：

```js
"cdn-example": {
    id: "cdn-example",
    name: "示例 CDN",
    downloadUrls: [           // 多源池（测速时随机选取，死链自动跳过）
        "https://cdn1.example.com/speedtest.bin",
        "https://cdn2.example.com/speedtest.bin"
    ],
    fallbackDownloadUrl: "http://webcdn.m.qq.com/speed/SpeedTestData.dat",
                              // 保底无限流源（池全部失效时兜底）
    uploadUrls: [             // 上传端点池（可选，缺省用共享池）
        "https://mbd.baidu.com/ztbox?action=zpblog&nocache=1"
    ],
    pingUrl: "http://webcdn.m.qq.com",
    streams: 15,              // 并发流数
    downloadTime: 10,         // 下载测速时长(秒)
    uploadTime: 10            // 上传测速时长(秒)
}
```

### 测速引擎特性（lib/cdnSpeedtest.js）

| 特性 | 说明 |
|---|---|
| 多流并发 | 默认 6 流（可配置），HTTP 下载 + POST 上传 |
| 死链健康检查 | 响应 4xx/5xx 或网络错误立即换下一候选，不空转 |
| 防盗链支持 | 自动附加浏览器 UA + 按主机匹配 Referer（腾讯视频/央视/凤凰等） |
| 保底源 | 源池全部失效时自动使用 `fallbackDownloadUrl` |
| 无限流安全 | 测速窗口结束后主动断开持续推流的连接（防挂起） |
| 上传端点适配 | Cloudflare `__up` 需 UA/Origin；QQ netsp 走 octet-stream；其余直传 |

---

## 环境要求

- **Node.js >= 18**（安装脚本可自动下载便携版，无需预先安装）
- **网络**：能访问目标 CDN（部分专线节点仅对应运营商网络可达）

无需 npm 依赖。测速为纯 HTTP 实现，**不依赖 Ookla/LibreSpeed/Cloudflare 外部二进制**。

---

## 报告输出

| 文件 | 内容 |
|---|---|
| `reports/last-report.json` | 检测报告：链接总数 / 可用 / 失效 / 替换数 / 备用池规模 |
| `reports/verify-report.json` | 验证报告：各节点实测下载/上传速度、耗时、平均与最快节点 |
| `data/cdn-backup-pool.json` | 备用池：按 CDN 分组的可用候选链接（跨运行累积） |

---

## 定时任务（可选）

让节点池持续保持健康：

```bash
# Linux crontab — 每天 03:17 自动执行
17 3 * * * cd /path/to/speedtest-cdn && ./run.sh >> logs/cron.log 2>&1
```

```powershell
# Windows 计划任务 (PowerShell 管理员)
$action = New-ScheduledTaskAction -Execute "node" `
    -Argument "scripts\pipeline.mjs" -WorkingDirectory "C:\path\to\speedtest-cdn"
$trigger = New-ScheduledTaskTrigger -Daily -At 3:17AM
Register-ScheduledTask -TaskName "speedtest-cdn" -Action $action -Trigger $trigger
```

---

## 常见问题

**Q: 检测报告显示部分节点失效且无法替换？**
A: 专线节点（电信/移动/Ookla）仅在对应运营商网络可达，属预期行为而非链接失效。这类节点不会自动替换。

**Q: 测速某个节点速度为 0？**
A: 检查网络是否能访问该 CDN。多源池节点会自动跳过失效源；全池失效时自动使用保底源。

**Q: 如何添加自定义节点？**
A: 编辑 `lib/servers.js`，在 `CDN_SERVERS` 中按上述格式添加即可，后续运行会自动纳入检测。

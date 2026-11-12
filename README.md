# Ekko Studio 0.7.21 · Windows 部署笔记

记录 Ekko Studio 0.7.21 在 Windows 上的部署、运行目录隔离和 Hermes 桥接验证。启动脚本使用 [上游 v0.7.21](https://github.com/EKKOLearnAI/ekko-studio/releases/tag/v0.7.21) 对应的 npm 包。上游程序及其许可证随原始发行渠道提供。

| 项目 | 本机进度 |
| --- | --- |
| Windows Web UI | 已部署并验证就绪探针与本地网页登录。 |
| 迁移验证 | 已在本机检查三份迁移配置。下方提供从空目录启动的步骤。 |
| Hermes Agent 0.18.2 | 已完成本机桥接验证。新环境需要自行安装并配置 Hermes Agent。 |
| 模型通道 | 已验证自配通道和本机调用。新环境按需配置自己的提供商。 |

## 从空目录启动

准备 Node.js 23 或更高版本和 PowerShell 7。原部署使用 Node.js 24。先安装固定版本的包，再设置本次本机登录口令并启动：

```powershell
$packageRoot = Join-Path $env:LOCALAPPDATA 'EkkoStudio-Windows-Package'
npm install --prefix $packageRoot hermes-web-ui@0.7.21
$packageDir = Join-Path $packageRoot 'node_modules/hermes-web-ui'

$env:AUTH_TOKEN = Read-Host '本机 Ekko Studio 登录口令' -MaskInput
try {
    .\Start-EkkoStudio.ps1 -PackageDirectory $packageDir
} finally {
    Remove-Item Env:AUTH_TOKEN -ErrorAction SilentlyContinue
}
```

就绪后打开 `http://127.0.0.1:8648/`，输入刚才设置的口令。若端口已占用，可传入 `-Port`。也可用 `-Node` 指定 `node.exe`。

脚本监听本机环回地址，默认将 Web UI 状态、Hermes 状态和日志写入本机应用数据目录下的 `EkkoStudio-Windows-Notes`。并行测试时使用不同的 `-Port` 和 `-DataDirectory`。进程号会在就绪时显示，可在任务管理器中按该进程号结束此次实例。

## Hermes 运行时

Web UI 和 Hermes Agent 使用分开的数据目录。启动脚本将 `HERMES_HOME` 和 `HERMES_AGENT_BASE_HOME` 指向实例的 `hermes`，并将工作区设为其中的 `workspace`。使用 Hermes 前需独立安装运行时并在本机配置提供商。脚本关闭了网关自动启动、局域网发现、自动注入 MCP 和技能。

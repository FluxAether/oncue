---
name: oncue-control
version: "1.0.0"
display_name: OnCue 控制
display_name_en: OnCue Control
description: 通过 OnCue App 的本地 CLI 查询应用、副驾和浮窗状态，按明确授权启动或停止音频会话、显示或隐藏副驾，并查询超时操作；系统未安装 OnCue 时从官方源校验下载并安装。用户提到安装或查询 OnCue、开始/停止监听或录音、打开/显示/隐藏副驾（包括 open/show/hide copilot）时使用。仅支持 macOS 和 Windows，不用于读取转录、录音、简历、凭据或更改账户与设置。
description_zh: 通过 OnCue App 的本地 CLI 查询应用、副驾和浮窗状态，按明确授权启动或停止音频会话、显示或隐藏副驾，并查询超时操作；系统未安装 OnCue 时从官方源校验下载并安装。用户提到安装或查询 OnCue、开始/停止监听或录音、打开/显示/隐藏副驾（包括 open/show/hide copilot）时使用。仅支持 macOS 和 Windows，不用于读取转录、录音、简历、凭据或更改账户与设置。
description_en: Use OnCue App's local CLI to query app, copilot, and floating-window status; start or stop audio sessions and show or hide the copilot only with explicit authorization; and query timed-out operations. If OnCue is not installed, download, verify, and install it from official sources. Use when the user asks to install or check OnCue, start/stop listening or recording, or open/show/hide the copilot. Supports macOS and Windows only. Do not use to read transcripts, recordings, resumes, or credentials, or to change accounts or settings.
---

# OnCue Control

## 先确认意图与边界

- 只使用同一 App 的 `oncue` / `oncue.exe` 的 `cli` 命令空间；不实现 RPC 客户端，不安装另一个 CLI 产品。
- 先读 [命令与结果参考](references/commands.md)，再调用命令；不要猜字段或将 JSON-RPC 封套当作平铺业务对象。
- 将“打开副驾”“显示副驾”解释为 **window show**，绝不解释为开始采集。将“隐藏副驾”解释为 **window hide**，绝不解释为停止采集。
- 仅在用户明确授权后执行 start、stop、show、hide；意图不清时先询问。状态查询可能冷启动 GUI，但绝不录音；向需要了解此副作用的用户说明。
- 不读取转录、录音、问题/回答、简历、账户标识、设备名、录音路径或密钥。不提供 toggle、clear、任意 invoke、设置写入、关闭窗口保护或绕过权限的替代路径。

## 1. 定位、必要时安装，再查询

先只读定位 App，再发状态请求。helper 优先使用显式 `ONCUE_BIN`，否则只检查标准安装位置/Windows 安装记录；从不搜索 PATH 或扫描磁盘。

- `ONCUE_BIN` 已设置但无效时停止，不清除、不回退安装。helper 退出 127 不等于未安装。
- 已有 App 但没有新 `oncue` / `oncue.exe`，或有残留/不完整安装时，报告旧版或安装异常，不覆盖、不升级、不停止现有 App；不执行旧 `rabbitinterview` 探测。读取失败或已知非标准安装同样不能当作缺失。
- **确认系统未安装 OnCue 时，自动按 [官方下载安装流程](references/install.md) 下载、校验并安装当前用户版本，然后继续本节。** 先简短告知，不增加重复确认；遵守宿主审批，不提权、不绕过安全策略。不要只凭 helper 127 就安装，也不自动安装 PATH 命令或用户 Skill。

对可信的新 binary，先通过对应 helper 执行 `cli --help --json`，限时 15 秒，确认退出 0、合法 JSON-RPC `result.help` 包含 `Usage: oncue cli`，再查询状态。能力检查失败时停止；安装成功不等于 CLI 可用，不自动重装。正式发布包可能尚未包含 CLI；只凭版本号或安装器退出码不能确认。

将下例中的 `<skill-dir>` 替换为本 Skill 的可信绝对目录。使用独立 argv，不拼接用户文本执行。

macOS 使用 [shell helper](scripts/oncue.sh)，无需 Python/Node：

```bash
/bin/bash "<skill-dir>/scripts/oncue.sh" cli app status --json
```

Windows 使用 [PowerShell helper](scripts/oncue.ps1)，它显式等待 GUI-subsystem 子进程并分别转发 OS stdout/stderr：

```powershell
powershell.exe -NoLogo -NoProfile -NonInteractive -File "<skill-dir>\scripts\oncue.ps1" cli app status --json
```

先查 `app status`，再按任务查 `copilot status` 或 `window status`。不要因 App 不在运行而手工另起 GUI；控制命令负责有界冷启动。正常暖调用不应为了查询而聚焦主窗口。

直接调用 helper 不会下载安装；上述缺失时安装由 Skill 编排。未知路径仍需可信来源，不执行工作目录里的同名文件。

## 2. 只执行已授权的动作

| 用户明确意图 | 执行 |
| --- | --- |
| 查询状态 | 仅相应 status 命令 |
| 打开/显示副驾 | `window show`，不调用 start |
| 隐藏副驾 | `window hide`，不调用 stop |
| 开始监听/录音 | `copilot start`，默认 `--audio saved` |
| 停止监听/录音 | `copilot stop`，并分别核对采集与归档 |

除非用户明确选择 `system`、`microphone` 或 `both`，使用 `saved` 以尊重现有音频来源。不修改持久化设置，不为解决冲突自行 stop/start。已在运行时说明实际状态；不要把 `starting`、`stopping` 或“已发送事件”当作成功。

为每个新的变更动作创建一个合法且唯一的 `--request-id`，在整个动作中保存该 ID、方法、参数和返回的 operation ID；它与每次请求的 JSON-RPC `id` 不同。只在用户授权重试且已确认安全时复用**相同** request ID 与参数，不因报错换 ID 重发。

## 3. 处理交互、超时与终态

- 登录、系统授权或恢复待处理时停止自动动作，引导用户在 GUI 完成；不要自动登录、购买、清空恢复会话、提权、删除端点或绕过安全检查。用户处理后重新查询状态。
- `error` 不代表动作一定未发生。遇到 TIMEOUT/OPERATION_UNKNOWN，保留 `error.data.operationId`，用 `operations get <operation-id> --json` 查询；不要重发变更。查询仍 pending/unknown 或没有可查询 ID 时如实报告未确认，不无限轮询。
- `operations.get` 查询本身成功不代表原动作成功；读取操作记录的终态及其结果/错误。App 重启、host 重载或记录过期后不要声称 exactly-once，也不要用新 ID 自动补做。
- 只有达到 `listening` 的 started/already-running 结果才报告正在采集。show/hide 只报告可见性与实际保护状态；隐藏不停止音频，也不关闭保护，不保证所有录屏软件都无法捕获。
- stop 后分别报告 `captureStopped` 与 `archive.outcome`（empty/saved/partial/failed），必要时补充 `recordSaved`。不要把“采集已停”说成“全部归档成功”；缺失确认时报告未知并建议 GUI 检查，不重复 stop 以修复归档。
- 只向用户概括已验证的白名单状态/归档结果；保留实际退出码，不泄露原始敏感内容，不将假 executable 测试当作真实 App 或音频验证。

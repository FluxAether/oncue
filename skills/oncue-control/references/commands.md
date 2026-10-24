# 命令与结果参考

## 命令白名单

以下命令由同一 OnCue App executable 承担。macOS binary 为 `oncue`，Windows 为 `oncue.exe`；不要使用旧 Cargo package 名 `rabbitinterview` 定位程序。

| argv（binary 之后） | RPC method | 语义 |
| --- | --- | --- |
| `cli app status --json` | `app.status` | 应用/控制就绪状态，不启动采集 |
| `cli copilot status --json` | `copilot.status` | 白名单会话摘要，不读取转录 |
| `cli copilot start --audio saved --request-id <request-id> --json` | `copilot.start` | 按明确授权开始采集 |
| `cli copilot stop --request-id <request-id> --json` | `copilot.stop` | 停止采集并分别报告归档结果 |
| `cli window status --json` | `copilot.window.status` | 浮窗可见性与保护状态 |
| `cli window show --request-id <request-id> --json` | `copilot.window.show` | 仅显示，不开始采集 |
| `cli window hide --request-id <request-id> --json` | `copilot.window.hide` | 仅隐藏，不停止采集/关闭保护 |
| `cli operations get <operation-id> --json` | `operations.get` | 查询已知操作，不重发动作 |

公共 `--timeout-ms` 默认 60000，范围 100..300000；它是等待上限，不是录音时长。`--audio` 只用于 start，可选 `saved|system|microphone|both`，省略等同 saved，不写入持久化设置。

`--request-id` 只用于 start/stop/show/hide，映射 RPC `params.requestId`；长度 1..128，仅 ASCII 字母、数字和 `._:-`。同 ID、同方法和规范化参数关联同一操作；同 ID 改参数会冲突。超时不要自动重试；用户授权的安全重试仍使用原 ID 和参数。JSON-RPC 的关联 `id` 由 CLI 为每次调用生成，与 request ID 无关；operation ID 由原生生成，是后续查询的 UUID。

help、版本与非法参数不启动 GUI。远程控制命令在明确未运行时自动拉起同一 App 的 GUI；status 可以打开 GUI，但绝不启动录音。登录/权限/恢复仍需用户在 GUI 交互，不自动清空、不绕过。

## stdout、stderr 与错误

`--json` 的 stdout 是一个 UTF-8 JSON-RPC 2.0 封套，不是平铺会话对象。恰有一个 `result` 或 `error`；诊断留在 stderr。解析 `jsonrpc`、`id` 和 result/error，不根据退出码 0 或某段 message 文案推断原操作的业务终态。

```json
{"jsonrpc":"2.0","id":"correlation-id","result":{"outcome":"status","session":{"phase":"idle","audioMode":"none","recoveryPending":false,"sessionRef":null,"archiveStatus":"idle"}}}
```

上例仅演示 copilot status 的封套形状，不是实际运行记录。错误用数字 `error.code` 表示 JSON-RPC 分类，用 `error.data.code` 表示稳定的大写业务码。超时错误的示意：

```json
{"jsonrpc":"2.0","id":"correlation-id","error":{"code":-32000,"message":"The wait ended; query the operation instead of retrying","data":{"code":"TIMEOUT","operationId":"00000000-0000-4000-8000-000000000001"}}}
```

取 `error.data.operationId` 原值运行 `cli operations get <operation-id> --json`。operation 查询的封套成功只表示取得记录；必须再检查记录内的执行状态与终态结果。未完成、unknown、host 丢失或 App 重启时不要猜测是否已执行，不盲重试。

| App 退出码 | 含义/处置 |
| --- | --- |
| 0 | 命令/查询成功，仍需检查业务结果 |
| 2 | 用法、协议或参数错误，修正参数，不重发变更 |
| 3 | 需要用户在 GUI 交互（包括待处理恢复） |
| 4 | 执行失败，按稳定业务码说明，不自动做补偿动作 |
| 5 | 结果未知或等待超时；有 operation ID 则查询 |
| 6 | 连接、启动、安全或实例/协议不匹配；不清理端点或换程序尝试 |

常见 `error.data.code` 包括 INVALID_PARAMS、INTERACTION_REQUIRED、RESTORING、NOT_READY、INITIALIZATION_FAILED、TIMEOUT、OPERATION_UNKNOWN、HOST_UNAVAILABLE、REQUEST_ID_CONFLICT、BUSY、AUDIO_CONFLICT、CAPTURE_START_FAILED、CAPTURE_STOP_FAILED、ARCHIVE_FAILED、WINDOW_FAILED、SESSION_CHANGED、DEADLINE_EXCEEDED、ENDPOINT_UNAVAILABLE、LAUNCH_FAILED、SECURITY_ERROR 和 PROTOCOL_MISMATCH。标准协议错误由数字 code 区分（如 -32700/-32600/-32601/-32602）；不要把所有 -32000 当成同一种失败。

helper 定位失败时 stdout 为空、stderr 以 `oncue helper:` 开头，退出 127；PowerShell helper 的本地执行/标准流转发失败退出 126。这些是 wrapper 自身错误，不伪造 App 的 JSON-RPC 错误；成功启动子进程后转发它的真实退出码。

## 只读取白名单结果

- 会话摘要只含 `phase`、`audioMode`、`recoveryPending`、不透明 `sessionRef`、`archiveStatus` 等控制字段；不要读取/推断转录、问题、答案、图片、简历、账号、设备名、录音路径或凭据。
- start 只有 `started` 或 `already-running` 且 phase 为 `listening` 才算开始成功；`starting`/`stopping` 不算成功。音频冲突请用户决定，不自动停止现有会话。
- stop 的业务结果用 `captureStopped` 确认采集，用 `archive.outcome` 区分 `empty`（无内容）、`saved`（归档成功）、`partial`（部分归档失败）、`failed`（归档失败）；`recordSaved` 单独表明记录是否保存。部分归档失败不等于仍在采集，也不应再启动/停止音频以“修复”。缺少这些确认时报告未知，不能假报成功。
- 浮窗字段包括 `visible`、`protectionRequested`、`protectionApplied`、`platformSupported`；区分请求保护与实际应用保护，不宣称对所有录屏软件绝对有效。

## 安全调用 helper

shell helper 用 argv 数组和 exec；PowerShell helper 用 .NET Process、Windows argv quote 规则、并行字节流转发和 WaitForExit，不使用 eval/Invoke-Expression。不要将用户的话拼成命令代码。Windows 的 OS stdout/stderr 不属于当前 PowerShell pipeline，机器捕获应启动独立 powershell.exe/pwsh 进程，而不是 `$json = & .\oncue.ps1 ...`。

只将 `ONCUE_BIN` 设为用户确认可信的完整 executable 路径。默认发现只覆盖 macOS 的系统/用户 Applications，以及 Windows 标准安装目录、App Paths 和 DisplayName 为 OnCue 的卸载记录 InstallLocation；不执行注册表命令字符串，不搜索 PATH，不递归扫描磁盘。若 helper 被系统执行策略拦截，说明阻塞并请用户按其组织策略处理，不自动设置 Bypass 或修改策略。

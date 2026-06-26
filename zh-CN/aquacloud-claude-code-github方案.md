# AquaCloud 接入 Claude Code 的 GitHub 辅助方案

## 需求复述

目标是设计一个工具，把 AquaCloud 中转站的 LLM 接入 Claude Code 使用，并且能通过该工具灵活更换模型。

已知文档：

- AquaCloud 文档：https://docs.aquacloud.io/
- OpenAI-compatible base URL：https://apibeta.aquacloud.io/v1
- Anthropic base URL：文档首页也标注为 https://apibeta.aquacloud.io/v1

## 关键判断

Claude Code 主要通过 Anthropic Messages API 与模型通信。官方文档说明，`ANTHROPIC_BASE_URL` 只改变请求发往哪里，不决定最终使用哪个模型；模型仍需通过 `/model` 或模型环境变量选择。因此 AquaCloud 如果完整兼容 Anthropic 协议，理论上可以直接接入；如果只稳定支持 OpenAI-compatible 协议，则需要一个本地网关把 Claude Code 的 Anthropic 请求转换成 OpenAI Chat/Responses 请求。

## 推荐路线

### 路线 A：先尝试直连 AquaCloud Anthropic endpoint

适合：AquaCloud 的 Anthropic-compatible endpoint 对 Claude Code 足够兼容。

PowerShell 示例：

```powershell
$env:ANTHROPIC_BASE_URL="https://apibeta.aquacloud.io/v1"
$env:ANTHROPIC_AUTH_TOKEN="你的_AquaCloud_API_Key"
$env:ANTHROPIC_MODEL="模型集市里的_platform_model_id"
claude
```

也可尝试：

```powershell
$env:ANTHROPIC_API_KEY="你的_AquaCloud_API_Key"
```

如果 Claude Code 报认证头、`/v1/messages`、`/v1/messages/count_tokens`、tool use 或 streaming 相关错误，就转路线 B。

### 路线 B：用 claude-code-router 做主工具

推荐度最高。它已经覆盖你的两个核心点：

- 把 Claude Code 请求路由到不同模型/提供商。
- 支持 Claude Code 内 `/model` 动态切换，也支持 `ccr model` 命令管理模型。

AquaCloud 作为 OpenAI-compatible provider 的配置草稿：

```json
{
  "APIKEY": "local-router-secret",
  "LOG": true,
  "API_TIMEOUT_MS": 600000,
  "Providers": [
    {
      "name": "aquacloud",
      "api_base_url": "https://apibeta.aquacloud.io/v1/chat/completions",
      "api_key": "$AQUACLOUD_API_KEY",
      "models": [
        "替换为_AquaCloud_platform_model_id_1",
        "替换为_AquaCloud_platform_model_id_2"
      ],
      "transformer": {
        "use": ["openrouter"]
      }
    }
  ],
  "Router": {
    "default": "aquacloud,替换为_AquaCloud_platform_model_id_1",
    "think": "aquacloud,替换为_AquaCloud_platform_model_id_2",
    "longContext": "aquacloud,替换为_AquaCloud_platform_model_id_2",
    "longContextThreshold": 60000
  }
}
```

如果 AquaCloud 的 OpenAI 协议与 OpenRouter 不完全一致，后续可以写一个 `aquacloud` transformer，专门处理请求头、模型名、reasoning 字段、tool calls、stream chunk 格式等差异。

### 路线 C：用 claude-code-proxy 做最小桥接

适合：你只想要一个很薄的 Anthropic-to-OpenAI 代理，模型切换可以先通过 `.env` 或启动脚本完成。

环境变量草稿：

```env
OPENAI_API_KEY=你的_AquaCloud_API_Key
OPENAI_BASE_URL=https://apibeta.aquacloud.io/v1
BIG_MODEL=替换为_AquaCloud_强模型
MIDDLE_MODEL=替换为_AquaCloud_日常模型
SMALL_MODEL=替换为_AquaCloud_轻量模型
HOST=127.0.0.1
PORT=8082
```

Claude Code 启动：

```powershell
$env:ANTHROPIC_BASE_URL="http://localhost:8082"
$env:ANTHROPIC_API_KEY="any-value"
claude
```

## GitHub 候选项目

| 项目 | 适合程度 | 用法定位 | 调研时状态 |
| --- | --- | --- | --- |
| https://github.com/musistudio/claude-code-router | 最高 | 主方案：路由、模型切换、provider/transformer 扩展 | TypeScript，约 35.3k stars，2026-06-25 仍活跃 |
| https://github.com/fuergaosi233/claude-code-proxy | 高 | 轻量协议桥：Claude Code -> OpenAI-compatible API | Python，约 2.7k stars，支持 `/v1/messages`、tool use、streaming |
| https://github.com/1rgs/claude-code-proxy | 中高 | LiteLLM 底座，支持 OpenAI/Gemini/Anthropic 后端 | Python，约 3.6k stars，Docker 运行方便 |
| https://github.com/lich0821/ccNexus | 中高 | 多端点轮换、故障转移、格式转换、统计面板 | Go，约 966 stars，偏网关/管理后台 |
| https://github.com/vibheksoni/UniClaudeProxy | 中 | 可参考 hot-reload、fallback、多 provider 转换设计 | Python，体量小 |

## 建议实现顺序

1. 拿 AquaCloud API Key 和 2-3 个 platform model id，先用 curl 验证 `/v1/messages` 和 `/v1/chat/completions` 哪个更稳定。
2. 如果 Anthropic endpoint 能跑通 Claude Code，先做一个很薄的 PowerShell/Node CLI：保存 key、列模型、切模型、启动 Claude Code。
3. 如果 Anthropic endpoint 跑不通，优先基于 `claude-code-router` 做 AquaCloud provider preset。
4. 若 `openrouter` transformer 不适配 AquaCloud，再补一个 `aquacloud` transformer。
5. 最后加一个本地 UI 或 TUI：配置 API Key、查看模型、设置 default/think/longContext、重启 router。

## 风险点

- Claude Code 的 tool use、streaming、thinking、token counting 都可能依赖 Anthropic 协议细节；只兼容普通聊天不等于能稳定跑 Claude Code。
- 第三方中转站会看到代码上下文、提示词和输出；处理私有仓库时要确认数据政策。
- 模型名不能凭感觉写，需要使用 AquaCloud 模型集市或管理员给出的 platform model id。
- 如果自行暴露本地 gateway，必须绑定 `127.0.0.1` 或加鉴权，避免代理被局域网滥用。

## 下一步可执行原型

最小原型可以做成一个 Node CLI：

- `aqua-cc init`：写入 API Key 和 base URL。
- `aqua-cc models`：请求 AquaCloud `/v1/models`，列出模型。
- `aqua-cc use <model>`：更新当前默认模型。
- `aqua-cc run`：设置 Claude Code 所需环境变量并启动 `claude`。
- `aqua-cc router-config`：生成 `claude-code-router` 配置。

这条路线投入小，失败时也能把产物转成 `claude-code-router` preset。

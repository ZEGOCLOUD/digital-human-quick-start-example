# 数字人交互聊天业务后台

本示例演示数字人交互聊天的业务后台，用于创建数字人任务、通过 WebSocket 驱动数字人、生成 RTC Token。

## 一、安装配置与启动

### 1. 环境要求
- Node.js 18+

### 2. 配置环境变量

```bash
cp .env.example .env
```

编辑 `.env` 文件，填入 ZEGO 控制台获取的配置：

| 变量 | 说明 |
|------|------|
| `APP_ID` | ZEGO 应用 ID。从 ZEGO [控制台](https://console.zego.im/) 获取。 |
| `SERVER_SECRET` | 服务端密钥（32位，用于生成 Token，服务端 API 签名验证）。从 ZEGO [控制台](https://console.zego.im/) 获取。 |
| `TOKEN_EXPIRE_SECONDS` | ZEGO 客户端 SDK 用的 Token 有效期（秒，默认 3600） |
| `DIGITAL_HUMAN_ID` | 数字人 ID。调用数字人服务端 `GetDigitalHumanList` 接口获取。 |

### 3. 准备音频文件（可选）

将 PCM 音频文件命名为 `sample.pcm` 并放置在 `audio/` 目录下。

格式要求:
- 采样率: 16000 Hz
- 位深度: 16 bit
- 声道: 单声道

如不提供，将使用静音数据作为占位符。

### 4. 安装依赖并启动

```bash
npm install
npm run dev
```

服务将在 `http://localhost:3000` 启动。

---

## 二、源码结构

```
server/
├── index.js                   # 服务入口（HTTP 路由）
├── lib/                       # 核心逻辑
│   ├── digitalHuman.js        # ZEGO 数字人 API 封装
│   ├── token.js               # Token04 算法实现。用于生成 ZEGO 客户端 SDK 用的 Token
│   └── websocket.js           # WebSocket 驱动数字人
├── audio/                     # 音频文件
│   └── sample.pcm             # 模拟音频文件
└── package.json
```

---

## 三、API 接口说明

### POST /api/digital-human/create-task

创建数字人视频流任务。

**请求参数**:
```json
{
  "roomId": "string",
  "streamId": "string"
}
```

**参数说明**：
| 参数 | 说明 |
|------|------|
| `roomId` | RTC 房间 ID。数字人将加入此房间推流，**每个用户应使用不同的 roomId**，避免多个用户进入同一房间 |
| `streamId` | 数字人推流的流 ID。服务端会使用此 streamId 创建数字人推流任务 |

**注意**：`digitalHumanId` 本示例由服务端环境变量配置，客户端无需传递。

**响应示例**:
```json
{
  "success": true,
  "taskId": "string"
}
```

### POST /api/digital-human/talk-to-ai

模拟 AI 交互，通过 WebSocket 驱动数字人播报。

**请求参数**:
```json
{
  "taskId": "string"
}
```

**响应示例**:
```json
{
  "success": true,
  "message": "AI interaction completed"
}
```

**注释说明**：实际业务中应采集麦克风音频 → ASR 语音识别 → LLM 生成回复 → TTS 语音合成 → WebSocket 驱动数字人。本示例简化为读取预置 PCM 文件。

### POST /api/digital-human/stop-task

停止数字人视频流任务。

**请求参数**:
```json
{
  "taskId": "string"
}
```

**响应示例**:
```json
{
  "success": true,
  "message": "Digital human task stopped"
}
```

### GET /api/token

生成 ZEGO RTC Token。

**请求参数**: `userId` (查询参数)

**响应示例**:
```json
{
  "success": true,
  "token": "string"
}
```

---


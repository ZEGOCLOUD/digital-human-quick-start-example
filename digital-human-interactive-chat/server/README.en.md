[中文](README.md) | [English](README.en.md)

# Digital Human Interactive Chat - Business Backend

This example demonstrates the business backend for digital human interactive chat, used for creating digital human tasks, driving digital humans via WebSocket, and generating RTC Tokens.

## 1. Installation, Configuration, and Startup

### 1. Environment Requirements
- Node.js 18+

### 2. Configure Environment Variables

```bash
cp .env.example .env
```

Edit the `.env` file and fill in the configuration obtained from the ZEGO console:

| Variable | Description |
|------|------|
| `APP_ID` | ZEGO App ID. Obtained from ZEGO [Console](https://console.zego.im/). |
| `SERVER_SECRET` | Server secret key (32 characters, used for Token generation and server API signature verification). Obtained from ZEGO [Console](https://console.zego.im/). |
| `TOKEN_EXPIRE_SECONDS` | Token validity period for ZEGO client SDK (seconds, default 3600) |
| `DIGITAL_HUMAN_ID` | Digital Human ID. Obtained by calling the digital human server `GetDigitalHumanList` API. |

### 3. Prepare Audio Files (Optional)

Name the PCM audio file as `sample.pcm` and place it in the `audio/` directory.

Format requirements:
- Sample rate: 16000 Hz
- Bit depth: 16 bit
- Channels: Mono

If not provided, silent data will be used as a placeholder.

### 4. Install Dependencies and Start

```bash
npm install
npm run dev
```

The service will start at `http://localhost:3000`.

---

## 2. Source Code Structure

```
server/
├── index.js                   # Service entry (HTTP routing)
├── lib/                       # Core logic
│   ├── digitalHuman.js        # ZEGO Digital Human API wrapper
│   ├── token.js               # Token04 algorithm implementation. Used for generating ZEGO client SDK Tokens
│   └── websocket.js           # WebSocket-driven digital human
├── audio/                     # Audio files
│   └── sample.pcm             # Simulated audio file
└── package.json
```

---

## 3. API Reference

### POST /api/digital-human/create-task

Create a digital human video stream task.

**Request Parameters**:
```json
{
  "roomId": "string",
  "streamId": "string"
}
```

**Parameter Description**:
| Parameter | Description |
|------|------|
| `roomId` | RTC room ID. The digital human will join this room to push streams. **Each user should use a different roomId** to avoid multiple users entering the same room |
| `streamId` | Stream ID for digital human streaming. The server will use this streamId to create a digital human streaming task |

**Note**: `digitalHumanId` is configured by server environment variables in this example, no need for client to pass.

**Response Example**:
```json
{
  "success": true,
  "taskId": "string"
}
```

### POST /api/digital-human/talk-to-ai

Simulate AI interaction, drive digital human broadcasting via WebSocket.

**Request Parameters**:
```json
{
  "taskId": "string"
}
```

**Response Example**:
```json
{
  "success": true,
  "message": "AI interaction completed"
}
```

**Note**: In production, you should capture microphone audio → ASR speech recognition → LLM generates response → TTS speech synthesis → WebSocket drives digital human. This example simplifies by reading a preset PCM file.

### POST /api/digital-human/stop-task

Stop the digital human video stream task.

**Request Parameters**:
```json
{
  "taskId": "string"
}
```

**Response Example**:
```json
{
  "success": true,
  "message": "Digital human task stopped"
}
```

### GET /api/token

Generate ZEGO RTC Token.

**Request Parameters**: `userId` (query parameter)

**Response Example**:
```json
{
  "success": true,
  "token": "string"
}
```

---

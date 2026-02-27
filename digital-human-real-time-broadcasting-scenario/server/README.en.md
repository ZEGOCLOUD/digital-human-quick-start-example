[中文](README.md) | [English](README.en.md)

# Digital Human Broadcasting System - Orchestration End

This example demonstrates the orchestration end of the digital human broadcasting system, used for configuring broadcast content and starting broadcast tasks.

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

### 3. Install Dependencies and Start

```bash
npm install
npm run dev
```

Visit `http://localhost:3000` to open the configuration page.

---

## 2. Source Code Structure

```
server/
├── app/
│   ├── api/                    # API routes
│   │   ├── broadcast/          # Broadcast task management
│   │   ├── token/              # Token generation
│   │   ├── digital-humans/     # Digital human list
│   │   └── timbres/            # Timbre list
│   ├── page.jsx                # Orchestration panel (Web UI)
├── lib/                        # Core logic
│   ├── digitalHuman.js         # ZEGO Digital Human API wrapper
│   ├── token.js                # Token04 algorithm implementation. Used for generating ZEGO client SDK Tokens
│   └── broadcast.js            # Broadcast task management logic. Implement according to business requirements.
├── instrumentation.js          # Server startup hook. Used for cleaning up legacy digital human tasks.
└── package.json
```

---

## 3. API Reference

The business backend provides two types of interfaces, called by the orchestration end and playback end respectively:

### 1. Orchestration End Interfaces

The orchestration end (orchestration panel) calls the following interfaces to configure and manage broadcast tasks:

| Endpoint | Method | Request Parameters | Description |
|------|------|---------|------|
| `/api/digital-humans` | GET | - | Get digital human list |
| `/api/broadcast` | POST | `digitalHumanId`, `timbreId`, `roomId`, `streamId`, `textPool` | Start broadcast task |
| `/api/broadcast?index=N` | DELETE | `index` (query parameter) | Stop specified broadcast task |
| `/api/timbres` | GET | `digitalHumanId` (optional) | Get timbre list |

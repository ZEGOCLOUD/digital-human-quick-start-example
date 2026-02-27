[中文](README.md) | [English](README.en.md)

# Digital Human Interactive Chat - Web React Client

This example demonstrates the Web React client engaging in real-time interactive conversations with digital humans.

## 1. Installation, Configuration, and Running

### 1. Environment Requirements
- Node.js 18+
- Modern browsers (Chrome, Safari, Edge, etc.)

### 2. Configuration

Edit the `.env` file:

| Variable | Description |
|------|------|
| `VITE_APP_ID` | ZEGO App ID. Obtained from ZEGO [Console](https://console.zego.im/). |
| `VITE_API_BASE_URL` | Business backend address |

```bash
VITE_APP_ID=1234567890
VITE_API_BASE_URL=http://localhost:3000
```

### 3. Install Dependencies and Run

```bash
npm install
npm run dev
```

Visit `http://localhost:5173`.

---

## 2. Source Code Structure

```
web-react/
├── src/
│   ├── App.jsx                  # Main component, contains complete interaction flow
│   ├── main.jsx                 # Entry file
│   └── assets/                  # Static resources
├── .env                         # Environment variable configuration
├── package.json
└── vite.config.js
```

---

## 3. Core Flow

```
Create Task → Get Token → Login Room → Pull Stream & Play → Simulate Speech → End Call
```

| Step | Description |
|------|------|
| Create Task | Call `POST /api/digital-human/create-task` to get taskId |
| Get Token | Call `GET /api/token?userId=xxx` to get RTC login Token |
| Login Room | Use Express SDK to login to RTC room |
| Pull Stream & Play | Pull digital human audio/video stream and render to page |
| Simulate Speech | Call `POST /api/digital-human/talk-to-ai`, business backend drives digital human via WebSocket |
| End Call | Stop streaming, exit room, call `POST /api/digital-human/stop-task` |

---

## 4. Dependency Description

| Dependency | Description |
|------|------|
| `zego-express-engine-webrtc` | ZEGO Express Web SDK |
| `react` / `react-dom` | React framework |
| `vite` | Build tool |

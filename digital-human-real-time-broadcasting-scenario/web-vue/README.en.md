[中文](README.md) | [English](README.en.md)

# Digital Human Broadcasting System - Web Playback End (Vue)

This example demonstrates the Web end as a playback end, pulling and playing digital human audio/video streams.

## 1. Installation, Configuration, and Running

### 1. Environment Requirements
- Node.js 18+
- Modern browsers (Chrome, Safari, Edge, etc.)

### 2. Configuration

Edit the `.env` file:

| Variable | Description |
|------|------|
| `VITE_APP_ID` | ZEGO App ID |
| `VITE_API_BASE_URL` | Business backend address |

```bash
VITE_APP_ID=1234567890
VITE_API_BASE_URL=http://localhost:3001
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
web-vue/
├── src/
│   ├── App.vue                  # Main component, contains complete playback flow
│   ├── main.js                  # Entry file
│   └── assets/                  # Static resources
├── .env                         # Environment variable configuration
├── package.json
└── vite.config.js
```

---

## 3. Core Flow

```
Get Broadcast List → Get Token → Login Room → Pull Stream & Play
```

| Step | Description |
|------|------|
| Get Broadcast List | Call `GET /api/broadcast` to get roomId and streamId |
| Get Token | Call `GET /api/token?userId=xxx` to get RTC login Token |
| Login Room | Use Express SDK to login to RTC room |
| Pull Stream & Play | Pull digital human audio/video stream and render to page |

---

## 4. Dependency Description

| Dependency | Description |
|------|------|
| `zego-express-engine-webrtc` | ZEGO Express Web SDK |
| `vue` | Vue 3 framework |
| `vite` | Build tool |

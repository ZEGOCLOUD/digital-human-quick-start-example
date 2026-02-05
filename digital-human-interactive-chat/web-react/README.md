# 数字人交互聊天 - Web React 客户端

本示例演示 Web React 端作为客户端，与数字人进行实时交互对话。

## 一、安装配置与运行

### 1. 环境要求
- Node.js 18+
- 现代浏览器（Chrome、Safari、Edge 等）

### 2. 配置

编辑 `.env` 文件：

| 变量 | 说明 |
|------|------|
| `VITE_APP_ID` | ZEGO 应用 ID |
| `VITE_API_BASE_URL` | 业务后台地址 |
| `VITE_DIGITAL_HUMAN_ID` | 数字人 ID |

```bash
VITE_APP_ID=1234567890
VITE_API_BASE_URL=http://localhost:3000
VITE_DIGITAL_HUMAN_ID=your_digital_human_id
```

### 3. 安装依赖并运行

```bash
npm install
npm run dev
```

访问 `http://localhost:5173`。

---

## 二、源码结构

```
web-react/
├── src/
│   ├── App.jsx                  # 主组件，包含完整的交互流程
│   ├── main.jsx                 # 入口文件
│   └── assets/                  # 静态资源
├── .env                         # 环境变量配置
├── package.json
└── vite.config.js
```

---

## 三、核心流程

```
创建任务 → 获取 Token → 登录房间 → 拉流播放 → 模拟说话 → 结束通话
```

| 步骤 | 说明 |
|------|------|
| 创建任务 | 调用 `POST /api/digital-human/create-task`，获取 taskId、roomId、streamId |
| 获取 Token | 调用 `GET /api/token?userId=xxx`，获取 RTC 登录 Token |
| 登录房间 | 使用 Express SDK 登录 RTC 房间 |
| 拉流播放 | 拉取数字人音视频流并渲染到页面 |
| 模拟说话 | 调用 `POST /api/digital-human/talk-to-ai`，业务后台通过 WebSocket 驱动数字人 |
| 结束通话 | 停止拉流、退出房间、调用 `POST /api/digital-human/stop-task` |

---

## 四、依赖说明

| 依赖 | 说明 |
|------|------|
| `zego-express-engine-webrtc` | ZEGO Express Web SDK |
| `react` / `react-dom` | React 框架 |
| `vite` | 构建工具 |

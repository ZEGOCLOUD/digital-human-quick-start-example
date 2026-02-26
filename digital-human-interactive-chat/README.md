# 数字人交互聊天示例

本示例演示客户端与数字人实时交互对话的完整流程。客户端模拟音频采集，业务后台将采集的音频经过 ASR -> LLM -> TTS 处理后，通过 WebSocket 驱动数字人，客户端拉流播放。

## 一、核心架构

数字人交互聊天系统由两个核心角色组成：

### 1. 客户端
- **功能**：模拟音频采集，调用业务后台 AI 交互接口，拉流播放数字人音视频
- **平台**：Web / Android / iOS，均使用 ZEGO Express SDK 拉流播放
- **调用接口**：
  - `POST /api/digital-human/create-task` - 创建数字人任务
  - `GET /api/token` - 获取 RTC Token
  - `POST /api/digital-human/talk-to-ai` - 模拟用户说话与 AI 交互
  - `POST /api/digital-human/stop-task` - 停止数字人任务

### 2. 业务后台
- **功能**：创建数字人任务，通过 WebSocket 驱动数字人，生成 RTC Token
- **调用接口**：
  - ZEGO 数字人 API：创建任务、获取 WebSocket 驱动信息、停止任务

### 3. ZEGO 服务端
- **数字人 API**：创建数字人视频流任务、WebSocket 驱动数字人、停止任务
- **实时音视频云**：数字人音视频流通过 ZEGO 实时音视频云推送，客户端通过 Express SDK 拉取

### 架构图

![数字人交互聊天架构图](./architecture-diagram.drawio.png)

---

## 二、业务流程时序图

```mermaid
sequenceDiagram
    participant 客户端 as 客户端<br/>(Web/Android/iOS)
    participant 业务后台 as 业务后台
    participant 数字人API as ZEGO<br/>数字人 API
    participant RTC云 as ZEGO<br/>实时音视频云

    Note over 客户端,业务后台: 阶段1: 客户端开始通话
    客户端->>业务后台: 1. POST /api/digital-human/create-task<br/>(roomId, streamId)
    业务后台->>数字人API: 2. 创建数字人视频流任务
    数字人API-->>业务后台: TaskId
    业务后台-->>客户端: TaskId
    客户端->>业务后台: 3. GET /api/token?userId=xxx
    业务后台-->>客户端: Token
    客户端->>RTC云: 4. loginRoom(roomId, token)
    客户端->>RTC云: 5. startPlayingStream(streamId)

    Note over 客户端,业务后台: 阶段2: 客户端模拟说话
    客户端->>业务后台: 6. POST /api/digital-human/talk-to-ai<br/>(注释: 实际应采集麦克风音频)
    业务后台->>数字人API: 7. 获取 WebSocket 驱动信息
    数字人API-->>业务后台: DriveId + WssAddress
    业务后台->>业务后台: 8. 读取 PCM 音频<br/>(注释: 实际应 ASR→LLM→TTS)
    业务后台->>数字人API: 9. WebSocket 驱动数字人<br/>(流式发送 PCM 音频)
    数字人API->>RTC云: 10. 渲染数字人并推送音视频流
    RTC云-->>客户端: 11. 播放数字人说话画面

    Note over 客户端,业务后台: 阶段3: 客户端结束通话
    客户端->>RTC云: 12. stopPlayingStream + logoutRoom
    客户端->>业务后台: 13. POST /api/digital-human/stop-task
    业务后台->>数字人API: 14. 停止流任务
    业务后台-->>客户端: 停止成功
```

---

## 三、业务后台 API 接口说明

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
| `roomId` | RTC 房间 ID。**每个用户应使用不同的 roomId**，避免多个用户进入同一房间 |
| `streamId` | 数字人推流的流 ID。服务端会使用此 streamId 创建数字人推流任务 |

**注意**：`digitalHumanId` 由服务端环境变量配置，客户端无需传递。

**响应示例**:
```json
{
  "success": true,
  "taskId": "string"
}
```

**响应字段说明**：
| 字段 | 说明 |
|------|------|
| `taskId` | 数字人任务 ID，用于后续的 AI 交互和停止任务 |

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

生成 ZEGO SDK Token。

**请求参数**: `userId` (查询参数)

**响应示例**:
```json
{
  "success": true,
  "token": "string"
}
```

---

## 四、客户端接入示例

### 1. Web 客户端接入示例

Web 客户端使用 ZEGO Express SDK 拉流播放：

```javascript
// 步骤1: 创建数字人任务
// 注意：roomId 应为每个用户生成唯一的值，streamId 为数字人推流的流ID
const roomId = 'room_' + Date.now();  // 每个用户使用不同的 roomId
const streamId = 'stream_' + Date.now();  // 数字人推流的流 ID

const createRes = await fetch('/api/digital-human/create-task', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    roomId: roomId,
    streamId: streamId
  })
});
const { taskId } = await createRes.json();
// 服务端只返回 taskId。roomId 和 streamId 使用客户端生成的值

// 步骤2: 获取 Token
const userId = 'user_001';
const tokenRes = await fetch(`/api/token?userId=${userId}`);
const { token } = await tokenRes.json();

// 步骤3: 初始化 Express SDK
const { ZegoExpressEngine } = await import('zego-express-engine-webrtc');
const engine = new ZegoExpressEngine(appId, "");

// 步骤4: 登录 RTC 房间
await engine.loginRoom(roomId, token, {
  userID: userId,
  userName: userId
});

// 步骤5: 拉取数字人音视频流
const remoteStream = await engine.startPlayingStream(streamId);
const remoteView = engine.createRemoteStreamView(remoteStream);
remoteView.play('remote-video'); // 渲染到 DOM 元素

// 步骤6: 模拟说话
await fetch('/api/digital-human/talk-to-ai', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ taskId })
});

// 步骤7: 结束通话
await engine.stopPlayingStream(streamId);
await engine.logoutRoom();
await fetch('/api/digital-human/stop-task', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ taskId })
});
```

### 2. Android 客户端接入示例

Android 客户端使用 ZEGO Express SDK 拉流播放：

```java
// 步骤1: 创建数字人任务
// POST /api/digital-human/create-task
// 请求 body: { "roomId": "room_xxx", "streamId": "stream_xxx" }
// 注意：roomId 应为每个用户生成唯一的值，streamId 为数字人推流的流ID
// 服务端返回：{ "taskId": "task_001" }

// 步骤2: 初始化 Express SDK
ZegoEngineProfile profile = new ZegoEngineProfile();
profile.appID = appId;
profile.scenario = ZegoScenario.HIGH_QUALITY_CHATROOM;
ZegoExpressEngine.createEngine(profile, null);

// 步骤3: 登录房间并拉流（使用客户端定义的 roomId 和 streamId）
ZegoUser user = new ZegoUser(userId, userId);
ZegoRoomConfig config = new ZegoRoomConfig();
config.token = token;
ZegoExpressEngine.getEngine().loginRoom(roomId, user, config, (errorCode, extendedData) -> {
    if (errorCode == 0) {
        // 使用 ZegoCanvas 包装 TextureView 进行渲染
        ZegoCanvas canvas = new ZegoCanvas(findViewById(R.id.remote_video_view));
        ZegoExpressEngine.getEngine().startPlayingStream(streamId, canvas);
    }
});

// 步骤4: 模拟说话（调用业务后台接口）
// POST /api/digital-human/talk-to-ai
// 请求 body: { "taskId": "xxx" }

// 步骤5: 结束通话
ZegoExpressEngine.getEngine().stopPlayingStream(streamId);
ZegoExpressEngine.getEngine().logoutRoom();
// POST /api/digital-human/stop-task
// 请求 body: { "taskId": "xxx" }
```

### 3. iOS 客户端接入示例

iOS 客户端使用 ZEGO Express SDK 拉流播放：

```objc
// 步骤1: 创建数字人任务
// POST /api/digital-human/create-task
// 请求 body: { "roomId": "room_xxx", "streamId": "stream_xxx" }
// 注意：roomId 应为每个用户生成唯一的值，streamId 为数字人推流的流ID
// 服务端返回：{ "taskId": "task_001" }

// 步骤2: 初始化 Express SDK
ZegoEngineProfile *profile = [[ZegoEngineProfile alloc] init];
profile.appID = (unsigned int)appId;
profile.scenario = ZegoScenarioHighQualityChatroom;
self.expressEngine = [ZegoExpressEngine createEngineWithProfile:profile eventHandler:self];

// 步骤3: 登录房间并拉流（使用客户端生成的 roomId 和 streamId）
ZegoUser *user = [[ZegoUser alloc] init];
user.userID = userId;
user.userName = userId;
ZegoRoomConfig *roomConfig = [[ZegoRoomConfig alloc] init];
roomConfig.token = token;
[self.expressEngine loginRoom:roomId user:user config:roomConfig callback:^(int errorCode, NSDictionary *extendedData) {
    if (errorCode == 0) {
        // 使用 ZegoCanvas 包装 UIView 进行渲染
        ZegoCanvas *canvas = [ZegoCanvas canvasWithView:self.remoteVideoView];
        [self.expressEngine startPlayingStream:streamId canvas:canvas];
    }
}];

// 步骤4: 模拟说话（调用业务后台接口）
// POST /api/digital-human/talk-to-ai
// 请求 body: { "taskId": "xxx" }

// 步骤5: 结束通话
[self.expressEngine stopPlayingStream:streamId];
[self.expressEngine logoutRoom];
// POST /api/digital-human/stop-task
// 请求 body: { "taskId": "xxx" }
```

---

## 五、各端示例代码详细说明

- [业务后台示例代码详细说明](./server/README.md)
- [Web(React) 端示例代码详细说明](./web-react/README.md)
- [Web(Vue) 端示例代码详细说明](./web-vue/README.md)
- [Android 端示例代码详细说明](./android/README.md)
- [iOS(Objective-C) 端示例代码详细说明](./ios-oc/README.md)

---

## 六、注意事项

- 业务后台使用预置 PCM 文件模拟 AI 交互，实际业务应接入 ASR、LLM、TTS 服务
- Token 生成需要使用 Token04 算法，确保 `SERVER_SECRET` 安全
- 客户端销毁时需停止拉流、退出房间、停止数字人任务
- **每个用户应使用不同的 roomId**，避免多个用户进入同一房间互相干扰
- 客户端定义的 streamId 是数字人推流的流 ID，客户端使用此 streamId 拉流播放

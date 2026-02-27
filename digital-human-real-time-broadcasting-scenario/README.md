[中文](README.md) | [English](README.en.md)

# 数字人播报系统示例

本示例演示数字人播报的**三方架构**：编排端配置播报内容 → 业务后台驱动数字人 → 播放端拉流播放。

## 一、核心架构

数字人播报系统由三个核心角色组成：

### 1. 播放端（终端机）
- **功能**：使用 ZEGO Express SDK 拉取并播放数字人音视频流
- **平台**：Web / Android / iOS，均使用 Express SDK 拉流播放
- **调用接口**：
  - `GET /api/broadcast` - 获取播报信息（roomId/streamId）
  - `GET /api/token` - 获取 RTC Token

### 2. 编排端（编排面板 + 业务服务）
- **编排面板**：Web UI，用于配置数字人播报内容
  - 选择数字人形象和音色
  - 配置播报文本内容
  - 启动/停止播报任务
- **业务服务**（本服务）：接收编排指令，调用 ZEGO 数字人 API 驱动数字人
- **调用接口**：
  - `GET /api/digital-humans` - 获取数字人列表
  - `GET /api/timbres` - 获取音色列表
  - `POST /api/broadcast` - 启动播报任务
  - `DELETE /api/broadcast` - 停止播报任务

### 3. ZEGO 服务端
- **数字人 API**：创建数字人视频流任务、文本驱动数字人、音频驱动数字人、停止数字人视频流任务
- **实时音视频云**：数字人音视频流通过 ZEGO 实时音视频云推送，播放端通过 ZEGO Express SDK 拉取

### 架构图

![数字人业务服务端架构图](./architecture-diagram.drawio.png)

---

## 二、业务流程时序图

```mermaid
sequenceDiagram
    participant 编排端 as 编排面板<br/>(编排端)
    participant 业务后台 as 业务后台<br/>(编排端)
    participant 数字人API as ZEGO<br/>数字人 API
    participant RTC云 as ZEGO<br/>实时音视频云
    participant 播放端 as 播放端<br/>(终端机)

    Note over 编排端,业务后台: 阶段1: 编排端配置并启动播报
    编排端->>业务后台: 1. GET /api/digital-humans
    业务后台-->>编排端: 数字人列表
    编排端->>业务后台: 2. GET /api/timbres
    业务后台-->>编排端: 音色列表
    编排端->>业务后台: 3. POST /api/broadcast<br/>(数字人ID/音色ID/播报文本)
    业务后台->>数字人API: 4. 创建数字人流任务
    数字人API-->>业务后台: TaskId
    业务后台->>业务后台: 5. 启动定时器
    业务后台-->>编排端: 启动成功

    Note over 业务后台,RTC云: 阶段2: 业务后台定时驱动数字人
    loop 仅示例，定时驱动
        业务后台->>数字人API: 文本驱动(随机文本)
        数字人API->>RTC云: 渲染数字人并推送音视频流
    end

    Note over 播放端,RTC云: 阶段3: 播放端拉流播放
    播放端->>业务后台: 6. GET /api/broadcast
    业务后台-->>播放端: roomId/streamId
    播放端->>业务后台: 7. GET /api/token?userId=xxx
    业务后台-->>播放端: token
    播放端->>RTC云: 8. loginRoom(roomId, token)
    播放端->>RTC云: 9. startPlayingStream(streamId)
    RTC云-->>播放端: 10. 播放数字人音视频

    Note over 编排端,业务后台: 阶段4: 编排端停止播报
    编排端->>业务后台: 11. DELETE /api/broadcast?index=N
    业务后台->>数字人API: 12. 停止流任务
    业务后台->>业务后台: 13. 清除定时器
    业务后台-->>编排端: 停止成功
```

---

## 三、业务后台 API 接口说明

业务后台提供两类接口，分别供编排端和播放端调用：

### 1. 编排端调用接口

编排端（编排面板）调用以下接口配置和管理播报任务：

| 端点 | 方法 | 请求参数 | 说明 |
|------|------|---------|------|
| `/api/digital-humans` | GET | - | 获取数字人列表 |
| `/api/timbres` | GET | `digitalHumanId`（可选） | 获取音色列表 |
| `/api/broadcast` | POST | `digitalHumanId`, `timbreId`, `roomId`, `streamId`, `textPool` | 启动播报任务 |
| `/api/broadcast?index=N` | DELETE | `index`（查询参数） | 停止指定播报任务 |

**POST /api/broadcast 请求示例：**

其中：
- digitalHumanId, timbreId, roomId, streamId 是 ZEGO 数字人 API 需要的参数
- broadcastIndex 和 textPool 是本业务服务演示用的参数。实际业务应根据需求自行实现。
```json
{
  "broadcastIndex": 0,
  "textPool": ["欢迎光临", "请稍等"],
  "digitalHumanId": "dh_001",
  "timbreId": "timbre_001",
  "roomId": "room_001",
  "streamId": "stream_001"
}
```


### 2. 播放端调用接口

播放端（终端机）调用以下接口获取播放信息：

| 端点 | 方法 | 请求参数 | 说明 |
|------|------|---------|------|
| `/api/broadcast` | GET | - | 获取播报列表信息（包含 roomId/streamId） |
| `/api/token` | GET | `userId`（查询参数） | 获取 ZEGO 客户端 SDK 用的 Token |

**GET /api/broadcast 响应示例：**

```json
{
  "broadcastList": {
    "0": {
      "taskId": "task_001",
      "roomId": "room_001",
      "streamId": "stream_001"
    }
  }
}
```

### 3. 播放端接入示例（Web）

Web 客户端使用 ZEGO Express SDK 拉流播放：

```javascript
// 步骤1: 获取播报信息
const broadcastRes = await fetch('/api/broadcast');
const { broadcastList } = await broadcastRes.json();
const { roomId, streamId } = Object.values(broadcastList)[0];

// 步骤2: 获取 Token
const userId = 'terminal_001';
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
```

### 4. 播放端接入示例（Android）

Android 客户端使用 ZEGO Express SDK 拉流播放：

```java
// 步骤1: 获取播报信息
// GET /api/broadcast 返回，取第一个播报任务做示例：
// { "roomId": "room_001", "streamId": "stream_001" }

// 步骤2: 初始化 Express SDK
ZegoEngineProfile profile = new ZegoEngineProfile();
profile.appID = appId;
profile.scenario = ZegoScenario.HIGH_QUALITY_CHATROOM;
ZegoExpressEngine.createEngine(profile, null);

// 步骤3: 登录房间并拉流
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
```

### 5. 播放端接入示例（iOS）

iOS 客户端使用 ZEGO Express SDK 拉流播放：

```objc
// 步骤1: 获取播报信息
// GET /api/broadcast 返回，取第一个播报任务做示例：
// { "roomId": "room_001", "streamId": "stream_001" }

// 步骤2: 初始化 Express SDK
ZegoEngineProfile *profile = [[ZegoEngineProfile alloc] init];
profile.appID = (unsigned int)appId;
profile.scenario = ZegoScenarioHighQualityChatroom;
self.expressEngine = [ZegoExpressEngine createEngineWithProfile:profile eventHandler:self];

// 步骤3: 登录房间并拉流
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
```

---

## 四、各端示例代码详细说明

- [业务后台示例代码详细说明](./server/README.md)
- [Web(React) 端示例代码详细说明](./web-react/README.md)
- [Web(Vue) 端示例代码详细说明](./web-vue/README.md)
- [Android 端示例代码详细说明](./android/README.md)
- [iOS(Objective-C) 端示例代码详细说明](./ios-oc/README.md)


## 五、注意事项

- 业务后台需要妥善管理播报任务状态（示例使用全局变量，生产环境建议使用数据库）
- Token 生成需要使用 Token04 算法，确保 `SERVER_SECRET` 安全
- 定时驱动仅为演示，实际业务应根据需求自行实现驱动逻辑

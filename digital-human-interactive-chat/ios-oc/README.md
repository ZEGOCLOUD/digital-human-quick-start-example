# 数字人交互聊天 - iOS 客户端

本示例演示 iOS 端作为客户端，与数字人进行实时交互对话。

## 一、安装配置与运行

### 1. 环境要求
- Xcode 15.0 或更高版本
- iOS 12.0+
- CocoaPods

### 2. 安装依赖

```bash
cd ZegoDigitalHumanQuickStart
pod install
```

打开 `ZegoDigitalHumanQuickStart.xcworkspace`（注意是 xcworkspace）。

### 3. 配置

编辑 `ZegoDigitalHumanQuickStart/Config.m`：

| 变量 | 说明 |
|------|------|
| `APP_ID` | ZEGO 应用 ID。从 ZEGO [控制台](https://console.zego.im/) 获取。 |
| `API_BASE_URL` | 业务后台地址。模拟器使用 `localhost`，真机使用电脑的局域网 IP。 |
| `DIGITAL_HUMAN_ID` | 数字人 ID。与服务端协商一致，用于预加载数字人资源。 |

```objc
@implementation Config

+ (NSUInteger)APP_ID {
    return 1234567890;  // 替换为你的 AppID
}

+ (NSString *)API_BASE_URL {
    return @"http://localhost:3000";  // 替换为实际地址
}

+ (NSString *)DIGITAL_HUMAN_ID {
    return @"your_digital_human_id";  // 替换为你的数字人 ID
}

@end
```

### 4. 运行

```bash
# 在 Xcode 中选择目标设备，点击运行
# 或使用命令行
xcodebuild -workspace ZegoDigitalHumanQuickStart.xcworkspace \
           -scheme ZegoDigitalHumanQuickStart \
           -configuration Debug
```

---

## 二、源码结构

```
ios-oc/
└── ZegoDigitalHumanQuickStart/
    ├── ZegoDigitalHumanQuickStart/
    │   ├── ViewController.m           # 主视图控制器，包含完整的播放流程
    │   ├── Config.h/m                 # 配置文件
    │   └── Info.plist                 # 权限配置
    ├── Podfile                        # CocoaPods 依赖配置
    └── ZegoDigitalHumanQuickStart.xcworkspace
```

---

## 三、核心流程

```
创建任务 → 获取 Token → 预加载资源 → 登录房间 → 启动数字人 → 模拟说话 → 结束通话
```

| 步骤 | 说明 |
|------|------|
| 创建任务 | 调用 `POST /api/digital-human/create-task`，获取 taskId、roomId、streamId 和渲染信息 |
| 获取 Token | 调用 `GET /api/token?userId=xxx`，获取 RTC 登录 Token |
| 预加载资源 | 使用数字人 SDK 预加载资源文件 |
| 登录房间 | 使用 Express SDK 登录 RTC 房间 |
| 启动数字人 | 启动数字人 SDK，开启自定义视频渲染，透传视频帧和 SEI 数据 |
| 模拟说话 | 调用 `POST /api/digital-human/talk-to-ai`，业务后台通过 WebSocket 驱动数字人 |
| 结束通话 | 停止数字人 SDK、停止拉流、退出房间、调用 `POST /api/digital-human/stop-task` |

---

## 四、依赖说明

| 依赖 | 版本 | 说明 |
|------|------|------|
| `ZegoExpressPrivate` | 3.22.0.46788 | ZEGO Express SDK (RTC) |
| `ZegoDigitalMobile` | 1.4.0.88 | ZEGO 数字人 SDK |

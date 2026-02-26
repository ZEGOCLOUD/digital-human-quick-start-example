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

```objc
@implementation Config

+ (NSUInteger)APP_ID {
    return 1234567890;  // 替换为你的 AppID
}

+ (NSString *)API_BASE_URL {
    return @"http://localhost:3000";  // 替换为实际地址
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
创建任务 → 获取 Token → 登录房间 → 拉流播放 → 模拟说话 → 结束通话
```

| 步骤 | 说明 |
|------|------|
| 创建任务 | 调用 `POST /api/digital-human/create-task` 获取 taskId |
| 获取 Token | 调用 `GET /api/token?userId=xxx`，获取 RTC 登录 Token |
| 登录房间 | 使用 Express SDK 登录 RTC 房间 |
| 拉流播放 | 使用 Express SDK 拉取数字人音视频流并渲染 |
| 模拟说话 | 调用 `POST /api/digital-human/talk-to-ai`，业务后台通过 WebSocket 驱动数字人 |
| 结束通话 | 停止拉流、退出房间、调用 `POST /api/digital-human/stop-task` |

---

## 四、依赖说明

| 依赖 | 版本 | 说明 |
|------|------|------|
| `ZegoExpressEngine` | 3.22.0 | ZEGO Express SDK (RTC) |

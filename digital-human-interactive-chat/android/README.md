[中文](README.md) | [English](README.en.md)

# 数字人交互聊天 - Android 客户端

本示例演示 Android 端作为客户端，与数字人进行实时交互对话。

## 一、安装配置与运行

### 1. 环境要求
- Android Studio Hedgehog (2023.1.1) 或更高版本
- Android SDK 24+ (Android 7.0+)
- Kotlin 1.9+

### 2. 配置

编辑 `app/src/main/java/com/example/digitalhumanquickstartdemo/config/Config.kt`：

| 变量 | 说明 |
|------|------|
| `APP_ID` | ZEGO 应用 ID。从 ZEGO [控制台](https://console.zego.im/) 获取。 |
| `API_BASE_URL` | 业务后台地址。模拟器使用 `10.0.2.2` 访问宿主机，真机使用电脑的局域网 IP。 |

```kotlin
object Config {
    const val APP_ID: Long = 1234567890L  // 替换为你的 AppID
    const val API_BASE_URL = "http://10.0.2.2:3000"  // 替换为实际地址
}
```

### 3. 运行

```bash
# 打开 Android Studio，打开项目后点击运行
./gradlew installDebug
```

---

## 二、源码结构

```
android/
├── app/
│   └── src/main/
│       ├── java/com/example/digitalhumanquickstartdemo/
│       │   ├── MainActivity.kt           # 主 Activity，包含完整的交互流程
│       │   └── config/
│       │       └── Config.kt             # 配置文件
│       └── res/
│           └── layout/
│               └── activity_main.xml     # UI 布局
└── build.gradle.kts                      # 依赖配置
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
| `im.zego:express-video` | 3.22.0 | ZEGO Express SDK (RTC) |

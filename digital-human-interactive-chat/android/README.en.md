[中文](README.md) | [English](README.en.md)

# Digital Human Interactive Chat - Android Client

This example demonstrates the Android client engaging in real-time interactive conversations with digital humans.

## 1. Installation, Configuration, and Running

### 1. Environment Requirements
- Android Studio Hedgehog (2023.1.1) or higher
- Android SDK 24+ (Android 7.0+)
- Kotlin 1.9+

### 2. Configuration

Edit `app/src/main/java/com/example/digitalhumanquickstartdemo/config/Config.kt`:

| Variable | Description |
|------|------|
| `APP_ID` | ZEGO App ID. Obtained from ZEGO [Console](https://console.zego.im/). |
| `API_BASE_URL` | Business backend address. Emulator uses `10.0.2.2` to access host, real device uses the computer's LAN IP. |

```kotlin
object Config {
    const val APP_ID: Long = 1234567890L  // Replace with your AppID
    const val API_BASE_URL = "http://10.0.2.2:3000"  // Replace with actual address
}
```

### 3. Running

```bash
# Open Android Studio, open the project and click Run
./gradlew installDebug
```

---

## 2. Source Code Structure

```
android/
├── app/
│   └── src/main/
│       ├── java/com/example/digitalhumanquickstartdemo/
│       │   ├── MainActivity.kt           # Main Activity, contains complete interaction flow
│       │   └── config/
│       │       └── Config.kt             # Configuration file
│       └── res/
│           └── layout/
│               └── activity_main.xml     # UI layout
└── build.gradle.kts                      # Dependency configuration
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
| Pull Stream & Play | Use Express SDK to pull digital human audio/video stream and render |
| Simulate Speech | Call `POST /api/digital-human/talk-to-ai`, business backend drives digital human via WebSocket |
| End Call | Stop streaming, exit room, call `POST /api/digital-human/stop-task` |

---

## 4. Dependency Description

| Dependency | Version | Description |
|------|------|------|
| `im.zego:express-video` | 3.22.0 | ZEGO Express SDK (RTC) |

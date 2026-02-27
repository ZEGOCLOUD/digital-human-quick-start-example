[中文](README.md) | [English](README.en.md)

# Digital Human Broadcasting System - Android Playback End

This example demonstrates the Android end as a playback end, pulling and playing digital human audio/video streams.

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
    const val API_BASE_URL = "http://localhost:3000"  // Replace with actual address
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
│       │   ├── MainActivity.kt           # Main Activity, contains complete playback flow
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
Get Broadcast List → Get Token → Login Room → Pull Stream & Play
```

| Step | Description |
|------|------|
| Get Broadcast List | Call `GET /api/broadcast` to get roomId and streamId |
| Get Token | Call `GET /api/token?userId=xxx` to get RTC login Token |
| Login Room | Use Express SDK to login to RTC room |
| Pull Stream & Play | Use Express SDK to pull digital human audio/video stream and render |

---

## 4. Dependency Description

| Dependency | Version | Description |
|------|------|------|
| `im.zego:express-video` | 3.22.0 | ZEGO Express SDK (RTC) |

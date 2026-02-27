[中文](README.md) | [English](README.en.md)

# Digital Human Interactive Chat - iOS Client

This example demonstrates the iOS client engaging in real-time interactive conversations with digital humans.

## 1. Installation, Configuration, and Running

### 1. Environment Requirements
- Xcode 15.0 or higher
- iOS 12.0+
- CocoaPods

### 2. Install Dependencies

```bash
cd ZegoDigitalHumanQuickStart
pod install
```

Open `ZegoDigitalHumanQuickStart.xcworkspace` (note: xcworkspace, not xcodeproj).

### 3. Configuration

Edit `ZegoDigitalHumanQuickStart/Config.m`:

| Variable | Description |
|------|------|
| `APP_ID` | ZEGO App ID. Obtained from ZEGO [Console](https://console.zego.im/). |
| `API_BASE_URL` | Business backend address. Simulator uses `localhost`, real device uses the computer's LAN IP. |

```objc
@implementation Config

+ (NSUInteger)APP_ID {
    return 1234567890;  // Replace with your AppID
}

+ (NSString *)API_BASE_URL {
    return @"http://localhost:3000";  // Replace with actual address
}

@end
```

### 4. Running

```bash
# In Xcode, select target device and click Run
# Or use command line
xcodebuild -workspace ZegoDigitalHumanQuickStart.xcworkspace \
           -scheme ZegoDigitalHumanQuickStart \
           -configuration Debug
```

---

## 2. Source Code Structure

```
ios-oc/
└── ZegoDigitalHumanQuickStart/
    ├── ZegoDigitalHumanQuickStart/
    │   ├── ViewController.m           # Main view controller, contains complete playback flow
    │   ├── Config.h/m                 # Configuration file
    │   └── Info.plist                 # Permission configuration
    ├── Podfile                        # CocoaPods dependency configuration
    └── ZegoDigitalHumanQuickStart.xcworkspace
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
| `ZegoExpressEngine` | 3.22.0 | ZEGO Express SDK (RTC) |

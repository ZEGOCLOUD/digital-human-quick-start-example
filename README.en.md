[中文](README.md) | [English](README.en.md)

# Digital Human Sample Code

This directory contains complete sample code for two digital human application scenarios, helping developers quickly understand architecture design and implementation methods for different business scenarios.

## Examples Directory

### 1. Digital Human Interactive Chat Example (`digital-human-interactive-chat`)

**Application Scenarios**: Intelligent customer service, virtual anchor interaction, education training, and other scenarios requiring real-time conversation

**Core Functionality**: Clients engage in real-time two-way interactive conversations with digital humans

**Architecture Features**:
- **Two-way Interaction**: User speaks → ASR speech recognition → LLM generates response → TTS speech synthesis → Digital human responds in real-time
- **Dual-role Architecture**: Client + Business backend
- **Real-time Communication**: WebSocket-driven digital human, RTC streaming for audio/video playback


---

### 2. Digital Human Real-time Broadcasting Example (`digital-human-real-time-broadcasting-scenario`)

**Application Scenarios**: Shopping mall guides, airport/station announcements, elevator advertising screens, digital human live streaming, and other one-way broadcasting scenarios

**Core Functionality**: Orchestration end configures broadcast content, playback end streams and plays digital human audio/video

**Architecture Features**:
- **One-way Broadcasting**: Orchestration end configures content → Business backend schedules driving → Playback end streams and plays
- **Three-party Architecture**: Orchestration end (configuration) + Business backend (driving) + Playback end (playback)
- **Centralized Management**: Supports multiple playback ends receiving the same broadcast content simultaneously

---

## Architecture Comparison

| Feature | Interactive Chat | Real-time Broadcasting |
|------|------------|------------|
| **Interaction Mode** | Two-way real-time interaction | One-way broadcasting |
| **Role Architecture** | Dual-role (Client + Business backend) | Three-role (Orchestration + Business backend + Playback) |
| **Driving Method** | User speech triggers ASR→LLM→TTS | Orchestration end configures content, scheduled driving |
| **Applicable Scenarios** | Intelligent customer service, virtual anchor interaction, education training | Shopping mall guides, airport announcements, advertising screens, live streaming |
| **Communication Complexity** | Higher (requires real-time audio capture) | Lower (text/audio driving only) |

## Quick Start

Each example directory contains complete business backend and client-side code for all platforms:

- **Business Backend**: Node.js + Express, providing API interfaces and digital human driving logic
- **Web Clients**: React / Vue examples, using ZEGO Express SDK for streaming playback
- **Mobile Clients**: Android / iOS examples, using ZEGO Express SDK for streaming playback

For detailed integration guides, please refer to the README.md file in each example directory.

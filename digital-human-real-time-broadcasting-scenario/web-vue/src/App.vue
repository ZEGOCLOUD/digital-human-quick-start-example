<script setup>
import { onMounted, onUnmounted, ref } from 'vue'

const toNumber = (value, fallback) => {
  const parsed = Number(value)
  return Number.isFinite(parsed) ? parsed : fallback
}

// 从环境变量获取配置
const clientConfig = {
  appId: toNumber(import.meta.env.VITE_APP_ID, 0),
  apiBaseUrl: import.meta.env.VITE_API_BASE_URL || 'http://localhost:3001'
}

// 生成随机用户 ID
const generateUserId = () => `user_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`

const status = ref('初始化中...')
const roomInfo = ref(null)
let engine = null
let currentRoom = null
let stopped = false

onMounted(async () => {
  try {
    // 检查配置
    if (!clientConfig.appId) {
      status.value = '请检查 VITE_APP_ID'
      return
    }

    // 步骤1：从业务后台获取播报列表
    status.value = '从业务后台获取播报列表中...'
    const broadcastResponse = await fetch(`${clientConfig.apiBaseUrl}/api/broadcast`, { cache: 'no-store' })

    if (!broadcastResponse.ok) {
      status.value = '获取播报列表失败'
      return
    }

    const payload = await broadcastResponse.json()
    const broadcasts = payload.broadcastList || {}
    const broadcastKeys = Object.keys(broadcasts)

    if (broadcastKeys.length === 0) {
      status.value = '没有可用播报，请先在配置页面启动播报任务'
      return
    }

    // 仅作示例。选择第一个播报
    const firstIndex = broadcastKeys[0]
    const broadcast = broadcasts[firstIndex]

    if (stopped) return

    // 步骤2：获取用于登录 RTC 房间的 Token
    status.value = '获取 Token 中...'
    const userId = generateUserId()
    const tokenResponse = await fetch(`${clientConfig.apiBaseUrl}/api/token?userId=${userId}`)

    if (!tokenResponse.ok) {
      status.value = '获取 Token 失败'
      return
    }

    const tokenData = await tokenResponse.json()

    currentRoom = {
      roomId: broadcast.roomId,
      streamId: broadcast.streamId,
      userId,
      token: tokenData.token
    }

    if (stopped) return
    roomInfo.value = currentRoom

    status.value = '初始化拉流中...'

    // 步骤3：动态导入并初始化 ZegoExpressEngine
    const { ZegoExpressEngine } = await import('zego-express-engine-webrtc')
    engine = new ZegoExpressEngine(clientConfig.appId, "")

    // 步骤4：登录实时音视频 (RTC) 房间
    await engine.loginRoom(currentRoom.roomId, currentRoom.token, {
      userID: currentRoom.userId,
      userName: currentRoom.userId
    })

    // 步骤5：拉取数字人音视频流
    const remoteStream = await engine.startPlayingStream(currentRoom.streamId)
    const remoteView = engine.createRemoteStreamView(remoteStream)
    remoteView.play('remote-video')
    status.value = '播放中...'
  } catch (error) {
    status.value = `启动失败: ${error?.message || '未知错误'}`
  }
})

onUnmounted(() => {
  stopped = true
  if (engine && currentRoom) {
    engine.stopPlayingStream(currentRoom.streamId)
    engine.logoutRoom(currentRoom.roomId)
    engine.destroyEngine()
  }
})
</script>

<template>
  <div class="container">
    <header class="header">
      <h1>数字人快速开始</h1>
      <p class="status">状态：{{ status }}</p>
      <p v-if="roomInfo" class="room-info">
        房间：{{ roomInfo.roomId }} · 流：{{ roomInfo.streamId }}
      </p>
    </header>

    <div
      id="remote-video"
      class="video-container"
    />
  </div>
</template>

<style scoped>
.container {
  max-width: 900px;
  margin: 0 auto;
  padding: 2rem;
}

.header {
  margin-bottom: 1.5rem;
  text-align: center;
}

h1 {
  font-size: 1.5rem;
  font-weight: 600;
  margin: 0 0 0.75rem 0;
}

.status {
  margin: 0.5rem 0;
  font-size: 0.9rem;
  opacity: 0.8;
}

.room-info {
  margin: 0.5rem 0;
  font-size: 0.85rem;
  opacity: 0.7;
}

.video-container {
  width: 100%;
  aspect-ratio: 16 / 9;
  background-color: #000;
  border-radius: 12px;
  overflow: hidden;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.15);
}
</style>

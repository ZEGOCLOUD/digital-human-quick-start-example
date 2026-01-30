import { useEffect, useState } from 'react'
import './index.css'

const toNumber = (value, fallback) => {
  const parsed = Number(value)
  return Number.isFinite(parsed) ? parsed : fallback
}

// 从环境变量获取配置
const clientConfig = {
  appId: toNumber(import.meta.env.VITE_APP_ID, 0),
  apiBaseUrl: import.meta.env.VITE_API_BASE_URL || 'http://localhost:3000'
}

// 生成随机用户 ID
const generateUserId = () => `user_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`

function App() {
  const [status, setStatus] = useState('初始化中...')
  const [roomInfo, setRoomInfo] = useState(null)

  useEffect(() => {
    let stopped = false
    let engine = null
    let currentRoom = null

    const bootstrap = async () => {
      try {
        // 检查配置
        if (!clientConfig.appId) {
          setStatus('请检查 VITE_APP_ID')
          return
        }

        // 步骤1：从业务后台获取播报列表
        setStatus('从业务后台获取播报列表中...')
        const broadcastResponse = await fetch(`${clientConfig.apiBaseUrl}/api/broadcast`, { cache: 'no-store' })

        if (!broadcastResponse.ok) {
          setStatus('获取播报列表失败')
          return
        }

        const payload = await broadcastResponse.json()
        const broadcasts = payload.broadcastList || {}
        const broadcastKeys = Object.keys(broadcasts)

        if (broadcastKeys.length === 0) {
          setStatus('没有可用播报，请先在配置页面启动播报任务')
          return
        }

        // 选择第一个播报
        const firstIndex = broadcastKeys[0]
        const broadcast = broadcasts[firstIndex]

        if (stopped) return

        // 步骤2：获取用于登录 RTC 房间的 Token
        setStatus('获取 Token 中...')
        const userId = generateUserId()
        const tokenResponse = await fetch(`${clientConfig.apiBaseUrl}/api/token?userId=${userId}`)

        if (!tokenResponse.ok) {
          setStatus('获取 Token 失败')
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
        setRoomInfo(currentRoom)

        setStatus('初始化拉流中...')

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
        setStatus('播放中...')
      } catch (error) {
        setStatus(`启动失败: ${error?.message || '未知错误'}`)
      }
    }

    bootstrap()

    return () => {
      stopped = true
      if (engine && currentRoom) {
        engine.stopPlayingStream(currentRoom.streamId)
        engine.logoutRoom(currentRoom.roomId)
        engine.destroyEngine()
      }
    }
  }, [])

  return (
    <div className="grid">
      <section className="card">
        <h1>数字人快速开始（React + Vite）</h1>
        <p className="meta">状态：{status}</p>
        {roomInfo && (
          <p className="meta">
            房间：{roomInfo.roomId} ｜ 流：{roomInfo.streamId}
          </p>
        )}
      </section>

      <section className="card">
        <div
          id="remote-video"
          className="video-container"
        />
      </section>
    </div>
  )
}

export default App

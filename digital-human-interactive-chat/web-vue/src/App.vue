<template>
  <div class="app">
    <h1>数字人交互聊天示例<br />Digital Human Interactive Chat Example</h1>

    <!-- 数字人视频区域 -->
    <!-- Digital human video area -->
    <div ref="videoContainer" class="video-container"></div>

    <!-- 状态显示 -->
    <!-- Status display -->
    <div class="status">
      Status: {{ status }}
    </div>

    <!-- 说明文字 -->
    <!-- Note -->
    <div class="note">
      正常逻辑是客户端采集用户说话音频后发送至业务后台
      <br />
      In normal operation, the client captures user speech audio and sends it to the backend
    </div>

    <!-- 按钮区域 -->
    <!-- Button area -->
    <div class="controls">
      <button @click="handleStartCall" :disabled="isCallStarted">
        Start Call
        <br />
        开始通话
      </button>
      <button @click="handleStopCall" :disabled="!isCallStarted">
        Stop Call
        <br />
        结束通话
      </button>
      <button @click="() => handleSimulateTalk('zh')" :disabled="!isCallStarted">
        Simulate User Speech (ZH)
        <br />
        模拟用户说话(中文)
      </button>
      <button @click="() => handleSimulateTalk('en')" :disabled="!isCallStarted">
        Simulate User Speech (EN)
        <br />
        模拟用户说话(英文)
      </button>
    </div>
  </div>
</template>

<script>
import { ref, onBeforeUnmount } from 'vue';
import { ZegoExpressEngine } from 'zego-express-engine-webrtc';

export default {
  name: 'App',
  setup() {
    const videoContainer = ref(null);
    const engine = ref(null);
    const status = ref('waiting for initialization...');
    const taskId = ref(null);
    const roomId = ref(null);
    const streamId = ref(null);
    const isCallStarted = ref(false);

    const parseSpeakStatusFromExperimentalAPI = (content) => {
      if (!content) return null;

      const contentData = typeof content === 'string' ? JSON.parse(content) : content;
      const method = contentData?.method;
      if (
        method !== 'onRecvRoomChannelMessage' &&
        method !== 'liveroom.room.on_recive_room_channel_message'
      ) {
        return null;
      }

      const params = contentData?.params || contentData?.content;
      const msgContent = params?.msg_content || params?.msgContent;
      if (!msgContent) {
        return null;
      }

      const msgData = typeof msgContent === 'string' ? JSON.parse(msgContent) : msgContent;
      if (msgData?.Product !== 'digitalhuman' || msgData?.Cmd !== 1001 || !msgData?.Data) {
        return null;
      }

      return {
        speakStatus: msgData.Data.Status,
        driveID: msgData.Data.DriveId,
      };
    };

    /**
     * 开始通话
     * Start call
     */
    const handleStartCall = async () => {
      try {
        status.value = 'Initializing...';

        // 1. 初始化 SDK / Initialize SDK
        const appId = Number(import.meta.env.VITE_APP_ID);
        const server = 'wss://webliveroom-api.zego.im/ws';
        const zg = new ZegoExpressEngine(appId, server);
        engine.value = zg;

        zg.on('recvExperimentalAPI', (content) => {
          try {
            const result = parseSpeakStatusFromExperimentalAPI(content);
            if (!result) return;

            if (result.speakStatus === 2) {
              status.value = result.driveID
                ? `Digital human started speaking, DriveID: ${result.driveID}`
                : 'Digital human started speaking';
            } else if (result.speakStatus === 4) {
              status.value = result.driveID
                ? `Digital human finished speaking, DriveID: ${result.driveID}`
                : 'Digital human finished speaking';
            }
          } catch (error) {
            console.error('Handle experimental API failed:', error);
          }
        });

        await zg.callExperimentalAPI({
          method: 'onRecvRoomChannelMessage',
          params: {},
        });

        // 2. 生成唯一标识 / Generate unique identifiers
        const userId = `user_${Date.now()}`;
        const newRoomId = `room_${Date.now()}`;  // 数字人加入的 RTC 房间 ID，每个用户应使用不同的房间 ID / Digital human's RTC room ID, each user should use a different room ID
        const newStreamId = `stream_${Date.now()}`;  // 数字人推流的流 ID / Digital human's stream ID for pushing stream

        // 3. 创建数字人任务 / Create digital human task
        // POST /api/digital-human/create-task
        // 请求参数：roomId (数字人加入的房间 ID), streamId (数字人推流的流 ID)
        // Request parameters: roomId (Digital human's RTC room ID), streamId (Digital human's stream ID)
        // (digitalHumanId 由服务端环境变量配置 / digitalHumanId configured in server env)
        status.value = 'Creating digital human task...';
        const apiBaseUrl = import.meta.env.VITE_API_BASE_URL;
        const createTaskResponse = await fetch(
          `${apiBaseUrl}/api/digital-human/create-task`,
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              roomId: newRoomId,
              streamId: newStreamId,
            }),
          }
        );

        if (!createTaskResponse.ok) {
          throw new Error(`Server error: ${createTaskResponse.status}`);
        }

        const taskInfo = await createTaskResponse.json();
        if (!taskInfo.success) {
          throw new Error(`Create task failed: ${taskInfo.error}`);
        }

        taskId.value = taskInfo.taskId;
        roomId.value = newRoomId;
        streamId.value = newStreamId;

        // 4. 获取 Token / Get Token
        status.value = 'Fetching token...';
        const tokenResponse = await fetch(`${apiBaseUrl}/api/token?userId=${userId}`);
        if (!tokenResponse.ok) {
          throw new Error(`Server error: ${tokenResponse.status}`);
        }

        const tokenData = await tokenResponse.json();
        if (!tokenData.success) {
          throw new Error(`Get token failed: ${tokenData.error}`);
        }

        const token = tokenData.token;

        // 5. 登录房间 / Login room
        status.value = 'Logging in to room...';
        await zg.loginRoom(newRoomId, token, {
          userID: userId,
          userName: userId,
        });

        // 6. 拉流 / Start playing stream
        status.value = 'Starting playing stream...';
        const remoteStream = await zg.startPlayingStream(newStreamId);
        const remoteView = zg.createRemoteStreamView(remoteStream);
        remoteView.play(videoContainer.value);

        isCallStarted.value = true;
        status.value = 'In call';
      } catch (error) {
        console.error('Start call failed:', error);
        status.value = `Start failed: ${error.message}`;
      }
    };

    /**
     * 模拟说话
     * Simulate talk
     */
    const handleSimulateTalk = async (lang) => {
      try {
        // 注释说明: 实际场景中,这里应该采集麦克风音频数据并发送至服务端
        // Note: In actual scenario, microphone audio data should be captured here and sent to the backend
        // 本示例为模拟,直接调用服务端接口
        // This example simulates by directly calling server API

        const langText = lang === 'en' ? 'English' : 'Chinese';
        status.value = `AI interacting (${langText})...`;

        const apiBaseUrl = import.meta.env.VITE_API_BASE_URL;
        const response = await fetch(`${apiBaseUrl}/api/digital-human/talk-to-ai`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ taskId: taskId.value, lang }),
        });

        if (response.ok) {
          status.value = 'AI responding...';
          // 服务端收到用户说话音频后，经过 ASR -> LLM -> TTS 处理后，通过 WebSocket 驱动数字人播报
          // After receiving the user's speech audio, the server will process it through ASR -> LLM -> TTS, and then drive the digital human via WebSocket
          setTimeout(() => {
            status.value = 'In call';
          }, 2000);
        } else {
          status.value = `Request failed: ${response.status}`;
        }
      } catch (error) {
        console.error('Simulate talk failed:', error);
        status.value = `Simulate user speech failed: ${error.message}`;
      }
    };

    /**
     * 结束通话
     * Stop call
     */
    const handleStopCall = async () => {
      try {
        status.value = 'Stopping call...';

        // 1. 停止拉流 / Stop playing stream
        if (engine.value && streamId.value) {
          await engine.value.stopPlayingStream(streamId.value);
        }

        // 2. 退出房间 / Logout room
        if (engine.value && roomId.value) {
          await engine.value.logoutRoom();
        }

        // 3. 调用服务端停止任务 / Call server to stop task
        if (taskId.value) {
          const apiBaseUrl = import.meta.env.VITE_API_BASE_URL;
          await fetch(`${apiBaseUrl}/api/digital-human/stop-task`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ taskId: taskId.value }),
          });
        }

        isCallStarted.value = false;
        taskId.value = null;
        roomId.value = null;
        streamId.value = null;
        status.value = 'waiting for initialization...';
      } catch (error) {
        console.error('Stop call failed:', error);
        status.value = `Stop failed: ${error.message}`;
      }
    };

    // 组件卸载时清理资源
    // Cleanup resources on component unmount
    onBeforeUnmount(() => {
      if (engine.value && isCallStarted.value) {
        handleStopCall();
      }
    });

    return {
      videoContainer,
      status,
      isCallStarted,
      handleStartCall,
      handleSimulateTalk,
      handleStopCall,
    };
  },
};
</script>

<style scoped>
.app {
  text-align: center;
  padding: 20px;
  font-family: Arial, sans-serif;
}

h1 {
  color: #333;
  margin-bottom: 20px;
  line-height: 1.4;
}

.video-container {
  width: 640px;
  height: 480px;
  background-color: #000;
  border: 2px solid #ccc;
  border-radius: 8px;
  margin: 20px auto;
}

.status {
  font-size: 16px;
  margin: 20px 0;
  color: #666;
}

.note {
  font-size: 12px;
  color: #999;
  margin: 10px 0;
  line-height: 1.6;
}

.controls {
  display: flex;
  gap: 10px;
  justify-content: center;
  margin-top: 20px;
}

button {
  padding: 10px 20px;
  font-size: 14px;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  background-color: #4caf50;
  color: white;
  transition: background-color 0.3s;
}

button:hover:not(:disabled) {
  background-color: #45a049;
}

button:disabled {
  background-color: #ccc;
  cursor: not-allowed;
}
</style>

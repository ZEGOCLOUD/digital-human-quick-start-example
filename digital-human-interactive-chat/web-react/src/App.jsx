import { useState, useRef, useEffect } from 'react';
import { ZegoExpressEngine } from 'zego-express-engine-webrtc';
import './App.css';

function App() {
  const [engine, setEngine] = useState(null);
  const [status, setStatus] = useState('waiting for initialization...');
  const [taskId, setTaskId] = useState(null);
  const [roomId, setRoomId] = useState(null);
  const [streamId, setStreamId] = useState(null);
  const [isCallStarted, setIsCallStarted] = useState(false);
  const videoRef = useRef(null);

  useEffect(() => {
    return () => {
      // 组件卸载时清理资源
      // Cleanup resources on component unmount
      if (engine && isCallStarted) {
        handleStopCall();
      }
    };
  }, [engine, isCallStarted]);

  /**
   * 开始通话
   * Start call
   */
  const handleStartCall = async () => {
    try {
      setStatus('Initializing...');

      // 1. 初始化 SDK / Initialize SDK
      const appId = Number(import.meta.env.VITE_APP_ID);
      const server = 'wss://webliveroom-api.zego.im/ws';
      const zg = new ZegoExpressEngine(appId, server);
      setEngine(zg);

      // 2. 生成唯一标识 / Generate unique identifiers
      const userId = `user_${Date.now()}`;
      const newRoomId = `room_${Date.now()}`;  // 数字人加入的 RTC 房间 ID，每个用户应使用不同的房间 ID / Digital human's RTC room ID, each user should use a different room ID
      const newStreamId = `stream_${Date.now()}`;  // 数字人推流的流 ID / Digital human's stream ID for pushing stream

      // 3. 创建数字人任务 / Create digital human task
      // POST /api/digital-human/create-task
      // 请求参数：roomId (数字人加入的房间 ID), streamId (数字人推流的流 ID)
      // Request parameters: roomId (Digital human's RTC room ID), streamId (Digital human's stream ID)
      // (digitalHumanId 由服务端环境变量配置 / digitalHumanId configured in server env)
      setStatus('Creating digital human task...');
      const apiBaseUrl = import.meta.env.VITE_API_BASE_URL;
      const createTaskResponse = await fetch(`${apiBaseUrl}/api/digital-human/create-task`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          roomId: newRoomId,
          streamId: newStreamId,
        }),
      });

      if (!createTaskResponse.ok) {
        throw new Error(`Server error: ${createTaskResponse.status}`);
      }

      const taskInfo = await createTaskResponse.json();
      if (!taskInfo.success) {
        throw new Error(`Create task failed: ${taskInfo.error}`);
      }

      setTaskId(taskInfo.taskId);
      setRoomId(newRoomId);
      setStreamId(newStreamId);

      // 4. 获取 Token / Get Token
      setStatus('Fetching token...');
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
      setStatus('Logging in to room...');
      await zg.loginRoom(newRoomId, token, {
        userID: userId,
        userName: userId,
      });

      // 6. 拉流 / Start playing stream
      setStatus('Starting playing stream...');
      const remoteStream = await zg.startPlayingStream(newStreamId);
      const remoteView = zg.createRemoteStreamView(remoteStream);
      remoteView.play(videoRef.current);

      setIsCallStarted(true);
      setStatus('In call');
    } catch (error) {
      console.error('Start call failed:', error);
      setStatus(`Start failed: ${error.message}`);
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
      setStatus(`AI interacting (${langText})...`);

      const apiBaseUrl = import.meta.env.VITE_API_BASE_URL;
      const response = await fetch(`${apiBaseUrl}/api/digital-human/talk-to-ai`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ taskId, lang }),
      });

      if (response.ok) {
        setStatus('AI responding...');
        // 服务端收到用户说话音频后，经过 ASR -> LLM -> TTS 处理后，通过 WebSocket 驱动数字人播报
        // After receiving the user's speech audio, the server will process it through ASR -> LLM -> TTS, and then drive the digital human via WebSocket
        setTimeout(() => {
          setStatus('In call');
        }, 2000);
      } else {
        setStatus(`Request failed: ${response.status}`);
      }
    } catch (error) {
      console.error('Simulate talk failed:', error);
      setStatus(`Simulate user speech failed: ${error.message}`);
    }
  };

  /**
   * 结束通话
   * Stop call
   */
  const handleStopCall = async () => {
    try {
      setStatus('Stopping call...');

      // 1. 停止拉流 / Stop playing stream
      if (engine && streamId) {
        await engine.stopPlayingStream(streamId);
      }

      // 2. 退出房间 / Logout room
      if (engine && roomId) {
        await engine.logoutRoom();
      }

      // 3. 调用服务端停止任务 / Call server to stop task
      if (taskId) {
        const apiBaseUrl = import.meta.env.VITE_API_BASE_URL;
        await fetch(`${apiBaseUrl}/api/digital-human/stop-task`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ taskId }),
        });
      }

      setIsCallStarted(false);
      setTaskId(null);
      setRoomId(null);
      setStreamId(null);
      setStatus('waiting for initialization...');
    } catch (error) {
      console.error('Stop call failed:', error);
      setStatus(`Stop failed: ${error.message}`);
    }
  };

  return (
    <div className="App">
      <h1>数字人交互聊天示例<br />Digital Human Interactive Chat Example</h1>

      {/* 数字人视频区域 */}
      {/* Digital human video area */}
      <div
        ref={videoRef}
        className="video-container"
        style={{
          width: '640px',
          height: '480px',
          backgroundColor: '#000',
          margin: '20px auto',
        }}
      />

      {/* 状态显示 */}
      {/* Status display */}
      <div className="status">
        Status: {status}
      </div>

      {/* 说明文字 */}
      {/* Note */}
      <div style={{ textAlign: 'center', fontSize: '12px', color: '#666', marginTop: '10px' }}>
        正常逻辑是客户端采集用户说话音频后发送至业务后台
        <br />
        In normal operation, the client captures user speech audio and sends it to the backend
      </div>

      {/* 按钮区域 */}
      {/* Button area */}
      <div className="controls">
        <button onClick={handleStartCall} disabled={isCallStarted}>
          Start Call
          <br />
          开始通话
        </button>
        <button onClick={handleStopCall} disabled={!isCallStarted}>
          Stop Call
          <br />
          结束通话
        </button>
        <button onClick={() => handleSimulateTalk('zh')} disabled={!isCallStarted}>
          Simulate User Speech (ZH)
          <br />
          模拟用户说话(中文)
        </button>
        <button onClick={() => handleSimulateTalk('en')} disabled={!isCallStarted}>
          Simulate User Speech (EN)
          <br />
          模拟用户说话(英文)
        </button>
      </div>
    </div>
  );
}

export default App;

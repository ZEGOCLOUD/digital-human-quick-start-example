<script setup>
import { ref, reactive, computed, inject } from "vue";
import { streamAPI, driveAPI } from "../utils/api";
import { CONFIG } from "../config";
import { roomMessageParser } from "../utils";

// 不再需要isDev

// 接收 props
const props = defineProps({
  appConfig: Object,
  taskState: Object,
  isMobile: Boolean,
  showMessage: Function,
  updateTaskState: Function,
  userId: String,
});

// 不再需要emit事件

// 响应式状态
const loading = reactive({
  createTask: false,
  stopTask: false,
  textDrive: false,
  audioDrive: false,
  wsTTSDrive: false,
  interrupt: false,
});

// 不再需要表单数据，所有参数在服务端设置

// 是否登录房间
const isRoomLogined = ref(false);
// 已注册回调的引擎实例
const registeredInstance = ref(null);

// 计算属性
const canCreateTask = computed(() => {
  return (
    !props.taskState.currentTaskId &&
    !loading.createTask
  );
});

const canOperate = computed(() => !!props.taskState.currentTaskId);

const controlClass = computed(() => props.isMobile ? "control-mobile" : "control-desktop");

// 不再需要防抖和音色切换处理

// 创建数字人视频流任务
const handleCreateTask = async () => {
  if (!canCreateTask.value) {
    return;
  }
  loading.createTask = true;
  try {
    const userID = props.userId || ("user_" + Math.random().toString(36).substr(2, 8));
    const userName = "user_" + Math.floor(Math.random() * 10000);
    
    // 1. 创建任务
    // Web端传大图模式(OutputMode: 1)，传递UserId
    const config = {
      OutputMode: 1,
      UserId: userID  // 用户ID，必选
    };

    // 调用服务端接口，服务端会生成 RoomId 和 StreamId
    const result = await streamAPI.createStreamTask(config);
    
    // 2. 从服务端返回结果中获取 AppId、RoomId、StreamId 和 Token
    const appId = result.Data?.AppId;
    const roomId = result.Data?.RoomId;
    const streamId = result.Data?.StreamId;
    const token = result.Data?.Token;
    
    if (!appId) {
      throw new Error('服务端未返回 AppId');
    }
    
    if (!roomId) {
      throw new Error('服务端未返回 RoomId');
    }
    
    if (!streamId) {
      throw new Error('服务端未返回 StreamId');
    }
    
    if (!token) {
      throw new Error('服务端未返回 Token');
    }
    
    // 3. 使用返回的 AppId 初始化 ZegoExpressEngine
    const server = CONFIG.DEFAULT_SERVER;
    const zgInstance = initZegoEngine(appId, server);
    
    if (!zgInstance) {
      throw new Error('ZegoExpressEngine 初始化失败');
    }
    
    // 4. 更新appConfig中的appId
    props.appConfig.appId = appId;
    
    // 5. 注册回调（如果引擎实例发生变化，则重新注册）
    if (registeredInstance.value !== zgInstance) {
      // 5.1 注册流状态更新回调
      zgInstance.on('roomStreamUpdate', async (roomID, updateType, streamList, extendedData) => {
        console.log('[WebRTC] roomStreamUpdate', { roomID, updateType, streamList, extendedData });
        if (updateType === 'ADD' && streamList.length > 0) {
          // 只拉取第一条流，实际业务建议遍历
          const streamID = streamList[0].streamID;
          try {
            const remoteStream = await zgInstance.startPlayingStream(streamID);
            const remoteView = zgInstance.createRemoteStreamView(remoteStream, { objectFit: 'contain' });
            remoteView.play("remote-video");
            console.log('[WebRTC] 已拉取并播放远端流', streamID);
            if (typeof props.updateTaskState === 'function') {
              props.updateTaskState({ isStreaming: true });
            }
          } catch (err) {
            console.error('[WebRTC] 拉流失败', err);
          }
        } else if (updateType === 'DELETE') {
          // 停止拉流
          for (const stream of streamList) {
            zgInstance.stopPlayingStream(stream.streamID);
          }
          if (typeof props.updateTaskState === 'function') {
            props.updateTaskState({ isStreaming: false, currentTask: null });
          }
        }
      });
      
      // 5.2 注册实验性 API 回调，用于接收房间内发送的智能体状态消息
      zgInstance.on('recvExperimentalAPI', (content) => {
        console.log('[WebRTC] 收到实验性 API 消息:', content);
        try {
          const result = roomMessageParser.parseSpeakStatusFromExperimentalAPI(content);
          if (!result) return;

          let message = '';
          if (result.speakStatus === 2) {
            message = result.driveID ? `数字人开始说话，DriveID: ${result.driveID}` : '数字人开始说话';
          } else if (result.speakStatus === 4) {
            message = result.driveID ? `数字人说话结束，DriveID: ${result.driveID}` : '数字人说话结束';
          }

          if (message) {
            console.log('[WebRTC] 显示消息 Toast:', message);
            props.showMessage('warning', message);
          }
        } catch (e) {
          console.error('[WebRTC] 处理实验性 API 消息失败:', e);
        }
      });

      registeredInstance.value = zgInstance;

      try {
        await zgInstance.callExperimentalAPI({
          method: 'onRecvRoomChannelMessage',
          params: {},
        });
        console.log('[WebRTC] 已开启 onRecvRoomChannelMessage experimental API');
      } catch (error) {
        console.error('[WebRTC] 开启 onRecvRoomChannelMessage experimental API 失败:', error);
      }
    }
    
    // 7. 使用服务端返回的 token 登录房间
    await zgInstance.loginRoom(roomId, token, { userID, userName });
    console.log("[webrtc] 登录房间成功", roomId, { userID, userName });
    isRoomLogined.value = true;

    props.updateTaskState({
      currentTaskId: result.Data.TaskId,
      taskStatus: 1,
      isStreaming: false,
      currentTask: {
        RoomId: roomId,
        StreamId: streamId,
        UserID: userID,
        UserName: userName,
        Token: token,
        appId,
        server,
      }
    });

    props.showMessage("success", "任务创建成功，可以开始驱动数字人了");
  } catch (error) {
    console.error("创建任务失败", error);
    isRoomLogined.value = false;
    props.updateTaskState({
      currentTaskId: null,
      taskStatus: null,
      isStreaming: false,
    });

    props.showMessage("error", `创建失败: ${error.msg || error.message}`);
  } finally {
    loading.createTask = false;
  }
};

// 停止数字人视频流任务
const handleStopTask = async () => {
  if (!canOperate.value) return;
  loading.stopTask = true;
  try {
    const zgInstance = zg.value;
    if (zgInstance) {
      zgInstance.logoutRoom();
      console.log('logoutRoom success');
    }
    isRoomLogined.value = false;
    await streamAPI.stopStreamTask(
      props.taskState.currentTaskId
    );
    props.updateTaskState({
      currentTaskId: null,
      taskStatus: null,
      isStreaming: false,
      driveList: [],
      currentTask: null,
      isRoomLogined: false,
    });

    props.showMessage("success", "任务已停止");
  } catch (error) {
    props.showMessage("error", `停止失败: ${error.message}`);
  } finally {
    loading.stopTask = false;
  }
};

// 文本驱动数字人 - 只传递TaskId，所有参数在服务端设置
const handleTextDrive = async () => {
  if (!canOperate.value) {
    props.showMessage("warning", "请先创建任务");
    return;
  }

  loading.textDrive = true;

  try {
    const result = await driveAPI.driveByText(props.taskState.currentTaskId);
  } catch (error) {
    console.error(error);
    let code = error?.Code || error?.response?.Code;
    let msg = error?.Message || error?.response?.Message || error?.message;
    if (code || msg) {
      props.showMessage("error", `文本驱动失败: [${code ?? ''}] ${msg ?? ''}`);
    } else {
      props.showMessage("error", "文本驱动失败，未知错误");
    }
  } finally {
    loading.textDrive = false;
  }
};

// 音频驱动数字人 - 只传递TaskId，所有参数在服务端设置
const handleAudioDrive = async () => {
  if (!canOperate.value) {
    props.showMessage("warning", "请先创建任务");
    return;
  }

  loading.audioDrive = true;

  try {
    const result = await driveAPI.driveByAudio(props.taskState.currentTaskId);
  } catch (error) {
    let code = error?.Code || error?.response?.Code;
    let msg = error?.Message || error?.response?.Message || error?.message;
    if (code) {
      props.showMessage("error", `音频驱动失败: [${code}] ${msg}`);
    } else {
      props.showMessage("error", `音频驱动失败: ${msg}`);
    }
  } finally {
    loading.audioDrive = false;
  }
};

// WebSocket TTS驱动数字人 - 只传递TaskId，所有参数在服务端设置
const handleWsTTSDrive = async () => {
  if (!canOperate.value) {
    props.showMessage("warning", "请先创建任务");
    return;
  }

  loading.wsTTSDrive = true;

  try {
    const result = await driveAPI.driveByWsStreamWithTTS(props.taskState.currentTaskId);
    props.showMessage("success", "WebSocket TTS驱动成功");
  } catch (error) {
    let code = error?.Code || error?.response?.Code;
    let msg = error?.Message || error?.response?.Message || error?.message;
    if (code) {
      props.showMessage("error", `WebSocket TTS驱动失败: [${code}] ${msg}`);
    } else {
      props.showMessage("error", `WebSocket TTS驱动失败: ${msg}`);
    }
  } finally {
    loading.wsTTSDrive = false;
  }
};

// 打断驱动任务
const handleInterrupt = async () => {
  if (!canOperate.value) return;

  loading.interrupt = true;

  try {
    await driveAPI.interruptDriveTask(
      props.taskState.currentTaskId
    );
  } catch (error) {
    props.showMessage("error", `打断失败: ${error.message}`);
  } finally {
    loading.interrupt = false;
  }
};

// 不再需要切换标签页

// 销毁全部任务
const handleDestroyAllTasks = async () => {
  loading.stopTask = true;
  try {
    const zgInstance = zg.value;
    if (zgInstance) {
      zgInstance.logoutRoom();
    }
    const res = await streamAPI.queryStreamTasks();
    console.log("queryStreamTasks 返回：", res);
    const data = res?.Data;
    let tasks = [];
    if (Array.isArray(data)) {
      tasks = data;
    } else if (Array.isArray(data?.Tasks)) {
      tasks = data.Tasks;
    } else if (Array.isArray(data?.TaskList)) {
      tasks = data.TaskList;
    }
    if (tasks.length === 0) {
      props.showMessage("info", "当前没有运行中的任务");
      return;
    }
    // 只停止 RoomId 以 test_room_ 开头的任务
    const filteredTasks = tasks.filter(task => typeof task.RoomId === 'string' && task.RoomId.startsWith('test_room_'));
    if (filteredTasks.length === 0) {
      props.showMessage("info", "没有可销毁的 test_room_ 任务");
      return;
    }
    for (const task of filteredTasks) {
      try {
        await streamAPI.stopStreamTask(task.TaskId);
      } catch (e) {
        // 忽略单个任务停止失败
      }
    }
    props.updateTaskState({
      currentTaskId: null,
      taskStatus: null,
      isStreaming: false,
      driveList: [],
    });

    props.showMessage("success", `已销毁 ${filteredTasks.length} 个任务`);
  } catch (err) {
    props.showMessage("error", `销毁全部任务失败: ${err.message}`);
  } finally {
    loading.stopTask = false;
  }
};

// 不再需要监听音色变化和初始化

const zg = inject('zg');
const initZegoEngine = inject('initZegoEngine');

</script>

<template>
  <div :class="controlClass">
    <!-- 任务控制区 -->
    <div class="task-section">
      <h3>任务控制</h3>
      <div class="task-buttons">
        <button
          class="task-btn create-btn"
          :disabled="!canCreateTask"
          @click="handleCreateTask"
        >
          <div class="loading-spinner" v-if="loading.createTask"></div>
          <svg v-else viewBox="0 0 24 24" fill="currentColor">
            <path
              d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm5 11h-4v4h-2v-4H7v-2h4V7h2v4h4v2z"
            />
          </svg>
          {{ loading.createTask ? "创建中..." : "创建任务" }}
        </button>

        <button
          class="task-btn stop-btn"
          :disabled="!canOperate"
          @click="handleStopTask"
        >
          <div class="loading-spinner" v-if="loading.stopTask"></div>
          <svg v-else viewBox="0 0 24 24" fill="currentColor">
            <path
              d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm4 14H8V8h8v8z"
            />
          </svg>
          {{ loading.stopTask ? "停止中..." : "停止任务" }}
        </button>

        <button
          class="task-btn interrupt-btn"
          :disabled="!canOperate"
          @click="handleInterrupt"
        >
          <div class="loading-spinner" v-if="loading.interrupt"></div>
          <svg v-else viewBox="0 0 24 24" fill="currentColor">
            <path
              d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8zM8.5 7L12 10.5 15.5 7 17 8.5 13.5 12 17 15.5 15.5 17 12 13.5 8.5 17 7 15.5 10.5 12 7 8.5 8.5 7z"
            />
          </svg>
          {{ loading.interrupt ? "打断中..." : "打断" }}
        </button>

        <button
          class="task-btn destroy-btn"
          :disabled="loading.stopTask"
          @click="handleDestroyAllTasks"
        >
          <div class="loading-spinner" v-if="loading.stopTask"></div>
          <svg v-else viewBox="0 0 24 24" fill="currentColor">
            <path d="M3 6h18M9 6v12a2 2 0 0 0 2 2h2a2 2 0 0 0 2-2V6"/>
          </svg>
          {{ loading.stopTask ? "销毁中..." : "销毁全部" }}
        </button>
      </div>
    </div>

    <!-- 驱动控制区 -->
    <div class="drive-section">
      <h3>驱动控制</h3>

      <!-- 驱动按钮 -->
      <div class="drive-buttons">
        <button
          class="drive-btn text-drive-btn"
          :disabled="!canOperate"
          @click="handleTextDrive"
        >
          <div class="loading-spinner" v-if="loading.textDrive"></div>
          <svg v-else viewBox="0 0 24 24" fill="currentColor">
            <path d="M3 17h18v2H3zm0-6h18v2H3zm0-6h18v2H3z" />
          </svg>
          {{ loading.textDrive ? "驱动中..." : "文本驱动" }}
        </button>

        <button
          class="drive-btn audio-drive-btn"
          :disabled="!canOperate"
          @click="handleAudioDrive"
        >
          <div class="loading-spinner" v-if="loading.audioDrive"></div>
          <svg v-else viewBox="0 0 24 24" fill="currentColor">
            <path
              d="M12 2c1.1 0 2 .9 2 2v6c0 1.1-.9 2-2 2s-2-.9-2-2V4c0-1.1.9-2 2-2zm6 6c0 2.76-2.24 5-5 5s-5-2.24-5-5H6c0 3.53 2.61 6.43 6 6.92V21h2v-2.08c3.39-.49 6-3.39 6-6.92h-2z"
            />
          </svg>
          {{ loading.audioDrive ? "驱动中..." : "音频驱动" }}
        </button>

        <button
          class="drive-btn ws-tts-drive-btn"
          :disabled="!canOperate"
          @click="handleWsTTSDrive"
        >
          <div class="loading-spinner" v-if="loading.wsTTSDrive"></div>
          <svg v-else viewBox="0 0 24 24" fill="currentColor">
            <path
              d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"
            />
          </svg>
          {{ loading.wsTTSDrive ? "驱动中..." : "WebSocket TTS驱动" }}
        </button>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* 桌面端样式 */
.control-desktop {
  display: flex;
  flex-direction: column;
  height: 100%;
  overflow-y: auto;
}

/* 移动端样式 */
.control-mobile {
  display: flex;
  flex-direction: column;
  padding: 15px;
  gap: 15px;
  min-height: 100%;
}

/* 通用样式 */
h3 {
  margin: 0 0 15px 0;
  color: white;
  font-size: 16px;
  font-weight: 600;
}

/* 任务控制区 */
.task-section {
  background: rgba(255, 255, 255, 0.1);
  backdrop-filter: blur(10px);
  border-radius: 12px;
  padding: 15px;
  border: 1px solid rgba(255, 255, 255, 0.2);
}

.task-buttons {
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
}

.task-btn {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px 15px;
  border: none;
  border-radius: 8px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s ease;
  flex: 1;
  min-width: 100px;
}

.create-btn {
  background: linear-gradient(135deg, #52c41a, #73d13d);
  color: white;
}

.create-btn:hover:not(:disabled) {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(82, 196, 26, 0.3);
}

.stop-btn {
  background: linear-gradient(135deg, #ff4d4f, #ff7875);
  color: white;
}

.stop-btn:hover:not(:disabled) {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(255, 77, 79, 0.3);
}

.interrupt-btn {
  background: linear-gradient(135deg, #faad14, #ffc53d);
  color: white;
}

.interrupt-btn:hover:not(:disabled) {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(250, 173, 20, 0.3);
}

.task-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
  transform: none;
  box-shadow: none;
}

.task-btn svg {
  width: 16px;
  height: 16px;
}

/* 驱动控制区 */
.drive-section {
  background: rgba(255, 255, 255, 0.1);
  backdrop-filter: blur(10px);
  border-radius: 12px;
  padding: 15px;
  border: 1px solid rgba(255, 255, 255, 0.2);
  flex: 1;
}

.drive-buttons {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.form-group {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.form-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 15px;
}

label {
  color: rgba(255, 255, 255, 0.9);
  font-size: 13px;
  font-weight: 500;
}

.text-input,
.url-input,
.select-input {
  padding: 10px 12px;
  border: 1px solid rgba(255, 255, 255, 0.3);
  border-radius: 6px;
  background: rgba(255, 255, 255, 0.1);
  color: white;
  font-size: 14px;
  resize: vertical;
  outline: none;
  transition: border-color 0.2s ease;
}

.text-input:focus,
.url-input:focus,
.select-input:focus {
  border-color: rgba(255, 255, 255, 0.6);
}

.text-input::placeholder,
.url-input::placeholder {
  color: rgba(255, 255, 255, 0.5);
}

.char-count {
  align-self: flex-end;
  font-size: 12px;
  color: rgba(255, 255, 255, 0.6);
}

.cache-info {
  align-self: flex-end;
  font-size: 11px;
  color: rgba(255, 255, 255, 0.4);
  margin-top: 4px;
}

.timbre-selector {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.form-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 8px;
}

.timbre-toggle {
  display: flex;
  align-items: center;
  gap: 8px;
}

.toggle-label-text {
  font-size: 11px;
  color: rgba(255, 255, 255, 0.8);
  font-weight: 500;
}

.toggle-label {
  display: flex;
  align-items: center;
  cursor: pointer;
  user-select: none;
}

.toggle-input {
  display: none;
}

.toggle-slider {
  position: relative;
  width: 32px;
  height: 16px;
  background: rgba(255, 255, 255, 0.3);
  border-radius: 8px;
  transition: all 0.3s ease;
}

.toggle-slider::before {
  content: '';
  position: absolute;
  top: 1px;
  left: 1px;
  width: 12px;
  height: 12px;
  background: white;
  border-radius: 50%;
  transition: all 0.3s ease;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.2);
}

.toggle-input:checked + .toggle-slider {
  background: #1890ff;
}

.toggle-input:checked + .toggle-slider::before {
  transform: translateX(16px);
}

.toggle-text {
  font-size: 10px;
  color: rgba(255, 255, 255, 0.9);
  font-weight: 600;
  z-index: 1;
  transition: all 0.3s ease;
  text-shadow: 0 1px 2px rgba(0, 0, 0, 0.3);
}

.range-input {
  -webkit-appearance: none;
  appearance: none;
  height: 4px;
  border-radius: 2px;
  background: rgba(255, 255, 255, 0.3);
  outline: none;
}

.range-input::-webkit-slider-thumb {
  -webkit-appearance: none;
  appearance: none;
  width: 16px;
  height: 16px;
  border-radius: 50%;
  background: white;
  cursor: pointer;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
}

.drive-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 12px 20px;
  border: none;
  border-radius: 8px;
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s ease;
  margin-top: 10px;
}

.text-drive-btn {
  background: linear-gradient(135deg, #1890ff, #40a9ff);
  color: white;
}

.audio-drive-btn {
  background: linear-gradient(135deg, #722ed1, #9254de);
  color: white;
}

.ws-tts-drive-btn {
  background: linear-gradient(135deg, #13c2c2, #36cfc9);
  color: white;
}

.drive-btn:hover:not(:disabled) {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.2);
}

.drive-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
  transform: none;
  box-shadow: none;
}

.drive-btn svg {
  width: 16px;
  height: 16px;
}

/* 加载动画 */
.loading-spinner {
  width: 16px;
  height: 16px;
  border: 2px solid rgba(255, 255, 255, 0.3);
  border-top: 2px solid white;
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  0% {
    transform: rotate(0deg);
  }
  100% {
    transform: rotate(360deg);
  }
}

/* 移动端适配 */
@media (max-width: 768px) {
  .form-row {
    grid-template-columns: 1fr;
  }

  .task-buttons {
    flex-direction: column;
  }

  .task-btn {
    flex: none;
  }

  /* 保持标签页水平布局，与PC端一致 */
  .tabs {
    flex-direction: row;
  }

  .tab-btn {
    font-size: 12px;
    padding: 6px 8px;
  }

  /* 移动端文本输入优化 */
  .text-input {
    min-height: 80px;
    font-size: 16px; /* 防止iOS自动缩放 */
  }

  .url-input {
    font-size: 16px; /* 防止iOS自动缩放 */
  }

  /* 移动端滑块优化 */
  .range-input {
    height: 6px;
  }

  .range-input::-webkit-slider-thumb {
    width: 20px;
    height: 20px;
  }

  /* 移动端驱动按钮优化 */
  .drive-btn {
    padding: 14px 20px;
    font-size: 16px;
    min-height: 48px; /* 确保足够的触摸目标 */
  }

  /* 移动端音色切换器优化 */
  .form-header {
    flex-direction: column;
    align-items: flex-start;
    gap: 6px;
  }

  .timbre-toggle {
    align-self: flex-end;
    gap: 6px;
  }

  .toggle-label-text {
    font-size: 12px;
    font-weight: 600;
  }

  .toggle-slider {
    width: 36px;
    height: 18px;
  }

  .toggle-slider::before {
    width: 14px;
    height: 14px;
    top: 2px;
    left: 2px;
  }

  .toggle-input:checked + .toggle-slider::before {
    transform: translateX(18px);
  }

  .toggle-text {
    font-size: 11px;
    font-weight: 600;
  }

  /* 移动端颜色对比度优化 */
  .control-mobile h3 {
    color: #2c3e50;
    text-shadow: 0 1px 2px rgba(255, 255, 255, 0.8);
  }

  .control-mobile label {
    color: #34495e;
    font-weight: 600;
    text-shadow: 0 1px 1px rgba(255, 255, 255, 0.6);
  }

  .control-mobile .text-input,
  .control-mobile .url-input,
  .control-mobile .select-input {
    background: rgba(255, 255, 255, 0.9);
    color: #2c3e50;
    border: 1px solid rgba(52, 73, 94, 0.3);
    box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.1);
  }

  .control-mobile .text-input::placeholder,
  .control-mobile .url-input::placeholder {
    color: rgba(52, 73, 94, 0.6);
  }

  .control-mobile .char-count {
    color: #7f8c8d;
  }

  .control-mobile .tab-btn {
    color: rgba(44, 62, 80, 0.8);
    font-weight: 600;
  }

  .control-mobile .tab-btn.active {
    background: rgba(52, 152, 219, 0.2);
    color: #2980b9;
  }
}
</style>

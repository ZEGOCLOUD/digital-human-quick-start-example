import { createStreamTask, driveByText, stopStreamTask, getDigitalHumanRenderInfo } from "./digitalHuman.js";

const globalState = globalThis;

const toNumber = (value, fallback) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
};

// 获取服务器配置信息
// Get server configuration
const getServerConfig = () => {
  const appId = toNumber(process.env.APP_ID, 0);
  const serverSecret = process.env.SERVER_SECRET || "";
  const tokenExpireSeconds = toNumber(process.env.TOKEN_EXPIRE_SECONDS, 3600);

  if (!appId) {
    throw new Error("APP_ID not configured");
  }
  if (!serverSecret) {
    throw new Error("SERVER_SECRET not configured");
  }

  return { appId, serverSecret, tokenExpireSeconds };
};

export const getBroadcastList = () => globalState.__DH_BROADCASTS__;

// 开始播报任务
// Start broadcast task
export const startBroadcast = async (options) => {
  // 初始化全局状态
  // Initialize global state
  if (!globalState.__DH_BROADCASTS__) {
    globalState.__DH_BROADCASTS__ = {};
  }

  const config = getServerConfig();

  const broadcastIndex = options?.broadcastIndex ?? 0;
  const digitalHumanId = options?.digitalHumanId;
  const timbreId = options?.timbreId;
  const roomId = options?.roomId;
  const streamId = options?.streamId;
  const outputMode = options?.outputMode ?? 1;  // 1=Web模式, 2=Mobile模式
  const textPool = options?.textPool && options.textPool.length > 0
    ? options.textPool
    : [];

  // 验证必需参数
  // Validate required parameters
  if (!digitalHumanId) {
    throw new Error("Digital human ID not configured, please pass via parameter");
  }
  if (!timbreId) {
    throw new Error("Timbre ID not configured, please pass via parameter");
  }
  if (!roomId) {
    throw new Error("Room ID not configured, please pass via parameter");
  }
  if (!streamId) {
    throw new Error("Stream ID not configured, please pass via parameter");
  }

  // 如果已存在该索引的播报任务，先停止旧任务
  // If a broadcast task with this index exists, stop the old task first
  if (globalState.__DH_BROADCASTS__ && globalState.__DH_BROADCASTS__[broadcastIndex]) {
    await stopBroadcast(broadcastIndex);
  }

  // 调用 ZEGO 数字人 API 创建新的播报任务
  // Call ZEGO Digital Human API to create a new broadcast task
  const taskId = await createStreamTask({
    appId: config.appId,
    serverSecret: config.serverSecret,
    digitalHumanId,
    roomId,
    streamId,
    outputMode,
  });

  // 获取数字人渲染信息（Android/iOS 端需要）
  // Get digital human render info (required by Android/iOS)
  const renderInfo = await getDigitalHumanRenderInfo({ digitalHumanId });

  // 单次驱动播报的异步函数
  // Async function to drive broadcast once
  const driveOnce = async () => {
    try {
      const text = textPool[Math.floor(Math.random() * textPool.length)];
      await driveByText({
        appId: config.appId,
        serverSecret: config.serverSecret,
        taskId,
        text,
        timbreId,
      });
    } catch (error) {
      console.log(`Broadcast drive failed (task may have stopped):`, error.message);
    }
  };

  // 启动定时器，每隔 8 秒调用一次 driveOnce
  // Start a timer to call driveOnce every 8 seconds
  // 注意！！！这仅仅是演示，实际请根据业务需求自行实现
  // NOTE!!! This is just a demo, implement according to your business requirements
  const timer = setInterval(
    () => driveOnce().catch(() => {}),
    8000
  );

  // 延迟后首次驱动，给 ZEGO API 时间处理新创建的任务
  // Delay initial drive to give ZEGO API time to process the newly created task
  setTimeout(() => driveOnce(), 500);

  // 更新全局状态（生产环境建议使用数据库）
  // Update global state (recommend using database in production)
  globalState.__DH_BROADCASTS__[broadcastIndex] = {
    taskId,
    roomId,
    streamId,
    digitalHumanId,
    clientInferencePackageUrl: renderInfo.clientInferencePackageUrl,
    isSupportSmallImageMode: renderInfo.isSupportSmallImageMode,
    timer,
  };
};

// 停止播报任务
// Stop broadcast task
export const stopBroadcast = async (broadcastIndex) => {
  const broadcastInfo = globalState.__DH_BROADCASTS__[broadcastIndex];
  if (!broadcastInfo) {
    console.log(`Broadcast task ${broadcastIndex} does not exist`);
    return;
  }

  // 立即清除定时器，防止后续调用
  // Immediately clear the timer to prevent future calls
  if (broadcastInfo.timer) {
    clearInterval(broadcastInfo.timer);
  }

  // 保存 taskId 后删除状态，防止重复调用
  // Save taskId then delete state to prevent duplicate calls
  const taskId = broadcastInfo.taskId;
  delete globalState.__DH_BROADCASTS__[broadcastIndex];

  // 调用 ZEGO 数字人 API 停止播报任务
  // Call ZEGO Digital Human API to stop the broadcast task
  try {
    await stopStreamTask({ taskId });
    console.log(`Stopped broadcast task ${taskId} successfully`);
  } catch (error) {
    console.log(`Error stopping broadcast task ${taskId} (may have already stopped):`, error.message);
  }
};

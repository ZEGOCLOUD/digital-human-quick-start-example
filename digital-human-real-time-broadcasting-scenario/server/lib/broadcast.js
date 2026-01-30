import { createStreamTask, driveByText, stopStreamTask, getDigitalHumanRenderInfo } from "./digitalHuman.js";

const globalState = globalThis;

const toNumber = (value, fallback) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
};

const getServerConfig = () => {
  const appId = toNumber(process.env.APP_ID, 0);
  const serverSecret = process.env.SERVER_SECRET || "";
  const tokenExpireSeconds = toNumber(process.env.TOKEN_EXPIRE_SECONDS, 3600);

  if (!appId) {
    throw new Error("APP_ID 未配置");
  }
  if (!serverSecret) {
    throw new Error("SERVER_SECRET 未配置");
  }

  return { appId, serverSecret, tokenExpireSeconds };
};

export const getBroadcastList = () => globalState.__DH_BROADCASTS__;

export const startBroadcast = async (options) => {
  // 初始化全局状态
  if (!globalState.__DH_BROADCASTS__) {
    globalState.__DH_BROADCASTS__ = {};
  }

  const config = getServerConfig();

  // 所有参数必须从 options 传入
  const broadcastIndex = options?.broadcastIndex ?? 0;
  const digitalHumanId = options?.digitalHumanId;
  const timbreId = options?.timbreId;
  const roomId = options?.roomId;
  const streamId = options?.streamId;
  const outputMode = options?.outputMode ?? 1;  // 1=Web模式, 2=Mobile模式
  const textPool = options?.textPool && options.textPool.length > 0
    ? options.textPool
    : [];

  if (!digitalHumanId) {
    throw new Error("数字人ID未配置，请通过参数传入");
  }
  if (!timbreId) {
    throw new Error("音色ID未配置，请通过参数传入");
  }
  if (!roomId) {
    throw new Error("房间ID未配置，请通过参数传入");
  }
  if (!streamId) {
    throw new Error("流ID未配置，请通过参数传入");
  }

  // globalState.__DH_BROADCASTS__ 是一个 Object，key 是 broadcastIndex，value 是 broadcastInfo
  // broadcastInfo 是一个 Object，包含 roomId, streamId, userId, timer
  // 如果 globalState.__DH_BROADCASTS__ 中已经存在 broadcastIndex，则先停止旧的播报任务
  if (globalState.__DH_BROADCASTS__ && globalState.__DH_BROADCASTS__[broadcastIndex]) {
    await stopBroadcast(broadcastIndex);
  }

  // 调用 ZEGO 数字人 API 创建新的播报任务
  const taskId = await createStreamTask({
    appId: config.appId,
    serverSecret: config.serverSecret,
    digitalHumanId,
    roomId,
    streamId,
    outputMode,
  });

  // 获取数字人渲染信息。Android和iOS需要使用渲染信息中的素材包下载地址。
  const renderInfo = await getDigitalHumanRenderInfo({ digitalHumanId });

  const driveOnce = async () => {
    try {
      const text = textPool[Math.floor(Math.random() * textPool.length)];

      // 调用 ZEGO 数字人 API 驱动数字人播报
      await driveByText({
        appId: config.appId,
        serverSecret: config.serverSecret,
        taskId,
        text,
        timbreId,
      });
    } catch (error) {
      // 如果驱动失败（例如任务已停止），静默处理
      console.log(`驱动播报失败（任务可能已停止）:`, error.message);
    }
  };

  // 启动定时器，每隔一段时间调用一次 driveOnce 函数
  // 注意！！！这仅仅是演示，实际怎么驱动数字人，请根据业务需求自行实现
  const timer = setInterval(
    () => driveOnce().catch(() => {}),
    8000 // 8秒播报一次
  );

  // 延迟后首次驱动，给 ZEGO API 一些时间处理新创建的任务
  setTimeout(() => driveOnce(), 500);

  // 更新全局状态。真实业务建议存数据库
  globalState.__DH_BROADCASTS__[broadcastIndex] = {
    taskId,
    roomId,
    streamId,
    digitalHumanId,  // Android和iOS端需要用于生成base64config
    clientInferencePackageUrl: renderInfo.clientInferencePackageUrl,  // Android和iOS端需要用于生成base64config
    isSupportSmallImageMode: renderInfo.isSupportSmallImageMode,  // Android和iOS端需要用于生成base64config
    timer,
  };
};

export const stopBroadcast = async (broadcastIndex) => {
  const broadcastInfo = globalState.__DH_BROADCASTS__[broadcastIndex];
  if (!broadcastInfo) {
    console.log(`播报任务 ${broadcastIndex} 不存在`);
    return;
  }

  // 立即清除定时器，防止后续调用
  if (broadcastInfo.timer) {
    clearInterval(broadcastInfo.timer);
  }

  // 保存 taskId 后删除状态，防止重复调用
  const taskId = broadcastInfo.taskId;
  delete globalState.__DH_BROADCASTS__[broadcastIndex];

  // 调用 ZEGO 数字人 API 停止播报任务
  try {
    await stopStreamTask({ taskId });
    console.log(`停止播报任务 ${taskId} 成功`);
  } catch (error) {
    // 忽略停止任务的错误（可能已经停止）
    console.log(`停止播报任务 ${taskId} 时出错（可能已停止）:`, error.message);
  }
};

import crypto from "crypto";

// 构建通用 API 请求参数（包含签名）
// Build common API request parameters (including signature)
const buildCommonParams = (action) => {
  const appId = process.env.APP_ID;
  const serverSecret = process.env.SERVER_SECRET || "";
  const signatureNonce = crypto.randomBytes(8).toString("hex");
  const timestamp = Math.floor(Date.now() / 1000);
  // 计算 MD5 签名
  // Calculate MD5 signature
  const signature = crypto
    .createHash("md5")
    .update(`${appId}${signatureNonce}${serverSecret}${timestamp}`)
    .digest("hex");

  return new URLSearchParams({
    Action: action,
    AppId: appId.toString(),
    SignatureNonce: signatureNonce,
    Timestamp: timestamp.toString(),
    Signature: signature,
    SignatureVersion: "2.0",
  });
};

// 发送 POST 请求到 ZEGO 数字人 API
// Send POST request to ZEGO Digital Human API
const post = async (action, body) => {
  const params = buildCommonParams(action);
  const url = `https://aigc-digitalhuman-api.zegotech.cn/?${params.toString()}`;
  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const data = await response.json();
  if (data.Code !== 0) {
    throw new Error(`Digital Human API failed: ${data.Code} ${data.Message}`);
  }
  return data.Data;
};

// 创建数字人视频流任务
// Create digital human video stream task
export const createStreamTask = async (params) => {
  const data = await post(
    "CreateDigitalHumanStreamTask",
    {
      DigitalHumanConfig: { DigitalHumanId: params.digitalHumanId },
      RTCConfig: { RoomId: params.roomId, StreamId: params.streamId },
    }
  );
  return data.TaskId;
};

// 通过文本驱动数字人播报
// Drive digital human broadcast by text
export const driveByText = async (params) => {
  await post(
    "DriveByText",
    {
      TaskId: params.taskId,
      Text: params.text,
      InterruptMode: 1,
      TTSConfig: {
        TimbreId: params.timbreId,
        SpeechRate: 0,
        PitchRate: 0,
        Volume: 50,
      },
    }
  );
};

// 停止数字人视频流任务
// Stop digital human video stream task
export const stopStreamTask = async (params) => {
  await post(
    "StopDigitalHumanStreamTask",
    { TaskId: params.taskId }
  );
};

// 获取音色列表
// Get timbre list
export const getTimbreList = async (params) => {
  const body = {};
  if (params.digitalHumanId) {
    body.DigitalHumanId = params.digitalHumanId;
  }
  if (params.offset !== undefined) {
    body.Offset = params.offset;
  }
  if (params.limit !== undefined) {
    body.Limit = params.limit;
  }
  const data = await post("GetTimbreList", body);
  return data;
};

// 获取数字人列表
// Get digital human list
export const getDigitalHumanList = async (params) => {
  const body = {};
  if (params.inferenceMode !== undefined) {
    body.InferenceMode = params.inferenceMode;
  }
  if (params.fetchMode !== undefined) {
    body.FetchMode = params.fetchMode;
  }
  if (params.offset !== undefined) {
    body.Offset = params.offset;
  }
  if (params.limit !== undefined) {
    body.Limit = params.limit;
  }

  const data = await post("GetDigitalHumanList", body);
  return data;
};

// 查询正在运行的数字人视频流任务
// Query running digital human video stream tasks
export const queryStreamTasks = async () => {
  const data = await post("QueryDigitalHumanStreamTasks", {});
  return data.TaskList || [];
};

// 清理所有正在运行的数字人任务
// Clear all running digital human tasks
export const clearAllTasks = async () => {
  try {
    const taskList = await queryStreamTasks();

    if (taskList.length === 0) {
      console.log("[clearAllTasks] No tasks to clean up");
      return;
    }

    console.log(`[clearAllTasks] Found ${taskList.length} running tasks, starting cleanup...`);

    for (const task of taskList) {
      try {
        await stopStreamTask({ taskId: task.TaskId });
        console.log(`[clearAllTasks] Stopped task - TaskId: ${task.TaskId}, RoomId: ${task.RoomId}, StreamId: ${task.StreamId}, Status: ${task.Status}`);
      } catch (error) {
        console.log(`[clearAllTasks] Failed to stop task - TaskId: ${task.TaskId}, Error: ${error.message}`);
      }
    }

    console.log("[clearAllTasks] Cleanup completed");
  } catch (error) {
    console.error("[clearAllTasks] Failed to query tasks:", error.message);
  }
};

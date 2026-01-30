import crypto from "crypto";


const buildCommonParams = (action) => {
  const appId = process.env.APP_ID;
  const serverSecret = process.env.SERVER_SECRET || "";
  const signatureNonce = crypto.randomBytes(8).toString("hex");
  const timestamp = Math.floor(Date.now() / 1000);
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

const post = async (
  action,
  body
) => {

  const params = buildCommonParams(action);
  const url = `https://aigc-digitalhuman-api.zegotech.cn/?${params.toString()}`;
  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const data = await response.json();
  if (data.Code !== 0) {
    throw new Error(`数字人 API 失败: ${data.Code} ${data.Message}`);
  }
  return data.Data;
};

export const createStreamTask = async (params) => {
  const data = await post(
    "CreateDigitalHumanStreamTask",
    {
      DigitalHumanConfig: { DigitalHumanId: params.digitalHumanId },
      RTCConfig: { RoomId: params.roomId, StreamId: params.streamId },
      ExtraConfig: { OutputMode: params.outputMode ?? 1 },
    }
  );
  return data.TaskId;
};

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

export const stopStreamTask = async (params) => {
  await post(
    "StopDigitalHumanStreamTask",
    { TaskId: params.taskId }
  );
};

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
  const data = await post(
    "GetTimbreList",
    body
  );
  return data;
};

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

  const data = await post(
    "GetDigitalHumanList",
    body
  );
  return data;
};


// TODO：新版本SDK不需要这个，临时保留。获取数字人渲染信息。Android和iOS需要使用渲染信息中的素材包下载地址启动数字人SDK。
export const getDigitalHumanRenderInfo = async (params) => {
  const data = await post(
    "GetDigitalHumanRenderInfo",
    { DigitalHumanId: params.digitalHumanId }
  );
  return {
    clientInferencePackageUrl: data.ClientInferencePackageUrl,
    isSupportSmallImageMode: data.IsSupportSmallImageMode,
  };
};


// 查询正在运行的数字人视频流任务
export const queryStreamTasks = async () => {
  const data = await post(
    "QueryDigitalHumanStreamTasks",
    {}
  );
  return data.TaskList || [];
};

// 清理所有正在运行的数字人任务
export const clearAllTasks = async () => {
  try {
    const taskList = await queryStreamTasks();

    if (taskList.length === 0) {
      console.log("[clearAllTasks] 没有需要清理的任务");
      return;
    }

    console.log(`[clearAllTasks] 发现 ${taskList.length} 个正在运行的任务，开始清理...`);

    for (const task of taskList) {
      try {
        await stopStreamTask({ taskId: task.TaskId });
        console.log(`[clearAllTasks] 已停止任务 - TaskId: ${task.TaskId}, RoomId: ${task.RoomId}, StreamId: ${task.StreamId}, Status: ${task.Status}`);
      } catch (error) {
        console.log(`[clearAllTasks] 停止任务失败 - TaskId: ${task.TaskId}, 错误: ${error.message}`);
      }
    }

    console.log("[clearAllTasks] 清理完成");
  } catch (error) {
    console.error("[clearAllTasks] 查询任务失败:", error.message);
  }
};

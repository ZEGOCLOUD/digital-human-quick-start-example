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
  const data = await post("CreateDigitalHumanStreamTask", {
    DigitalHumanConfig: { DigitalHumanId: params.digitalHumanId },
    RTCConfig: { RoomId: params.roomId, StreamId: params.streamId },
  });
  return data.TaskId;
};

// 停止数字人视频流任务
// Stop digital human video stream task
export const stopStreamTask = async (params) => {
  await post("StopDigitalHumanStreamTask", { TaskId: params.taskId });
};

// 获取 WebSocket 驱动信息
// Get WebSocket drive info
export const getDriveByWsStreamInfo = async (params) => {
  const data = await post("DriveByWsStream", { TaskId: params.taskId });
  return {
    driveId: data.DriveId,
    wssAddress: data.WssAddress,
  };
};

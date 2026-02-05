import WebSocket from "ws";
import { getDriveByWsStreamInfo } from "./digitalHuman.js";
import fs from "fs";
import path from "path";

// 通过 WebSocket 驱动数字人播报
// Drive digital human broadcast via WebSocket
export const callTTSAndDriveDigitalHumanByWebSocket = async (taskId, lang = "zh") => {
  try {
    // 步骤 1: 获取 WebSocket 驱动信息
    // Step 1: Get WebSocket drive info
    console.log("[WebSocket Drive] Getting WebSocket drive info...");
    const { driveId, wssAddress } = await getDriveByWsStreamInfo({ taskId });
    console.log(`[WebSocket Drive] DriveId: ${driveId}, WssAddress: ${wssAddress}`);

    // 步骤 2: 建立 WebSocket 连接（跳过证书验证）
    // Step 2: Establish WebSocket connection (skip certificate verification)
    console.log("[WebSocket Drive] Connecting to WebSocket...");
    const ws = new WebSocket(wssAddress, {
      rejectUnauthorized: false, // 跳过证书验证
    });

    // 等待连接建立
    // Wait for connection to be established
    await new Promise((resolve, reject) => {
      ws.on("open", resolve);
      ws.on("error", reject);
    });
    console.log("[WebSocket Drive] WebSocket connected");

    // 步骤 3: 发送 Start 指令。通常在 TTS 开启前启动。
    // Step 3: Send Start command
    console.log("[WebSocket Drive] Sending Start command...");
    const startCommand = JSON.stringify({
      Action: "Start",
      Payload: {
        DriveId: driveId,
        SampleRate: 24000, // 24kHz 采样率 / 24kHz sample rate
      },
    });
    ws.send(startCommand);



    // 步骤 4: 调用 TTS 接口，流式接收 PCM 音频数据，并直接转发给数字人WebSocket
    // Step 4: Call TTS API , receive PCM audio data from TTS WebSocket, and directly forward to digital human WebSocket
    console.log(`[WebSocket Drive] Receiving PCM audio data from TTS WebSocket and forwarding to digital human WebSocket ...`);
    // 正常来说，这里调用 TTS 接口，并等待 TTS 服务返回音频数据。
    // 本示例简化处理: 直接读取预定义的 PCM 文件模拟最终的 TTS结果
    // 正常业务逻辑示例：TTS服务接收音频（TTS WebSocket回调）
    // ttsWs.onMessage = (msg) => {
    //   if (msg.type === 'MsgTypeAudioOnlyServer') {
    //       const pcmDataFrame = msg.payload;  // 原始PCM音频数据

    //       // 2. 直接转发给数字人WebSocket
    //       digitalHumanWs.send(pcmDataFrame);
    //   }
    // };

    // 用 for 循环模拟 TTS 持续的数据回调过程
    const chunkSize = 4096; // 模拟 TTS 回调每次收到 4KB PCM 音频数据
    const pcmData = readPCMAudioFile(lang);
    for (let i = 0; i < pcmData.length; i += chunkSize) {
      const chunk = pcmData.subarray(i, i + chunkSize);
      ws.send(chunk);
    }
    console.log("[WebSocket Drive] PCM audio data sent");

    // 步骤 5: 发送 Stop 指令。通常在 TTS 结束后发送。
    // Step 5: Send Stop command
    console.log("[WebSocket Drive] Sending Stop command...");
    const stopCommand = JSON.stringify({
      Action: "Stop",
      Payload: {
        DriveId: driveId,
      },
    });
    ws.send(stopCommand);

    // 步骤 6: 断开连接
    // Step 6: Close connection
    ws.close();
    console.log("[WebSocket Drive] WebSocket closed");
  } catch (error) {
    console.error("[WebSocket Drive] Error:", error.message);
    throw error;
  }
};

// 读取 PCM 音频文件
// Read PCM audio file
export const readPCMAudioFile = (lang = "zh") => {
  // 根据语言参数选择对应的音频文件
  // Select audio file based on language parameter
  const fileName = lang === "en" ? "sample_en.wav" : "sample.wav";
  const pcmFilePath = path.join(process.cwd(), "audio", fileName);

  // 如果文件不存在，返回空数据（占位）
  // If file doesn't exist, return empty data (placeholder)
  if (!fs.existsSync(pcmFilePath)) {
    console.warn(`[WebSocket Drive] PCM file not found: ${fileName}, using empty data`);
    // 返回 1 秒的静音数据作为占位符
    // Return 1 second of silence as placeholder
    // 24kHz * 1s * 2 bytes (16-bit) = 48000 bytes
    return Buffer.alloc(48000);
  }

  return fs.readFileSync(pcmFilePath);
};

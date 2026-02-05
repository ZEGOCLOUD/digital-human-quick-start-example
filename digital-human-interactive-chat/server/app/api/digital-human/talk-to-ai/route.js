import { NextResponse } from "next/server";
import {
  callTTSAndDriveDigitalHumanByWebSocket,
  readPCMAudioFile,
} from "../../../../lib/websocket.js";

export const runtime = "nodejs";

// CORS 头配置
// Configure CORS headers
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

// 处理 OPTIONS 预检请求
// Handle OPTIONS preflight request
export const OPTIONS = async () => {
  return new NextResponse(null, {
    status: 200,
    headers: corsHeaders,
  });
};

// POST /api/digital-human/talk-to-ai - 模拟 AI 交互
// Simulate AI interaction
export const POST = async (request) => {
  try {
    const body = await request.json();
    const { taskId, lang = "zh" } = body;

    console.log("[POST /api/digital-human/talk-to-ai] Starting AI interaction:", {
      taskId,
      lang,
    });

    // 验证必需参数
    // Validate required parameters
    if (!taskId) {
      return NextResponse.json(
        {
          success: false,
          error: "Missing required parameter: taskId",
        },
        { status: 400, headers: corsHeaders }
      );
    }

    // 说明: 实际业务中的 AI 交互流程 / Note: Actual AI interaction flow in production
    // 1. 接收客户端音频数据 / Receive client audio data
    // 2. ASR (语音识别) → 转为文本 / ASR (Speech Recognition) → Convert to text
    // 3. LLM (大语言模型) → 生成回复文本 / LLM (Large Language Model) → Generate reply text
    // 4. TTS (语音合成) → 生成 PCM 音频流 / TTS (Text-to-Speech) → Generate PCM audio stream
    // 注意⚠️：如果您还没有处理以上流程，我们强烈建议您使用 [ZEGO 实时互动 AI Agent](https://doc-zh.zego.im/aiagent-server/introduction/overview) 产品，它已经帮您实现了以上流程。 / Note: If you haven't processed the above process, we strongly recommend using the [ZEGO Conversational AI](https://www.zegocloud.com/docs/aiagent-server/introduction/overview) product, which has already implemented the above process for you.

    // 第 4 步: 调用 TTS 接口，合成语音后，通过 WebSocket 驱动数字人。
    // Step 4: Call TTS API, synthesize speech, and drive digital human via WebSocket
    // After using TTS to synthesize speech, drive digital human via WebSocket
    console.log("[POST /api/digital-human/talk-to-ai] Calling TTS API, synthesizing speech, and driving digital human via WebSocket...");
    await callTTSAndDriveDigitalHumanByWebSocket(taskId, lang);

    return NextResponse.json(
      {
        success: true,
        message: "AI interaction completed",
      },
      { headers: corsHeaders }
    );
  } catch (error) {
    console.error("[POST /api/digital-human/talk-to-ai] Error:", error);
    return NextResponse.json(
      {
        success: false,
        error: error.message,
      },
      { status: 500, headers: corsHeaders }
    );
  }
};

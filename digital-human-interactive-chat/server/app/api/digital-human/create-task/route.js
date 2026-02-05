import { NextResponse } from "next/server";
import {
  createStreamTask,
  getDigitalHumanRenderInfo,
} from "../../../../lib/digitalHuman.js";

export const runtime = "nodejs";

// CORS 头配置（测试环境，不做跨域限制）
// Configure CORS headers for testing (no cross-origin restrictions)
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

// POST /api/digital-human/create-task - 创建数字人视频流任务
// Create digital human video stream task
export const POST = async (request) => {
  try {
    const body = await request.json();
    const { digitalHumanId: clientDigitalHumanId, roomId, streamId, outputMode } = body;

    // 优先使用客户端传递的 digitalHumanId，否则使用服务端环境变量
    // Use client-provided digitalHumanId first, otherwise use server env variable
    const digitalHumanId = clientDigitalHumanId || process.env.DIGITAL_HUMAN_ID;

    console.log("[POST /api/digital-human/create-task] Creating digital human task:", {
      digitalHumanId,
      roomId,
      streamId,
      outputMode,
    });

    // 验证必需参数
    // Validate required parameters
    if (!digitalHumanId || !roomId || !streamId) {
      return NextResponse.json(
        {
          success: false,
          error: "Missing required parameters. Please configure DIGITAL_HUMAN_ID in server .env or provide digitalHumanId in request body. Required: roomId, streamId",
        },
        { status: 400, headers: corsHeaders }
      );
    }

    // 调用 ZEGO 数字人 API 创建任务
    // Call ZEGO Digital Human API to create task
    const taskId = await createStreamTask({
      digitalHumanId,
      roomId,
      streamId,
      outputMode: outputMode ?? 2, // 默认 Mobile 模式 / Default to Mobile mode
    });

    // 获取渲染信息（Android/iOS 端需要）
    // Get render info (required by Android/iOS)
    const renderInfo = await getDigitalHumanRenderInfo({ digitalHumanId });

    console.log("[POST /api/digital-human/create-task] Task created successfully:", {
      taskId,
      renderInfo,
    });

    return NextResponse.json(
      {
        success: true,
        taskId,
        roomId,
        streamId,
        digitalHumanId,
        clientInferencePackageUrl: renderInfo.clientInferencePackageUrl,
        isSupportSmallImageMode: renderInfo.isSupportSmallImageMode,
      },
      { headers: corsHeaders }
    );
  } catch (error) {
    console.error("[POST /api/digital-human/create-task] Error:", error);
    return NextResponse.json(
      {
        success: false,
        error: error.message,
      },
      { status: 500, headers: corsHeaders }
    );
  }
};

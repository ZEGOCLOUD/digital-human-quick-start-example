import { NextResponse } from "next/server";
import { stopStreamTask } from "../../../../lib/digitalHuman.js";

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

// POST /api/digital-human/stop-task - 停止数字人视频流任务
// Stop digital human video stream task
export const POST = async (request) => {
  try {
    const body = await request.json();
    const { taskId } = body;

    console.log("[POST /api/digital-human/stop-task] Stopping digital human task:", {
      taskId,
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

    // 调用 ZEGO 数字人 API 停止任务
    // Call ZEGO Digital Human API to stop task
    await stopStreamTask({ taskId });

    console.log("[POST /api/digital-human/stop-task] Task stopped successfully");

    return NextResponse.json(
      {
        success: true,
        message: "Digital human task stopped",
      },
      { headers: corsHeaders }
    );
  } catch (error) {
    console.error("[POST /api/digital-human/stop-task] Error:", error);
    return NextResponse.json(
      {
        success: false,
        error: error.message,
      },
      { status: 500, headers: corsHeaders }
    );
  }
};

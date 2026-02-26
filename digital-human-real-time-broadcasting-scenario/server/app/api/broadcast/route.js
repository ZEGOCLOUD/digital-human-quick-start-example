import { NextResponse } from "next/server";
import { getBroadcastList, startBroadcast, stopBroadcast } from "../../../lib/broadcast.js";

export const runtime = "nodejs";

// CORS 头配置（测试环境，不做跨域限制）
// Configure CORS headers for testing (no cross-origin restrictions)
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, DELETE, OPTIONS",
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

// GET /api/broadcast - 获取当前播报任务列表
// Get current broadcast task list
export const GET = async () => {
  const broadcastList = getBroadcastList() || {};

  // 过滤掉不可序列化的 timer 对象
  // Filter out non-serializable timer objects
  const sanitizedList = {};
  for (const [index, info] of Object.entries(broadcastList)) {
    sanitizedList[index] = {
      taskId: info.taskId,
      roomId: info.roomId,
      streamId: info.streamId,
      // timer 不可序列化，不返回
      // timer is not serializable, exclude from response
    };
  }

  return NextResponse.json({
    broadcastList: sanitizedList,
  }, {
    headers: corsHeaders,
  });
};

// POST /api/broadcast - 开始新的播报任务
// Start a new broadcast task
export const POST = async (request) => {
  try {
    const body = await request.json();
    console.log("[POST /api/broadcast] Starting broadcast with params:", {
      broadcastIndex: body.broadcastIndex,
      digitalHumanId: body.digitalHumanId,
      timbreId: body.timbreId,
      roomId: body.roomId,
      streamId: body.streamId,
      textPoolLength: body.textPool?.length,
    });
    await startBroadcast(body);
    return NextResponse.json({
      success: true,
      message: "Broadcast task started"
    }, {
      headers: corsHeaders,
    });
  } catch (error) {
    console.error("[POST /api/broadcast] Error:", error);
    return NextResponse.json({
      success: false,
      error: error.message
    }, {
      status: 400,
      headers: corsHeaders,
    });
  }
};

// DELETE /api/broadcast/:index - 停止指定的播报任务
// Stop the specified broadcast task
export const DELETE = async (request) => {
  try {
    const { searchParams } = new URL(request.url);
    const index = searchParams.get("index");

    if (index === null) {
      return NextResponse.json({
        success: false,
        error: "Missing index parameter"
      }, {
        status: 400,
        headers: corsHeaders,
      });
    }

    await stopBroadcast(Number(index));
    return NextResponse.json({
      success: true,
      message: `Broadcast task ${index} stopped`
    }, {
      headers: corsHeaders,
    });
  } catch (error) {
    return NextResponse.json({
      success: false,
      error: error.message
    }, {
      status: 400,
      headers: corsHeaders,
    });
  }
};

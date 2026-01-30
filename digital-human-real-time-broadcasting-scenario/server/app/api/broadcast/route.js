import { NextResponse } from "next/server";
import { getBroadcastList, startBroadcast, stopBroadcast } from "../../../lib/broadcast.js";

export const runtime = "nodejs";

// 测试，不做跨域限制
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

// 处理 OPTIONS 预检请求
export const OPTIONS = async () => {
  return new NextResponse(null, {
    status: 200,
    headers: corsHeaders,
  });
};

// GET /api/broadcast - 获取播报列表
export const GET = async () => {
  const broadcastList = getBroadcastList() || {};

  // 过滤掉不可序列化的 timer 对象
  const sanitizedList = {};
  for (const [index, info] of Object.entries(broadcastList)) {
    sanitizedList[index] = {
      taskId: info.taskId,
      roomId: info.roomId,
      streamId: info.streamId,
      digitalHumanId: info.digitalHumanId,
      clientInferencePackageUrl: info.clientInferencePackageUrl,
      isSupportSmallImageMode: info.isSupportSmallImageMode,
      // timer 不可序列化，不返回
    };
  }

  return NextResponse.json({
    broadcastList: sanitizedList,
  }, {
    headers: corsHeaders,
  });
};

// POST /api/broadcast - 开始播报
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
      message: "播报任务已启动"
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

// DELETE /api/broadcast/:index - 停止指定播报
export const DELETE = async (request) => {
  try {
    const { searchParams } = new URL(request.url);
    const index = searchParams.get("index");

    if (index === null) {
      return NextResponse.json({
        success: false,
        error: "缺少 index 参数"
      }, {
        status: 400,
        headers: corsHeaders,
      });
    }

    await stopBroadcast(Number(index));
    return NextResponse.json({
      success: true,
      message: `播报任务 ${index} 已停止`
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

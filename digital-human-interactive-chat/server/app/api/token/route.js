import { NextResponse } from "next/server";
import { generateToken } from "../../../lib/token.js";

export const runtime = "nodejs";

// CORS 头配置
// Configure CORS headers
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
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

// GET /api/token - 生成 ZEGO RTC Token
// Generate ZEGO RTC Token
export const GET = async (request) => {
  try {
    const { searchParams } = new URL(request.url);
    const userId = searchParams.get("userId");

    console.log("[GET /api/token] Generating token for userId:", userId);

    // 验证必需参数
    // Validate required parameters
    if (!userId) {
      return NextResponse.json(
        {
          success: false,
          error: "Missing required parameter: userId",
        },
        { status: 400, headers: corsHeaders }
      );
    }

    // 从环境变量读取配置
    // Read configuration from environment variables
    const appId = Number(process.env.APP_ID);
    const serverSecret = process.env.SERVER_SECRET;

    if (!appId || !serverSecret) {
      return NextResponse.json(
        {
          success: false,
          error: "Server configuration error: APP_ID or SERVER_SECRET not configured",
        },
        { status: 500, headers: corsHeaders }
      );
    }

    // 生成 Token（有效期 3600 秒）/ Generate token (3600 seconds validity)
    const token = generateToken(appId, userId, serverSecret, 3600, "");

    console.log("[GET /api/token] Token generated successfully");

    return NextResponse.json(
      {
        success: true,
        token,
      },
      { headers: corsHeaders }
    );
  } catch (error) {
    console.error("[GET /api/token] Error:", error);
    return NextResponse.json(
      {
        success: false,
        error: error.message,
      },
      { status: 500, headers: corsHeaders }
    );
  }
};

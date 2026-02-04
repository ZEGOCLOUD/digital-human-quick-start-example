import { generateToken04 } from "../../../lib/token.js";
import { NextResponse } from "next/server";

// 指定运行时环境为 Node.js
// Specify the runtime environment as Node.js
export const runtime = "nodejs";

// CORS 头配置，允许跨域访问
// Configure CORS headers to allow cross-origin access
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

// GET 请求处理器：生成并返回 ZEGO Token
// Generate and return ZEGO Token
export const GET = async (request) => {
  const appId = Number(process.env.APP_ID, 0);
  const serverSecret = process.env.SERVER_SECRET;
  const { searchParams } = new URL(request.url);
  const userId = searchParams.get("userId");
  // 生成有效期 3600 秒的 Token
  // Generate a token with 3600 seconds validity
  const token = generateToken04(appId, userId, serverSecret, 3600, "");
  return NextResponse.json({ token }, {
    headers: corsHeaders,
  });
};

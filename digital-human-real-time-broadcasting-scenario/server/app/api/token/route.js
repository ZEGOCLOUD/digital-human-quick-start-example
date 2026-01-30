import { generateToken04 } from "../../../lib/token.js";
import { NextResponse } from "next/server";

export const runtime = "nodejs";

// 添加 CORS 头
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

// 处理 OPTIONS 预检请求
export const OPTIONS = async () => {
  return new NextResponse(null, {
    status: 200,
    headers: corsHeaders,
  });
};

export const GET = async (request) => {
  const appId = Number(process.env.APP_ID, 0);
  const serverSecret = process.env.SERVER_SECRET;
  const { searchParams } = new URL(request.url);
  const userId = searchParams.get("userId");
  const token = generateToken04(appId, userId, serverSecret, 3600, "");
  return NextResponse.json({ token }, {
    headers: corsHeaders,
  });
};

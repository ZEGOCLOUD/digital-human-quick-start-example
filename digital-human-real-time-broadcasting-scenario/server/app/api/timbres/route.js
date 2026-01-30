import { NextRequest, NextResponse } from "next/server";
import { getTimbreList } from "../../../lib/digitalHuman.js";

const toNumber = (value, fallback) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
};

export const runtime = "nodejs";

export const GET = async (request) => {
  try {
    const appId = toNumber(process.env.APP_ID, 0);
    const serverSecret = process.env.SERVER_SECRET || "";

    const searchParams = request.nextUrl.searchParams;
    const digitalHumanId = searchParams.get("digitalHumanId") || undefined;
    const offset = searchParams.get("offset")
      ? parseInt(searchParams.get("offset"), 10)
      : 0;
    const limit = searchParams.get("limit")
      ? parseInt(searchParams.get("limit"), 10)
      : 20;

    if (!appId || !serverSecret) {
      return NextResponse.json(
        { error: "APP_ID 或 SERVER_SECRET 未配置" },
        { status: 500 }
      );
    }

    const result = await getTimbreList({
      appId,
      serverSecret,
      digitalHumanId,
      offset,
      limit,
    });

    console.log("音色列表API返回:", {
      digitalHumanId: digitalHumanId || "(空，查询公共音色)",
      total: result?.Total,
      timbresCount: result?.Timbres?.length || 0,
    });

    return NextResponse.json(result);
  } catch (error) {
    console.error("获取音色列表失败:", error);
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "未知错误" },
      { status: 500 }
    );
  }
};

import { NextResponse } from "next/server";
import { getTimbreList } from "../../../lib/digitalHuman.js";

const toNumber = (value, fallback) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
};

export const runtime = "nodejs";

// GET 请求处理器：获取音色列表
// Get timbre list
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
        { error: "APP_ID or SERVER_SECRET not configured" },
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

    console.log("Timbre list API response:", {
      digitalHumanId: digitalHumanId || "(empty, querying public timbres)",
      total: result?.Total,
      timbresCount: result?.Timbres?.length || 0,
    });

    return NextResponse.json(result);
  } catch (error) {
    console.error("Failed to get timbre list:", error);
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Unknown error" },
      { status: 500 }
    );
  }
};

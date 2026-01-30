import { NextResponse } from "next/server";
import { getDigitalHumanList } from "../../../lib/digitalHuman.js";

export const runtime = "nodejs";

export const GET = async (request) => {
  try {
    const searchParams = request.nextUrl.searchParams;
    const inferenceMode = searchParams.get("inferenceMode")
      ? parseInt(searchParams.get("inferenceMode"), 10)
      : undefined;
    const fetchMode = searchParams.get("fetchMode")
      ? parseInt(searchParams.get("fetchMode"), 10)
      : undefined;
    const offset = searchParams.get("offset")
      ? parseInt(searchParams.get("offset"), 10)
      : 0;
    const limit = searchParams.get("limit")
      ? parseInt(searchParams.get("limit"), 10)
      : 20;

    const result = await getDigitalHumanList({
      inferenceMode,
      fetchMode,
      offset,
      limit,
    });

    return NextResponse.json(result);
  } catch (error) {
    console.error("获取数字人列表失败:", error);
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "未知错误" },
      { status: 500 }
    );
  }
};

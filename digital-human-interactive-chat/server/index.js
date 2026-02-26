import http from "http";
import url from "url";
import {
  createStreamTask,
  stopStreamTask,
} from "./lib/digitalHuman.js";
import { generateToken } from "./lib/token.js";
import { callTTSAndDriveDigitalHumanByWebSocket } from "./lib/websocket.js";

// 加载 .env 文件（Node.js 20.6+ 内置支持 --env-file，低版本需手动解析）
// Load .env file (Node.js 20.6+ has built-in --env-file support)
import { readFileSync, existsSync } from "fs";

const loadEnv = () => {
  const envPath = new URL(".env", import.meta.url).pathname;
  if (!existsSync(envPath)) return;
  const content = readFileSync(envPath, "utf-8");
  for (const line of content.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const idx = trimmed.indexOf("=");
    if (idx === -1) continue;
    const key = trimmed.slice(0, idx).trim();
    const value = trimmed.slice(idx + 1).trim();
    if (!process.env[key]) process.env[key] = value;
  }
};
loadEnv();

const PORT = process.env.PORT || 3000;

// CORS 头配置（测试环境，不做跨域限制）
// Configure CORS headers for testing (no cross-origin restrictions)
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

// 发送 JSON 响应
// Send JSON response
const sendJSON = (res, data, status = 200) => {
  res.writeHead(status, { ...corsHeaders, "Content-Type": "application/json" });
  res.end(JSON.stringify(data));
};

// 解析 JSON 请求体
// Parse JSON request body
const parseBody = (req) =>
  new Promise((resolve, reject) => {
    const chunks = [];
    req.on("data", (chunk) => chunks.push(chunk));
    req.on("end", () => {
      try {
        resolve(chunks.length ? JSON.parse(Buffer.concat(chunks).toString()) : {});
      } catch (e) {
        reject(new Error("Invalid JSON body"));
      }
    });
    req.on("error", reject);
  });

// ============ 路由处理 / Route Handlers ============

// POST /api/digital-human/create-task - 创建数字人视频流任务
// Create digital human video stream task
const handleCreateTask = async (req, res) => {
  try {
    const body = await parseBody(req);
    const { roomId, streamId } = body;

    // digitalHumanId 由服务端环境变量配置
    // digitalHumanId is configured in server environment variable
    const digitalHumanId = process.env.DIGITAL_HUMAN_ID;

    console.log("[POST /api/digital-human/create-task] Creating digital human task:", { roomId, streamId, digitalHumanId });

    // 调用 ZEGO 数字人 API 创建任务
    // Call ZEGO Digital Human API to create task
    const taskId = await createStreamTask({
      digitalHumanId,
      roomId,
      streamId,
    });

    console.log("[POST /api/digital-human/create-task] Task created successfully:", { taskId });

    sendJSON(res, {
      success: true,
      taskId,
    });
  } catch (error) {
    console.error("[POST /api/digital-human/create-task] Error:", error);
    sendJSON(res, { success: false, error: error.message }, 500);
  }
};

// POST /api/digital-human/stop-task - 停止数字人视频流任务
// Stop digital human video stream task
const handleStopTask = async (req, res) => {
  try {
    const body = await parseBody(req);
    const { taskId } = body;

    console.log("[POST /api/digital-human/stop-task] Stopping digital human task:", { taskId });

    // 验证必需参数
    // Validate required parameters
    if (!taskId) {
      return sendJSON(res, { success: false, error: "Missing required parameter: taskId" }, 400);
    }

    // 调用 ZEGO 数字人 API 停止任务
    // Call ZEGO Digital Human API to stop task
    await stopStreamTask({ taskId });

    console.log("[POST /api/digital-human/stop-task] Task stopped successfully");

    sendJSON(res, { success: true, message: "Digital human task stopped" });
  } catch (error) {
    console.error("[POST /api/digital-human/stop-task] Error:", error);
    sendJSON(res, { success: false, error: error.message }, 500);
  }
};

// POST /api/digital-human/talk-to-ai - 模拟 AI 交互
// Simulate AI interaction
const handleTalkToAI = async (req, res) => {
  try {
    const body = await parseBody(req);
    const { taskId, lang = "zh" } = body;

    console.log("[POST /api/digital-human/talk-to-ai] Starting AI interaction:", { taskId, lang });

    // 验证必需参数
    // Validate required parameters
    if (!taskId) {
      return sendJSON(res, { success: false, error: "Missing required parameter: taskId" }, 400);
    }

    // 说明: 实际业务中的 AI 交互流程 / Note: Actual AI interaction flow in production
    // 1. 接收客户端音频数据 / Receive client audio data
    // 2. ASR (语音识别) → 转为文本 / ASR (Speech Recognition) → Convert to text
    // 3. LLM (大语言模型) → 生成回复文本 / LLM (Large Language Model) → Generate reply text
    // 4. TTS (语音合成) → 生成 PCM 音频流 / TTS (Text-to-Speech) → Generate PCM audio stream
    // 注意⚠️：如果您还没有处理以上流程，我们强烈建议您使用 [ZEGO 实时互动 AI Agent](https://doc-zh.zego.im/aiagent-server/introduction/overview) 产品，它已经帮您实现了以上流程。 / Note: If you haven't processed the above process, we strongly recommend using the [ZEGO Conversational AI](https://www.zegocloud.com/docs/aiagent-server/introduction/overview) product, which has already implemented the above process for you.

    // 第 4 步: 调用 TTS 接口，合成语音后，通过 WebSocket 驱动数字人。
    // Step 4: Call TTS API, synthesize speech, and drive digital human via WebSocket
    console.log("[POST /api/digital-human/talk-to-ai] Calling TTS API, synthesizing speech, and driving digital human via WebSocket...");
    await callTTSAndDriveDigitalHumanByWebSocket(taskId, lang);

    sendJSON(res, { success: true, message: "AI interaction completed" });
  } catch (error) {
    console.error("[POST /api/digital-human/talk-to-ai] Error:", error);
    sendJSON(res, { success: false, error: error.message }, 500);
  }
};

// GET /api/token - 生成 ZEGO RTC Token
// Generate ZEGO RTC Token
const handleToken = async (req, res) => {
  try {
    const parsedUrl = url.parse(req.url, true);
    const userId = parsedUrl.query.userId;

    console.log("[GET /api/token] Generating token for userId:", userId);

    // 验证必需参数
    // Validate required parameters
    if (!userId) {
      return sendJSON(res, { success: false, error: "Missing required parameter: userId" }, 400);
    }

    // 从环境变量读取配置
    // Read configuration from environment variables
    const appId = Number(process.env.APP_ID);
    const serverSecret = process.env.SERVER_SECRET;

    if (!appId || !serverSecret) {
      return sendJSON(
        res,
        { success: false, error: "Server configuration error: APP_ID or SERVER_SECRET not configured" },
        500
      );
    }

    // 生成 Token（有效期 3600 秒）/ Generate token (3600 seconds validity)
    const token = generateToken(appId, userId, serverSecret, 3600, "");

    console.log("[GET /api/token] Token generated successfully");

    sendJSON(res, { success: true, token });
  } catch (error) {
    console.error("[GET /api/token] Error:", error);
    sendJSON(res, { success: false, error: error.message }, 500);
  }
};

// ============ HTTP 服务器 / HTTP Server ============

const server = http.createServer(async (req, res) => {
  const parsedUrl = url.parse(req.url, true);
  const pathname = parsedUrl.pathname;
  const method = req.method;

  // 处理 OPTIONS 预检请求
  // Handle OPTIONS preflight request
  if (method === "OPTIONS") {
    res.writeHead(200, corsHeaders);
    return res.end();
  }

  // 路由分发
  // Route dispatch
  if (method === "POST" && pathname === "/api/digital-human/create-task") {
    return handleCreateTask(req, res);
  }
  if (method === "POST" && pathname === "/api/digital-human/stop-task") {
    return handleStopTask(req, res);
  }
  if (method === "POST" && pathname === "/api/digital-human/talk-to-ai") {
    return handleTalkToAI(req, res);
  }
  if (method === "GET" && pathname === "/api/token") {
    return handleToken(req, res);
  }

  // 404
  sendJSON(res, { success: false, error: "Not Found" }, 404);
});

server.listen(PORT, () => {
  console.log(`Digital Human Server running at http://localhost:${PORT}`);
});

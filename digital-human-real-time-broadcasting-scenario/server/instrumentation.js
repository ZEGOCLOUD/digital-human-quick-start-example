// Instrumentation hook for Next.js
// Broadcasts are now managed via /api/broadcast endpoints
export async function register() {
  if (process.env.NEXT_RUNTIME === "nodejs") {
    const { clearAllTasks } = await import("./lib/digitalHuman.js");
    // 服务器启动时清理所有正在运行的数字人任务
    await clearAllTasks();
  }
}

// 设备检测
export const device = {
  // 检测是否为移动设备
  isMobile() {
    return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(
      navigator.userAgent
    );
  },

  // 检测屏幕宽度
  getScreenWidth() {
    return window.innerWidth || document.documentElement.clientWidth;
  },

  // 检测屏幕高度
  getScreenHeight() {
    return window.innerHeight || document.documentElement.clientHeight;
  },

  // 检测是否为小屏幕（移动端）
  isSmallScreen() {
    return this.getScreenWidth() < 768;
  },

  // 检测是否为平板
  isTablet() {
    const width = this.getScreenWidth();
    return width >= 768 && width < 1024;
  },

  // 检测是否为桌面端
  isDesktop() {
    return this.getScreenWidth() >= 1024;
  },

  // 检测是否为大屏幕桌面端
  isLargeDesktop() {
    return this.getScreenWidth() >= 1440;
  },

  // 获取设备类型
  getDeviceType() {
    if (this.isMobile() || this.isSmallScreen()) {
      return "mobile";
    } else if (this.isTablet()) {
      return "tablet";
    } else if (this.isLargeDesktop()) {
      return "large-desktop";
    } else {
      return "desktop";
    }
  },

  // 检测是否为触摸设备
  isTouchDevice() {
    return "ontouchstart" in window || navigator.maxTouchPoints > 0;
  },
};

// 防抖函数
export function debounce(func, wait, immediate = false) {
  let timeout;
  return function executedFunction(...args) {
    const later = () => {
      timeout = null;
      if (!immediate) func.apply(this, args);
    };
    const callNow = immediate && !timeout;
    clearTimeout(timeout);
    timeout = setTimeout(later, wait);
    if (callNow) func.apply(this, args);
  };
}

// 节流函数
export function throttle(func, limit) {
  let inThrottle;
  return function (...args) {
    if (!inThrottle) {
      func.apply(this, args);
      inThrottle = true;
      setTimeout(() => (inThrottle = false), limit);
    }
  };
}

// 生成唯一ID
export function generateId(prefix = "") {
  return (
    prefix + Date.now().toString(36) + Math.random().toString(36).substr(2)
  );
}

// 格式化时间
export function formatDuration(seconds) {
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = seconds % 60;

  if (hours > 0) {
    return `${hours}:${minutes.toString().padStart(2, "0")}:${secs
      .toString()
      .padStart(2, "0")}`;
  }
  return `${minutes}:${secs.toString().padStart(2, "0")}`;
}

// 文件大小格式化
export function formatFileSize(bytes) {
  if (bytes === 0) return "0 Bytes";

  const k = 1024;
  const sizes = ["Bytes", "KB", "MB", "GB"];
  const i = Math.floor(Math.log(bytes) / Math.log(k));

  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + " " + sizes[i];
}

// 深拷贝
export function deepClone(obj) {
  if (obj === null || typeof obj !== "object") return obj;
  if (obj instanceof Date) return new Date(obj.getTime());
  if (obj instanceof Array) return obj.map((item) => deepClone(item));
  if (typeof obj === "object") {
    const clonedObj = {};
    for (const key in obj) {
      if (obj.hasOwnProperty(key)) {
        clonedObj[key] = deepClone(obj[key]);
      }
    }
    return clonedObj;
  }
}

// 错误消息映射
export const errorMessages = {
  400000001: "输入参数无效",
  400000002: "数字人 PaaS 服务权限未开通",
  400000003: "未找到数字人形象",
  400000004: "未找到音色",
  400000005: "实时流任务未找到",
  400000006: "实时流任务未启动",
  400000007: "实时流任务已停止",
  400000008: "实时流任务并发超出限制",
  400000009: "不支持的音色",
  400000010: "数字人形象内部配置出错",
  400000015: "当前流 ID 已存在",
  400000016: "数字人模型版本错误",
  400010000: "系统错误",
  400010001: "未获得接口调用权限",
  400010002: "系统繁忙",
  400010007: "没有可用节点",
  400010008: "指定的vpc不存在",
  400010009: "接口频率限制",
};

// 获取错误消息
export function getErrorMessage(code, defaultMessage = "未知错误") {
  return errorMessages[code] || defaultMessage;
}

// 驱动状态映射
export const driveStatusMap = {
  1: { text: "排队中", color: "#1890ff", loading: true },
  2: { text: "驱动中", color: "#52c41a", loading: true },
  3: { text: "驱动失败", color: "#ff4d4f", loading: false },
  4: { text: "驱动结束", color: "#52c41a", loading: false },
  5: { text: "驱动打断", color: "#faad14", loading: false },
};

/**
 * 房间消息解析器，用于解析来自 ZegoExpressEngine 的消息
 */
export const roomMessageParser = {
  /**
   * 从 experimentalAPI 的 content 中解析出数字人说话状态
   * @param {string|object} content - Zego 引擎返回的内容
   * @returns {object|null} - 返回 { speakStatus, driveID }，解析失败返回 null
   */
  parseSpeakStatusFromExperimentalAPI(content) {
    if (!content) return null;
    
    let contentData;
    try {
      if (typeof content === 'string') {
        contentData = JSON.parse(content);
      } else {
        contentData = content;
      }
    } catch (e) {
      console.error('[roomMessageParser] content JSON 解析失败:', e);
      return null;
    }

    // 检查是否是房间消息
    const method = contentData.method;
    if (method !== 'onRecvRoomChannelMessage' && method !== 'liveroom.room.on_recive_room_channel_message') {
      return null;
    }

    const params = contentData.params || contentData.content;
    if (!params) return null;

    const msgContent = params.msg_content || params.msgContent || null;
    if (!msgContent) return null;

    let msgData;
    if (!msgContent) return null;

    try {
      msgData = typeof msgContent === 'string' ? JSON.parse(msgContent) : msgContent;
    } catch (e) {
      console.error('[roomMessageParser] msgContent 解析失败:', e);
      return null;
    }

    if (msgData.Product !== 'digitalhuman') {
      return null;
    }

    if (msgData.Cmd !== 1001) {
      return null;
    }

    const body = msgData.Data;
    if (!body) return null;

    return {
      speakStatus: body.Status, // 2: 开始说话, 4: 结束说话
      driveID: body.DriveId
    };
  }
};

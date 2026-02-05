package com.example.digitalhumanquickstartdemo.config

object Config {
    // 从 ZEGO 控制台获取 AppID
    // Get AppID from ZEGO Console
    // https://console.zego.im/
    const val APP_ID: Long = 1234567890L  // 替换为您的 AppID / Replace with your AppID

    // 业务后台地址
    // Business backend API address
    const val API_BASE_URL = "http://192.168.92.50:3000"  // 替换为您的服务端地址 / Replace with your server URL

    // 数字人 ID
    // Digital Human ID
    // 用于预加载数字人 SDK。与业务后台约定或者从业务后台获取即可。
    // Used to preload the digital human SDK. It can be obtained from the backend or agreed with the backend.
    const val DIGITAL_HUMAN_ID = "1b1b0ab5-4261-405e-8932-f67029a8311a"  // 替换为您的数字人 ID / Replace with your digital human ID
}

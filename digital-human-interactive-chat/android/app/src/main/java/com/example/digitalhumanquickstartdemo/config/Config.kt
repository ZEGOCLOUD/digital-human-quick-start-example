package com.example.digitalhumanquickstartdemo.config

object Config {
    // 从 ZEGO 控制台获取 AppID
    // Get AppID from ZEGO Console
    // https://console.zego.im/
    const val APP_ID: Long = 1234567890L  // 替换为您的 AppID / Replace with your AppID

    // 业务后台地址
    // Business backend API address
    // (数字人 ID 由服务端配置 / Digital Human ID is configured on server)
    const val API_BASE_URL = "http://192.168.92.50:3000"  // 替换为您的服务端地址 / Replace with your server URL
}

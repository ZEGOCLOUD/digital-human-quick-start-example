package com.example.digitalhumanquickstartdemo.config

/**
 * 客户端配置
 * Client configuration
 *
 * 使用说明：
 * Usage instructions:
 * 1. appId: 从即构控制台获取 https://console.zego.im /Get appId from ZEGO console https://console.zegocloud.com
 * 2. apiBaseUrl: 业务后台地址，用于获取播报列表和Token / Backend API address for fetching broadcast list and token
 */
object Config {
    // 请替换为你的 AppID
    // Please replace with your AppID
    const val APP_ID: Long = 123456789L

    // 业务后台地址，请替换为实际地址
    // Backend API address, please replace with actual address
    const val API_BASE_URL = "http://localhost:3000"
}

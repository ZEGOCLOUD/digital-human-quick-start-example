package com.example.digitalhumanquickstartdemo.config

/**
 * 客户端配置
 *
 * 使用说明：
 * 1. appId: 从即构控制台获取 https://console.zego.im
 * 2. apiBaseUrl: 业务后台地址，用于获取播报列表和Token
 */
object Config {
    // 请替换为你的 AppID
    const val APP_ID: Long = 123456789L

    // 业务后台地址，请替换为实际地址
    const val API_BASE_URL = "http://localhost:3000"
}

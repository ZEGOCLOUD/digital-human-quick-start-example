//
//  Config.h
//  ZegoDigitalHumanQuickStart
//
//  简单配置文件 - 对齐Android的Config.kt
//  Simple configuration file - aligned with Android's Config.kt
//

#ifndef Config_h
#define Config_h

#import <Foundation/Foundation.h>

/**
 * 客户端配置
 * Client configuration
 *
 * 使用说明：
 * Usage instructions:
 * 1. APP_ID: 从即构控制台获取 https://console.zego.im / Get APP_ID from ZEGO console https://console.zegocloud.com
 * 2. API_BASE_URL: 业务后台地址，用于创建数字人任务和获取Token / Backend API address for creating digital human task and fetching token
 *    (数字人 ID 由服务端配置 / Digital Human ID is configured on server)
 */
@interface Config : NSObject

// 请替换为你的 AppID
// Please replace with your AppID
@property (class, nonatomic, readonly) NSUInteger APP_ID;

// 业务后台地址，请替换为实际地址
// Backend API address, please replace with actual address
@property (class, nonatomic, readonly) NSString *API_BASE_URL;

@end

#endif /* Config_h */

//
//  Config.h
//  ZegoDigitalHumanQuickStart
//
//  简单配置文件 - 对齐Android的Config.kt
//

#ifndef Config_h
#define Config_h

#import <Foundation/Foundation.h>

/**
 * 客户端配置
 *
 * 使用说明：
 * 1. APP_ID: 从即构控制台获取 https://console.zego.im
 * 2. API_BASE_URL: 业务后台地址，用于获取播报列表和Token
 */
@interface Config : NSObject

// 请替换为你的 AppID
@property (class, nonatomic, readonly) NSUInteger APP_ID;

// 业务后台地址，请替换为实际地址
@property (class, nonatomic, readonly) NSString *API_BASE_URL;

@end

#endif /* Config_h */

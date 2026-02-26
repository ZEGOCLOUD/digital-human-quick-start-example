//
//  Config.m
//  ZegoDigitalHumanQuickStart
//
//  简单配置文件 - 对齐Android的Config.kt
//  Simple configuration file - aligned with Android's Config.kt
//

#import "Config.h"

@implementation Config

+ (NSUInteger)APP_ID {
    // 从Zego控制台获取 https://console.zego.im/
    // Get from ZEGO console https://console.zegocloud.com/
    // 请替换为你的 AppID
    // Please replace with your AppID
    return 1234567890;
}

+ (NSString *)API_BASE_URL {
    // 业务后台地址，请替换为实际地址
    // Backend API address, please replace with actual address
    // (数字人 ID 由服务端配置 / Digital Human ID is configured on server)
    return @"http://localhost:3000";
}

@end

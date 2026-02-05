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
    return @"http://localhost:3000";
}

+ (NSString *)DIGITAL_HUMAN_ID {
    // 数字人 ID，用于预加载数字人 SDK。与业务后台约定或者从业务后台获取即可。
    // Digital Human ID, used to preload the digital human SDK. It can be obtained from the backend or agreed with the backend.
    return @"c7a4e7a5-1648-4ed6-ac7c-53ad44b9d5f5";
}

@end

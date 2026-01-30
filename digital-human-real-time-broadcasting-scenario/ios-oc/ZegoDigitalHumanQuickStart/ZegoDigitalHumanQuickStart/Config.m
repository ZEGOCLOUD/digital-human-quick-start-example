//
//  Config.m
//  ZegoDigitalHumanQuickStart
//
//  简单配置文件 - 对齐Android的Config.kt
//

#import "Config.h"

@implementation Config

+ (NSUInteger)APP_ID {
    // 从Zego控制台获取 https://console.zego.im/
    // 请替换为你的 AppID
    return 1234567890;
}

+ (NSString *)API_BASE_URL {
    // 业务后台地址，请替换为实际地址
    return @"http://localhost:3000";
}

@end

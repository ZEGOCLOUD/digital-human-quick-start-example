//
//  ZegoMainViewController+RTC.m
//  ZegoDigitalHumanModelQuickStart
//
//  Created by Zego.
//

#import "ZegoMainViewController+RTC.h"
#import "ZegoMainViewController.h"
#import "ZegoMainViewController+Setup.h"
#import <ZegoDigitalMobile/ZegoDigitalMobile.h>

static int ZegoParseSpeakStatusFromExperimentalAPI(NSString *content, NSString **driveID) {
    if (driveID) {
        *driveID = nil;
    }

    if (!content || content.length == 0) {
        return -1;
    }

    NSError *error = nil;
    NSDictionary *contentDict = [NSJSONSerialization JSONObjectWithData:[content dataUsingEncoding:NSUTF8StringEncoding]
                                                                 options:0
                                                                   error:&error];
    if (error || !contentDict) {
        NSLog(@"[RTC] 解析 experimental api 失败: %@", error.localizedDescription);
        return -1;
    }

    NSString *method = contentDict[@"method"];
    if (![method isEqualToString:@"liveroom.room.on_recive_room_channel_message"]) {
        return -1;
    }

    NSDictionary *params = contentDict[@"params"];
    if (![params isKindOfClass:[NSDictionary class]]) {
        return -1;
    }

    NSString *msgContent = params[@"msg_content"];
    if (msgContent.length == 0) {
        return -1;
    }

    NSDictionary *msgDict = [NSJSONSerialization JSONObjectWithData:[msgContent dataUsingEncoding:NSUTF8StringEncoding]
                                                            options:0
                                                              error:&error];
    if (error || !msgDict) {
        NSLog(@"[RTC] 解析房间消息失败: %@", error.localizedDescription);
        return -1;
    }

    if (![msgDict[@"Product"] isEqualToString:@"digitalhuman"]) {
        return -1;
    }

    if ([msgDict[@"Cmd"] intValue] != 1001) {
        return -1;
    }

    NSDictionary *data = msgDict[@"Data"];
    if (![data isKindOfClass:[NSDictionary class]]) {
        return -1;
    }

    if (driveID) {
        *driveID = data[@"DriveId"];
    }

    return [data[@"Status"] intValue];
}

@implementation ZegoMainViewController (RTC)

#pragma mark - RTC Engine Management

- (void)initExpressEngineWithAppId:(NSInteger)appId {
    if (self.rtcEngineCreated) {
        NSLog(@"[RTC] 引擎已创建，跳过");
        return;
    }
    
    // 创建引擎
    ZegoEngineProfile *profile = [[ZegoEngineProfile alloc] init];
    profile.appID = (unsigned int)appId;
    profile.scenario = ZegoScenarioHighQualityChatroom;
    
    [ZegoExpressEngine createEngineWithProfile:profile eventHandler:self];
    self.rtcEngineCreated = YES;
    NSLog(@"[RTC] Express引擎创建成功，AppId: %ld", (long)appId);

    // 启用自定义视频渲染
    ZegoCustomVideoRenderConfig *renderConfig = [[ZegoCustomVideoRenderConfig alloc] init];
    renderConfig.bufferType = ZegoVideoBufferTypeRawData;
    renderConfig.frameFormatSeries = ZegoVideoFrameFormatSeriesRGB;
    renderConfig.enableEngineRender = NO;
    [[ZegoExpressEngine sharedEngine] enableCustomVideoRender:YES config:renderConfig];
    [[ZegoExpressEngine sharedEngine] setCustomVideoRenderHandler:self];
    NSLog(@"[RTC] 自定义视频渲染已启用");
}

- (void)destroyExpressEngine {
    if (!self.rtcEngineCreated) {
        return;
    }
    
    // 停止拉流
    if (self.currentStreamId && self.currentStreamId.length > 0) {
        [[ZegoExpressEngine sharedEngine] stopPlayingStream:self.currentStreamId];
    }
    
    // 退出房间
    if (self.isRoomLogined && self.currentRoomId && self.currentRoomId.length > 0) {
        [[ZegoExpressEngine sharedEngine] logoutRoom:self.currentRoomId];
        self.isRoomLogined = NO;
    }
    
    // 销毁引擎
    [ZegoExpressEngine destroyEngine:nil];
    self.rtcEngineCreated = NO;
    NSLog(@"[RTC] Express引擎已销毁");
}

- (void)loginRoomWithCompletion:(void(^)(BOOL success))completion {
    [self updateStatus:@"正在登录房间..."];
    
    // 设置高级配置
    ZegoEngineConfig *engineConfig = [[ZegoEngineConfig alloc] init];
    engineConfig.advancedConfig = @{
        @"set_audio_volume_ducking_mode": @"1",/**该配置是用来做音量闪避的**/
        @"enable_rnd_volume_adaptive": @"true",/**该配置是用来做播放音量自适用**/
        @"sideinfo_callback_version":@(3),
        @"sideinfo_bound_to_video_decoder":@"true"
    };
    [ZegoExpressEngine setEngineConfig:engineConfig];

    //这个设置只影响AEC（回声消除），我们这里设置为ModeGeneral，是会走我们自研的回声消除，这比较可控，
    //如果其他选项，可能会走系统的回声消除，这在iphone手机上效果可能会更好，但如果在一些android机上效果可能不好
    [[ZegoExpressEngine sharedEngine] setAudioDeviceMode:ZegoAudioDeviceModeGeneral];

    //开启传统音频 3A 处理
    [[ZegoExpressEngine sharedEngine] enableAGC:TRUE];
    [[ZegoExpressEngine sharedEngine] enableAEC:TRUE];
    [[ZegoExpressEngine sharedEngine] enableANS:TRUE];

    // 开启 AI 回声消除
    [[ZegoExpressEngine sharedEngine] setAECMode:ZegoAECModeAIBalanced];
    
    // 开启 AI 降噪，适度的噪声抑制
    [[ZegoExpressEngine sharedEngine] setANSMode:ZegoANSModeMedium];

    ZegoRoomConfig *roomConfig = [[ZegoRoomConfig alloc] init];
    roomConfig.isUserStatusNotify = YES;
    roomConfig.token = self.currentToken;
    
    ZegoUser *user = [[ZegoUser alloc] init];
    user.userID = self.currentUserId;
    user.userName = self.currentUserId;
    
    __weak typeof(self) weakSelf = self;
    [[ZegoExpressEngine sharedEngine] loginRoom:self.currentRoomId
                                           user:user
                                         config:roomConfig
                                       callback:^(int errorCode, NSDictionary * _Nonnull extendedData) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        if (errorCode == 0) {
            strongSelf.isRoomLogined = YES;
            NSLog(@"[RTC] 登录房间成功: %@", strongSelf.currentRoomId);
            
            if (completion) completion(YES);
        } else {
            NSLog(@"[RTC] 登录房间失败: %d", errorCode);
            [strongSelf updateStatus:[NSString stringWithFormat:@"登录房间失败: %d", errorCode]];
            if (completion) completion(NO);
        }
    }];
}



- (void)startPlayingStream:(NSString *)streamID {
    // 边界检查
    if (!streamID || streamID.length == 0) {
        NSLog(@"[RTC] 错误：streamID不能为空");
        return;
    }
    
    // 设置拉流缓冲区
    [[ZegoExpressEngine sharedEngine] setPlayStreamBufferIntervalRange:streamID min:100 max:2000];
    
    // 开始拉流
    [[ZegoExpressEngine sharedEngine] startPlayingStream:streamID];
    
    [self updateStatus:@"正在拉流..."];
    NSLog(@"[RTC] 开始拉流: %@", streamID);
}

#pragma mark - ZegoEventHandler (RTC回调)

- (void)onRoomStreamUpdate:(ZegoUpdateType)updateType
                streamList:(NSArray<ZegoStream *> *)streamList
              extendedData:(NSDictionary *)extendedData
                    roomID:(NSString *)roomID {
    NSLog(@"[RTC] 房间流更新: roomID=%@, 更新类型=%@, 流数量=%lu",
          roomID,
          updateType == ZegoUpdateTypeAdd ? @"新增" : @"移除",
          (unsigned long)streamList.count);
    
    if (updateType == ZegoUpdateTypeAdd) {
        for (ZegoStream *stream in streamList) {
            if ([stream.streamID isEqualToString:self.currentStreamId]) {
                NSLog(@"[RTC] 检测到目标流，开始拉流: %@", stream.streamID);
                [self startPlayingStream:stream.streamID];
                break;
            }
        }
    } else if (updateType == ZegoUpdateTypeDelete) {
        for (ZegoStream *stream in streamList) {
            if ([stream.streamID isEqualToString:self.currentStreamId]) {
                NSLog(@"[RTC] 流已移除: %@", stream.streamID);
            }
        }
    }
}

- (void)onPlayerSyncRecvSEI:(NSData *)data streamID:(NSString *)streamID {
    // 边界检查
    if (!data || !streamID || streamID.length == 0) {
        return;
    }
    
    // 传递给数字人SDK
    if ([streamID isEqualToString:self.currentStreamId] && self.digitalMobile) {
        [self.digitalMobile onPlayerSyncRecvSEI:streamID data:data];
    }
}

- (void)onRecvExperimentalAPI:(NSString *)content {
    NSString *driveID = nil;
    int speakStatus = ZegoParseSpeakStatusFromExperimentalAPI(content, &driveID);
    if (speakStatus == -1) {
        return;
    }

    NSString *statusText = nil;
    if (speakStatus == 2) {
        statusText = driveID.length > 0
            ? [NSString stringWithFormat:@"数字人开始说话，DriveID: %@", driveID]
            : @"数字人开始说话";
    } else if (speakStatus == 4) {
        statusText = driveID.length > 0
            ? [NSString stringWithFormat:@"数字人说话结束，DriveID: %@", driveID]
            : @"数字人说话结束";
    }

    if (statusText.length == 0) {
        return;
    }

    NSLog(@"[RTC] 收到数字人说话状态: %@", statusText);
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusLabel.hidden = NO;
    });
    [self updateStatus:statusText];
}

#pragma mark - ZegoCustomVideoRenderHandler

- (void)onRemoteVideoFrameRawData:(unsigned char **)data
                       dataLength:(unsigned int *)dataLength
                            param:(ZegoVideoFrameParam *)param
                         streamID:(NSString *)streamID {
    // 边界检查
    if (!data || !dataLength || !param || !streamID || streamID.length == 0) {
        return;
    }
    
    // 传递给数字人SDK
    if ([streamID isEqualToString:self.currentStreamId] && self.digitalMobile) {
        // 创建ZDMVideoFrameParam
        ZDMVideoFrameParam *dmParam = [[ZDMVideoFrameParam alloc] init];
        dmParam.format = (ZDMVideoFrameFormat)param.format;
        dmParam.width = param.size.width;
        dmParam.height = param.size.height;
        dmParam.rotation = param.rotation;
        
        // 设置步长
        for (int i = 0; i < 4; i++) {
            [dmParam setStride:param.strides[i] atIndex:i];
        }
        
        [self.digitalMobile onRemoteVideoFrameRawData:data
                                                dataLength:dataLength
                                                     param:dmParam
                                                  streamID:streamID];
    }
}

@end

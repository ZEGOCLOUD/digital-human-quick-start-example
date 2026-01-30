//
//  ViewController.m
//  ZegoDigitalHumanQuickStart
//
//  单文件实现 - 对齐Android的MainActivity.kt调用流程
//  核心流程：获取播报列表 → 获取Token → 预加载资源 → 登录房间 → 启动数字人
//

#import "ViewController.h"
#import "Config.h"
#import <ZegoExpressEngine/ZegoExpressEngine.h>
#import <ZegoDigitalMobile/ZegoDigitalMobile.h>

// ========== 1. 内部接口扩展 ==========
@interface ViewController () <ZegoDigitalMobileDelegate, ZegoDigitalHumanResourceDelegate, ZegoEventHandler, ZegoCustomVideoRenderHandler>

// 数字人视图（SDK提供的渲染视图）
@property (nonatomic, strong) ZegoDigitalView *digitalHumanView;

// SDK实例
@property (nonatomic, strong) ZegoExpressEngine *expressEngine;

// 房间信息
@property (nonatomic, copy) NSString *currentRoomId;
@property (nonatomic, copy) NSString *currentStreamId;
@property (nonatomic, copy) NSString *currentUserId;
@property (nonatomic, assign) BOOL isRoomLoggedIn;

// 播报信息（从API获取）
@property (nonatomic, copy) NSString *digitalHumanId;
@property (nonatomic, copy) NSString *clientInferencePackageUrl;
@property (nonatomic, assign) BOOL isSupportSmallImageMode;

// 用于在预加载成功后启动数字人
@property (nonatomic, copy) NSString *pendingBase64Config;

@end

// ========== 2. 实现 ==========
@implementation ViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    // 初始化状态
    self.isRoomLoggedIn = NO;

    // 初始化UI
    [self initViews];

    // 检查配置
    if ([Config APP_ID] == 0) {
        [self updateStatus:@"请在 Config.h 中配置 APP_ID"];
        return;
    }

    // 初始化SDK
    [self initSDKs];

    // 启动数字人播放流程
    [self startDigitalHuman];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    // 页面消失时清理资源
    [self cleanup];
}

- (void)dealloc {
    [self cleanup];
}

#pragma mark - 3. UI Setup

- (void)initViews {
    self.view.backgroundColor = [UIColor colorWithRed:0.4 green:0.5 blue:0.9 alpha:1.0];

    // 状态标签
    self.tvStatus = [[UILabel alloc] init];
    self.tvStatus.text = @"状态：初始化...";
    self.tvStatus.textColor = [UIColor whiteColor];
    self.tvStatus.font = [UIFont systemFontOfSize:14];
    self.tvStatus.numberOfLines = 0;
    self.tvStatus.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.tvStatus];

    // 房间信息标签
    self.tvRoomInfo = [[UILabel alloc] init];
    self.tvRoomInfo.text = @"房间: -- | 流: --";
    self.tvRoomInfo.textColor = [UIColor whiteColor];
    self.tvRoomInfo.font = [UIFont systemFontOfSize:12];
    self.tvRoomInfo.numberOfLines = 0;
    self.tvRoomInfo.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.tvRoomInfo];

    // 数字人视图容器
    self.digitalHumanContainerView = [[UIView alloc] init];
    self.digitalHumanContainerView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.digitalHumanContainerView];

    // 布局约束
    self.tvStatus.translatesAutoresizingMaskIntoConstraints = NO;
    self.tvRoomInfo.translatesAutoresizingMaskIntoConstraints = NO;
    self.digitalHumanContainerView.translatesAutoresizingMaskIntoConstraints = NO;

    [NSLayoutConstraint activateConstraints:@[
        [self.tvStatus.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:20],
        [self.tvStatus.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.tvStatus.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],

        [self.tvRoomInfo.topAnchor constraintEqualToAnchor:self.tvStatus.bottomAnchor constant:10],
        [self.tvRoomInfo.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.tvRoomInfo.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],

        [self.digitalHumanContainerView.topAnchor constraintEqualToAnchor:self.tvRoomInfo.bottomAnchor constant:20],
        [self.digitalHumanContainerView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.digitalHumanContainerView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.digitalHumanContainerView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

#pragma mark - 4. SDK Initialization

/**
 * 初始化 Express SDK 和数字人 SDK
 */
- (void)initSDKs {
    // 初始化 Express SDK
    ZegoEngineProfile *profile = [[ZegoEngineProfile alloc] init];
    profile.appID = (unsigned int)[Config APP_ID];
    profile.scenario = ZegoScenarioHighQualityChatroom;

    self.expressEngine = [ZegoExpressEngine createEngineWithProfile:profile eventHandler:self];

    // 初始化数字人SDK
    self.digitalMobile = [ZegoDigitalHuman create];

    // 创建数字人视图并绑定
    self.digitalHumanView = [[ZegoDigitalView alloc] initWithFrame:self.digitalHumanContainerView.bounds];
    self.digitalHumanView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.digitalHumanContainerView addSubview:self.digitalHumanView];

    [self.digitalMobile attach:self.digitalHumanView];

    NSLog(@"[SDK] Express引擎和数字人SDK初始化完成");
}

#pragma mark - 5. Main Flow

/**
 * 启动数字人播放流程 - 对齐Android的startDigitalHuman()
 */
- (void)startDigitalHuman {
    // 在后台线程执行网络请求
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @try {
            // 步骤1: 从业务后台获取播报列表
            [self updateStatus:@"获取播报列表中..."];
            NSDictionary *broadcast = [self fetchBroadcastList];
            if (!broadcast) {
                [self updateStatus:@"没有可用播报，请先在服务端启动播报任务"];
                return;
            }

            // 保存房间信息
            self.currentRoomId = broadcast[@"roomId"];
            self.currentStreamId = broadcast[@"streamId"];
            self.digitalHumanId = broadcast[@"digitalHumanId"];
            self.clientInferencePackageUrl = broadcast[@"clientInferencePackageUrl"];
            self.isSupportSmallImageMode = [broadcast[@"isSupportSmallImageMode"] boolValue];

            dispatch_async(dispatch_get_main_queue(), ^{
                self.tvRoomInfo.text = [NSString stringWithFormat:@"房间: %@ | 流: %@", self.currentRoomId, self.currentStreamId];
            });

            // 步骤2: 获取Token
            [self updateStatus:@"获取 Token 中..."];
            self.currentUserId = [NSString stringWithFormat:@"user_%lld", (long long)([[NSDate date] timeIntervalSince1970] * 1000)];
            NSString *token = [self fetchToken:self.currentUserId];
            if (!token) {
                [self updateStatus:@"获取 Token 失败"];
                return;
            }

            // 步骤3: 预加载数字人资源
            [self updateStatus:@"预加载数字人资源..."];
            [self preloadDigitalHumanResources:self.currentUserId token:token];

            // 步骤4: 登录房间（登录成功后会启动数字人）
            [self updateStatus:@"登录房间中..."];
            [self loginRoom:self.currentRoomId streamId:self.currentStreamId userId:self.currentUserId token:token broadcast:broadcast];

        } @catch (NSException *exception) {
            NSLog(@"[错误] 启动失败: %@", exception.reason);
            [self updateStatus:[NSString stringWithFormat:@"启动失败: %@", exception.reason]];
        }
    });
}

#pragma mark - 6. API Calls (Inline - 对齐Android的OkHttp调用)

/**
 * 获取播报列表 - 对齐Android的fetchBroadcastList()
 * GET /api/broadcast
 */
- (NSDictionary *)fetchBroadcastList {
    NSString *urlString = [NSString stringWithFormat:@"%@/api/broadcast", [Config API_BASE_URL]];
    NSURL *url = [NSURL URLWithString:urlString];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"GET";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
    if (!data) {
        NSLog(@"[API] 获取播报列表失败: 无响应");
        return nil;
    }

    NSError *jsonError = nil;
    id jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    if (jsonError || ![jsonResponse isKindOfClass:[NSDictionary class]]) {
        NSLog(@"[API] 解析播报列表失败: %@", jsonError);
        return nil;
    }

    NSDictionary *json = (NSDictionary *)jsonResponse;
    NSDictionary *broadcastList = json[@"broadcastList"];
    if (![broadcastList isKindOfClass:[NSDictionary class]] || broadcastList.count == 0) {
        NSLog(@"[API] 播报列表为空");
        return nil;
    }

    // 获取第一个播报，仅示例
    NSString *firstKey = broadcastList.allKeys.firstObject;
    NSDictionary *broadcast = broadcastList[firstKey];
    if (![broadcast isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    // 验证必需字段
    NSString *roomId = broadcast[@"roomId"];
    NSString *streamId = broadcast[@"streamId"];
    NSString *packageUrl = broadcast[@"clientInferencePackageUrl"];
    NSString *digitalHumanId = broadcast[@"digitalHumanId"];

    if (!roomId || !streamId || !packageUrl || !digitalHumanId) {
        NSLog(@"[API] 播报信息不完整");
        return nil;
    }

    return @{
        @"roomId": roomId,
        @"streamId": streamId,
        @"clientInferencePackageUrl": packageUrl,
        @"digitalHumanId": digitalHumanId,
        @"isSupportSmallImageMode": broadcast[@"isSupportSmallImageMode"] ?: @NO
    };
}

/**
 * 获取Token - 对齐Android的fetchToken()
 * GET /api/token?userId=xxx
 */
- (NSString *)fetchToken:(NSString *)userId {
    NSString *urlString = [NSString stringWithFormat:@"%@/api/token?userId=%@", [Config API_BASE_URL], userId];
    NSURL *url = [NSURL URLWithString:urlString];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"GET";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
    if (!data) {
        NSLog(@"[API] 获取Token失败: 无响应");
        return nil;
    }

    NSError *jsonError = nil;
    id jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    if (jsonError || ![jsonResponse isKindOfClass:[NSDictionary class]]) {
        NSLog(@"[API] 解析Token失败: %@", jsonError);
        return nil;
    }

    NSDictionary *json = (NSDictionary *)jsonResponse;
    NSString *token = json[@"token"];
    return token;
}

#pragma mark - 7. RTC Operations

/**
 * 登录房间 - 对齐Android的loginRoom()
 */
- (void)loginRoom:(NSString *)roomId
          streamId:(NSString *)streamId
            userId:(NSString *)userId
             token:(NSString *)token
         broadcast:(NSDictionary *)broadcast {

    ZegoEngineConfig *engineConfig = [[ZegoEngineConfig alloc] init];
    engineConfig.advancedConfig = @{
        @"set_audio_volume_ducking_mode": @"1",
        @"enable_rnd_volume_adaptive": @"true",
        @"sideinfo_callback_version": @"3",
        @"sideinfo_bound_to_video_decoder": @"true"
    };
    [ZegoExpressEngine setEngineConfig:engineConfig];

    [self.expressEngine setRoomScenario:ZegoScenarioHighQualityChatroom];

    ZegoRoomConfig *roomConfig = [[ZegoRoomConfig alloc] init];
    roomConfig.isUserStatusNotify = YES;
    roomConfig.token = token;

    ZegoUser *user = [[ZegoUser alloc] init];
    user.userID = userId;
    user.userName = userId;

    __weak typeof(self) weakSelf = self;
    [self.expressEngine loginRoom:roomId user:user config:roomConfig callback:^(int errorCode, NSDictionary *extendedData) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        if (errorCode == 0) {
            strongSelf.isRoomLoggedIn = YES;
            NSLog(@"[RTC] 登录房间成功");

            // 登录成功后：开启自定义渲染
            [strongSelf enableCustomVideoRender];

            // 生成配置
            NSString *base64Config = [strongSelf generateBase64Config:strongSelf.digitalHumanId
                                                               roomId:strongSelf.currentRoomId
                                                            streamId:strongSelf.currentStreamId
                                                          packageUrl:strongSelf.clientInferencePackageUrl
                                           isSupportSmallImageMode:strongSelf.isSupportSmallImageMode];
            strongSelf.pendingBase64Config = base64Config;

            [strongSelf startDigitalHumanSDK:base64Config];
        } else {
            NSLog(@"[RTC] 登录房间失败: %d", errorCode);
            [strongSelf updateStatus:[NSString stringWithFormat:@"登录房间失败: %d", errorCode]];
        }
    }];
}

/**
 * 开启自定义视频渲染 - 对齐Android的enableCustomVideoRender()
 */
- (void)enableCustomVideoRender {
    ZegoCustomVideoRenderConfig *renderConfig = [[ZegoCustomVideoRenderConfig alloc] init];
    renderConfig.bufferType = ZegoVideoBufferTypeRawData;
    renderConfig.frameFormatSeries = ZegoVideoFrameFormatSeriesRGB;
    renderConfig.enableEngineRender = NO;
    [self.expressEngine enableCustomVideoRender:YES config:renderConfig];

    // 设置视频帧回调
    [self.expressEngine setCustomVideoRenderHandler:self];

    NSLog(@"[RTC] 自定义视频渲染已启用");
}

/**
 * 开始拉流 - 对齐Android的startPlayingStream()
 */
- (void)startPlayingStream:(NSString *)streamID {
    // 设置拉流缓冲区
    [self.expressEngine setPlayStreamBufferIntervalRange:streamID min:100 max:2000];

    // 开始拉流
    [self.expressEngine startPlayingStream:streamID];

    [self updateStatus:@"播放中..."];
    NSLog(@"[RTC] 开始拉流: %@", streamID);
}

#pragma mark - 8. Digital Human

/**
 * 预加载数字人资源 - 对齐Android的preloadDigitalHumanResources()
 */
- (void)preloadDigitalHumanResources:(NSString *)userId
                               token:(NSString *)token {
    ZegoDigitalHumanAuth *auth = [[ZegoDigitalHumanAuth alloc] initWithAppID:(unsigned int)[Config APP_ID]
                                                                        userID:userId
                                                                         token:token];

    [[ZegoDigitalHumanResource sharedInstance] preloadWithAuth:auth
                                               digitalHumanId:self.digitalHumanId
                                                     delegate:self];
    NSLog(@"[数字人] 开始预加载资源: %@", self.digitalHumanId);
}

/**
 * 启动数字人SDK - 对齐Android的startDigitalHumanSDK()
 */
- (void)startDigitalHumanSDK:(NSString *)base64Config {
    if (!self.digitalMobile) {
        [self updateStatus:@"数字人SDK未初始化"];
        return;
    }

    @try {
        [self.digitalMobile start:base64Config delegate:self];
        NSLog(@"[数字人] 开始启动数字人");
    } @catch (NSException *exception) {
        NSLog(@"[数字人] 启动失败: %@", exception.reason);
        [self updateStatus:[NSString stringWithFormat:@"数字人SDK启动失败: %@", exception.reason]];
    }
}

/**
 * 停止数字人
 */
- (void)stopDigitalHuman {
    if (self.digitalMobile) {
        [self.digitalMobile stop];
        self.digitalMobile = nil;
    }
    NSLog(@"[数字人] 数字人已停止");
}

#pragma mark - 9. Helper Methods

/**
 * 生成 Base64Config - 对齐Android的generateBase64Config()
 */
- (NSString *)generateBase64Config:(NSString *)digitalHumanId
                           roomId:(NSString *)roomId
                        streamId:(NSString *)streamId
                      packageUrl:(NSString *)packageUrl
       isSupportSmallImageMode:(BOOL)isSupportSmallImageMode {

    // 构建Streams配置
    NSDictionary *stream = @{
        @"RoomId": roomId ?: @"",
        @"StreamId": streamId ?: @"",
        @"EncodeCode": @"H264",
        @"PackageUrl": packageUrl ?: @"",
        @"ConfigId": @"mobile",
        @"IsSupportSmallImageMode": isSupportSmallImageMode ? @YES : @NO
    };

    NSDictionary *config = @{
        @"DigitalHumanId": digitalHumanId ?: @"",
        @"Streams": @[stream]
    };

    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:config options:0 error:&jsonError];
    if (jsonError) {
        NSLog(@"[配置] JSON序列化失败: %@", jsonError);
        return @"";
    }

    NSString *base64String = [jsonData base64EncodedStringWithOptions:0];
    return base64String;
}

/**
 * 更新状态显示
 */
- (void)updateStatus:(NSString *)msg {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.tvStatus.text = [NSString stringWithFormat:@"状态：%@", msg];
        NSLog(@"[状态] %@", msg);
    });
}

/**
 * 清理资源
 */
- (void)cleanup {
    // 停止数字人
    [self stopDigitalHuman];

    // 停止拉流
    if (self.currentStreamId) {
        [self.expressEngine stopPlayingStream:self.currentStreamId];
    }

    // 退出房间
    if (self.isRoomLoggedIn && self.currentRoomId) {
        [self.expressEngine logoutRoom:self.currentRoomId];
        self.isRoomLoggedIn = NO;
    }

    // 销毁引擎
    if (self.expressEngine) {
        [ZegoExpressEngine destroyEngine:nil];
        self.expressEngine = nil;
    }
}

#pragma mark - 10. Delegates

// ========== ZegoDigitalMobileDelegate ==========

- (void)onDigitalMobileStartSuccess {
    [self updateStatus:@"数字人启动成功"];
}

- (void)onError:(int)errorCode errorMsg:(NSString *)errorMsg {
    NSLog(@"[数字人] 错误: %d, %@", errorCode, errorMsg);
    [self updateStatus:[NSString stringWithFormat:@"数字人错误: %@", errorMsg ?: @"未知错误"]];
}

- (void)onSurfaceFirstFrameDraw {
    [self updateStatus:@"数字人播放中"];
}

// ========== ZegoDigitalHumanResourceDelegate ==========

- (void)onPreloadSuccess:(NSString *)digitalHumanId {
    NSLog(@"[数字人] 预加载成功: %@", digitalHumanId);
}

- (void)onPreloadFailed:(NSString *)digitalHumanId
              errorCode:(NSInteger)errorCode
           errorMessage:(NSString *)errorMessage {
    NSLog(@"[数字人] 预加载失败: %@ - code: %ld, msg: %@", digitalHumanId, (long)errorCode, errorMessage);
}

- (void)onPreloadProgress:(NSString *)digitalHumanId
                 progress:(float)progress {
    // 预加载进度（可选显示）
}

// ========== ZegoEventHandler ==========

- (void)onRoomStreamUpdate:(ZegoUpdateType)updateType
                streamList:(NSArray<ZegoStream *> *)streamList
              extendedData:(NSDictionary *)extendedData
                    roomID:(NSString *)roomID {

    if (updateType == ZegoUpdateTypeAdd) {
        for (ZegoStream *stream in streamList) {
            if ([stream.streamID isEqualToString:self.currentStreamId]) {
                [self startPlayingStream:stream.streamID];
                break;
            }
        }
    }
}

- (void)onPlayerSyncRecvSEI:(NSData *)data streamID:(NSString *)streamID {
    if ([streamID isEqualToString:self.currentStreamId] && self.digitalMobile) {
        // 重要：将 SEI 信息设置到数字人 SDK
        [self.digitalMobile onPlayerSyncRecvSEI:streamID data:data];
    }
}

// ========== ZegoCustomVideoRenderHandler ==========

- (void)onRemoteVideoFrameRawData:(unsigned char **)data
                       dataLength:(unsigned int *)dataLength
                            param:(ZegoVideoFrameParam *)param
                         streamID:(NSString *)streamID {

    if (!data || !dataLength || !param || !streamID || ![streamID isEqualToString:self.currentStreamId]) {
        return;
    }

    if (!self.digitalMobile) {
        return;
    }

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

    // 重要：将视频帧数据设置到数字人 SDK
    [self.digitalMobile onRemoteVideoFrameRawData:data
                                            dataLength:dataLength
                                                 param:dmParam
                                              streamID:streamID];
}

@end

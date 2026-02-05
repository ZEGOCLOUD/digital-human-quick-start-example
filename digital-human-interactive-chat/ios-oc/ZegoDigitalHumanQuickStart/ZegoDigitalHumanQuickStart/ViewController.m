//
//  ViewController.m
//  ZegoDigitalHumanQuickStart
//
//  单文件实现 - 对齐Android的MainActivity.kt调用流程
//  Single-file implementation - aligned with Android's MainActivity.kt call flow
//

#import "ViewController.h"
#import "Config.h"
#import <ZegoExpressEngine/ZegoExpressEngine.h>
#import <ZegoDigitalMobile/ZegoDigitalMobile.h>

// ========== 常量定义 / Constant Definitions ==========
// 固定ID以便预加载数字人资源 / Fixed IDs for preloading digital human resources
static NSString *const kFixedUserId = @"user_demo_ios";
static NSString *const kFixedRoomId = @"room_demo_ios";
static NSString *const kFixedStreamId = @"stream_demo_ios";

// ========== 1. 内部接口扩展 ==========
// ========== 1. Internal interface extensions ==========
@interface ViewController () <ZegoDigitalMobileDelegate, ZegoDigitalHumanResourceDelegate, ZegoEventHandler, ZegoCustomVideoRenderHandler>

// 数字人视图（SDK提供的渲染视图）
// Digital human view (rendering view provided by SDK)
@property (nonatomic, strong) ZegoDigitalView *digitalHumanView;

// 播报信息（从API获取）/ Broadcast information (from API)
@property (nonatomic, copy) NSString *digitalHumanId;
@property (nonatomic, copy) NSString *clientInferencePackageUrl;
@property (nonatomic, assign) BOOL isSupportSmallImageMode;

// 用于在预加载成功后启动数字人 / Used to start digital human after successful preload
@property (nonatomic, copy) NSString *pendingBase64Config;

@end

// ========== 2. 实现 ==========
// ========== 2. Implementation ==========
@implementation ViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    // 初始化状态 / Initialize state
    self.isRoomLoggedIn = NO;
    self.isCallStarted = NO;

    // 初始化UI / Initialize UI
    [self initViews];

    // 检查配置 / Check configuration
    if ([Config APP_ID] == 0) {
        [self updateStatus:@"Please configure APP_ID in Config.h"];
        return;
    }

    // 初始化SDK / Initialize SDKs
    [self initSDKs];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    // 页面消失时如果正在通话，则停止通话
    // Stop call if in progress when page disappears
    if (self.isCallStarted) {
        [self stopCall];
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    // 更新数字人视图尺寸以匹配容器
    // Update digital human view frame to match container
    if (self.digitalHumanView && self.digitalHumanContainerView) {
        self.digitalHumanView.frame = self.digitalHumanContainerView.bounds;
        NSLog(@"[Layout] Updated digital human view frame: %@", NSStringFromCGRect(self.digitalHumanView.frame));
    }
}

- (void)dealloc {
    [self cleanup];
}

#pragma mark - 3. UI Setup

- (void)initViews {
    // 使用默认背景色 / Use default background color
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    // 标题标签 / Title label
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"数字人交互聊天示例\nDigital Human Interactive Chat Example";
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    titleLabel.numberOfLines = 0;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:titleLabel];

    // 状态标签 / Status label
    self.tvStatus = [[UILabel alloc] init];
    self.tvStatus.text = @"Status: waiting for initialization...";
    self.tvStatus.font = [UIFont systemFontOfSize:14];
    self.tvStatus.numberOfLines = 0;
    self.tvStatus.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.tvStatus];

    // 说明文字 / Note label
    UILabel *noteLabel = [[UILabel alloc] init];
    noteLabel.text = @"正常逻辑是客户端采集用户说话音频后发送至业务后台\nIn normal operation, the client captures user speech audio and sends it to the backend";
    noteLabel.textColor = [UIColor secondaryLabelColor];
    noteLabel.font = [UIFont systemFontOfSize:11];
    noteLabel.numberOfLines = 0;
    noteLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:noteLabel];

    // 数字人视图容器 / Digital human view container
    self.digitalHumanContainerView = [[UIView alloc] init];
    self.digitalHumanContainerView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.digitalHumanContainerView];

    // Start Call 按钮 / Start Call button
    self.btnStartCall = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.btnStartCall setTitle:@"Start Call\n开始通话" forState:UIControlStateNormal];
    self.btnStartCall.enabled = YES;
    [self.btnStartCall addTarget:self action:@selector(handleStartCall) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.btnStartCall];

    // Stop Call 按钮 / Stop Call button
    self.btnStopCall = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.btnStopCall setTitle:@"Stop Call\n结束通话" forState:UIControlStateNormal];
    self.btnStopCall.enabled = NO;
    [self.btnStopCall addTarget:self action:@selector(handleStopCall) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.btnStopCall];

    // 模拟说话按钮（中文）/ Simulate talk button (Chinese)
    self.btnSimulateTalkZh = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.btnSimulateTalkZh setTitle:@"模拟说话(中文)\nSimulate Speech (ZH)" forState:UIControlStateNormal];
    self.btnSimulateTalkZh.enabled = NO;
    [self.btnSimulateTalkZh addTarget:self action:@selector(handleSimulateTalkZh) forControlEvents:UIControlEventTouchUpInside];
    self.btnSimulateTalkZh.titleLabel.numberOfLines = 0;
    [self.view addSubview:self.btnSimulateTalkZh];

    // 模拟说话按钮（英文）/ Simulate talk button (English)
    self.btnSimulateTalkEn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.btnSimulateTalkEn setTitle:@"模拟说话(英文)\nSimulate Speech (EN)" forState:UIControlStateNormal];
    self.btnSimulateTalkEn.enabled = NO;
    [self.btnSimulateTalkEn addTarget:self action:@selector(handleSimulateTalkEn) forControlEvents:UIControlEventTouchUpInside];
    self.btnSimulateTalkEn.titleLabel.numberOfLines = 0;
    [self.view addSubview:self.btnSimulateTalkEn];

    // 布局约束 / Layout constraints
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.tvStatus.translatesAutoresizingMaskIntoConstraints = NO;
    noteLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.digitalHumanContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    self.btnStartCall.translatesAutoresizingMaskIntoConstraints = NO;
    self.btnStopCall.translatesAutoresizingMaskIntoConstraints = NO;
    self.btnSimulateTalkZh.translatesAutoresizingMaskIntoConstraints = NO;
    self.btnSimulateTalkEn.translatesAutoresizingMaskIntoConstraints = NO;

    [NSLayoutConstraint activateConstraints:@[
        // Title label constraints
        [titleLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:20],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [titleLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],

        // Status label constraints
        [self.tvStatus.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:20],
        [self.tvStatus.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.tvStatus.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],

        // Note label constraints
        [noteLabel.topAnchor constraintEqualToAnchor:self.tvStatus.bottomAnchor constant:10],
        [noteLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [noteLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],

        // Digital human container constraints
        [self.digitalHumanContainerView.topAnchor constraintEqualToAnchor:noteLabel.bottomAnchor constant:20],
        [self.digitalHumanContainerView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.digitalHumanContainerView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.digitalHumanContainerView.heightAnchor constraintEqualToConstant:300],

        // Start/Stop Call buttons
        [self.btnStartCall.topAnchor constraintEqualToAnchor:self.digitalHumanContainerView.bottomAnchor constant:20],
        [self.btnStartCall.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.btnStartCall.trailingAnchor constraintEqualToAnchor:self.view.centerXAnchor constant:-10],
        [self.btnStartCall.heightAnchor constraintEqualToConstant:50],

        [self.btnStopCall.topAnchor constraintEqualToAnchor:self.digitalHumanContainerView.bottomAnchor constant:20],
        [self.btnStopCall.leadingAnchor constraintEqualToAnchor:self.view.centerXAnchor constant:10],
        [self.btnStopCall.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.btnStopCall.heightAnchor constraintEqualToConstant:50],

        // Simulate Talk buttons - vertical layout
        [self.btnSimulateTalkZh.topAnchor constraintEqualToAnchor:self.btnStartCall.bottomAnchor constant:10],
        [self.btnSimulateTalkZh.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.btnSimulateTalkZh.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.btnSimulateTalkZh.heightAnchor constraintEqualToConstant:50],

        [self.btnSimulateTalkEn.topAnchor constraintEqualToAnchor:self.btnSimulateTalkZh.bottomAnchor constant:10],
        [self.btnSimulateTalkEn.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.btnSimulateTalkEn.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.btnSimulateTalkEn.heightAnchor constraintEqualToConstant:50],
    ]];
}

#pragma mark - 4. SDK Initialization

/**
 * 初始化 Express SDK 和数字人 SDK
 * Initialize Express SDK and Digital Human SDK
 */
- (void)initSDKs {
    // 初始化 Express SDK / Initialize Express SDK
    ZegoEngineProfile *profile = [[ZegoEngineProfile alloc] init];
    profile.appID = (unsigned int)[Config APP_ID];
    profile.scenario = ZegoScenarioHighQualityChatroom;

    self.expressEngine = [ZegoExpressEngine createEngineWithProfile:profile eventHandler:self];

    // 初始化数字人SDK / Initialize Digital Human SDK
    self.digitalMobile = [ZegoDigitalHuman create];

    // 创建数字人视图并绑定 / Create and bind digital human view
    self.digitalHumanView = [[ZegoDigitalView alloc] initWithFrame:self.digitalHumanContainerView.bounds];
    self.digitalHumanView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.digitalHumanContainerView addSubview:self.digitalHumanView];

    [self.digitalMobile attach:self.digitalHumanView];

    // 预加载数字人资源 / Preload digital human resources
    [self updateStatus:@"Preloading digital human resources..."];
    NSString *token = [self fetchToken:kFixedUserId];
    if (token) {
        ZegoDigitalHumanAuth *auth = [[ZegoDigitalHumanAuth alloc] initWithAppID:(unsigned int)[Config APP_ID]
                                                                            userID:kFixedUserId
                                                                             token:token];
        [[ZegoDigitalHumanResource sharedInstance] preloadWithAuth:auth
                                                   digitalHumanId:[Config DIGITAL_HUMAN_ID]
                                                         delegate:self];
        NSLog(@"[DigitalHuman] Starting resource preload: %@", [Config DIGITAL_HUMAN_ID]);
    }

    [self updateStatus:@"waiting for initialization..."];
}

#pragma mark - 5. Main Flow

/**
 * 开始通话
 * Start call
 */
- (void)startCall {
    // 在后台线程执行网络请求 / Execute network requests in background thread
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @try {
            // 1. 使用固定ID / Use fixed IDs
            [self updateStatus:@"Initializing..."];
            self.currentUserId = kFixedUserId;
            NSString *roomId = kFixedRoomId;
            NSString *streamId = kFixedStreamId;

            // 2. 调用服务端创建数字人任务 / Call server to create digital human task
            [self updateStatus:@"Creating digital human task..."];
            NSDictionary *taskInfo = [self createDigitalHumanTask:roomId streamId:streamId];
            if (!taskInfo) {
                [self updateStatus:@"Failed to create task"];
                return;
            }

            // 保存任务信息 / Save task information
            self.currentTaskId = taskInfo[@"taskId"];
            self.currentRoomId = taskInfo[@"roomId"];
            self.currentStreamId = taskInfo[@"streamId"];
            self.digitalHumanId = [Config DIGITAL_HUMAN_ID]; // 与服务端协商一致
            self.clientInferencePackageUrl = taskInfo[@"clientInferencePackageUrl"];
            self.isSupportSmallImageMode = [taskInfo[@"isSupportSmallImageMode"] boolValue];

            NSLog(@"[Task] Task created - TaskId: %@", self.currentTaskId);

            // 3. 获取Token / Get Token
            [self updateStatus:@"Fetching token..."];
            NSString *token = [self fetchToken:self.currentUserId];
            if (!token) {
                [self updateStatus:@"Failed to fetch token"];
                return;
            }

            // 4. 登录房间（登录成功后会启动数字人SDK）/ Login room (digital human SDK will start after successful login)
            [self updateStatus:@"Logging in to room..."];
            [self loginRoom:self.currentRoomId streamId:self.currentStreamId userId:self.currentUserId token:token];

        } @catch (NSException *exception) {
            NSLog(@"[Error] Start call failed: %@", exception.reason);
            [self updateStatus:[NSString stringWithFormat:@"Start failed: %@", exception.reason]];
        }
    });
}

#pragma mark - 6. API Calls (Inline - 对齐Android的OkHttp调用)
// #pragma mark - 6. API Calls (Inline - aligned with Android's OkHttp calls)

/**
 * 创建数字人任务 - 对齐Android的createDigitalHumanTask()
 * Create digital human task - aligned with Android's createDigitalHumanTask()
 * POST /api/digital-human/create-task
 */
- (NSDictionary *)createDigitalHumanTask:(NSString *)roomId streamId:(NSString *)streamId {
    NSString *urlString = [NSString stringWithFormat:@"%@/api/digital-human/create-task", [Config API_BASE_URL]];
    NSURL *url = [NSURL URLWithString:urlString];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    // 构建请求体 (digitalHumanId 由服务端环境变量配置)
    // Build request body (digitalHumanId is configured in server env)
    NSDictionary *bodyDict = @{
        @"roomId": roomId,
        @"streamId": streamId,
        @"outputMode": @2  // Mobile 模式 / Mobile mode
    };

    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:bodyDict options:0 error:&jsonError];
    if (jsonError) {
        NSLog(@"[API] Failed to serialize request body: %@", jsonError);
        return nil;
    }

    request.HTTPBody = jsonData;

    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
    if (!data) {
        NSLog(@"[API] Failed to create task: No response");
        return nil;
    }

    id jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    if (jsonError || ![jsonResponse isKindOfClass:[NSDictionary class]]) {
        NSLog(@"[API] Failed to parse response: %@", jsonError);
        return nil;
    }

    NSDictionary *json = (NSDictionary *)jsonResponse;
    if (![json[@"success"] boolValue]) {
        NSLog(@"[API] Create task failed: %@", json[@"error"]);
        return nil;
    }

    // 验证必需字段
    // Validate required fields
    NSString *taskId = json[@"taskId"];
    NSString *respRoomId = json[@"roomId"];
    NSString *respStreamId = json[@"streamId"];
    NSString *digitalHumanId = json[@"digitalHumanId"];
    NSString *packageUrl = json[@"clientInferencePackageUrl"];

    if (!taskId || !respRoomId || !respStreamId || !digitalHumanId || !packageUrl) {
        NSLog(@"[API] Incomplete task information");
        return nil;
    }

    return @{
        @"taskId": taskId,
        @"roomId": respRoomId,
        @"streamId": respStreamId,
        @"digitalHumanId": digitalHumanId,
        @"clientInferencePackageUrl": packageUrl,
        @"isSupportSmallImageMode": json[@"isSupportSmallImageMode"] ?: @NO
    };
}

/**
 * 获取Token - 对齐Android的fetchToken()
 * Fetch token - aligned with Android's fetchToken()
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
        NSLog(@"[API] Failed to fetch token: No response");
        return nil;
    }

    NSError *jsonError = nil;
    id jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    if (jsonError || ![jsonResponse isKindOfClass:[NSDictionary class]]) {
        NSLog(@"[API] Failed to parse token: %@", jsonError);
        return nil;
    }

    NSDictionary *json = (NSDictionary *)jsonResponse;
    NSString *token = json[@"token"];
    return token;
}

/**
 * 停止数字人任务
 * Stop digital human task
 * POST /api/digital-human/stop-task
 */
- (void)stopDigitalHumanTask:(NSString *)taskId {
    NSString *urlString = [NSString stringWithFormat:@"%@/api/digital-human/stop-task", [Config API_BASE_URL]];
    NSURL *url = [NSURL URLWithString:urlString];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    NSDictionary *bodyDict = @{@"taskId": taskId};
    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:bodyDict options:0 error:&jsonError];
    if (jsonError) {
        NSLog(@"[API] Failed to serialize request body: %@", jsonError);
        return;
    }

    request.HTTPBody = jsonData;

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            NSLog(@"[API] Stop task failed: %@", error);
            return;
        }

        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode != 200) {
            NSLog(@"[API] Stop task failed with status code: %ld", (long)httpResponse.statusCode);
            return;
        }

        NSLog(@"[API] Task stopped successfully");
    }];

    [task resume];
}

#pragma mark - 7. RTC Operations

/**
 * 登录房间
 * Login room
 */
- (void)loginRoom:(NSString *)roomId
          streamId:(NSString *)streamId
            userId:(NSString *)userId
             token:(NSString *)token {

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
    [self.expressEngine loginRoom:roomId user:user config:roomConfig callback:^(int errorCode, NSDictionary * _Nullable extendedData) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        if (errorCode == 0) {
            strongSelf.isRoomLoggedIn = YES;
            NSLog(@"[RTC] Room login successful");

            // 登录成功后：开启自定义渲染 / After successful login: enable custom video rendering
            [strongSelf enableCustomVideoRender];

            // 生成配置 / Generate configuration
            NSString *base64Config = [strongSelf generateBase64Config:strongSelf.digitalHumanId
                                                                 roomId:strongSelf.currentRoomId
                                                              streamId:strongSelf.currentStreamId
                                                            packageUrl:strongSelf.clientInferencePackageUrl
                                                 isSupportSmallImageMode:strongSelf.isSupportSmallImageMode];

            // 打印base64config用于调试 / Print base64config for debugging
            NSLog(@"[Config] Base64Config: %@", base64Config);

            // 启动数字人SDK / Start digital human SDK
            [strongSelf startDigitalHumanSDK:base64Config];
        } else {
            NSLog(@"[RTC] Room login failed: %d", errorCode);
            [strongSelf updateStatus:[NSString stringWithFormat:@"Room login failed: %d", errorCode]];
        }
    }];
}

/**
 * 开启自定义视频渲染 - 对齐Android的enableCustomVideoRender()
 * Enable custom video rendering - aligned with Android's enableCustomVideoRender()
 */
- (void)enableCustomVideoRender {
    ZegoCustomVideoRenderConfig *renderConfig = [[ZegoCustomVideoRenderConfig alloc] init];
    renderConfig.bufferType = ZegoVideoBufferTypeRawData;
    renderConfig.frameFormatSeries = ZegoVideoFrameFormatSeriesRGB;
    renderConfig.enableEngineRender = NO;
    [self.expressEngine enableCustomVideoRender:YES config:renderConfig];

    // 设置视频帧回调
    // Set video frame callback
    [self.expressEngine setCustomVideoRenderHandler:self];

    NSLog(@"[RTC] Custom video rendering enabled");
}

/**
 * 开始拉流 - 对齐Android的startPlayingStream()
 * Start playing stream - aligned with Android's startPlayingStream()
 */
- (void)startPlayingStream:(NSString *)streamID {
    // 设置拉流缓冲区
    // Set stream buffer interval range
    [self.expressEngine setPlayStreamBufferIntervalRange:streamID min:100 max:2000];

    // 开始拉流 / Start playing stream
    [self.expressEngine startPlayingStream:streamID];

    [self updateStatus:@"Playing..."];
    NSLog(@"[RTC] Started playing stream: %@", streamID);
}

#pragma mark - 8. Digital Human

/**
 * 启动数字人SDK - 对齐Android的startDigitalHumanSDK()
 * Start digital human SDK - aligned with Android's startDigitalHumanSDK()
 */
- (void)startDigitalHumanSDK:(NSString *)base64Config {
    if (!self.digitalMobile) {
        [self updateStatus:@"SDK not initialized"];
        return;
    }

    @try {
        NSLog(@"[DigitalHuman] Starting digital human SDK with config...");
        NSLog(@"[DigitalHuman] DigitalHumanID: %@", self.digitalHumanId);
        NSLog(@"[DigitalHuman] RoomID: %@", self.currentRoomId);
        NSLog(@"[DigitalHuman] StreamID: %@", self.currentStreamId);

        [self.digitalMobile start:base64Config delegate:self];

        NSLog(@"[DigitalHuman] SDK start method called successfully");
        [self updateStatus:@"Digital human SDK started"];
    } @catch (NSException *exception) {
        NSLog(@"[DigitalHuman] Startup failed: %@", exception.reason);
        NSLog(@"[DigitalHuman] Exception stack: %@", exception.callStackSymbols);
        [self updateStatus:[NSString stringWithFormat:@"Failed to start: %@", exception.reason]];
    }
}

/**
 * 停止数字人
 * Stop digital human
 */
- (void)stopDigitalHuman {
    if (self.digitalMobile) {
        [self.digitalMobile stop];
        self.digitalMobile = nil;
    }
    NSLog(@"[DigitalHuman] Digital human stopped");
}

#pragma mark - 9. Helper Methods

/**
 * 生成 Base64Config - 对齐Android的generateBase64Config()
 * Generate Base64Config - aligned with Android's generateBase64Config()
 */
- (NSString *)generateBase64Config:(NSString *)digitalHumanId
                           roomId:(NSString *)roomId
                        streamId:(NSString *)streamId
                      packageUrl:(NSString *)packageUrl
       isSupportSmallImageMode:(BOOL)isSupportSmallImageMode {

    // 构建Streams配置
    // Build Streams configuration
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
        NSLog(@"[Config] JSON serialization failed: %@", jsonError);
        return @"";
    }

    // 打印原始配置JSON用于调试 / Print raw config JSON for debugging
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    NSLog(@"[Config] Raw config JSON: %@", jsonString);

    NSString *base64String = [jsonData base64EncodedStringWithOptions:0];
    return base64String;
}

/**
 * 结束通话
 * Stop call
 */
- (void)stopCall {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @try {
            [self updateStatus:@"Stopping call..."];

            // 1. 停止数字人SDK / Stop digital human SDK
            [self.digitalMobile stop];

            // 2. 停止拉流 / Stop playing stream
            if (self.currentStreamId) {
                [self.expressEngine stopPlayingStream:self.currentStreamId];
            }

            // 3. 退出房间 / Logout room
            if (self.isRoomLoggedIn && self.currentRoomId) {
                [self.expressEngine logoutRoom:self.currentRoomId];
                self.isRoomLoggedIn = NO;
            }

            // 4. 调用服务端停止任务 / Call server to stop task
            if (self.currentTaskId) {
                [self stopDigitalHumanTask:self.currentTaskId];
            }

            self.isCallStarted = NO;
            self.currentTaskId = nil;
            self.currentRoomId = nil;
            self.currentStreamId = nil;

            [self updateUI];
            [self updateStatus:@"waiting for initialization..."];

        } @catch (NSException *exception) {
            NSLog(@"[Error] Stop call failed: %@", exception.reason);
            [self updateStatus:[NSString stringWithFormat:@"Stop failed: %@", exception.reason]];
        }
    });
}

/**
 * 开始通话按钮点击
 * Start call button clicked
 */
- (void)handleStartCall {
    [self startCall];
}

/**
 * 结束通话按钮点击
 * Stop call button clicked
 */
- (void)handleStopCall {
    [self stopCall];
}

/**
 * 更新UI状态
 * Update UI state
 */
- (void)updateUI {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.btnStartCall.enabled = !self.isCallStarted;
        self.btnStopCall.enabled = self.isCallStarted;
        self.btnSimulateTalkZh.enabled = self.isCallStarted;
        self.btnSimulateTalkEn.enabled = self.isCallStarted;
    });
}

/**
 * 更新状态显示
 * Update status display
 */
- (void)updateStatus:(NSString *)msg {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.tvStatus.text = [NSString stringWithFormat:@"Status: %@", msg];
        NSLog(@"[Status] %@", msg);
    });
}

/**
 * 模拟说话（中文）
 * Simulate talk (Chinese)
 */
- (void)handleSimulateTalkZh {
    [self simulateTalkWithLang:@"zh"];
}

/**
 * 模拟说话（英文）
 * Simulate talk (English)
 */
- (void)handleSimulateTalkEn {
    [self simulateTalkWithLang:@"en"];
}

/**
 * 模拟说话
 * Simulate talk
 */
- (void)simulateTalkWithLang:(NSString *)lang {
    // 注释说明: 实际场景中,这里应该采集麦克风音频数据
    // Note: In actual scenario, microphone audio data should be captured here
    // 本示例为模拟,直接调用服务端接口
    // This example simulates by directly calling server API

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @try {
            NSString *langText = [lang isEqualToString:@"en"] ? @"English" : @"Chinese";
            [self updateStatus:[NSString stringWithFormat:@"AI interacting (%@)...", langText]];

            NSString *urlString = [NSString stringWithFormat:@"%@/api/digital-human/talk-to-ai", [Config API_BASE_URL]];
            NSURL *url = [NSURL URLWithString:urlString];

            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
            request.HTTPMethod = @"POST";
            [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

            // 构建请求体 / Build request body
            NSDictionary *bodyDict = @{
                @"taskId": self.currentTaskId ?: @"",
                @"lang": lang
            };

            NSError *jsonError = nil;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:bodyDict options:0 error:&jsonError];
            if (jsonError) {
                NSLog(@"[API] Failed to serialize request body: %@", jsonError);
                [self updateStatus:@"Failed to serialize"];
                return;
            }

            request.HTTPBody = jsonData;

            NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
            if (data) {
                [self updateStatus:@"AI responding..."];
            } else {
                [self updateStatus:@"Request failed"];
            }
        } @catch (NSException *exception) {
            NSLog(@"[Error] Simulate talk failed: %@", exception.reason);
            [self updateStatus:[NSString stringWithFormat:@"Failed: %@", exception.reason]];
        }
    });
}

/**
 * 清理资源
 * Cleanup resources
 */
- (void)cleanup {
    // 停止数字人 / Stop digital human
    [self stopDigitalHuman];

    // 停止拉流 / Stop playing stream
    if (self.currentStreamId) {
        [self.expressEngine stopPlayingStream:self.currentStreamId];
    }

    // 退出房间 / Logout room
    if (self.isRoomLoggedIn && self.currentRoomId) {
        [self.expressEngine logoutRoom:self.currentRoomId];
        self.isRoomLoggedIn = NO;
    }

    // 销毁引擎 / Destroy engine
    if (self.expressEngine) {
        [ZegoExpressEngine destroyEngine:nil];
        self.expressEngine = nil;
    }

    // 禁用按钮 / Disable buttons
    self.btnSimulateTalkZh.enabled = NO;
    self.btnSimulateTalkEn.enabled = NO;
}

#pragma mark - 10. Delegates

// ========== ZegoDigitalMobileDelegate ==========

- (void)onDigitalMobileStartSuccess {
    [self updateStatus:@"Digital human started successfully"];
    NSLog(@"[DigitalHuman] SDK started successfully, waiting for first frame...");
}

- (void)onError:(int)errorCode errorMsg:(NSString *)errorMsg {
    NSLog(@"[DigitalHuman] Error: %d, %@", errorCode, errorMsg);
    [self updateStatus:[NSString stringWithFormat:@"Error: %@", errorMsg ?: @"Unknown"]];
}

- (void)onSurfaceFirstFrameDraw {
    [self updateStatus:@"In call"];
    NSLog(@"[DigitalHuman] First frame rendered, task is now ready");

    // 第一帧渲染后才启用按钮 / Enable buttons only after first frame is rendered
    dispatch_async(dispatch_get_main_queue(), ^{
        self.btnSimulateTalkZh.enabled = YES;
        self.btnSimulateTalkEn.enabled = YES;
        NSLog(@"[DigitalHuman] Talk buttons enabled");
    });
}

// ========== ZegoDigitalHumanResourceDelegate ==========

- (void)onPreloadSuccess:(NSString *)digitalHumanId {
    NSLog(@"[DigitalHuman] Preload success: %@", digitalHumanId);
}

- (void)onPreloadFailed:(NSString *)digitalHumanId
              errorCode:(NSInteger)errorCode
           errorMessage:(NSString *)errorMessage {
    NSLog(@"[DigitalHuman] Preload failed: %@ - code: %ld, msg: %@", digitalHumanId, (long)errorCode, errorMessage);
}

- (void)onPreloadProgress:(NSString *)digitalHumanId
                 progress:(float)progress {
    // 预加载进度（可选显示）
    // Preload progress (optional display)
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
        // IMPORTANT: Set SEI data to digital human SDK
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
    // Create ZDMVideoFrameParam
    ZDMVideoFrameParam *dmParam = [[ZDMVideoFrameParam alloc] init];

    // 转换format / Convert format (对齐Android / aligned with Android)
    switch (param.format) {
        case ZegoVideoFrameFormatI420:
            dmParam.format = ZDMVideoFrameFormatI420;
            break;
        case ZegoVideoFrameFormatNV12:
            dmParam.format = ZDMVideoFrameFormatNV12;
            break;
        case ZegoVideoFrameFormatNV21:
            dmParam.format = ZDMVideoFrameFormatNV21;
            break;
        default:
            dmParam.format = ZDMVideoFrameFormatUnknown;
            break;
    }

    dmParam.width = param.size.width;
    dmParam.height = param.size.height;
    dmParam.rotation = param.rotation;

    // 设置步长
    // Set strides
    for (int i = 0; i < 4; i++) {
        [dmParam setStride:param.strides[i] atIndex:i];
    }

    // 重要：将视频帧数据设置到数字人 SDK
    // IMPORTANT: Set video frame data to digital human SDK
    [self.digitalMobile onRemoteVideoFrameRawData:data
                                            dataLength:dataLength
                                                 param:dmParam
                                              streamID:streamID];
}

@end

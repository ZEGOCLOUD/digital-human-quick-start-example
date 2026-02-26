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

// ========== 常量定义 / Constant Definitions ==========
// ID前缀（用于生成动态ID）/ ID prefixes (for generating dynamic IDs)
static NSString *const kUserIdPrefix = @"user_demo_ios";
static NSString *const kRoomIdPrefix = @"room_demo_ios";
static NSString *const kStreamIdPrefix = @"stream_demo_ios";

// ========== 1. 内部接口扩展 ==========
// ========== 1. Internal interface extensions ==========
@interface ViewController () <ZegoEventHandler>

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

    // 初始化SDK / Initialize SDK
    [self initSDK];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    // 页面消失时如果正在通话，则停止通话
    // Stop call if in progress when page disappears
    if (self.isCallStarted) {
        [self stopCall];
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
    titleLabel.text = @"数字人交互聊天\nDigital Human Chat";
    titleLabel.font = [UIFont boldSystemFontOfSize:14];
    titleLabel.numberOfLines = 0;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:titleLabel];

    // 状态标签 / Status label
    self.tvStatus = [[UILabel alloc] init];
    self.tvStatus.text = @"Status: waiting...";
    self.tvStatus.font = [UIFont systemFontOfSize:11];
    self.tvStatus.numberOfLines = 0;
    self.tvStatus.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.tvStatus];

    // 说明文字 / Note label
    UILabel *noteLabel = [[UILabel alloc] init];
    noteLabel.text = @"正常逻辑是客户端采集用户说话音频后发送至业务后台\nIn normal operation, the client captures user speech audio and sends it to the backend";
    noteLabel.textColor = [UIColor secondaryLabelColor];
    noteLabel.font = [UIFont systemFontOfSize:9];
    noteLabel.numberOfLines = 0;
    noteLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:noteLabel];

    // 远端视频视图 / Remote video view
    self.remoteVideoView = [[UIView alloc] init];
    self.remoteVideoView.backgroundColor = [UIColor blackColor];
    [self.view addSubview:self.remoteVideoView];

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
    self.remoteVideoView.translatesAutoresizingMaskIntoConstraints = NO;
    self.btnStartCall.translatesAutoresizingMaskIntoConstraints = NO;
    self.btnStopCall.translatesAutoresizingMaskIntoConstraints = NO;
    self.btnSimulateTalkZh.translatesAutoresizingMaskIntoConstraints = NO;
    self.btnSimulateTalkEn.translatesAutoresizingMaskIntoConstraints = NO;

    [NSLayoutConstraint activateConstraints:@[
        // Title label constraints - minimal top spacing
        [titleLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:2],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [titleLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],

        // Status label constraints - minimal spacing
        [self.tvStatus.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:2],
        [self.tvStatus.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [self.tvStatus.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],

        // Note label constraints - minimal spacing
        [noteLabel.topAnchor constraintEqualToAnchor:self.tvStatus.bottomAnchor constant:2],
        [noteLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [noteLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],

        // Remote video view constraints - maximize height
        [self.remoteVideoView.topAnchor constraintEqualToAnchor:noteLabel.bottomAnchor constant:4],
        [self.remoteVideoView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.remoteVideoView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.remoteVideoView.heightAnchor constraintEqualToConstant:500],

        // Start/Stop Call buttons - compact
        [self.btnStartCall.topAnchor constraintEqualToAnchor:self.remoteVideoView.bottomAnchor constant:4],
        [self.btnStartCall.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [self.btnStartCall.trailingAnchor constraintEqualToAnchor:self.view.centerXAnchor constant:-4],
        [self.btnStartCall.heightAnchor constraintEqualToConstant:36],

        [self.btnStopCall.topAnchor constraintEqualToAnchor:self.remoteVideoView.bottomAnchor constant:4],
        [self.btnStopCall.leadingAnchor constraintEqualToAnchor:self.view.centerXAnchor constant:4],
        [self.btnStopCall.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
        [self.btnStopCall.heightAnchor constraintEqualToConstant:36],

        // Simulate Talk buttons - compact vertical layout
        [self.btnSimulateTalkZh.topAnchor constraintEqualToAnchor:self.btnStartCall.bottomAnchor constant:4],
        [self.btnSimulateTalkZh.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [self.btnSimulateTalkZh.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
        [self.btnSimulateTalkZh.heightAnchor constraintEqualToConstant:36],

        [self.btnSimulateTalkEn.topAnchor constraintEqualToAnchor:self.btnSimulateTalkZh.bottomAnchor constant:4],
        [self.btnSimulateTalkEn.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [self.btnSimulateTalkEn.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
        [self.btnSimulateTalkEn.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-4],
        [self.btnSimulateTalkEn.heightAnchor constraintEqualToConstant:36],
    ]];
}

#pragma mark - 4. SDK Initialization

/**
 * 初始化 Express SDK
 * Initialize Express SDK
 */
- (void)initSDK {
    ZegoEngineProfile *profile = [[ZegoEngineProfile alloc] init];
    profile.appID = (unsigned int)[Config APP_ID];
    profile.scenario = ZegoScenarioHighQualityChatroom;

    self.expressEngine = [ZegoExpressEngine createEngineWithProfile:profile eventHandler:self];

    [self updateStatus:@"Ready"];
    NSLog(@"[SDK] Express engine initialized");
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
            // 1. 生成动态ID，仅作示例使用 / Generate dynamic IDs, only for example usage
            [self updateStatus:@"Initializing..."];
            self.currentUserId = [self generateDynamicId:kUserIdPrefix];
            NSString *roomId = [self generateDynamicId:kRoomIdPrefix];
            NSString *streamId = [self generateDynamicId:kStreamIdPrefix];

            // 2. 调用服务端创建数字人任务 / Call server to create digital human task
            [self updateStatus:@"Creating digital human task..."];
            NSString *taskId = [self createDigitalHumanTask:roomId streamId:streamId];
            if (!taskId) {
                [self updateStatus:@"Failed to create task"];
                return;
            }

            // 保存任务信息 / Save task information
            self.currentTaskId = taskId;
            self.currentRoomId = roomId;  // 使用客户端生成的 roomId
            self.currentStreamId = streamId;  // 使用客户端生成的 streamId

            NSLog(@"[Task] Task created - TaskId: %@", self.currentTaskId);

            // 3. 获取Token / Get Token
            [self updateStatus:@"Fetching token..."];
            NSString *token = [self fetchToken:self.currentUserId];
            if (!token) {
                [self updateStatus:@"Failed to fetch token"];
                return;
            }

            // 4. 登录房间 / Login room
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
 * 创建数字人任务 - 对齐 Android 的 createDigitalHumanTask()
 * Create digital human task - aligned with Android's createDigitalHumanTask()
 * POST /api/digital-human/create-task
 *
 * 请求参数说明 / Request parameters:
 * - roomId: 数字人加入的 RTC 房间 ID，每个用户应使用不同的房间 ID
 *   Digital human's RTC room ID, each user should use a different room ID
 * - streamId: 数字人推流的流 ID
 *   Digital human's stream ID for pushing stream
 *
 * @return 任务 ID / Task ID
 */
- (NSString *)createDigitalHumanTask:(NSString *)roomId streamId:(NSString *)streamId {
    NSString *urlString = [NSString stringWithFormat:@"%@/api/digital-human/create-task", [Config API_BASE_URL]];
    NSURL *url = [NSURL URLWithString:urlString];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    // 构建请求体 (digitalHumanId 由服务端环境变量配置)
    // Build request body (digitalHumanId is configured in server env)
    NSDictionary *bodyDict = @{
        @"roomId": roomId,
        @"streamId": streamId
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
    // roomId 由客户端生成，直接使用传入参数 // roomId is generated by client, use passed parameter
    // streamId 由客户端生成，直接使用传入参数 // streamId is generated by client, use passed parameter

    if (!taskId) {
        NSLog(@"[API] Incomplete task information");
        return nil;
    }

    return taskId;
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
            strongSelf.isCallStarted = YES;
            NSLog(@"[RTC] Room login successful");

            // 更新UI状态 / Update UI state
            [strongSelf updateUI];
            [strongSelf updateStatus:@"In call, waiting for stream..."];
        } else {
            NSLog(@"[RTC] Room login failed: %d", errorCode);
            [strongSelf updateStatus:[NSString stringWithFormat:@"Room login failed: %d", errorCode]];
        }
    }];
}

/**
 * 开始拉流 - 对齐Android的startPlayingStream()
 * Start playing stream - aligned with Android's startPlayingStream()
 */
- (void)startPlayingStream:(NSString *)streamID {
    // 使用 ZegoCanvas 包装 UIView 进行渲染
    // Use ZegoCanvas to wrap UIView for rendering
    ZegoCanvas *canvas = [ZegoCanvas canvasWithView:self.remoteVideoView];
    [self.expressEngine startPlayingStream:streamID canvas:canvas];

    [self updateStatus:@"Playing..."];
    NSLog(@"[RTC] Started playing stream: %@", streamID);
}

#pragma mark - 8. Helper Methods


- (NSString *)generateDynamicId:(NSString *)prefix {
    NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];
    NSInteger timestampInt = (NSInteger)timestamp;
    // 取最后6位 / Take last 6 digits
    NSInteger sixDigits = timestampInt % 1000000;
    return [NSString stringWithFormat:@"%@_%06ld", prefix, (long)sixDigits];
}

/**
 * 结束通话
 * Stop call
 */
- (void)stopCall {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @try {
            [self updateStatus:@"Stopping call..."];

            // 1. 停止拉流 / Stop playing stream
            if (self.currentStreamId) {
                [self.expressEngine stopPlayingStream:self.currentStreamId];
            }

            // 2. 退出房间 / Logout room
            if (self.isRoomLoggedIn && self.currentRoomId) {
                [self.expressEngine logoutRoom:self.currentRoomId];
                self.isRoomLoggedIn = NO;
            }

            // 3. 调用服务端停止任务 / Call server to stop task
            if (self.currentTaskId) {
                [self stopDigitalHumanTask:self.currentTaskId];
            }

            self.isCallStarted = NO;
            self.currentTaskId = nil;
            self.currentRoomId = nil;
            self.currentStreamId = nil;

            [self updateUI];
            [self updateStatus:@"Ready"];

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

#pragma mark - 9. Delegates

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

@end

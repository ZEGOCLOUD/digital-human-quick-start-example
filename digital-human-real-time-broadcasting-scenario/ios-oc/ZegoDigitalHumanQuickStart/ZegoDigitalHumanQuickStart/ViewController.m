//
//  ViewController.m
//  ZegoDigitalHumanQuickStart
//
//  单文件实现 - 对齐Android的MainActivity.kt调用流程
//  Single-file implementation - aligned with Android's MainActivity.kt call flow
//  核心流程：获取播报列表 → 获取Token → 登录房间 → 拉流渲染
//  Core flow: Fetch broadcast list → Get token → Login room → Play stream
//

#import "ViewController.h"
#import "Config.h"
#import <ZegoExpressEngine/ZegoExpressEngine.h>

// ========== 1. 内部接口扩展 ==========
// ========== 1. Internal interface extensions ==========
@interface ViewController () <ZegoEventHandler>

// SDK实例
// SDK instance
@property (nonatomic, strong) ZegoExpressEngine *expressEngine;

// 房间信息
// Room information
@property (nonatomic, copy) NSString *currentRoomId;
@property (nonatomic, copy) NSString *currentStreamId;
@property (nonatomic, copy) NSString *currentUserId;
@property (nonatomic, assign) BOOL isRoomLoggedIn;

@end

// ========== 2. 实现 ==========
// ========== 2. Implementation ==========
@implementation ViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    // 初始化状态
    // Initialize state
    self.isRoomLoggedIn = NO;

    // 初始化UI
    // Initialize UI
    [self initViews];

    // 检查配置
    // Check configuration
    if ([Config APP_ID] == 0) {
        [self updateStatus:@"Please configure APP_ID in Config.h"];
        return;
    }

    // 初始化SDK
    // Initialize SDK
    [self initSDK];

    // 启动数字人播放流程
    // Start digital human playback process
    [self startDigitalHuman];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    // 页面消失时清理资源
    // Cleanup resources when page disappears
    [self cleanup];
}

- (void)dealloc {
    [self cleanup];
}

#pragma mark - 3. UI Setup

- (void)initViews {
    self.view.backgroundColor = [UIColor colorWithRed:0.4 green:0.5 blue:0.9 alpha:1.0];

    // 状态标签
    // Status label
    self.tvStatus = [[UILabel alloc] init];
    self.tvStatus.text = @"Status: Initializing...";
    self.tvStatus.textColor = [UIColor whiteColor];
    self.tvStatus.font = [UIFont systemFontOfSize:14];
    self.tvStatus.numberOfLines = 0;
    self.tvStatus.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.tvStatus];

    // 房间信息标签
    // Room information label
    self.tvRoomInfo = [[UILabel alloc] init];
    self.tvRoomInfo.text = @"Room: -- | Stream: --";
    self.tvRoomInfo.textColor = [UIColor whiteColor];
    self.tvRoomInfo.font = [UIFont systemFontOfSize:12];
    self.tvRoomInfo.numberOfLines = 0;
    self.tvRoomInfo.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.tvRoomInfo];

    // 远端视频视图容器
    // Remote video view container
    self.remoteVideoView = [[UIView alloc] init];
    self.remoteVideoView.backgroundColor = [UIColor blackColor];
    [self.view addSubview:self.remoteVideoView];

    // 布局约束
    // Layout constraints
    self.tvStatus.translatesAutoresizingMaskIntoConstraints = NO;
    self.tvRoomInfo.translatesAutoresizingMaskIntoConstraints = NO;
    self.remoteVideoView.translatesAutoresizingMaskIntoConstraints = NO;

    [NSLayoutConstraint activateConstraints:@[
        [self.tvStatus.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:20],
        [self.tvStatus.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.tvStatus.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],

        [self.tvRoomInfo.topAnchor constraintEqualToAnchor:self.tvStatus.bottomAnchor constant:10],
        [self.tvRoomInfo.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.tvRoomInfo.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],

        [self.remoteVideoView.topAnchor constraintEqualToAnchor:self.tvRoomInfo.bottomAnchor constant:20],
        [self.remoteVideoView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.remoteVideoView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.remoteVideoView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
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

    NSLog(@"[SDK] Express engine initialized");
}

#pragma mark - 5. Main Flow

/**
 * 启动数字人播放流程 - 对齐Android的startDigitalHuman()
 * Start digital human playback process - aligned with Android's startDigitalHuman()
 */
- (void)startDigitalHuman {
    // 在后台线程执行网络请求
    // Execute network requests in background thread
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @try {
            // 步骤1: 从业务后台获取播报列表
            // Step 1: Fetch broadcast list from backend
            [self updateStatus:@"Fetching broadcast list..."];
            NSDictionary *broadcast = [self fetchBroadcastList];
            if (!broadcast) {
                [self updateStatus:@"No available broadcast, please start broadcast task on server first"];
                return;
            }

            // 保存房间信息
            // Save room information
            self.currentRoomId = broadcast[@"roomId"];
            self.currentStreamId = broadcast[@"streamId"];

            dispatch_async(dispatch_get_main_queue(), ^{
                self.tvRoomInfo.text = [NSString stringWithFormat:@"Room: %@ | Stream: %@", self.currentRoomId, self.currentStreamId];
            });

            // 步骤2: 获取Token
            // Step 2: Get token
            [self updateStatus:@"Fetching token..."];
            self.currentUserId = [NSString stringWithFormat:@"user_%lld", (long long)([[NSDate date] timeIntervalSince1970] * 1000)];
            NSString *token = [self fetchToken:self.currentUserId];
            if (!token) {
                [self updateStatus:@"Failed to fetch token"];
                return;
            }

            // 步骤3: 登录房间
            // Step 3: Login to room
            [self updateStatus:@"Logging in to room..."];
            [self loginRoom:self.currentRoomId streamId:self.currentStreamId userId:self.currentUserId token:token];

        } @catch (NSException *exception) {
            NSLog(@"[Error] Startup failed: %@", exception.reason);
            [self updateStatus:[NSString stringWithFormat:@"Startup failed: %@", exception.reason]];
        }
    });
}

#pragma mark - 6. API Calls (Inline - 对齐Android的OkHttp调用)
// #pragma mark - 6. API Calls (Inline - aligned with Android's OkHttp calls)

/**
 * 获取播报列表 - 对齐Android的fetchBroadcastList()
 * Fetch broadcast list - aligned with Android's fetchBroadcastList()
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
        NSLog(@"[API] Failed to fetch broadcast list: No response");
        return nil;
    }

    NSError *jsonError = nil;
    id jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    if (jsonError || ![jsonResponse isKindOfClass:[NSDictionary class]]) {
        NSLog(@"[API] Failed to parse broadcast list: %@", jsonError);
        return nil;
    }

    NSDictionary *json = (NSDictionary *)jsonResponse;
    NSDictionary *broadcastList = json[@"broadcastList"];
    if (![broadcastList isKindOfClass:[NSDictionary class]] || broadcastList.count == 0) {
        NSLog(@"[API] Broadcast list is empty");
        return nil;
    }

    // 获取第一个播报，仅示例
    // Get first broadcast, for demo only
    NSString *firstKey = broadcastList.allKeys.firstObject;
    NSDictionary *broadcast = broadcastList[firstKey];
    if (![broadcast isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    // 验证必需字段
    // Validate required fields
    NSString *roomId = broadcast[@"roomId"];
    NSString *streamId = broadcast[@"streamId"];

    if (!roomId || !streamId) {
        NSLog(@"[API] Incomplete broadcast information");
        return nil;
    }

    return @{
        @"roomId": roomId,
        @"streamId": streamId
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

#pragma mark - 7. RTC Operations

/**
 * 登录房间 - 对齐Android的loginRoom()
 * Login to room - aligned with Android's loginRoom()
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
    [self.expressEngine loginRoom:roomId user:user config:roomConfig callback:^(int errorCode, NSDictionary *extendedData) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        if (errorCode == 0) {
            strongSelf.isRoomLoggedIn = YES;
            NSLog(@"[RTC] Room login successful");
            [strongSelf updateStatus:@"Room logged in, waiting for stream..."];
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
 * 清理资源
 * Cleanup resources
 */
- (void)cleanup {
    // 停止拉流
    // Stop playing stream
    if (self.currentStreamId) {
        [self.expressEngine stopPlayingStream:self.currentStreamId];
    }

    // 退出房间
    // Logout room
    if (self.isRoomLoggedIn && self.currentRoomId) {
        [self.expressEngine logoutRoom:self.currentRoomId];
        self.isRoomLoggedIn = NO;
    }

    // 销毁引擎
    // Destroy engine
    if (self.expressEngine) {
        [ZegoExpressEngine destroyEngine:nil];
        self.expressEngine = nil;
    }
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

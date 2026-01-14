//
//  ZegoMainViewController+Setup.m
//  ZegoDigitalHumanModelQuickStart
//
//  Created by Zego.
//

#import "ZegoMainViewController+Setup.h"
#import "ZegoMainViewController.h"
#import "ZegoMainViewController+Task.h"
#import "ZegoConfigManager.h"
#import "ZegoAPIService.h"
#import "ZegoDigitalHumanInfo.h"
#import "ZegoTaskControlView.h"
#import "ZegoDriveControlView.h"
#import "ZegoDigitalHumanPlaceholderView.h"
#import "ZegoTask.h"
#import "ZegoConfig.h"
#import "ZegoMainViewController+RTC.h"
#import <ZegoDigitalMobile/ZegoDigitalMobile.h>
#import <ZegoDigitalMobile/ZegoDigitalHumanResource.h>
#import <ZegoDigitalMobile/ZegoDigitalHumanAuth.h>

@interface ZegoMainViewController () <ZegoDigitalHumanResourceDelegate>
@end

@implementation ZegoMainViewController (Setup)

#pragma mark - Setup

- (void)loadConfig {
    self.config = [[ZegoConfigManager sharedManager] currentConfig];
    
    // 配置API Service（appId不再需要，会从服务端返回）
    [[ZegoAPIService sharedService] setServerURL:self.config.serverURL];
}

/// 获取当前用户ID，如果不存在则生成新的
- (NSString *)getCurrentUserId {
    if (!self.currentUserId || self.currentUserId.length == 0) {
        self.currentUserId = [NSString stringWithFormat:@"user_%u", arc4random_uniform(1000000)];
        NSLog(@"[用户ID] 生成新的 userId: %@", self.currentUserId);
    }
    return self.currentUserId;
}

- (void)loadInitialData {
    // 获取或生成 userId
    NSString *userId = [self getCurrentUserId];
    
    // 加载数字人信息并更新占位视图
    __weak typeof(self) weakSelf = self;
    [[ZegoAPIService sharedService] getDigitalHumanInfo:userId success:^(ZegoDigitalHumanInfoModel * _Nonnull digitalHuman) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        // 更新占位视图
        [strongSelf.placeholderView updateWithName:digitalHuman.name coverUrl:digitalHuman.coverUrl];
        NSLog(@"[数字人] 加载数字人信息成功: %@", digitalHuman.name);
        
        
        [strongSelf initExpressEngineWithAppId:digitalHuman.appId];
        
        // 触发预加载
        [strongSelf preloadDigitalHumanResource:digitalHuman];
    } failure:^(NSError * _Nonnull error, NSInteger code, NSString * _Nullable message) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        // 加载失败时显示默认信息
        [strongSelf.placeholderView updateWithName:@"数字人" coverUrl:nil];
        NSLog(@"[数字人] 加载数字人信息失败: %@", message ?: error.localizedDescription);
    }];
}

- (void)preloadDigitalHumanResource:(ZegoDigitalHumanInfoModel *)digitalHuman {
    if (!digitalHuman) {
        NSLog(@"[预加载] 数字人信息为空，跳过预加载");
        return;
    }
    
    NSString *digitalHumanId = digitalHuman.digitalHumanId;
    if (!digitalHumanId || digitalHumanId.length == 0) {
        NSLog(@"[预加载] 数字人ID为空，跳过预加载");
        return;
    }
    
    // 从数字人信息中获取appID和token
    NSInteger appId = digitalHuman.appId;
    if (appId == 0) {
        NSLog(@"[预加载] AppID未设置，跳过预加载");
        return;
    }
    
    NSString *token = digitalHuman.token;
    if (!token || token.length == 0) {
        NSLog(@"[预加载] Token为空，跳过预加载");
        return;
    }
    
    // 预加载使用当前客户端的 userId
    NSString *userId = self.currentUserId;
    
    NSLog(@"[预加载] 开始预加载数字人资源: %@", digitalHumanId);
    
    // 创建认证对象，使用返回的token
    ZegoDigitalHumanAuth *auth = [[ZegoDigitalHumanAuth alloc] initWithAppID:(unsigned int)appId 
                                                                      userID:userId 
                                                                       token:token];
    
    // 执行预加载资源
    [[ZegoDigitalHumanResource sharedInstance] preloadWithAuth:auth
                                               digitalHumanId:digitalHumanId
                                                     delegate:self];
}

- (void)setupUI {
    // 数字人渲染视图（纯视图，全屏显示，放在最底层）
    self.digitalHumanView = [[ZegoDigitalView alloc] initWithFrame:self.view.bounds];
    self.digitalHumanView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view insertSubview:self.digitalHumanView atIndex:0]; // 插入到最底层
    
    // 占位视图（显示数字人图标和名称，覆盖在数字人视图上方）
    self.placeholderView = [[ZegoDigitalHumanPlaceholderView alloc] init];
    [self.view addSubview:self.placeholderView];
    [self.placeholderView show];
    
    // 状态标签（悬浮在数字人上方）
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.text = @"待机中\n点击控制面板\"创建任务\"";//待机中
    self.statusLabel.textColor = [UIColor whiteColor];
    self.statusLabel.font = [UIFont systemFontOfSize:14];
    self.statusLabel.numberOfLines = 2;
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.lineBreakMode = NSLineBreakByWordWrapping;
    [self.view addSubview:self.statusLabel];
    
    // 控制面板切换按钮（悬浮在底部）
    self.toggleControlButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.toggleControlButton setTitle:@"▲ 打开控制面板" forState:UIControlStateNormal];
    self.toggleControlButton.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.9];
    self.toggleControlButton.tintColor = [UIColor colorWithRed:0.4 green:0.5 blue:0.9 alpha:1.0];
    self.toggleControlButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    self.toggleControlButton.layer.cornerRadius = 12;
    self.toggleControlButton.layer.shadowColor = [UIColor blackColor].CGColor;
    self.toggleControlButton.layer.shadowOffset = CGSizeMake(0, -2);
    self.toggleControlButton.layer.shadowRadius = 8;
    self.toggleControlButton.layer.shadowOpacity = 0.1;
    [self.toggleControlButton addTarget:self action:@selector(toggleControlPanel) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.toggleControlButton];
    
    // 控制面板容器（悬浮在最上层）
    [self setupControlPanel];
    
    // 添加点击手势（用于点击外部收缩面板）
    [self setupGestureRecognizers];
}

- (void)setupGestureRecognizers {
    self.tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapGesture:)];
    self.tapGesture.cancelsTouchesInView = NO; // 不影响其他控件的交互
    [self.view addGestureRecognizer:self.tapGesture];
}

- (void)handleTapGesture:(UITapGestureRecognizer *)gesture {
    // 只在面板打开时处理
    if (!self.isControlPanelVisible) {
        return;
    }
    
    // 获取点击位置
    CGPoint location = [gesture locationInView:self.view];
    
    // 检查是否点击在控制面板外部
    CGRect panelFrame = self.controlPanelContainerView.frame;
    if (!CGRectContainsPoint(panelFrame, location)) {
        // 点击在控制面板外部，收缩面板
        [self toggleControlPanel];
    }
}

- (void)setupControlPanel {
    self.controlPanelContainerView = [[UIView alloc] init];
    self.controlPanelContainerView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.95];
    self.controlPanelContainerView.layer.cornerRadius = 20;
    self.controlPanelContainerView.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    self.controlPanelContainerView.clipsToBounds = YES;
    // 确保控制面板在按钮之上
    self.controlPanelContainerView.layer.zPosition = 1000;
    [self.view addSubview:self.controlPanelContainerView];
    
    // 使用ScrollView以支持滚动
    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.showsVerticalScrollIndicator = YES;
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.controlPanelContainerView addSubview:scrollView];
    
    // 任务控制视图
    self.taskControlView = [[ZegoTaskControlView alloc] init];
    self.taskControlView.delegate = self;
    self.taskControlView.translatesAutoresizingMaskIntoConstraints = NO;
    [scrollView addSubview:self.taskControlView];
    
    // 驱动控制视图
    self.driveControlView = [[ZegoDriveControlView alloc] init];
    self.driveControlView.delegate = self;
    self.driveControlView.translatesAutoresizingMaskIntoConstraints = NO;
    [scrollView addSubview:self.driveControlView];
    
    // 布局约束
    [NSLayoutConstraint activateConstraints:@[
        [scrollView.topAnchor constraintEqualToAnchor:self.controlPanelContainerView.topAnchor],
        [scrollView.leadingAnchor constraintEqualToAnchor:self.controlPanelContainerView.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:self.controlPanelContainerView.trailingAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:self.controlPanelContainerView.bottomAnchor],
        
        [self.taskControlView.topAnchor constraintEqualToAnchor:scrollView.topAnchor constant:10],
        [self.taskControlView.leadingAnchor constraintEqualToAnchor:scrollView.leadingAnchor],
        [self.taskControlView.trailingAnchor constraintEqualToAnchor:scrollView.trailingAnchor],
        [self.taskControlView.widthAnchor constraintEqualToAnchor:scrollView.widthAnchor],
        
        [self.driveControlView.topAnchor constraintEqualToAnchor:self.taskControlView.bottomAnchor constant:15],
        [self.driveControlView.leadingAnchor constraintEqualToAnchor:scrollView.leadingAnchor],
        [self.driveControlView.trailingAnchor constraintEqualToAnchor:scrollView.trailingAnchor],
        [self.driveControlView.widthAnchor constraintEqualToAnchor:scrollView.widthAnchor],
        [self.driveControlView.bottomAnchor constraintEqualToAnchor:scrollView.bottomAnchor constant:-10]
    ]];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    CGFloat safeTop = 0;
    CGFloat safeBottom = 0;
    if (@available(iOS 11.0, *)) {
        safeTop = self.view.safeAreaInsets.top;
        safeBottom = self.view.safeAreaInsets.bottom;
    }
    
    CGFloat padding = 15;
    CGFloat screenWidth = self.view.bounds.size.width;
    CGFloat screenHeight = self.view.bounds.size.height;
    
    // 数字人渲染区域
    self.digitalHumanView.frame = self.view.bounds;
    
    // 占位视图（全屏，覆盖在数字人视图上方）
    self.placeholderView.frame = self.view.bounds;
    
    // 状态标签（悬浮在数字人上方）
    // 高度设置为44，确保可以显示2行文本（14号字体，行高约20，加上间距）
    self.statusLabel.frame = CGRectMake(0, safeTop + 10, screenWidth, 44);
    
    // 切换按钮（悬浮在底部）
    CGFloat toggleButtonY = screenHeight - safeBottom - 60;
    self.toggleControlButton.frame = CGRectMake(padding, toggleButtonY, screenWidth - 2*padding, 50);
    
    // 控制面板（根据可见性调整位置）
    // 计算实际内容高度：任务控制(~100) + 间距(15) + 驱动控制(~213) + 上下边距(20) ≈ 348
    // 设置为360，留出一些安全边距，避免内容被裁剪，同时减少底部空白
    CGFloat panelHeight = 360;
    CGFloat panelY = self.isControlPanelVisible ? (screenHeight - panelHeight) : screenHeight;
    self.controlPanelContainerView.frame = CGRectMake(0, panelY, screenWidth, panelHeight);
}

#pragma mark - Actions

- (void)toggleControlPanel {
    self.isControlPanelVisible = !self.isControlPanelVisible;
    
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        [self viewDidLayoutSubviews];
        NSString *title = self.isControlPanelVisible ? @"▼ 关闭控制面板" : @"▲ 打开控制面板";
        [self.toggleControlButton setTitle:title forState:UIControlStateNormal];
    } completion:nil];
}

- (void)updateStatus:(NSString *)status {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusLabel.text = status;
        NSLog(@"[状态] %@", status);
    });
}

- (void)updatePlaceholderView {
    if (!self.placeholderView) {
        return;
    }
    
    // 占位视图显示默认信息
    [self.placeholderView updateWithName:@"数字人" coverUrl:nil];
}

#pragma mark - ZegoDigitalHumanResourceDelegate

- (void)onPreloadSuccess:(NSString *)digitalHumanId {
    NSLog(@"[预加载] 预加载成功: %@", digitalHumanId);
}

- (void)onPreloadFailed:(NSString *)digitalHumanId
              errorCode:(NSInteger)errorCode
           errorMessage:(NSString *)errorMessage {
    NSLog(@"[预加载] 预加载失败: %@ - code: %ld, msg: %@", digitalHumanId, (long)errorCode, errorMessage);
}

- (void)onPreloadProgress:(NSString *)digitalHumanId
                 progress:(float)progress {
    NSLog(@"[预加载] 预加载进度: %@ - %.1f%%", digitalHumanId, progress);
}

#pragma mark - Digital Human Management

- (void)startDigitalHumanWithConfig:(NSString *)base64Config {

    if (!base64Config || base64Config.length == 0) {
        NSLog(@"[数字人] 错误：配置为空");
        [self updateStatus:@"数字人错误：配置为空"];
        return;
    }
    
    NSLog(@"[数字人] 开始启动数字人");
    
    // 步骤1: 创建数字人SDK实例
    self.digitalMobile = [ZegoDigitalHuman create];
    if (!self.digitalMobile) {
        NSLog(@"[数字人] 错误：创建数字人SDK失败");
        [self updateStatus:@"数字人错误：创建数字人SDK失败"];
        return;
    }

    // 步骤2: 绑定预览视图 - 将数字人渲染视图绑定到SDK实例
    if (self.digitalHumanView) {
        [self.digitalMobile attach:self.digitalHumanView];
        NSLog(@"[数字人] 已绑定预览视图");
    }

    // 步骤3: 启动数字人 - 使用配置启动数字人，并设置代理接收回调
    [self.digitalMobile start:base64Config delegate:self];
}

- (void)stopDigitalHuman {
    NSLog(@"[数字人] 开始停止数字人");
    
    if (self.digitalMobile) {
        [self.digitalMobile stop];
        self.digitalMobile = nil;
    }
    
    NSLog(@"[数字人] 数字人已停止");
    [self updateStatus:@"数字人已停止"];
    // 显示占位视图
    [self.placeholderView show];
}

#pragma mark - ZegoDigitalMobileDelegate

- (void)onDigitalMobileStartSuccess {
    NSLog(@"[数字人] 数字人启动成功");
    [self updateStatus:@"数字人启动成功"];
}

- (void)onError:(int)errorCode errorMsg:(NSString *)errorMsg {
    NSLog(@"[数字人] 数字人错误：code=%d, msg=%@", errorCode, errorMsg);
    [self updateStatus:[NSString stringWithFormat:@"数字人错误: %@", errorMsg ?: @"未知错误"]];
}

- (void)onSurfaceFirstFrameDraw {
    NSLog(@"[数字人] 首帧绘制完成");
    [self updateStatus:@"数字人首帧绘制完成"];
    // 隐藏占位视图
    [self.placeholderView hide];
}

@end


//
//  ZegoMainViewController.m
//  ZegoDigitalHumanModelQuickStart
//
//  Created by Zego.
//

#import "ZegoMainViewController.h"
#import "ZegoMainViewController+Setup.h"
#import "ZegoMainViewController+RTC.h"
#import "ZegoMainViewController+Task.h"
#import "ZegoTaskControlView.h"
#import "ZegoDriveControlView.h"
#import "ZegoDigitalHumanPlaceholderView.h"
#import "ZegoTask.h"
#import "ZegoConfig.h"
#import <ZegoExpressEngine/ZegoExpressEngine.h>

@implementation ZegoMainViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"数字人快速启动";
    self.view.backgroundColor = [UIColor colorWithRed:0.4 green:0.5 blue:0.9 alpha:1.0];
    
    // 初始化状态
    self.isControlPanelVisible = NO;
    self.rtcEngineCreated = NO;
    self.isRoomLogined = NO;
    
    // 加载配置
    [self loadConfig];
    
    // 设置UI
    [self setupUI];
    
    // 加载数据
    [self loadInitialData];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // 重新加载配置
    [self loadConfig];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    // 检查是否是真正的退出（pop或dismiss），而不是push到其他页面
    // 如果是主页面退出，需要停止正在运行的任务
    BOOL isMovingFromParent = [self isMovingFromParentViewController];
    BOOL isBeingDismissed = [self isBeingDismissed];
    
    if (self.currentTask && (isMovingFromParent || isBeingDismissed)) {
        NSLog(@"[生命周期] 检测到运行中的任务，开始停止任务");
        [self stopTaskAndCleanup];
    }
}





#pragma mark - Memory Management



- (void)dealloc {
    NSLog(@"[ZegoMainViewController] dealloc");
    
    // 销毁RTC引擎和数字人任务
    [self destroyAllTask];
    
    // 清理资源
    _currentTask = nil;
    _config = nil;
}

@end

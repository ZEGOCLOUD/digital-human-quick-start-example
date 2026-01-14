//
//  ZegoMainViewController+Task.m
//  ZegoDigitalHumanModelQuickStart
//
//  Created by Zego.
//

#import "ZegoMainViewController+Task.h"
#import "ZegoMainViewController.h"
#import "ZegoMainViewController+Setup.h"
#import "ZegoMainViewController+RTC.h"
#import "ZegoAPIService.h"
#import "ZegoTask.h"
#import <ZegoExpressEngine/ZegoExpressEngine.h>

@implementation ZegoMainViewController (Task)

#pragma mark - Task Management

- (void)createTaskWithCompletion:(void(^)(BOOL success))completion {
    [self updateStatus:@"正在创建任务..."];
    [self.taskControlView setLoading:YES forButton:0];
    
    // 获取或生成 userId（复用已存在的 userId）
    NSString *userId = [self getCurrentUserId];
    
    // 直接创建任务，复用已存在的 userId
    [self createStreamTaskWithUserId:userId completion:completion];
}

//TODO: 整个流程对齐文档上的UML图
- (void)createStreamTaskWithUserId:(NSString *)userId
                        completion:(void(^)(BOOL success))completion {
    [self updateStatus:@"正在创建任务..."];
    
    // 边界检查
    if (!userId || userId.length == 0) {
        [self updateStatus:@"错误：用户ID不能为空"];
        [self.taskControlView setLoading:NO forButton:0];
        if (completion) completion(NO);
        return;
    }
    
    // 步骤1: 构建任务配置（iOS端传小图模式，传递OutputMode和UserId）
    NSDictionary *taskConfig = @{
        @"OutputMode": @(2),  // 小图模式
        @"UserId": userId      // 用户ID，必选
    };
    
    __weak typeof(self) weakSelf = self;
    // 步骤2: 调用API创建数字人流任务
    [[ZegoAPIService sharedService] createDigitalHumanStreamTask:taskConfig success:^(NSDictionary * _Nonnull taskData) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        // 提取服务端返回的任务数据
        NSString *taskId = taskData[@"TaskId"];
        NSString *base64Config = taskData[@"Base64Config"];
        NSString *roomId = taskData[@"RoomId"];
        NSString *streamId = taskData[@"StreamId"];
        NSString *appIdStr = taskData[@"AppId"];
        NSString *token = taskData[@"Token"];
        
        if (!appIdStr || appIdStr.length == 0) {
            [strongSelf updateStatus:@"错误：服务端未返回 AppId"];
            [strongSelf.taskControlView setLoading:NO forButton:0];
            if (completion) completion(NO);
            return;
        }
        
        // 保存appID用于后续预加载
        strongSelf.currentAppId = [appIdStr integerValue];
        
        if (!token || token.length == 0) {
            [strongSelf updateStatus:@"错误：服务端未返回 Token"];
            [strongSelf.taskControlView setLoading:NO forButton:0];
            if (completion) completion(NO);
            return;
        }
        
        if (!roomId || roomId.length == 0) {
            [strongSelf updateStatus:@"错误：服务端未返回 RoomId"];
            [strongSelf.taskControlView setLoading:NO forButton:0];
            if (completion) completion(NO);
            return;
        }
        
        if (!streamId || streamId.length == 0) {
            [strongSelf updateStatus:@"错误：服务端未返回 StreamId"];
            [strongSelf.taskControlView setLoading:NO forButton:0];
            if (completion) completion(NO);
            return;
        }
        
        if (!base64Config || base64Config.length == 0) {
            [strongSelf updateStatus:@"错误：服务端未返回 Base64Config"];
            [strongSelf.taskControlView setLoading:NO forButton:0];
            if (completion) completion(NO);
            return;
        }
        
        // 步骤3: 使用返回的 AppId 初始化Express引擎
        NSInteger appId = [appIdStr integerValue];
        
        // 创建任务对象并保存任务状态
        ZegoTask *task = [[ZegoTask alloc] initWithDictionary:@{
            @"TaskId": taskId,
            @"RoomId": roomId,
            @"StreamId": streamId,
            @"UserID": userId,
            @"appId": @(appId)
        }];
        task.status = ZegoTaskStatusRunning;
        strongSelf.currentTask = task;
        strongSelf.currentRoomId = roomId;
        strongSelf.currentStreamId = streamId;
        
        [strongSelf updateStatus:@"任务创建成功"];
        [strongSelf.taskControlView updateButtonStatesWithHasTask:YES];
        [strongSelf.taskControlView setLoading:NO forButton:0];
        [strongSelf.driveControlView setDriveButtonsEnabled:YES];
        
        NSLog(@"[任务] 创建成功: %@", taskId);
        
        // 步骤4: 使用返回的 token 登录RTC房间
        strongSelf.currentToken = token;
        [strongSelf loginRoomWithCompletion:^(BOOL success) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            
            if (success) {
                // 步骤5: 启动数字人渲染（使用服务端返回的Base64Config）
                // 注意: 拉流在RTC回调的房间消息onRoomStreamUpdate中实现
                if (base64Config && base64Config.length > 0) {
                    NSLog(@"[数字人] 使用服务端返回的 Base64Config 启动数字人");
                    [[ZegoExpressEngine sharedEngine] setCustomVideoRenderHandler:self];
                    [strongSelf startDigitalHumanWithConfig:base64Config];
                }
                if (completion) completion(YES);
            } else {
                if (completion) completion(NO);
            }
        }];
        
    } failure:^(NSError * _Nonnull error, NSInteger code, NSString * _Nullable message) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        [strongSelf updateStatus:[NSString stringWithFormat:@"创建任务失败: %@", message]];
        [strongSelf.taskControlView setLoading:NO forButton:0];
        NSLog(@"[任务] 创建失败: %@", message);
        
        if (completion) completion(NO);
    }];
}
//TODO: 简洁流程,去除兼容逻辑
- (void)stopTaskAndCleanup {
    if (!self.currentTask) {
        return;
    }
    
    [self updateStatus:@"正在停止任务..."];
    [self.taskControlView setLoading:YES forButton:1];
    
    // 先停止 RTC，再停止数字人
    // 1. 先设置 setCustomVideoRenderHandler(nil)
    [[ZegoExpressEngine sharedEngine] setCustomVideoRenderHandler:nil];
    NSLog(@"[RTC] 已清除自定义视频渲染处理器");
    
    // 2. 停止拉流
    if (self.currentStreamId && self.currentStreamId.length > 0) {
        [[ZegoExpressEngine sharedEngine] stopPlayingStream:self.currentStreamId];
        NSLog(@"[RTC] 已停止拉流: %@", self.currentStreamId);
    }
    
    // 3. 退出房间（使用 logoutRoomWithCallback 确保异步操作完成）
    __weak typeof(self) weakSelf = self;
    if (self.isRoomLogined && self.currentRoomId) {
        [[ZegoExpressEngine sharedEngine] logoutRoomWithCallback:^(int errorCode, NSDictionary * _Nonnull extendedData) {
            NSLog(@"[RTC] 登出房间结果: errorCode=%d", errorCode);
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            
            strongSelf.isRoomLogined = NO;
            
            // 4. RTC 完全停止后，再停止数字人渲染
            [strongSelf stopDigitalHuman];
            
            // 5. 直接调用停止任务 API
            [strongSelf callStopTaskAPI];
        }];
    } else {
        // 如果没有登录房间，直接停止数字人和调用 API
        [self stopDigitalHuman];
        [self callStopTaskAPI];
    }
}

#pragma mark - Task Cleanup Helpers

/// 清理任务状态并更新 UI
- (void)cleanupTaskState {
    self.currentTask = nil;
    self.currentStreamId = nil;
    self.currentRoomId = nil;
    self.currentUserId = nil;
    self.currentToken = nil;
    
    [self updateStatus:@"任务已停止"];
    [self.taskControlView updateButtonStatesWithHasTask:NO];
    [self.taskControlView setLoading:NO forButton:1];
    [self.driveControlView setDriveButtonsEnabled:NO];
    
    NSLog(@"[任务] 已停止");
}

/// 调用停止任务 API
- (void)callStopTaskAPI {
    if (!self.currentTask) {
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    [[ZegoAPIService sharedService] stopDigitalHumanStreamTask:self.currentTask.taskId
                                                       success:^(NSDictionary * _Nullable data) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        [strongSelf cleanupTaskState];
        
    } failure:^(NSError * _Nonnull error, NSInteger code, NSString * _Nullable message) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        [strongSelf updateStatus:[NSString stringWithFormat:@"停止失败: %@", message]];
        [strongSelf.taskControlView setLoading:NO forButton:1];
        NSLog(@"[任务] 停止失败: %@", message);
    }];
}

- (void)stopRTCBeforeDestroyingCurrentTask:(void(^)(void))completion {
    if (!self.currentTask) {
        if (completion) completion();
        return;
    }
    
    // 1. 清理自定义渲染
    [[ZegoExpressEngine sharedEngine] setCustomVideoRenderHandler:nil];
    NSLog(@"[RTC] 已清除自定义视频渲染处理器");
    
    // 2. 停止拉流
    if (self.currentStreamId && self.currentStreamId.length > 0) {
        [[ZegoExpressEngine sharedEngine] stopPlayingStream:self.currentStreamId];
        NSLog(@"[RTC] 已停止拉流: %@", self.currentStreamId);
    }
    
    __weak typeof(self) weakSelf = self;
    void (^invokeCompletion)(void) = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        if (completion) completion();
    };
    
    // 3. 退出房间并销毁引擎
    if (self.isRoomLogined && self.currentRoomId) {
        [[ZegoExpressEngine sharedEngine] logoutRoomWithCallback:^(int errorCode, NSDictionary * _Nonnull extendedData) {
            NSLog(@"[RTC] 登出房间结果: errorCode=%d", errorCode);
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            
            strongSelf.isRoomLogined = NO;
            [strongSelf stopDigitalHuman];
            
            if (strongSelf.rtcEngineCreated) {
                NSLog(@"[RTC] 开始销毁引擎(销毁任务)");
                [ZegoExpressEngine destroyEngine:^{
                    __strong typeof(weakSelf) strongSelf = weakSelf;
                    if (!strongSelf) return;
                    strongSelf.rtcEngineCreated = NO;
                    invokeCompletion();
                }];
            } else {
                invokeCompletion();
            }
        }];
    } else {
        [self stopDigitalHuman];
        if (self.rtcEngineCreated) {
            NSLog(@"[RTC] 开始销毁引擎(销毁任务)");
            [ZegoExpressEngine destroyEngine:^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;
                strongSelf.rtcEngineCreated = NO;
                invokeCompletion();
            }];
        } else {
            invokeCompletion();
        }
    }
}

- (void)destroyTasksInArray:(NSArray<ZegoTask *> *)tasks index:(NSInteger)index completion:(void(^)(void))completion {
    // 边界检查
    if (index >= tasks.count) {
        if (completion) completion();
        return;
    }
    
    ZegoTask *task = tasks[index];
    __weak typeof(self) weakSelf = self;
    void (^continueDestroy)(void) = ^{
        [[ZegoAPIService sharedService] stopDigitalHumanStreamTask:task.taskId
                                                           success:^(NSDictionary * _Nullable data) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            
            if (strongSelf.currentTask && [strongSelf.currentTask.taskId isEqualToString:task.taskId]) {
                [strongSelf cleanupTaskState];
            }
            
            // 继续下一个
            [strongSelf destroyTasksInArray:tasks index:index + 1 completion:completion];
        } failure:^(NSError * _Nonnull error, NSInteger code, NSString * _Nullable message) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            
            // 忽略错误，继续下一个
            [strongSelf destroyTasksInArray:tasks index:index + 1 completion:completion];
        }];
    };
    
    // 对当前任务先做 RTC 清理，再调用销毁接口
    if (self.currentTask && [self.currentTask.taskId isEqualToString:task.taskId]) {
        [self stopRTCBeforeDestroyingCurrentTask:^{
            continueDestroy();
        }];
    } else {
        [self destroyExpressEngine];
        continueDestroy();
    }
}


- (void)destroyAllTask {
    __weak typeof(self) weakSelf = self;
    [[ZegoAPIService sharedService] queryDigitalHumanStreamTasks:^(NSArray<ZegoTask *> * _Nonnull tasks) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        if (tasks.count == 0) {
            [strongSelf destroyExpressEngine];
            [strongSelf updateStatus:@"没有运行中的任务"];
            return;
        }
        
        // 筛选test_room_开头的任务
        NSMutableArray *filteredTasks = [NSMutableArray array];
        for (ZegoTask *task in tasks) {
            if ([task.roomId hasPrefix:@"test_room_"]) {
                [filteredTasks addObject:task];
            }
        }
        
        if (filteredTasks.count == 0) {
            [strongSelf destroyExpressEngine];
            [strongSelf updateStatus:@"没有可销毁的test_room_任务"];
            return;
        }
        
        // 依次停止所有任务
        [strongSelf destroyTasksInArray:filteredTasks index:0 completion:^{
            [strongSelf updateStatus:[NSString stringWithFormat:@"已销毁%lu个任务", (unsigned long)filteredTasks.count]];
        }];
        
    } failure:^(NSError * _Nonnull error, NSInteger code, NSString * _Nullable message) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        [strongSelf destroyExpressEngine];
        [strongSelf updateStatus:@"查询任务失败"];
    }];
}



#pragma mark - ZegoTaskControlViewDelegate

- (void)taskControlViewDidTapCreateTask:(ZegoTaskControlView *)view {
    // 立即隐藏控制面板
    if (self.isControlPanelVisible) {
        [self toggleControlPanel];
    }
    
    [self createTaskWithCompletion:nil];
}

- (void)taskControlViewDidTapStopTask:(ZegoTaskControlView *)view {
    // 立即隐藏控制面板
    if (self.isControlPanelVisible) {
        [self toggleControlPanel];
    }
    
    [self stopTaskAndCleanup];
}

- (void)taskControlViewDidTapInterrupt:(ZegoTaskControlView *)view {
    if (!self.currentTask) return;
    
    // 立即隐藏控制面板
    if (self.isControlPanelVisible) {
        [self toggleControlPanel];
    }
    
    [self.taskControlView setLoading:YES forButton:2];
    
    __weak typeof(self) weakSelf = self;
    [[ZegoAPIService sharedService] interruptDriveTask:self.currentTask.taskId
                                               success:^(NSDictionary * _Nullable data) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        [strongSelf updateStatus:@"打断成功"];
        [strongSelf.taskControlView setLoading:NO forButton:2];
    } failure:^(NSError * _Nonnull error, NSInteger code, NSString * _Nullable message) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        [strongSelf updateStatus:[NSString stringWithFormat:@"打断失败: %@", message]];
        [strongSelf.taskControlView setLoading:NO forButton:2];
    }];
}


#pragma mark - ZegoDriveControlViewDelegate

- (void)driveControlViewDidTapTextDrive:(ZegoDriveControlView *)view {
    if (!self.currentTask) {
        [self updateStatus:@"请先创建任务"];
        return;
    }
    
    // 立即隐藏控制面板，以便查看数字人效果
    if (self.isControlPanelVisible) {
        [self toggleControlPanel];
    }
    
    [self updateStatus:@"正在文本驱动..."];
    [self.driveControlView setLoading:YES forDriveType:ZegoDriveTypeText];
    
    __weak typeof(self) weakSelf = self;
    [[ZegoAPIService sharedService] driveByText:self.currentTask.taskId
                                         success:^(NSDictionary * _Nullable data) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        [strongSelf updateStatus:@"文本驱动成功"];
        [strongSelf.driveControlView setLoading:NO forDriveType:ZegoDriveTypeText];
    } failure:^(NSError * _Nonnull error, NSInteger code, NSString * _Nullable message) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        [strongSelf updateStatus:[NSString stringWithFormat:@"文本驱动失败: %@", message]];
        [strongSelf.driveControlView setLoading:NO forDriveType:ZegoDriveTypeText];
    }];
}

- (void)driveControlViewDidTapAudioDrive:(ZegoDriveControlView *)view {
    if (!self.currentTask) {
        [self updateStatus:@"请先创建任务"];
        return;
    }
    
    // 立即隐藏控制面板，以便查看数字人效果
    if (self.isControlPanelVisible) {
        [self toggleControlPanel];
    }
    
    [self updateStatus:@"正在音频驱动..."];
    [self.driveControlView setLoading:YES forDriveType:ZegoDriveTypeAudio];
    
    __weak typeof(self) weakSelf = self;
    [[ZegoAPIService sharedService] driveByAudio:self.currentTask.taskId
                                         success:^(NSDictionary * _Nullable data) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        [strongSelf updateStatus:@"音频驱动成功"];
        [strongSelf.driveControlView setLoading:NO forDriveType:ZegoDriveTypeAudio];
    } failure:^(NSError * _Nonnull error, NSInteger code, NSString * _Nullable message) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        [strongSelf updateStatus:[NSString stringWithFormat:@"音频驱动失败: %@", message]];
        [strongSelf.driveControlView setLoading:NO forDriveType:ZegoDriveTypeAudio];
    }];
}

- (void)driveControlViewDidTapWsTTSDrive:(ZegoDriveControlView *)view {
    if (!self.currentTask) {
        [self updateStatus:@"请先创建任务"];
        return;
    }
    
    // 立即隐藏控制面板，以便查看数字人效果
    if (self.isControlPanelVisible) {
        [self toggleControlPanel];
    }
    
    [self updateStatus:@"正在WebSocket TTS驱动..."];
    [self.driveControlView setLoading:YES forDriveType:ZegoDriveTypeWsTTS];
    
    __weak typeof(self) weakSelf = self;
    [[ZegoAPIService sharedService] driveByWsStreamWithTTS:self.currentTask.taskId
                                                   success:^(NSDictionary * _Nullable data) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        [strongSelf updateStatus:@"WebSocket TTS驱动成功"];
        [strongSelf.driveControlView setLoading:NO forDriveType:ZegoDriveTypeWsTTS];
    } failure:^(NSError * _Nonnull error, NSInteger code, NSString * _Nullable message) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        [strongSelf updateStatus:[NSString stringWithFormat:@"WebSocket TTS驱动失败: %@", message]];
        [strongSelf.driveControlView setLoading:NO forDriveType:ZegoDriveTypeWsTTS];
    }];
}

@end


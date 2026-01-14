//
//  ZegoTaskControlView.h
//  ZegoDigitalHumanQuickStart
//
//  Created by Zego.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class ZegoTaskControlView;

/// 任务控制视图代理
@protocol ZegoTaskControlViewDelegate <NSObject>

@optional
/// 点击创建任务按钮
- (void)taskControlViewDidTapCreateTask:(ZegoTaskControlView *)view;

/// 点击停止任务按钮
- (void)taskControlViewDidTapStopTask:(ZegoTaskControlView *)view;

/// 点击打断按钮
- (void)taskControlViewDidTapInterrupt:(ZegoTaskControlView *)view;

@end

/// 任务控制视图
@interface ZegoTaskControlView : UIView

/// 代理
@property (nonatomic, weak, nullable) id<ZegoTaskControlViewDelegate> delegate;

/// 创建任务按钮
@property (nonatomic, strong, readonly) UIButton *createTaskButton;

/// 停止任务按钮
@property (nonatomic, strong, readonly) UIButton *stopTaskButton;

/// 打断按钮
@property (nonatomic, strong, readonly) UIButton *interruptButton;


/// 更新按钮状态
/// @param hasTask 是否有任务
- (void)updateButtonStatesWithHasTask:(BOOL)hasTask;

/// 设置按钮Loading状态
/// @param loading 是否Loading
/// @param button 按钮类型：0-创建 1-停止 2-打断 3-销毁全部
- (void)setLoading:(BOOL)loading forButton:(NSInteger)button;

@end

NS_ASSUME_NONNULL_END


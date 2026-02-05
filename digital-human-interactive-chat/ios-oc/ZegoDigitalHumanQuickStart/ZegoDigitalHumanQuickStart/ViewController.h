//
//  ViewController.h
//  ZegoDigitalHumanQuickStart
//
//  单文件实现 - 对齐Android的MainActivity.kt
//  Single-file implementation - aligned with Android's MainActivity.kt
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class ZegoDigitalView;
@protocol IZegoDigitalMobile;
@class ZegoExpressEngine;

@interface ViewController : UIViewController

// UI组件 / UI components
@property (nonatomic, strong) UILabel *tvStatus;
@property (nonatomic, strong) UIView *digitalHumanContainerView;
@property (nonatomic, strong) UIButton *btnStartCall;
@property (nonatomic, strong) UIButton *btnStopCall;
@property (nonatomic, strong) UIButton *btnSimulateTalkZh;
@property (nonatomic, strong) UIButton *btnSimulateTalkEn;

// SDK实例 / SDK instances
@property (nonatomic, strong, nullable) ZegoExpressEngine *expressEngine;
@property (nonatomic, strong, nullable) id<IZegoDigitalMobile> digitalMobile;

// 任务状态 / Task state
@property (nonatomic, copy, nullable) NSString *currentTaskId;
@property (nonatomic, copy, nullable) NSString *currentRoomId;
@property (nonatomic, copy, nullable) NSString *currentStreamId;
@property (nonatomic, copy, nullable) NSString *currentUserId;
@property (nonatomic, assign) BOOL isCallStarted;
@property (nonatomic, assign) BOOL isRoomLoggedIn;

@end

NS_ASSUME_NONNULL_END

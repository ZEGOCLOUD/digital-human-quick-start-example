//
//  ViewController.h
//  ZegoDigitalHumanQuickStart
//
//  单文件实现 - 对齐Android的MainActivity.kt
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ViewController : UIViewController

// UI组件
@property (nonatomic, strong) UILabel *tvStatus;
@property (nonatomic, strong) UILabel *tvRoomInfo;
@property (nonatomic, strong) UIView *remoteVideoView;

@end

NS_ASSUME_NONNULL_END

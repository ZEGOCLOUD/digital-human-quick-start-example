//
//  ZegoMainViewController+Task.h
//  ZegoDigitalHumanModelQuickStart
//
//  Created by Zego.
//

#import "ZegoMainViewController.h"
#import "ZegoTaskControlView.h"
#import "ZegoDriveControlView.h"

NS_ASSUME_NONNULL_BEGIN

@interface ZegoMainViewController (Task) <ZegoTaskControlViewDelegate, ZegoDriveControlViewDelegate>
- (void)stopTaskAndCleanup;
- (void)destroyAllTask;
@end

NS_ASSUME_NONNULL_END


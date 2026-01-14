//
//  ZegoTaskControlView.m
//  ZegoDigitalHumanQuickStart
//
//  Created by Zego.
//

#import "ZegoTaskControlView.h"

@interface ZegoTaskControlView ()

@property (nonatomic, strong, readwrite) UIButton *createTaskButton;
@property (nonatomic, strong, readwrite) UIButton *stopTaskButton;
@property (nonatomic, strong, readwrite) UIButton *interruptButton;

@property (nonatomic, assign) BOOL hasTaskRunning; // 记录当前任务状态，便于恢复按钮可用性

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIStackView *buttonStackView;

@property (nonatomic, strong) UIActivityIndicatorView *createLoadingView;
@property (nonatomic, strong) UIActivityIndicatorView *stopLoadingView;
@property (nonatomic, strong) UIActivityIndicatorView *interruptLoadingView;
@property (nonatomic, strong) UIActivityIndicatorView *destroyAllLoadingView;

@end

@implementation ZegoTaskControlView

#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupViews];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self setupViews];
    }
    return self;
}

- (void)setupViews {
    self.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.05];
    self.layer.cornerRadius = 12;
    
    // 标题
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = @"任务控制";
    self.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    self.titleLabel.textColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0]; // 深灰色文字，提高对比度
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.titleLabel];
    
    // 创建按钮
    self.createTaskButton = [self createButtonWithTitle:@"创建任务" 
                                         backgroundColor:[UIColor colorWithRed:0.32 green:0.77 blue:0.10 alpha:1.0]
                                                  action:@selector(createTaskTapped)];
    
    self.stopTaskButton = [self createButtonWithTitle:@"停止任务" 
                                       backgroundColor:[UIColor colorWithRed:1.0 green:0.30 blue:0.31 alpha:1.0]
                                                action:@selector(stopTaskTapped)];
    
    self.interruptButton = [self createButtonWithTitle:@"打断" 
                                        backgroundColor:[UIColor colorWithRed:0.98 green:0.68 blue:0.08 alpha:1.0]
                                                 action:@selector(interruptTapped)];
    
    // 创建Loading指示器
    self.createLoadingView = [self createLoadingIndicator];
    self.stopLoadingView = [self createLoadingIndicator];
    self.interruptLoadingView = [self createLoadingIndicator];
    self.destroyAllLoadingView = [self createLoadingIndicator];
    
    [self.createTaskButton addSubview:self.createLoadingView];
    [self.stopTaskButton addSubview:self.stopLoadingView];
    [self.interruptButton addSubview:self.interruptLoadingView];
    
    // StackView布局按钮
    self.buttonStackView = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.createTaskButton,
        self.stopTaskButton,
        self.interruptButton
    ]];
    self.buttonStackView.axis = UILayoutConstraintAxisHorizontal;
    self.buttonStackView.distribution = UIStackViewDistributionFillEqually;
    self.buttonStackView.spacing = 10;
    self.buttonStackView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.buttonStackView];
    
    // 布局约束
    [NSLayoutConstraint activateConstraints:@[
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:15],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:15],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-15],
        
        [self.buttonStackView.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:10],
        [self.buttonStackView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:15],
        [self.buttonStackView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-15],
        [self.buttonStackView.heightAnchor constraintEqualToConstant:44],
        [self.buttonStackView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-15]
    ]];
    
    // 初始状态
    [self updateButtonStatesWithHasTask:NO];
}

- (UIButton *)createButtonWithTitle:(NSString *)title backgroundColor:(UIColor *)color action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    button.backgroundColor = color;
    button.tintColor = [UIColor whiteColor];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [button setTitleColor:[[UIColor whiteColor] colorWithAlphaComponent:0.5] forState:UIControlStateDisabled];
    button.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    button.layer.cornerRadius = 8;
    button.clipsToBounds = YES;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    return button;
}

- (UIActivityIndicatorView *)createLoadingIndicator {
    UIActivityIndicatorView *indicator;
    if (@available(iOS 13.0, *)) {
        indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    } else {
        indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    }
    indicator.hidesWhenStopped = YES;
    indicator.translatesAutoresizingMaskIntoConstraints = NO;
    return indicator;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    // 居中Loading指示器
    for (UIActivityIndicatorView *loading in @[self.createLoadingView, self.stopLoadingView, self.interruptLoadingView, self.destroyAllLoadingView]) {
        loading.center = CGPointMake(loading.superview.bounds.size.width / 2, loading.superview.bounds.size.height / 2);
    }
}

#pragma mark - Public Methods

- (void)updateButtonStatesWithHasTask:(BOOL)hasTask {
    self.hasTaskRunning = hasTask;
    self.createTaskButton.enabled = !hasTask;
    self.stopTaskButton.enabled = hasTask;
    self.interruptButton.enabled = hasTask;
    
    // 更新按钮透明度
    self.createTaskButton.alpha = hasTask ? 0.5 : 1.0;
    self.stopTaskButton.alpha = hasTask ? 1.0 : 0.5;
    self.interruptButton.alpha = hasTask ? 1.0 : 0.5;
}

- (void)setLoading:(BOOL)loading forButton:(NSInteger)button {
    UIActivityIndicatorView *loadingView = nil;
    UIButton *targetButton = nil;
    
    // 边界检查
    if (button < 0 || button > 3) {
        return;
    }
    
    switch (button) {
        case 0:
            loadingView = self.createLoadingView;
            targetButton = self.createTaskButton;
            break;
        case 1:
            loadingView = self.stopLoadingView;
            targetButton = self.stopTaskButton;
            break;
        case 2:
            loadingView = self.interruptLoadingView;
            targetButton = self.interruptButton;
            break;
    }
    
    if (loading) {
        [loadingView startAnimating];
        targetButton.enabled = NO;
        [targetButton setTitle:@"" forState:UIControlStateNormal];
    } else {
        [loadingView stopAnimating];
        // 恢复按钮标题
        NSArray *titles = @[@"创建任务", @"停止任务", @"打断"];
        if (button < titles.count) {
            [targetButton setTitle:titles[button] forState:UIControlStateNormal];
        }
        // 根据当前任务状态恢复按钮可用性，避免在任务仍运行时误禁用打断按钮
        [self updateButtonStatesWithHasTask:self.hasTaskRunning];
    }
}

#pragma mark - Actions

- (void)createTaskTapped {
    if ([self.delegate respondsToSelector:@selector(taskControlViewDidTapCreateTask:)]) {
        [self.delegate taskControlViewDidTapCreateTask:self];
    }
}

- (void)stopTaskTapped {
    if ([self.delegate respondsToSelector:@selector(taskControlViewDidTapStopTask:)]) {
        [self.delegate taskControlViewDidTapStopTask:self];
    }
}

- (void)interruptTapped {
    if ([self.delegate respondsToSelector:@selector(taskControlViewDidTapInterrupt:)]) {
        [self.delegate taskControlViewDidTapInterrupt:self];
    }
}


#pragma mark - Memory Management

- (void)dealloc {
    // 清理资源

}

@end


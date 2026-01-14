package com.example.zegodigitalhumanquickstart.callback;

/**
 * 任务控制视图回调接口
 */
public interface ZegoQuickStartTaskControlViewCallback {
    
    /**
     * 点击创建任务按钮
     */
    void onCreateTaskClicked();
    
    /**
     * 点击停止任务按钮
     */
    void onStopTaskClicked();
    
    /**
     * 点击打断按钮
     */
    void onInterruptClicked();

}


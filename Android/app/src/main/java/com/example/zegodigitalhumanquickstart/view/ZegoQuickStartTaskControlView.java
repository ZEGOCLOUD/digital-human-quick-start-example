package com.example.zegodigitalhumanquickstart.view;

import android.content.Context;
import android.graphics.Color;
import android.util.AttributeSet;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.example.zegodigitalhumanquickstart.callback.ZegoQuickStartTaskControlViewCallback;

/**
 * 任务控制视图
 * 包含创建、停止、打断、销毁全部按钮
 */
public class ZegoQuickStartTaskControlView extends LinearLayout {
    
    private static final String TAG = "ZegoQuickStartTaskControlView";
    
    private TextView titleTextView;
    private Button createTaskButton;
    private Button stopTaskButton;
    private Button interruptButton;
    
    private ProgressBar createLoadingView;
    private ProgressBar stopLoadingView;
    private ProgressBar interruptLoadingView;
    private ProgressBar destroyAllLoadingView;
    
    private ZegoQuickStartTaskControlViewCallback callback;
    private boolean hasTaskRunning; // 记录当前任务状态以恢复按钮可用性
    
    public ZegoQuickStartTaskControlView(@NonNull Context context) {
        super(context);
        init(context);
    }
    
    public ZegoQuickStartTaskControlView(@NonNull Context context, @Nullable AttributeSet attrs) {
        super(context, attrs);
        init(context);
    }
    
    public ZegoQuickStartTaskControlView(@NonNull Context context, @Nullable AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        init(context);
    }
    
    private void init(Context context) {
        setOrientation(LinearLayout.VERTICAL);
        setBackgroundColor(Color.parseColor("#0DFFFFFF"));
        int padding = (int) (15 * context.getResources().getDisplayMetrics().density);
        setPadding(padding, padding, padding, padding);
        
        float density = context.getResources().getDisplayMetrics().density;
        
        // 标题
        titleTextView = new TextView(context);
        titleTextView.setText("任务控制");
        titleTextView.setTextColor(Color.parseColor("#333333"));
        titleTextView.setTextSize(16);
        titleTextView.setTypeface(null, android.graphics.Typeface.BOLD);
        LinearLayout.LayoutParams titleParams = new LinearLayout.LayoutParams(
                LayoutParams.MATCH_PARENT,
                LayoutParams.WRAP_CONTENT
        );
        titleParams.bottomMargin = (int) (10 * density);
        addView(titleTextView, titleParams);
        
        // 按钮容器
        LinearLayout buttonLayout = new LinearLayout(context);
        buttonLayout.setOrientation(LinearLayout.HORIZONTAL);
        buttonLayout.setGravity(Gravity.CENTER);
        
        int buttonSpacing = (int) (10 * density);
        int buttonHeight = (int) (44 * density);
        
        // 创建4个按钮
        createTaskButton = createButton(context, "创建任务", Color.parseColor("#52C51A"));
        stopTaskButton = createButton(context, "停止任务", Color.parseColor("#FF4D4F"));
        interruptButton = createButton(context, "打断", Color.parseColor("#FAAD14"));
        
        // 创建Loading指示器
        createLoadingView = createLoadingIndicator(context);
        stopLoadingView = createLoadingIndicator(context);
        interruptLoadingView = createLoadingIndicator(context);
        destroyAllLoadingView = createLoadingIndicator(context);
        
        // 添加按钮到容器
        LinearLayout.LayoutParams buttonParams = new LinearLayout.LayoutParams(
                0, buttonHeight, 1.0f
        );
        
        buttonParams.rightMargin = buttonSpacing;
        buttonLayout.addView(createTaskButton, buttonParams);
        
        buttonParams = new LinearLayout.LayoutParams(0, buttonHeight, 1.0f);
        buttonParams.rightMargin = buttonSpacing;
        buttonLayout.addView(stopTaskButton, buttonParams);
        
        buttonParams = new LinearLayout.LayoutParams(0, buttonHeight, 1.0f);
        buttonLayout.addView(interruptButton, buttonParams);

        // 添加Loading到按钮
        ((LinearLayout) createTaskButton.getParent()).addView(createLoadingView);
        
        addView(buttonLayout, new LinearLayout.LayoutParams(
                LayoutParams.MATCH_PARENT,
                LayoutParams.WRAP_CONTENT
        ));
        
        // 设置点击事件
        createTaskButton.setOnClickListener(v -> {
            if (callback != null) callback.onCreateTaskClicked();
        });
        
        stopTaskButton.setOnClickListener(v -> {
            if (callback != null) callback.onStopTaskClicked();
        });
        
        interruptButton.setOnClickListener(v -> {
            if (callback != null) callback.onInterruptClicked();
        });

        // 初始状态：无任务
        updateButtonStates(false);
    }
    
    private Button createButton(Context context, String text, int backgroundColor) {
        Button button = new Button(context);
        button.setText(text);
        button.setTextColor(Color.WHITE);
        button.setTextSize(14);
        button.setBackgroundColor(backgroundColor);
        button.setAllCaps(false);
        
        // 设置圆角
        float radius = 8 * context.getResources().getDisplayMetrics().density;
        button.setBackground(createRoundedBackground(backgroundColor, radius));
        
        return button;
    }
    
    private android.graphics.drawable.GradientDrawable createRoundedBackground(int color, float radius) {
        android.graphics.drawable.GradientDrawable drawable = new android.graphics.drawable.GradientDrawable();
        drawable.setColor(color);
        drawable.setCornerRadius(radius);
        return drawable;
    }
    
    private ProgressBar createLoadingIndicator(Context context) {
        ProgressBar progressBar = new ProgressBar(context);
        progressBar.setVisibility(GONE);
        return progressBar;
    }
    
    /**
     * 设置回调接口
     */
    public void setCallback(ZegoQuickStartTaskControlViewCallback callback) {
        this.callback = callback;
    }
    
    /**
     * 更新按钮状态
     *
     * @param hasTask 是否有运行中的任务
     */
    public void updateButtonStates(boolean hasTask) {
        hasTaskRunning = hasTask;
        createTaskButton.setEnabled(!hasTask);
        stopTaskButton.setEnabled(hasTask);
        interruptButton.setEnabled(hasTask);
        
        // 更新透明度
        createTaskButton.setAlpha(hasTask ? 0.5f : 1.0f);
        stopTaskButton.setAlpha(hasTask ? 1.0f : 0.5f);
        interruptButton.setAlpha(hasTask ? 1.0f : 0.5f);
    }
    
    /**
     * 设置加载状态
     *
     * @param buttonIndex 按钮索引（0:创建, 1:停止, 2:打断, 3:销毁全部）
     * @param loading     是否加载中
     */
    public void setLoading(int buttonIndex, boolean loading) {
        // 边界检查
        if (buttonIndex < 0 || buttonIndex > 3) {
            return;
        }
        
        ProgressBar loadingView = null;
        Button button = null;
        String buttonText = "";
        
        switch (buttonIndex) {
            case 0:
                loadingView = createLoadingView;
                button = createTaskButton;
                buttonText = "创建任务";
                break;
            case 1:
                loadingView = stopLoadingView;
                button = stopTaskButton;
                buttonText = "停止任务";
                break;
            case 2:
                loadingView = interruptLoadingView;
                button = interruptButton;
                buttonText = "打断";
                break;
        }
        
        if (loadingView != null && button != null) {
            if (loading) {
                loadingView.setVisibility(VISIBLE);
                button.setEnabled(false);
                button.setText("");
            } else {
                loadingView.setVisibility(GONE);
                button.setText(buttonText);
                // 恢复按钮可用性，由当前任务状态决定，确保打断按钮在有任务时不被误禁用
                updateButtonStates(hasTaskRunning);
            }
        }
    }
}


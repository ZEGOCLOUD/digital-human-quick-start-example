package com.example.zegodigitalhumanquickstart.activity;

import android.Manifest;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.widget.Button;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import com.google.android.material.bottomsheet.BottomSheetBehavior;

import com.example.zegodigitalhumanquickstart.R;
import com.example.zegodigitalhumanquickstart.callback.ZegoQuickStartDriveControlViewCallback;
import com.example.zegodigitalhumanquickstart.callback.ZegoQuickStartTaskControlViewCallback;
import com.example.zegodigitalhumanquickstart.model.ZegoQuickStartConfig;
import com.example.zegodigitalhumanquickstart.model.ZegoQuickStartDigitalHuman;
import com.example.zegodigitalhumanquickstart.model.ZegoQuickStartDriveType;
import com.example.zegodigitalhumanquickstart.model.ZegoQuickStartTask;
import com.example.zegodigitalhumanquickstart.model.ZegoQuickStartTaskStatus;
import com.example.zegodigitalhumanquickstart.network.ZegoQuickStartAPIService;
import com.example.zegodigitalhumanquickstart.ZegoQuickStartConstants;
import com.example.zegodigitalhumanquickstart.view.ZegoQuickStartDigitalHumanPlaceholderView;
import com.example.zegodigitalhumanquickstart.view.ZegoQuickStartDriveControlView;
import com.example.zegodigitalhumanquickstart.view.ZegoQuickStartTaskControlView;

import im.zego.digitalmobile.IZegoDigitalMobile;
import im.zego.digitalmobile.ZegoDigitalHuman;
import im.zego.digitalmobile.ZegoDigitalView;
import com.google.gson.JsonObject;

import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.List;

import im.zego.zegoexpress.ZegoExpressEngine;
import im.zego.zegoexpress.callback.IZegoCustomVideoRenderHandler;
import im.zego.zegoexpress.callback.IZegoEventHandler;
import im.zego.zegoexpress.constants.ZegoAECMode;
import im.zego.zegoexpress.constants.ZegoANSMode;
import im.zego.zegoexpress.constants.ZegoAudioDeviceMode;
import im.zego.zegoexpress.constants.ZegoScenario;
import im.zego.zegoexpress.constants.ZegoUpdateType;
import im.zego.zegoexpress.constants.ZegoVideoBufferType;
import im.zego.zegoexpress.constants.ZegoVideoFrameFormat;
import im.zego.zegoexpress.constants.ZegoVideoFrameFormatSeries;
import im.zego.zegoexpress.entity.ZegoCustomVideoRenderConfig;
import im.zego.zegoexpress.entity.ZegoEngineConfig;
import im.zego.zegoexpress.entity.ZegoEngineProfile;
import im.zego.zegoexpress.entity.ZegoRoomConfig;
import im.zego.zegoexpress.entity.ZegoStream;
import im.zego.zegoexpress.entity.ZegoUser;
import im.zego.zegoexpress.entity.ZegoVideoFrameParam;

import im.zego.digitalmobile.ZegoDigitalHumanResource;
import im.zego.digitalmobile.config.ZegoDigitalMobileAuth;

/**
 * 主界面Activity
 * 数字人快速启动应用的主界面，包含数字人渲染、任务管理、驱动控制等功能
 */
public class ZegoQuickStartMainActivity extends AppCompatActivity implements
        IZegoDigitalMobile.ZegoDigitalMobileListener,
        ZegoQuickStartTaskControlViewCallback,
        ZegoQuickStartDriveControlViewCallback {
    
    private static final String TAG = "ZegoQuickStartMainActivity";
    private static final int PERMISSION_REQUEST_CODE = 1000;
    
    // UI组件
    private ZegoDigitalView digitalHumanView;  // 纯视图
    private IZegoDigitalMobile digitalMobile;  // 逻辑管理
    private ZegoQuickStartDigitalHumanPlaceholderView placeholderView;
    private TextView statusLabel;
    private Button toggleControlButton;
    private View controlPanelContainer;
    private BottomSheetBehavior<View> bottomSheetBehavior;
    private ZegoQuickStartTaskControlView taskControlView;
    private ZegoQuickStartDriveControlView driveControlView;
    
    // 配置和数据
    private ZegoQuickStartConfig config;
    private ZegoQuickStartAPIService apiService;
    
    // RTC引擎
    private boolean rtcEngineCreated = false;
    private boolean isRoomLoggedIn = false;
    private boolean isPublishing = false;
    
    // 任务状态
    private ZegoQuickStartTask currentTask;
    private String currentStreamId;
    private String currentRoomId;
    private String currentUserId;
    private String currentToken;
    
    
    // UI状态
    private boolean isControlPanelVisible = false;
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        
        // 初始化配置和服务
        initConfigAndServices();
        
        // 初始化UI
        initViews();
        
        // 请求权限
        requestPermissions();
        
        // 加载初始数据
        loadInitialData();
    }
    
    // ==================== 初始化 ====================
    
    private void initConfigAndServices() {
        config = new ZegoQuickStartConfig();
        
        apiService = ZegoQuickStartAPIService.getInstance();
        apiService.setServerURL(config.getServerURL());
    }
    
    private void initViews() {
        View mainRoot = findViewById(R.id.main_root);
        digitalHumanView = findViewById(R.id.digital_human_view);
        placeholderView = findViewById(R.id.placeholder_view);
        statusLabel = findViewById(R.id.status_label);
        toggleControlButton = findViewById(R.id.toggle_control_button);
        controlPanelContainer = findViewById(R.id.control_panel_container);
        
        // 初始化 BottomSheetBehavior
        try {
            // 启用NestedScrollView的嵌套滚动
            if (controlPanelContainer instanceof androidx.core.widget.NestedScrollView) {
                ((androidx.core.widget.NestedScrollView) controlPanelContainer).setNestedScrollingEnabled(true);
            }
            
            bottomSheetBehavior = BottomSheetBehavior.from(controlPanelContainer);
            bottomSheetBehavior.setState(BottomSheetBehavior.STATE_HIDDEN);
            bottomSheetBehavior.setHideable(true);
            // 禁用拖拽,只能通过代码控制显示/隐藏
            bottomSheetBehavior.setDraggable(false);
            
            bottomSheetBehavior.addBottomSheetCallback(new BottomSheetBehavior.BottomSheetCallback() {
                @Override
                public void onStateChanged(@NonNull View bottomSheet, int newState) {
                    if (newState == BottomSheetBehavior.STATE_EXPANDED) {
                        isControlPanelVisible = true;
                        toggleControlButton.setText(R.string.toggle_panel_close);
                    } else if (newState == BottomSheetBehavior.STATE_HIDDEN) {
                        isControlPanelVisible = false;
                        toggleControlButton.setText(R.string.toggle_panel_open);
                    } else if (newState == BottomSheetBehavior.STATE_COLLAPSED) {
                        isControlPanelVisible = false;
                        toggleControlButton.setText(R.string.toggle_panel_open);
                    }
                }

                @Override
                public void onSlide(@NonNull View bottomSheet, float slideOffset) {
                    // 在滑动过程中自动管理visibility
                    if (slideOffset > 0 && bottomSheet.getVisibility() != View.VISIBLE) {
                        bottomSheet.setVisibility(View.VISIBLE);
                    }
                    // 按钮不再跟随面板滑动，按钮固定在底部，控制面板展开时会覆盖按钮
                }
            });
        } catch (Exception e) {
            Log.e(TAG, "BottomSheetBehavior initialization failed", e);
        }

        taskControlView = findViewById(R.id.task_control_view);
        driveControlView = findViewById(R.id.drive_control_view);
        
        // 创建数字人SDK实例并绑定视图
        digitalMobile = ZegoDigitalHuman.create(this);
        if (digitalMobile != null && digitalHumanView != null) {
            digitalMobile.attach(digitalHumanView);
            Log.d(TAG, "[数字人] SDK实例已创建并绑定视图");
        }
        
        // 设置回调
        taskControlView.setCallback(this);
        driveControlView.setCallback(this);
        
        // 设置点击事件
        toggleControlButton.setOnClickListener(v -> toggleControlPanel());
        
        // 点击空白区域隐藏控制面板
        View.OnClickListener hidePanelListener = v -> {
            if (isControlPanelVisible && bottomSheetBehavior != null) {
                Log.d(TAG, "[UI] 点击背景区域,隐藏控制面板");
                bottomSheetBehavior.setState(BottomSheetBehavior.STATE_HIDDEN);
            }
        };
        
        // 设置数字人视图和占位视图可点击,并添加点击监听
        digitalHumanView.setClickable(true);
        digitalHumanView.setOnClickListener(hidePanelListener);
        
        placeholderView.setClickable(true);
        placeholderView.setOnClickListener(hidePanelListener);
        
        // 使用post确保在布局完成后显示
        placeholderView.post(() -> {
            placeholderView.show();
            Log.d(TAG, "[UI] 占位视图已显示");
        });
    }
    
    private void requestPermissions() {
        String[] permissions = {
                Manifest.permission.CAMERA,
                Manifest.permission.RECORD_AUDIO
        };
        
        List<String> permissionsToRequest = new ArrayList<>();
        for (String permission : permissions) {
            if (ContextCompat.checkSelfPermission(this, permission) != PackageManager.PERMISSION_GRANTED) {
                permissionsToRequest.add(permission);
            }
        }
        
        if (!permissionsToRequest.isEmpty()) {
            // 检查是否需要显示权限说明
            boolean shouldShowRationale = false;
            for (String permission : permissionsToRequest) {
                if (ActivityCompat.shouldShowRequestPermissionRationale(this, permission)) {
                    shouldShowRationale = true;
                    break;
                }
            }
            
            if (shouldShowRationale) {
                // 显示权限说明对话框
                Toast.makeText(this, "应用需要摄像头和麦克风权限才能正常工作", Toast.LENGTH_LONG).show();
            }
            
            ActivityCompat.requestPermissions(this,
                    permissionsToRequest.toArray(new String[0]),
                    PERMISSION_REQUEST_CODE);
        } else {
            Log.d(TAG, "所有权限已授予");
        }
    }
    
    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == PERMISSION_REQUEST_CODE) {
            boolean allGranted = true;
            // 检查权限是否被授予
            for (int i = 0; i < permissions.length; i++) {
                if (grantResults[i] != PackageManager.PERMISSION_GRANTED) {
                    allGranted = false;
                    Log.w(TAG, "权限未授予: " + permissions[i]);
                    
                    // 显示提示信息
                    String permissionName = permissions[i];
                    if (Manifest.permission.CAMERA.equals(permissionName)) {
                        Toast.makeText(this, "摄像头权限被拒绝，部分功能可能无法使用", Toast.LENGTH_LONG).show();
                    } else if (Manifest.permission.RECORD_AUDIO.equals(permissionName)) {
                        Toast.makeText(this, "麦克风权限被拒绝，RTC驱动功能将无法使用", Toast.LENGTH_LONG).show();
                    }
                }
            }
            
            if (allGranted) {
                Log.d(TAG, "所有权限已授予");
            }
        }
    }
    
    /**
     * 获取当前用户ID，如果不存在则生成新的
     * @return 用户ID
     */
    private String getCurrentUserId() {
        if (currentUserId == null || currentUserId.isEmpty()) {
            currentUserId = "user_" + ((int) (Math.random() * 1000000));
            Log.d(TAG, "[用户ID] 生成新的 userId: " + currentUserId);
        }
        return currentUserId;
    }
    
    private void loadInitialData() {
        
        String userId = getCurrentUserId();
        
        // 加载数字人信息并更新占位视图
        apiService.getDigitalHumanInfo(userId, new ZegoQuickStartAPIService.DigitalHumanInfoCallback() {
            @Override
            public void onSuccess(ZegoQuickStartDigitalHuman digitalHuman) {
                // 边界检查
                if (digitalHuman == null) {
                    Log.e(TAG, "数字人信息为空");
                    placeholderView.updateContent("数字人", null);
                    return;
                }
                
                // 更新占位视图
                String name = digitalHuman.getName();
                String coverUrl = digitalHuman.getAvatarUrl(); // 使用avatarUrl作为coverUrl
                placeholderView.updateContent(name, coverUrl);
                Log.d(TAG, "[数字人] 加载数字人信息成功: " + name);

                // 创建数字人
                initExpressEngineWithAppId(digitalHuman.getAppId());
                
                // 触发预加载
                preloadDigitalHumanResource(digitalHuman);
            }
            
            @Override
            public void onFailure(int code, String message) {
                // 加载失败时显示默认信息
                placeholderView.updateContent("数字人", null);
                Log.e(TAG, "[数字人] 加载数字人信息失败: " + message);
            }
        });
    }
    
    /**
     * 预加载数字人资源
     * @param digitalHuman 数字人信息对象
     */
    private void preloadDigitalHumanResource(ZegoQuickStartDigitalHuman digitalHuman) {
        if (digitalHuman == null) {
            Log.w(TAG, "[预加载] 数字人信息为空，跳过预加载");
            return;
        }
        
        String digitalHumanId = digitalHuman.getDigitalHumanId();
        if (digitalHumanId == null || digitalHumanId.isEmpty()) {
            Log.w(TAG, "[预加载] 数字人ID为空，跳过预加载");
            return;
        }
        
        // 从数字人信息中获取appID和token
        long appId = digitalHuman.getAppId();
        if (appId == 0) {
            Log.w(TAG, "[预加载] AppID未设置，跳过预加载");
            return;
        }
        
        String token = digitalHuman.getToken();
        if (token == null || token.isEmpty()) {
            Log.w(TAG, "[预加载] Token为空，跳过预加载");
            return;
        }
        
        // 预加载使用当前客户端的 userId
        String userId = getCurrentUserId();
        
        Log.d(TAG, "[预加载] 开始预加载数字人资源: " + digitalHumanId);
        
        // 创建认证对象，使用返回的token
        ZegoDigitalMobileAuth auth = new ZegoDigitalMobileAuth(appId, userId, token);
        
        // 执行预加载
        ZegoDigitalHumanResource.INSTANCE.preload(
            ZegoQuickStartMainActivity.this,
            auth,
            digitalHumanId,
            new ZegoDigitalHumanResource.PreloadCallback() {
                @Override
                public void onSuccess() {

                    Log.i(TAG, "[预加载] 预加载成功: " + digitalHumanId);
                }
                
                @Override
                public void onProgress(int progress) {
                    Log.d(TAG, "[预加载] 预加载进度: " + digitalHumanId + " - " + progress + "%");
                }
                
                @Override
                public void onError(int code, String msg) {
                    Log.e(TAG, "[预加载] 预加载失败: " + digitalHumanId + " - code: " + code + ", msg: " + msg);
                }
            }
        );
    }
    
    // ==================== UI控制 ====================
    
    private void toggleControlPanel() {
        if (bottomSheetBehavior == null) return;
        
        if (bottomSheetBehavior.getState() == BottomSheetBehavior.STATE_EXPANDED) {
            bottomSheetBehavior.setState(BottomSheetBehavior.STATE_HIDDEN);
        } else {
            // BottomSheetBehavior会自动处理visibility,不需要手动设置
            bottomSheetBehavior.setState(BottomSheetBehavior.STATE_EXPANDED);
        }
    }
    
    
    private void updateStatus(String status) {
        runOnUiThread(() -> {
            statusLabel.setText(status);
            Log.d(TAG, "[状态] " + status);
        });
    }
    
    // ==================== RTC引擎管理 ====================
    
    private void initExpressEngineWithAppId(long appId) {
        if (rtcEngineCreated) {
            Log.d(TAG, "[RTC] 引擎已创建，跳过");
            return;
        }
        
        try {
            // 创建引擎
            ZegoEngineProfile profile = new ZegoEngineProfile();
            profile.appID = appId;
            profile.scenario = ZegoScenario.HIGH_QUALITY_CHATROOM;  // 使用 HIGH_QUALITY_CHATROOM，
            profile.application = getApplication();
            
            ZegoExpressEngine.createEngine(profile, null);
            
            rtcEngineCreated = true;
            Log.d(TAG, "[RTC] Express引擎创建成功，AppId: " + appId);
            
            // 注意：自定义视频渲染需要在 loginRoom 成功后，startPlayingStream 之前启用
            
        } catch (Exception e) {
            Log.e(TAG, "[RTC] 创建引擎失败", e);
        }
    }
    
    private void enableCustomVideoRender() {
        try {
            ZegoExpressEngine engine = ZegoExpressEngine.getEngine();
            if (engine == null) {
                Log.e(TAG, "[RTC] 引擎未创建，无法启用自定义视频渲染");
                return;
            }
            
            // 开启自定义渲染
            ZegoCustomVideoRenderConfig renderConfig = new ZegoCustomVideoRenderConfig();
            renderConfig.bufferType = ZegoVideoBufferType.RAW_DATA;
            renderConfig.frameFormatSeries = ZegoVideoFrameFormatSeries.RGB;
            renderConfig.enableEngineRender = false;
            
            engine.enableCustomVideoRender(true, renderConfig);
            
            // 监听视频帧回调
            engine.setCustomVideoRenderHandler(new IZegoCustomVideoRenderHandler() {
                // onCapturedVideoFrameRawData 可能是可选方法，不添加 @Override
                public void onCapturedVideoFrameRawData(ByteBuffer[] data, int[] dataLength, ZegoVideoFrameParam param, ZegoVideoFrameFormat flipMode) {
                    // 不需要处理本地采集的视频帧
                }
                
                @Override
                public void onRemoteVideoFrameRawData(ByteBuffer[] data, int[] dataLength, ZegoVideoFrameParam param, String streamID) {
                    // 边界检查
                    if (streamID != null && streamID.equals(currentStreamId) && data != null && data.length > 0 && digitalMobile != null) {
                        try {
                            // 转换RTC的VideoFrameParam为数字人SDK的VideoFrameParam
                            IZegoDigitalMobile.ZegoVideoFrameParam sdkParam = new IZegoDigitalMobile.ZegoVideoFrameParam();
                            sdkParam.width = param.width;
                            sdkParam.height = param.height;
                            sdkParam.rotation = param.rotation;
                            
                            // 转换format
                            switch (param.format) {
                                case I420:
                                    sdkParam.format = IZegoDigitalMobile.ZegoVideoFrameFormat.I420;
                                    break;
                                case NV12:
                                    sdkParam.format = IZegoDigitalMobile.ZegoVideoFrameFormat.NV12;
                                    break;
                                case NV21:
                                    sdkParam.format = IZegoDigitalMobile.ZegoVideoFrameFormat.NV21;
                                    break;
                                default:
                                    sdkParam.format = IZegoDigitalMobile.ZegoVideoFrameFormat.Unknown;
                                    break;
                            }
                            
                            // 复制 strides
                            if (param.strides != null && param.strides.length >= 4) {
                                for (int i = 0; i < 4; i++) {
                                    sdkParam.strides[i] = param.strides[i];
                                }
                            }
                            
                            // 调用数字人SDK的方法
                            digitalMobile.onRemoteVideoFrameRawData(data, dataLength, sdkParam, streamID);
                        } catch (Exception e) {
                            Log.e(TAG, "[RTC] 处理视频帧失败", e);
                        }
                    } else {
                        if (streamID == null || !streamID.equals(currentStreamId)) {
                            Log.v(TAG, "[RTC] 忽略视频帧: streamID=" + streamID + " (期望: " + currentStreamId + ")");
                        } else if (data == null || data.length == 0) {
                            Log.w(TAG, "[RTC] 视频帧数据为空: streamID=" + streamID);
                        }
                    }
                }
            });
            
            // 监听 Express SEI 数据和房间流更新
            engine.setEventHandler(new IZegoEventHandler() {
                @Override
                public void onRoomStreamUpdate(String roomID, ZegoUpdateType updateType, ArrayList<ZegoStream> streamList, org.json.JSONObject extendedData) {
                    handleRoomStreamUpdate(roomID, updateType, streamList);
                }
                
                @Override
                public void onPlayerSyncRecvSEI(String streamID, byte[] data) {
                    handlePlayerSyncRecvSEI(streamID, data);
                }
            });
            
            Log.d(TAG, "[RTC] 自定义视频渲染已启用");
        } catch (Exception e) {
            Log.e(TAG, "[RTC] 启用自定义视频渲染失败", e);
        }
    }
    
    private void loginRoom(String roomId, String userId, String token, Runnable onSuccess, Runnable onFailure) {
        updateStatus("正在登录房间...");
        
        ZegoExpressEngine engine = ZegoExpressEngine.getEngine();
        if (engine == null) {
            Log.e(TAG, "[RTC] 引擎未创建，无法登录房间");
            updateStatus("错误：RTC引擎未初始化");
            if (onFailure != null) {
                runOnUiThread(onFailure);
            }
            return;
        }
        
        // 设置高级配置
        ZegoEngineConfig engineConfig = new ZegoEngineConfig();
        engineConfig.advancedConfig.put("set_audio_volume_ducking_mode", "1");
        engineConfig.advancedConfig.put("enable_rnd_volume_adaptive", "true");
        engineConfig.advancedConfig.put("sideinfo_callback_version", "3");
        engineConfig.advancedConfig.put("sideinfo_bound_to_video_decoder", "true");

        ZegoExpressEngine.setEngineConfig(engineConfig);
        
        ZegoExpressEngine.getEngine().setRoomScenario(ZegoScenario.HIGH_QUALITY_CHATROOM);
        ZegoExpressEngine.getEngine().setAudioDeviceMode(ZegoAudioDeviceMode.GENERAL);

        //开启传统音频 3A 处理
        ZegoExpressEngine.getEngine().enableAGC(true);
        ZegoExpressEngine.getEngine().enableAEC(true);
        ZegoExpressEngine.getEngine().enableANS(true);
        
        //开启 AI 回声消除
        ZegoExpressEngine.getEngine().setAECMode(ZegoAECMode.AI_BALANCED);
        // 开启 AI 降噪，适度的噪声抑制
        ZegoExpressEngine.getEngine().setANSMode(ZegoANSMode.MEDIUM);
        
        ZegoRoomConfig roomConfig = new ZegoRoomConfig();
        roomConfig.isUserStatusNotify = true;
        roomConfig.token = token;
        
        ZegoUser user = new ZegoUser(userId, userId);
        
        engine.loginRoom(roomId, user, roomConfig, (int errorCode, org.json.JSONObject extendedData) -> {
            if (errorCode == 0) {
                isRoomLoggedIn = true;
                Log.d(TAG, "[RTC] 登录房间成功: " + roomId);
                
                // 开启自定义渲染，express 开启自定义渲染需要在 startPublishingStream/startPlayingStream 前
                enableCustomVideoRender();
                
                if (onSuccess != null) {
                    runOnUiThread(onSuccess);
                }
            } else {
                Log.e(TAG, "[RTC] 登录房间失败: " + errorCode);
                updateStatus("登录房间失败: " + errorCode);
                if (onFailure != null) {
                    runOnUiThread(onFailure);
                }
            }
        });
    }
    
    private void handleRoomStreamUpdate(String roomID, ZegoUpdateType updateType, ArrayList<ZegoStream> streamList) {
        Log.d(TAG, "[RTC] 房间流更新: roomID=" + roomID + ", 更新类型=" + updateType);
        
        if (updateType == ZegoUpdateType.ADD) {
            for (ZegoStream stream : streamList) {
                if (stream.streamID.equals(currentStreamId)) {
                    Log.d(TAG, "[RTC] 检测到目标流，开始拉流: " + stream.streamID);
                    startPlayingStream(stream.streamID);
                    break;
                }
            }
        }
    }
    
    private void startPlayingStream(String streamID) {
        ZegoExpressEngine engine = ZegoExpressEngine.getEngine();
        if (engine == null) {
            Log.e(TAG, "[RTC] 引擎未创建，无法开始拉流");
            updateStatus("错误：RTC引擎未初始化");
            return;
        }
        
        // 设置拉流缓冲区
        engine.setPlayStreamBufferIntervalRange(streamID, 100, 2000);
        
        // 开始拉流（使用ZegoCanvas参数）
        im.zego.zegoexpress.entity.ZegoCanvas canvas = new im.zego.zegoexpress.entity.ZegoCanvas(null);
        engine.startPlayingStream(streamID, canvas);
        
        updateStatus("正在拉流...");
        Log.d(TAG, "[RTC] 开始拉流: " + streamID);
    }
    
    private void handlePlayerSyncRecvSEI(String streamID, byte[] data) {
        if (streamID != null && streamID.equals(currentStreamId) && data != null && data.length > 0 && digitalMobile != null) {
            try {
                digitalMobile.onPlayerSyncRecvSEI(streamID, data);
            } catch (Exception e) {
                Log.e(TAG, "[RTC] 处理SEI数据失败", e);
            }
        }
    }
    
    // ==================== 任务管理 ====================
    
    @Override
    public void onCreateTaskClicked() {
        // 隐藏控制面板（与"关闭控制面板"按钮功能一致）
        if (isControlPanelVisible) {
            toggleControlPanel();
        }
        
        updateStatus("正在创建任务...");
        taskControlView.setLoading(0, true);
        
        // 获取或生成 userId
        String userId = getCurrentUserId();
        
        // 步骤1: 构建任务配置（传递OutputMode和UserId）
        JsonObject taskConfig = new JsonObject();
        taskConfig.addProperty("OutputMode", 2);  // 小图模式
        taskConfig.addProperty("UserId", userId);  // 用户ID，必选
        
        // 步骤2: 调用API创建数字人流任务
        apiService.createDigitalHumanStreamTask(taskConfig, new ZegoQuickStartAPIService.TaskCallback() {
            @Override
            public void onSuccess(JsonObject data) {
                // 提取服务端返回的任务数据
                String taskId = data.has("TaskId") ? data.get("TaskId").getAsString() : "";
                String base64Config = data.has("Base64Config") ? data.get("Base64Config").getAsString() : "";
                String appIdStr = data.has("AppId") ? data.get("AppId").getAsString() : "";
                String roomId = data.has("RoomId") ? data.get("RoomId").getAsString() : "";
                String streamId = data.has("StreamId") ? data.get("StreamId").getAsString() : "";
                String token = data.has("Token") ? data.get("Token").getAsString() : "";
                
                // 边界检查
                if (appIdStr == null || appIdStr.isEmpty()) {
                    updateStatus("错误：服务端未返回 AppId");
                    taskControlView.setLoading(0, false);
                    return;
                }
                
                if (token == null || token.isEmpty()) {
                    updateStatus("错误：服务端未返回 Token");
                    taskControlView.setLoading(0, false);
                    return;
                }
                
                if (roomId == null || roomId.isEmpty()) {
                    updateStatus("错误：服务端未返回 RoomId");
                    taskControlView.setLoading(0, false);
                    return;
                }
                
                if (streamId == null || streamId.isEmpty()) {
                    updateStatus("错误：服务端未返回 StreamId");
                    taskControlView.setLoading(0, false);
                    return;
                }
                
                if (base64Config == null || base64Config.isEmpty()) {
                    updateStatus("错误：服务端未返回 Base64Config");
                    taskControlView.setLoading(0, false);
                    return;
                }
                
                // 步骤3: 使用返回的 AppId 初始化Express引擎
                long appId = Long.parseLong(appIdStr);
                
                // 更新API服务配置中的appId（用于后续API调用）
                apiService.setAppId(appId);
                
                // 创建任务对象并保存任务状态
                currentRoomId = roomId;
                currentStreamId = streamId;
                currentTask = new ZegoQuickStartTask();
                currentTask.setTaskId(taskId);
                currentTask.setRoomId(roomId);
                currentTask.setStreamId(streamId);
                currentTask.setAppId(appId);  // 使用从服务端返回的appId
                currentTask.setStatus(ZegoQuickStartTaskStatus.RUNNING);
                
                updateStatus("任务创建成功");
                taskControlView.updateButtonStates(true);
                taskControlView.setLoading(0, false);
                driveControlView.setDriveButtonsEnabled(true);
                
                Log.d(TAG, "[任务] 创建成功: " + taskId);
                
                // 步骤4: 使用返回的 token 登录RTC房间
                currentToken = token;
                loginRoom(roomId, userId, token, () -> {
                    // 步骤5: 启动数字人渲染（使用服务端返回的Base64Config）
                    // 注意: 拉流在RTC回调的房间消息onRoomStreamUpdate中实现
                    if (base64Config != null && !base64Config.isEmpty()) {
                        Log.d(TAG, "[数字人] 使用服务端返回的 Base64Config 启动数字人");
                        startDigitalHuman(base64Config);
                    }
                }, () -> {
                    // 登录失败时的处理
                    taskControlView.setLoading(0, false);
                    if (placeholderView != null) {
                        placeholderView.show();
                    }
                });
            }
            
            @Override
            public void onFailure(int code, String message) {
                updateStatus("创建任务失败: " + message);
                taskControlView.setLoading(0, false);
                if (placeholderView != null) {
                    placeholderView.show();
                }
                Log.e(TAG, "[任务] 创建失败: " + message);
            }
        });
    }
    
    
    @Override
    public void onStopTaskClicked() {
        if (currentTask == null) {
            return;
        }
        
        // 隐藏控制面板
        if (isControlPanelVisible) {
            toggleControlPanel();
        }
        
        updateStatus("正在停止任务...");
        taskControlView.setLoading(1, true);
        
        // 调用核心停止逻辑，并更新UI
        stopTaskInternal(true);
    }
    
    /**
     * 停止任务的核心逻辑
     * @param updateUI 是否更新UI（在onDestroy中调用时设为false，避免UI操作）
     */
    private void stopTaskInternal(boolean updateUI) {
        if (currentTask == null) {
            return;
        }
        
        // 先停止 RTC，再停止数字人
        ZegoExpressEngine engine = null;
        if (rtcEngineCreated) {
            try {
                engine = ZegoExpressEngine.getEngine();
            } catch (Exception e) {
                Log.e(TAG, "[RTC] 获取引擎失败", e);
            }
        }
        
        // 1. 先设置 setCustomVideoRenderHandler(null)
        if (engine != null) {
            try {
                engine.setCustomVideoRenderHandler(null);
                Log.d(TAG, "[RTC] 已清除自定义视频渲染处理器");
            } catch (Exception e) {
                Log.e(TAG, "[RTC] 清除自定义视频渲染处理器失败", e);
            }
        }
        
        // 2. 停止拉流
        if (currentStreamId != null && engine != null) {
            try {
                engine.stopPlayingStream(currentStreamId);
                Log.d(TAG, "[RTC] 已停止拉流: " + currentStreamId);
            } catch (Exception e) {
                Log.e(TAG, "[RTC] 停止拉流失败", e);
            }
        }
        
        // 保存taskId用于后续API调用
        String taskId = currentTask.getTaskId();
        
        // 3. 退出房间（使用回调确保异步操作完成）
        if (isRoomLoggedIn && currentRoomId != null && engine != null) {
            try {
                engine.logoutRoom(currentRoomId, (errorCode, extendedData) -> {
                Log.d(TAG, "[RTC] 登出房间结果: errorCode=" + errorCode);
                isRoomLoggedIn = false;
                
                // 4. RTC 完全停止后，再停止数字人
                stopDigitalHuman();
                
                // 5. 直接调用停止任务 API
                callStopTaskAPI(taskId, updateUI);
            });
            } catch (Exception e) {
                // 登出失败时兜底处理，避免未关闭的任务和引擎
                Log.e(TAG, "[RTC] 登出房间失败，直接停止任务", e);
                isRoomLoggedIn = false;
                stopDigitalHuman();
                callStopTaskAPI(taskId, updateUI);
            }
        } else {
            // 如果没有登录房间，直接停止数字人和调用 API
            stopDigitalHuman();
            callStopTaskAPI(taskId, updateUI);
        }
    }
    
    /**
     * 调用停止任务API
     * @param taskId 任务ID
     * @param updateUI 是否更新UI
     */
    private void callStopTaskAPI(String taskId, boolean updateUI) {
        if (taskId == null || taskId.isEmpty()) {
            return;
        }
        
        apiService.stopDigitalHumanStreamTask(taskId, new ZegoQuickStartAPIService.CommonCallback() {
            @Override
            public void onSuccess(JsonObject data) {
                if (updateUI) {
                    cleanupTaskUIAfterStop();
                } else {
                    // 只清理状态，不更新UI
                    cleanupTaskStateOnly();
                }
            }
            
            @Override
            public void onFailure(int code, String message) {
                Log.e(TAG, "[任务] 停止任务API调用失败: " + message);
                if (updateUI) {
                    updateStatus("停止失败: " + message);
                    taskControlView.setLoading(1, false);
                } else {
                    // 即使API调用失败，也清理本地状态
                    cleanupTaskStateOnly();
                }
            }
        });
    }
    
    /**
     * 仅清理任务状态，不更新UI（用于onDestroy场景）
     */
    private void cleanupTaskStateOnly() {
        currentTask = null;
        currentStreamId = null;
        currentRoomId = null;
        currentUserId = null;
        currentToken = null;
        Log.d(TAG, "[任务] 已清理任务状态");
    }
    
    private void cleanupTaskUIAfterStop() {
        currentTask = null;
        currentStreamId = null;
        currentRoomId = null;
        currentUserId = null;
        currentToken = null;
        
        updateStatus("任务已停止");
        taskControlView.updateButtonStates(false);
        taskControlView.setLoading(1, false);
        driveControlView.setDriveButtonsEnabled(false);
        
        if (placeholderView != null) {
            placeholderView.show();
        }
        
        Log.d(TAG, "[任务] 已停止");
    }
    
    @Override
    public void onInterruptClicked() {
        if (currentTask == null) {
            return;
        }
        
        // 隐藏控制面板
        if (isControlPanelVisible) {
            toggleControlPanel();
        }
        
        taskControlView.setLoading(2, true);
        
        apiService.interruptDriveTask(currentTask.getTaskId(), new ZegoQuickStartAPIService.CommonCallback() {
            @Override
            public void onSuccess(JsonObject data) {
                updateStatus("打断成功");
                taskControlView.setLoading(2, false);
            }
            
            @Override
            public void onFailure(int code, String message) {
                updateStatus("打断失败: " + message);
                taskControlView.setLoading(2, false);
            }
        });
    }
    

    public void destroyAllTasks() {
        apiService.queryDigitalHumanStreamTasks(new ZegoQuickStartAPIService.TaskListCallback() {
            @Override
            public void onSuccess(List<ZegoQuickStartTask> tasks) {
                if (tasks == null || tasks.isEmpty()) {
                    updateStatus("没有运行中的任务");
                    taskControlView.setLoading(3, false);
                    destroyExpress();
                    return;
                }
                
                // 筛选test_room_开头的任务
                List<ZegoQuickStartTask> filteredTasks = new ArrayList<>();
                for (ZegoQuickStartTask task : tasks) {
                    if (task.getRoomId().startsWith(ZegoQuickStartConstants.TASK_ROOM_PREFIX)) {
                        filteredTasks.add(task);
                    }
                }
                
                if (filteredTasks.isEmpty()) {
                    updateStatus("没有可销毁的test_room_任务");
                    taskControlView.setLoading(3, false);
                    destroyExpress();
                    return;
                }
                
                // 依次停止所有任务
                destroyTasksRecursively(filteredTasks, 0, filteredTasks.size());
            }
            
            @Override
            public void onFailure(int code, String message) {
                updateStatus("查询任务失败");
                taskControlView.setLoading(3, false);
            }
        });
    }
    
    private void stopRTCBeforeDestroy(Runnable completion) {
        ZegoExpressEngine engine = null;
        if (rtcEngineCreated) {
            try {
                engine = ZegoExpressEngine.getEngine();
            } catch (Exception e) {
                Log.e(TAG, "[RTC] 获取引擎失败(销毁任务)", e);
            }
        }
        
        if (engine != null) {
            try {
                engine.setCustomVideoRenderHandler(null);
                Log.d(TAG, "[RTC] 已清除自定义视频渲染处理器(销毁任务)");
            } catch (Exception e) {
                Log.e(TAG, "[RTC] 清除自定义视频渲染处理器失败(销毁任务)", e);
            }
        }
        
        if (currentStreamId != null && engine != null) {
            try {
                engine.stopPlayingStream(currentStreamId);
                Log.d(TAG, "[RTC] 已停止拉流(销毁任务): " + currentStreamId);
            } catch (Exception e) {
                Log.e(TAG, "[RTC] 停止拉流失败(销毁任务)", e);
            }
        }
        
        Runnable invokeCompletionOnUi = () -> {
            if (completion != null) {
                runOnUiThread(completion);
            }
        };
        
        if (isRoomLoggedIn && currentRoomId != null && engine != null) {
            try {
                engine.logoutRoom(currentRoomId, (errorCode, extendedData) -> {
                    Log.d(TAG, "[RTC] 登出房间结果(销毁任务): errorCode=" + errorCode);
                    isRoomLoggedIn = false;
                    stopDigitalHuman();
                    
                    if (rtcEngineCreated) {
                        ZegoExpressEngine.destroyEngine(() -> {
                            rtcEngineCreated = false;
                            invokeCompletionOnUi.run();
                        });
                    } else {
                        invokeCompletionOnUi.run();
                    }
                });
            } catch (Exception e) {
                Log.e(TAG, "[RTC] 登出房间失败(销毁任务)", e);
                stopDigitalHuman();
                if (rtcEngineCreated) {
                    ZegoExpressEngine.destroyEngine(() -> {
                        rtcEngineCreated = false;
                        invokeCompletionOnUi.run();
                    });
                } else {
                    invokeCompletionOnUi.run();
                }
            }
        } else {
            stopDigitalHuman();
            if (rtcEngineCreated) {
                ZegoExpressEngine.destroyEngine(() -> {
                    rtcEngineCreated = false;
                    invokeCompletionOnUi.run();
                });
            } else {
                invokeCompletionOnUi.run();
            }
        }
    }
    
    private void destroyTasksRecursively(List<ZegoQuickStartTask> tasks, int index, final int total) {
        // 边界检查
        if (index >= tasks.size()) {
            updateStatus("已销毁" + total + "个任务");
            taskControlView.setLoading(3, false);
            return;
        }
        
        ZegoQuickStartTask task = tasks.get(index);
        Runnable callStopApi = () -> apiService.stopDigitalHumanStreamTask(task.getTaskId(), new ZegoQuickStartAPIService.CommonCallback() {
            @Override
            public void onSuccess(JsonObject data) {
                if (currentTask != null && task.getTaskId().equals(currentTask.getTaskId())) {
                    cleanupTaskUIAfterStop();
                }
                // 继续下一个
                destroyTasksRecursively(tasks, index + 1, total);
            }
            
            @Override
            public void onFailure(int code, String message) {
                // 忽略错误，继续下一个
                destroyTasksRecursively(tasks, index + 1, total);
            }
        });
        
        if (currentTask != null && task.getTaskId().equals(currentTask.getTaskId())) {
            stopRTCBeforeDestroy(callStopApi);
        } else {
            callStopApi.run();
        }
    }
    
    // ==================== 驱动功能 ====================
    
    @Override
    public void onTextDriveClicked() {
        if (currentTask == null) {
            updateStatus("请先创建任务");
            return;
        }
        
        // 隐藏控制面板
        if (isControlPanelVisible) {
            toggleControlPanel();
        }
        
        updateStatus("正在文本驱动...");
        driveControlView.setLoading(ZegoQuickStartDriveType.TEXT, true);
        
        apiService.driveByText(currentTask.getTaskId(), new ZegoQuickStartAPIService.CommonCallback() {
            @Override
            public void onSuccess(JsonObject data) {
                updateStatus("文本驱动成功");
                driveControlView.setLoading(ZegoQuickStartDriveType.TEXT, false);
            }
            
            @Override
            public void onFailure(int code, String message) {
                updateStatus("文本驱动失败: " + message);
                driveControlView.setLoading(ZegoQuickStartDriveType.TEXT, false);
            }
        });
    }
    
    @Override
    public void onAudioDriveClicked() {
        if (currentTask == null) {
            updateStatus("请先创建任务");
            return;
        }
        
        // 隐藏控制面板
        if (isControlPanelVisible) {
            toggleControlPanel();
        }
        
        updateStatus("正在音频驱动...");
        driveControlView.setLoading(ZegoQuickStartDriveType.AUDIO, true);
        
        apiService.driveByAudio(currentTask.getTaskId(), new ZegoQuickStartAPIService.CommonCallback() {
            @Override
            public void onSuccess(JsonObject data) {
                updateStatus("音频驱动成功");
                driveControlView.setLoading(ZegoQuickStartDriveType.AUDIO, false);
            }
            
            @Override
            public void onFailure(int code, String message) {
                updateStatus("音频驱动失败: " + message);
                driveControlView.setLoading(ZegoQuickStartDriveType.AUDIO, false);
            }
        });
    }
    
    @Override
    public void onWsTTSDriveClicked() {
        if (currentTask == null) {
            updateStatus("请先创建任务");
            return;
        }
        
        // 隐藏控制面板
        if (isControlPanelVisible) {
            toggleControlPanel();
        }
        
        updateStatus("正在WebSocket TTS驱动...");
        driveControlView.setLoading(ZegoQuickStartDriveType.WS_TTS, true);
        
        apiService.driveByWsStreamWithTTS(currentTask.getTaskId(), new ZegoQuickStartAPIService.CommonCallback() {
            @Override
            public void onSuccess(JsonObject data) {
                updateStatus("WebSocket TTS驱动成功");
                driveControlView.setLoading(ZegoQuickStartDriveType.WS_TTS, false);
            }
            
            @Override
            public void onFailure(int code, String message) {
                updateStatus("WebSocket TTS驱动失败: " + message);
                driveControlView.setLoading(ZegoQuickStartDriveType.WS_TTS, false);
            }
        });
    }
    
    // ==================== 数字人管理 ====================
    
    private void startDigitalHuman(String base64Config) {
        // 边界检查
        if (base64Config == null || base64Config.isEmpty()) {
            Log.e(TAG, "[数字人] 错误：配置为空");
            updateStatus("数字人错误：配置为空");
            return;
        }
        
        if (digitalMobile == null) {
            Log.e(TAG, "[数字人] 错误：数字人SDK未初始化");
            updateStatus("数字人错误：数字人SDK未初始化");
            return;
        }
        
        try {
            Log.d(TAG, "[数字人] 开始启动数字人，配置长度: " + base64Config.length());
            digitalMobile.start(base64Config, this);
        } catch (Exception e) {
            Log.e(TAG, "[数字人] 启动数字人失败", e);
            updateStatus("数字人错误：启动失败: " + e.getMessage());
        }
    }
    
    private void stopDigitalHuman() {
        if (digitalMobile == null) {
            return;
        }
        
        try {
            Log.d(TAG, "[数字人] 停止数字人");
            digitalMobile.stop();
            updateStatus("数字人已停止");
            if (placeholderView != null) {
                placeholderView.show();
            }
        } catch (Exception e) {
            Log.e(TAG, "[数字人] 停止数字人失败", e);
        }
    }
    
    // ==================== IZegoDigitalMobile.ZegoDigitalMobileListener 回调 ====================
    
    @Override
    public void onDigitalMobileStartSuccess() {
        Log.d(TAG, "[数字人] 数字人启动成功");
        updateStatus("数字人启动成功");
    }
    
    @Override
    public void onError(int errorCode, String errorMsg) {
        Log.e(TAG, "[数字人] 数字人错误: " + errorCode + " - " + errorMsg);
        updateStatus("数字人错误: " + errorMsg);
    }
    
    @Override
    public void onSurfaceFirstFrameDraw() {
        Log.d(TAG, "[数字人] 首帧绘制完成");
        updateStatus("数字人首帧绘制完成");
        if (placeholderView != null) {
            placeholderView.hide();
        }
    }
    
    // ==================== 生命周期 ====================
    
    @Override
    protected void onStop() {
        super.onStop();
    }
    
    @Override
    protected void onResume() {
        super.onResume();
        
        Log.d(TAG, "onResume");
        
        // 重新应用配置（无持久化）
        apiService.setServerURL(config.getServerURL());
    }


    private void destroyExpress() {
        // 销毁引擎
        if (rtcEngineCreated) {
            try {
                ZegoExpressEngine.destroyEngine(null);
                rtcEngineCreated = false;
            } catch (Exception e) {
                Log.e(TAG, "销毁引擎时发生异常", e);
            }
        }
    }
    
    @Override
    protected void onDestroy() {
        super.onDestroy();
        destroyAllTasks();
        Log.d(TAG, "ZegoQuickStartMainActivity destroyed");
    }
}

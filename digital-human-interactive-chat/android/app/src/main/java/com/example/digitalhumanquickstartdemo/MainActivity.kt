package com.example.digitalhumanquickstartdemo

import android.os.Bundle
import android.util.Log
import android.widget.Button
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.example.digitalhumanquickstartdemo.config.Config
import com.google.gson.Gson
import com.google.gson.JsonArray
import com.google.gson.JsonObject
import im.zego.digitalmobile.IZegoDigitalMobile
import im.zego.digitalmobile.ZegoDigitalHuman
import im.zego.digitalmobile.ZegoDigitalHumanResource
import im.zego.digitalmobile.ZegoDigitalView
import im.zego.digitalmobile.config.ZegoDigitalMobileAuth
import im.zego.zegoexpress.ZegoExpressEngine
import im.zego.zegoexpress.callback.IZegoCustomVideoRenderHandler
import im.zego.zegoexpress.callback.IZegoEventHandler
import im.zego.zegoexpress.constants.ZegoScenario
import im.zego.zegoexpress.constants.ZegoUpdateType
import im.zego.zegoexpress.constants.ZegoVideoBufferType
import im.zego.zegoexpress.constants.ZegoVideoFrameFormat
import im.zego.zegoexpress.constants.ZegoVideoFrameFormatSeries
import im.zego.zegoexpress.entity.ZegoCustomVideoRenderConfig
import im.zego.zegoexpress.entity.ZegoEngineConfig
import im.zego.zegoexpress.entity.ZegoEngineProfile
import im.zego.zegoexpress.entity.ZegoRoomConfig
import im.zego.zegoexpress.entity.ZegoStream
import im.zego.zegoexpress.entity.ZegoUser
import im.zego.zegoexpress.entity.ZegoVideoFrameParam
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.nio.ByteBuffer
import java.util.concurrent.Executors

/**
 * 数字人交互聊天示例 - 主界面
 * Digital Human Interactive Chat Example - Main Activity
 */
class MainActivity : AppCompatActivity(),
    IZegoDigitalMobile.ZegoDigitalMobileListener {

    // ID 前缀（用于生成动态ID）/ ID prefixes (for generating dynamic IDs)
    companion object {
        private const val USER_ID_PREFIX = "user_demo_android"
        private const val ROOM_ID_PREFIX = "room_demo_android"
        private const val STREAM_ID_PREFIX = "stream_demo_android"
    }

    // UI 组件 / UI components
    private lateinit var tvStatus: TextView
    private lateinit var digitalHumanView: ZegoDigitalView
    private lateinit var btnStartCall: Button
    private lateinit var btnStopCall: Button
    private lateinit var btnSimulateTalkZh: Button
    private lateinit var btnSimulateTalkEn: Button

    // SDK 实例 / SDK instances
    private var expressEngine: ZegoExpressEngine? = null
    private var digitalMobile: IZegoDigitalMobile? = null

    // 任务状态 / Task state
    private var currentTaskId: String? = null
    private var currentRoomId: String? = null
    private var currentStreamId: String? = null
    private var currentUserId: String? = null
    private var isCallStarted = false
    private var isRoomLoggedIn = false

    private val gson = Gson()
    private val httpClient = OkHttpClient()

    // 任务信息（用于在回调中访问）/ Task info (for access in callbacks)
    private var pendingTaskInfo: TaskInfo? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        initViews()

        // 检查配置 / Check configuration
        if (Config.APP_ID == 0L) {
            updateStatus("Please configure APP_ID in Config.kt")
            return
        }

        // 初始化 SDK / Initialize SDKs
        initSDKs()

        // 设置按钮监听器 / Set button listeners
        setupButtonListeners()
    }

    /**
     * 初始化 UI 组件
     * Initialize UI components
     */
    private fun initViews() {
        tvStatus = findViewById(R.id.tvStatus)
        digitalHumanView = findViewById(R.id.digitalHumanView)
        btnStartCall = findViewById(R.id.btnStartCall)
        btnStopCall = findViewById(R.id.btnStopCall)
        btnSimulateTalkZh = findViewById(R.id.btnSimulateTalkZh)
        btnSimulateTalkEn = findViewById(R.id.btnSimulateTalkEn)

        // 初始状态 / Initial state
        btnStartCall.isEnabled = true
        btnStopCall.isEnabled = false
        btnSimulateTalkZh.isEnabled = false
        btnSimulateTalkEn.isEnabled = false
    }

    /**
     * 初始化 Express SDK 和数字人 SDK
     * Initialize Express SDK and Digital Human SDK
     */
    private fun initSDKs() {
        // 初始化 Express SDK / Initialize Express SDK
        val profile = ZegoEngineProfile()
        profile.appID = Config.APP_ID
        profile.scenario = ZegoScenario.HIGH_QUALITY_CHATROOM
        profile.application = application
        expressEngine = ZegoExpressEngine.createEngine(profile, null)

        // 初始化数字人 SDK / Initialize Digital Human SDK
        digitalMobile = ZegoDigitalHuman.create(this)
        digitalMobile?.attach(digitalHumanView)

        // 预加载数字人资源 / Preload digital human resources
        updateStatus("Preloading digital human resources...")
        Executors.newSingleThreadExecutor().execute {
            try {
                val userId = generateDynamicId(USER_ID_PREFIX)
                val token = getToken(userId)
                preloadDigitalHuman(userId, token, Config.DIGITAL_HUMAN_ID)
                Log.d("DH", "Preload started: ${Config.DIGITAL_HUMAN_ID}")
            } catch (e: Exception) {
                Log.e("DH", "Preload failed", e)
            }
        }

        updateStatus("waiting for initialization...")
    }

    /**
     * 设置按钮监听器
     * Set button listeners
     */
    private fun setupButtonListeners() {
        btnStartCall.setOnClickListener {
            startCall()
        }

        btnStopCall.setOnClickListener {
            stopCall()
        }

        btnSimulateTalkZh.setOnClickListener {
            simulateTalk("zh")
        }

        btnSimulateTalkEn.setOnClickListener {
            simulateTalk("en")
        }
    }

    /**
     * 开始通话
     * Start call
     */
    private fun startCall() {
        Executors.newSingleThreadExecutor().execute {
            try {
                updateStatus("Initializing...")

                // 1. 生成动态 ID，仅作示例使用 / Generate dynamic IDs, only for example usage
                val userId = generateDynamicId(USER_ID_PREFIX)
                val roomId = generateDynamicId(ROOM_ID_PREFIX)
                val streamId = generateDynamicId(STREAM_ID_PREFIX)
                currentUserId = userId

                // 2. 调用服务端创建数字人任务 / Call server to create digital human task
                updateStatus("Creating digital human task...")
                val taskInfo = createDigitalHumanTask(roomId, streamId)
                currentTaskId = taskInfo.taskId
                currentRoomId = taskInfo.roomId
                currentStreamId = taskInfo.streamId

                // 保存任务信息供回调使用 / Save task info for callback use
                pendingTaskInfo = taskInfo

                // 3. 获取 Token / Get Token
                updateStatus("Fetching token...")
                val token = getToken(userId)

                // 4. 登录房间并拉流（登录成功后会在回调中启动数字人SDK）
                // Login room and start playing (digital human SDK will start in callback after successful login)
                updateStatus("Logging in to room...")
                loginRoomAndStartPlaying(roomId, streamId, userId, token)

            } catch (e: Exception) {
                Log.e("DH", "Start call failed", e)
                updateStatus("Start failed: ${e.message}")
            }
        }
    }

    /**
     * 生成动态ID（带6位时间戳后缀）/ Generate dynamic ID (with 6-digit timestamp suffix)
     * @param prefix ID前缀 / ID prefix
     * @return 动态ID，格式如 "prefix_123456" / Dynamic ID, format: "prefix_123456"
     */
    private fun generateDynamicId(prefix: String): String {
        val timestamp = System.currentTimeMillis() / 1000 // 秒级时间戳 / Second-level timestamp
        val sixDigits = timestamp % 1000000
        return "${prefix}_${sixDigits.toString().padStart(6, '0')}"
    }

    /**
     * 创建数字人任务（HTTP 请求）
     * Create digital human task (HTTP request)
     */
    private fun createDigitalHumanTask(
        roomId: String,
        streamId: String
    ): TaskInfo {
        val json = JSONObject().apply {
            put("roomId", roomId)
            put("streamId", streamId)
            put("outputMode", 2) // Mobile 模式 / Mobile mode
        }

        val request = Request.Builder()
            .url("${Config.API_BASE_URL}/api/digital-human/create-task")
            .post(json.toString().toRequestBody("application/json".toMediaType()))
            .build()

        val response = httpClient.newCall(request).execute()
        val responseBody = response.body?.string() ?: throw Exception("Empty response")

        if (!response.isSuccessful) {
            throw Exception("Server error: ${response.code} - $responseBody")
        }

        val jsonResponse = gson.fromJson(responseBody, JsonObject::class.java)

        if (!jsonResponse.get("success").asBoolean) {
            throw Exception("Create task failed: ${jsonResponse.get("error").asString}")
        }

        return TaskInfo(
            taskId = jsonResponse.get("taskId").asString,
            roomId = jsonResponse.get("roomId").asString,
            streamId = jsonResponse.get("streamId").asString,
            digitalHumanId = jsonResponse.get("digitalHumanId").asString,
            clientInferencePackageUrl = jsonResponse.get("clientInferencePackageUrl").asString,
            isSupportSmallImageMode = jsonResponse.get("isSupportSmallImageMode").asBoolean
        )
    }

    /**
     * 获取 Token
     * Get Token
     */
    private fun getToken(userId: String): String {
        val request = Request.Builder()
            .url("${Config.API_BASE_URL}/api/token?userId=$userId")
            .build()

        val response = httpClient.newCall(request).execute()
        val responseBody = response.body?.string() ?: throw Exception("Empty response")

        if (!response.isSuccessful) {
            throw Exception("Server error: ${response.code} - $responseBody")
        }

        val jsonResponse = gson.fromJson(responseBody, JsonObject::class.java)

        if (!jsonResponse.get("success").asBoolean) {
            throw Exception("Get token failed: ${jsonResponse.get("error").asString}")
        }

        return jsonResponse.get("token").asString
    }

    /**
     * 预加载数字人资源
     * Preload digital human resources
     */
    private fun preloadDigitalHuman(userId: String, token: String, digitalHumanId: String) {
        val auth = ZegoDigitalMobileAuth(Config.APP_ID, userId, token)
        ZegoDigitalHumanResource.INSTANCE.preload(
            this,
            auth,
            digitalHumanId,
            object : ZegoDigitalHumanResource.PreloadCallback {
                override fun onSuccess() {
                    Log.d("DH", "Preload success")
                }

                override fun onProgress(progress: Int) {
                    // 预加载进度（可选显示）/ Preload progress (optional display)
                }

                override fun onError(code: Int, msg: String) {
                    Log.e("DH", "Preload failed: $code, $msg")
                }
            }
        )
    }

    /**
     * 生成 Base64Config
     * Generate Base64Config
     */
    private fun generateBase64Config(
        digitalHumanId: String,
        roomId: String,
        streamId: String,
        packageUrl: String,
        isSupportSmallImageMode: Boolean
    ): String {
        val stream = JsonObject().apply {
            addProperty("RoomId", roomId)
            addProperty("StreamId", streamId)
            addProperty("EncodeCode", "H264")
            addProperty("PackageUrl", packageUrl)
            addProperty("ConfigId", "mobile")
            addProperty("IsSupportSmallImageMode", isSupportSmallImageMode)
        }

        val streams = JsonArray()
        streams.add(stream)

        val config = JsonObject().apply {
            addProperty("DigitalHumanId", digitalHumanId)
            add("Streams", streams)
        }

        val configJson = config.toString()
        val bytes = configJson.toByteArray(Charsets.UTF_8)
        return android.util.Base64.encodeToString(bytes, android.util.Base64.NO_WRAP)
    }

    /**
     * 登录房间并拉流
     * Login room and start playing
     */
    private fun loginRoomAndStartPlaying(
        roomId: String,
        streamId: String,
        userId: String,
        token: String
    ) {
        val engine = expressEngine ?: return

        // 设置高级配置 / Set advanced configurations
        val engineConfig = ZegoEngineConfig()
        engineConfig.advancedConfig["sideinfo_callback_version"] = "3"
        engineConfig.advancedConfig["sideinfo_bound_to_video_decoder"] = "true"
        ZegoExpressEngine.setEngineConfig(engineConfig)

        // 开启自定义渲染 / Enable custom video rendering
        val renderConfig = ZegoCustomVideoRenderConfig()
        renderConfig.bufferType = ZegoVideoBufferType.RAW_DATA
        renderConfig.frameFormatSeries = ZegoVideoFrameFormatSeries.RGB
        renderConfig.enableEngineRender = false
        engine.enableCustomVideoRender(true, renderConfig)

        // 设置视频帧回调 / Set video frame callback
        engine.setCustomVideoRenderHandler(object : IZegoCustomVideoRenderHandler() {
            override fun onRemoteVideoFrameRawData(
                data: Array<ByteBuffer>?,
                dataLength: IntArray?,
                param: ZegoVideoFrameParam?,
                streamID: String?
            ) {
                if (data != null && dataLength != null && param != null && streamID != null) {
                    val dmParam = IZegoDigitalMobile.ZegoVideoFrameParam()
                    dmParam.width = param.width
                    dmParam.height = param.height
                    dmParam.rotation = param.rotation

                    // 转换 format / Convert format
                    dmParam.format = when (param.format) {
                        ZegoVideoFrameFormat.I420 ->
                            IZegoDigitalMobile.ZegoVideoFrameFormat.I420
                        ZegoVideoFrameFormat.NV12 ->
                            IZegoDigitalMobile.ZegoVideoFrameFormat.NV12
                        ZegoVideoFrameFormat.NV21 ->
                            IZegoDigitalMobile.ZegoVideoFrameFormat.NV21
                        else ->
                            IZegoDigitalMobile.ZegoVideoFrameFormat.Unknown
                    }

                    // 复制 strides / Copy strides
                    if (param.strides != null && param.strides.size >= 4) {
                        for (i in 0 until 4) {
                            dmParam.strides[i] = param.strides[i]
                        }
                    }

                    // 重要：将视频帧数据设置到数字人 SDK
                    // IMPORTANT: Set video frame data to digital human SDK
                    digitalMobile?.onRemoteVideoFrameRawData(data, dataLength, dmParam, streamID)
                }
            }
        })

        // 设置事件处理器（包含 SEI 回调和流更新回调）
        // Set event handler (includes SEI callback and stream update callback)
        engine.setEventHandler(object : IZegoEventHandler() {
            override fun onRoomStreamUpdate(
                roomID: String?,
                updateType: ZegoUpdateType,
                streamList: ArrayList<ZegoStream>?,
                extendedData: org.json.JSONObject?
            ) {
                if (updateType == ZegoUpdateType.ADD) {
                    streamList?.forEach { stream ->
                        if (stream.streamID == currentStreamId) {
                            startPlayingStream(stream.streamID)
                        }
                    }
                }
            }

            // 重要：将 SEI 信息设置到数字人 SDK
            // IMPORTANT: Set SEI data to digital human SDK
            override fun onPlayerSyncRecvSEI(streamID: String?, data: ByteArray?) {
                if (streamID != null && data != null) {
                    digitalMobile?.onPlayerSyncRecvSEI(streamID, data)
                }
            }
        })

        // 登录房间 / Login room
        val roomConfig = ZegoRoomConfig()
        roomConfig.token = token
        roomConfig.isUserStatusNotify = true
        val user = ZegoUser(userId, userId)

        engine.loginRoom(roomId, user, roomConfig) { errorCode, _ ->
            if (errorCode == 0) {
                isRoomLoggedIn = true
                isCallStarted = true
                updateUI()
                Log.d("DH", "Room login successful")

                // 登录成功后：启动数字人SDK / After successful login: start digital human SDK
                val taskInfo = pendingTaskInfo
                if (taskInfo != null) {
                    val base64Config = generateBase64Config(
                        taskInfo.digitalHumanId,
                        taskInfo.roomId,
                        taskInfo.streamId,
                        taskInfo.clientInferencePackageUrl,
                        taskInfo.isSupportSmallImageMode
                    )
                    Log.d("DH", "Starting digital human SDK...")
                    updateStatus("Starting digital human...")
                    startDigitalHumanSDK(base64Config)
                } else {
                    Log.e("DH", "Task info is null, cannot start digital human")
                }
            } else {
                Log.e("DH", "Room login failed: $errorCode")
                updateStatus("Login failed: $errorCode")
            }
        }
    }

    /**
     * 开始拉流
     * Start playing stream
     */
    private fun startPlayingStream(streamID: String) {
        val engine = expressEngine ?: return

        // 设置拉流缓冲区 / Set stream buffer interval range
        engine.setPlayStreamBufferIntervalRange(streamID, 100, 2000)

        // 开始拉流 / Start playing stream
        val canvas = im.zego.zegoexpress.entity.ZegoCanvas(null)
        engine.startPlayingStream(streamID, canvas)

        updateStatus("Playing...")
    }

    /**
     * 启动数字人 SDK
     * Start digital human SDK
     */
    private fun startDigitalHumanSDK(base64Config: String) {
        if (digitalMobile == null) {
            updateStatus("Digital human SDK not initialized")
            return
        }

        try {
            digitalMobile?.start(base64Config, this)
        } catch (e: Exception) {
            Log.e("DH", "Failed to start digital human SDK", e)
            updateStatus("Failed to start digital human SDK: ${e.message}")
        }
    }

    /**
     * 模拟说话
     * Simulate talk
     */
    private fun simulateTalk(lang: String) {
        // 注释说明: 实际场景中,这里应该采集麦克风音频数据并发送至服务端
        // Note: In actual scenario, microphone audio data should be captured here and sent to the backend
        // 本示例为模拟,直接调用服务端接口
        // This example simulates by directly calling server API

        Executors.newSingleThreadExecutor().execute {
            try {
                val langText = if (lang == "en") "English" else "Chinese"
                updateStatus("AI interacting ($langText)...")

                val json = JSONObject().apply {
                    put("taskId", currentTaskId)
                    put("lang", lang)
                }

                val request = Request.Builder()
                    .url("${Config.API_BASE_URL}/api/digital-human/talk-to-ai")
                    .post(json.toString().toRequestBody("application/json".toMediaType()))
                    .build()

                val response = httpClient.newCall(request).execute()
                val responseBody = response.body?.string() ?: throw Exception("Empty response")

                if (response.isSuccessful) {
                    updateStatus("AI responding...")
                } else {
                    updateStatus("Request failed: ${response.code}")
                }
            } catch (e: Exception) {
                Log.e("DH", "Simulate talk failed", e)
                updateStatus("Simulate user speech failed: ${e.message}")
            }
        }
    }

    /**
     * 结束通话
     * Stop call
     */
    private fun stopCall() {
        Executors.newSingleThreadExecutor().execute {
            try {
                updateStatus("Stopping call...")

                // 1. 停止数字人 SDK / Stop digital human SDK
                digitalMobile?.stop()

                // 2. 停止拉流 / Stop playing stream
                currentStreamId?.let {
                    expressEngine?.stopPlayingStream(it)
                }

                // 3. 退出房间 / Logout room
                if (isRoomLoggedIn) {
                    expressEngine?.logoutRoom()
                    isRoomLoggedIn = false
                }

                // 4. 调用服务端停止任务 / Call server to stop task
                currentTaskId?.let { taskId ->
                    val json = JSONObject().apply {
                        put("taskId", taskId)
                    }

                    val request = Request.Builder()
                        .url("${Config.API_BASE_URL}/api/digital-human/stop-task")
                        .post(json.toString().toRequestBody("application/json".toMediaType()))
                        .build()

                    httpClient.newCall(request).execute()
                }

                isCallStarted = false
                currentTaskId = null
                currentRoomId = null
                currentStreamId = null
                updateUI()
                updateStatus("waiting for initialization...")
            } catch (e: Exception) {
                Log.e("DH", "Stop call failed", e)
                updateStatus("Stop failed: ${e.message}")
            }
        }
    }

    /**
     * 更新 UI 状态
     * Update UI state
     */
    private fun updateUI() {
        runOnUiThread {
            btnStartCall.isEnabled = !isCallStarted
            btnStopCall.isEnabled = isCallStarted
            btnSimulateTalkZh.isEnabled = isCallStarted
            btnSimulateTalkEn.isEnabled = isCallStarted
        }
    }

    /**
     * 更新状态显示
     * Update status display
     */
    private fun updateStatus(msg: String) {
        runOnUiThread {
            tvStatus.text = "Status: $msg"
        }
    }

    // ==================== IZegoDigitalMobile.ZegoDigitalMobileListener 回调 ====================
    // ==================== IZegoDigitalMobile.ZegoDigitalMobileListener callbacks ====================

    override fun onDigitalMobileStartSuccess() {
        updateStatus("Digital human started successfully")
    }

    override fun onError(errorCode: Int, errorMsg: String?) {
        Log.e("DH", "Digital human SDK error: $errorCode, $errorMsg")
        updateStatus("Digital human error: $errorMsg")
    }

    override fun onSurfaceFirstFrameDraw() {
        updateStatus("In call")
    }

    // ==================== 生命周期 ====================
    // ==================== Lifecycle ====================

    override fun onDestroy() {
        super.onDestroy()

        // 停止数字人 / Stop digital human
        digitalMobile?.stop()

        // 停止拉流 / Stop playing stream
        currentStreamId?.let {
            expressEngine?.stopPlayingStream(it)
        }

        // 退出房间 / Logout room
        if (isRoomLoggedIn) {
            expressEngine?.logoutRoom()
        }

        // 销毁引擎 / Destroy engine
        ZegoExpressEngine.destroyEngine(null)
    }
}

/**
 * 任务信息数据类
 * Task info data class
 */
data class TaskInfo(
    val taskId: String,
    val roomId: String,
    val streamId: String,
    val digitalHumanId: String,
    val clientInferencePackageUrl: String,
    val isSupportSmallImageMode: Boolean
)


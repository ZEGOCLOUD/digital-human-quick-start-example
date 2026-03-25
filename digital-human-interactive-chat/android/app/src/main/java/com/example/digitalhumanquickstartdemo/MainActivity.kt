package com.example.digitalhumanquickstartdemo

import android.os.Bundle
import android.util.Log
import android.widget.Button
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.example.digitalhumanquickstartdemo.config.Config
import com.google.gson.Gson
import im.zego.zegoexpress.ZegoExpressEngine
import im.zego.zegoexpress.callback.IZegoEventHandler
import im.zego.zegoexpress.constants.ZegoScenario
import im.zego.zegoexpress.constants.ZegoUpdateType
import im.zego.zegoexpress.entity.ZegoCanvas
import im.zego.zegoexpress.entity.ZegoEngineProfile
import im.zego.zegoexpress.entity.ZegoRoomConfig
import im.zego.zegoexpress.entity.ZegoStream
import im.zego.zegoexpress.entity.ZegoUser
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.util.concurrent.Executors

/**
 * 数字人交互聊天示例 - 主界面
 * Digital Human Interactive Chat Example - Main Activity
 */
class MainActivity : AppCompatActivity() {

    // ID 前缀（用于生成动态ID）/ ID prefixes (for generating dynamic IDs)
    companion object {
        private const val USER_ID_PREFIX = "user_demo_android"
        private const val ROOM_ID_PREFIX = "room_demo_android"
        private const val STREAM_ID_PREFIX = "stream_demo_android"
    }

    data class ExperimentalApiMessage(
        val method: String? = null,
        val params: ExperimentalApiParams? = null
    )

    data class ExperimentalApiParams(
        val msg_content: String? = null
    )

    data class DigitalHumanDriveMessage(
        val Product: String? = null,
        val Cmd: Int = 0,
        val Data: DigitalHumanDriveData? = null
    )

    data class DigitalHumanDriveData(
        val Status: Int = 0,
        val DriveId: String? = null
    )

    // UI 组件 / UI components
    private lateinit var tvStatus: TextView
    private lateinit var remoteVideoView: android.view.TextureView
    private lateinit var btnStartCall: Button
    private lateinit var btnStopCall: Button
    private lateinit var btnSimulateTalkZh: Button
    private lateinit var btnSimulateTalkEn: Button

    // SDK 实例 / SDK instance
    private var expressEngine: ZegoExpressEngine? = null

    // 任务状态 / Task state
    private var currentTaskId: String? = null
    private var currentRoomId: String? = null
    private var currentStreamId: String? = null
    private var currentUserId: String? = null
    private var isCallStarted = false
    private var isRoomLoggedIn = false

    private val gson = Gson()
    private val httpClient = OkHttpClient()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        initViews()

        // 检查配置 / Check configuration
        if (Config.APP_ID == 0L) {
            updateStatus("Please configure APP_ID in Config.kt")
            return
        }

        // 初始化 SDK / Initialize SDK
        initSDK()

        // 设置按钮监听器 / Set button listeners
        setupButtonListeners()
    }

    /**
     * 初始化 UI 组件
     * Initialize UI components
     */
    private fun initViews() {
        tvStatus = findViewById(R.id.tvStatus)
        remoteVideoView = findViewById(R.id.remoteVideoView)
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
     * 初始化 Express SDK
     * Initialize Express SDK
     */
    private fun initSDK() {
        val profile = ZegoEngineProfile()
        profile.appID = Config.APP_ID
        profile.scenario = ZegoScenario.HIGH_QUALITY_CHATROOM
        profile.application = application
        expressEngine = ZegoExpressEngine.createEngine(profile, null)

        // 设置事件处理器
        // Set event handler
        expressEngine?.setEventHandler(object : IZegoEventHandler() {
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

            override fun onRecvExperimentalAPI(content: String) {
                handleExperimentalApi(content)
            }
        })

        updateStatus("Ready")
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
                val taskId = createDigitalHumanTask(roomId, streamId)
                currentTaskId = taskId
                currentRoomId = roomId
                currentStreamId = streamId

                // 3. 获取 Token / Get Token
                updateStatus("Fetching token...")
                val token = getToken(userId)

                // 4. 登录房间并拉流
                // Login room and start playing
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
     *
     * 请求参数说明 / Request parameters:
     * - roomId: 数字人加入的 RTC 房间 ID，每个用户应使用不同的房间 ID
     *   Digital human's RTC room ID, each user should use a different room ID
     * - streamId: 数字人推流的流 ID
     *   Digital human's stream ID for pushing stream
     *
     * @return 任务 ID / Task ID
     */
    private fun createDigitalHumanTask(
        roomId: String,
        streamId: String
    ): String {
        val json = JSONObject().apply {
            put("roomId", roomId)
            put("streamId", streamId)
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

        val jsonResponse = gson.fromJson(responseBody, Map::class.java)

        if (jsonResponse["success"] != true) {
            throw Exception("Create task failed: ${jsonResponse["error"]}")
        }

        return jsonResponse["taskId"] as String
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

        val jsonResponse = gson.fromJson(responseBody, Map::class.java)

        if (jsonResponse["success"] != true) {
            throw Exception("Get token failed: ${jsonResponse["error"]}")
        }

        return jsonResponse["token"] as String
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
                updateStatus("In call, waiting for stream...")
                Log.d("DH", "Room login successful")
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

        runOnUiThread {
            // 使用 ZegoCanvas 包装 TextureView 进行渲染
            // Use ZegoCanvas to wrap TextureView for rendering
            val canvas = ZegoCanvas(remoteVideoView)
            engine.startPlayingStream(streamID, canvas)
            updateStatus("Playing...")
        }
    }

    private fun handleExperimentalApi(content: String) {
        try {
            val contentMessage = gson.fromJson(content, ExperimentalApiMessage::class.java)
            if (contentMessage?.method != "liveroom.room.on_recive_room_channel_message") {
                return
            }

            val msgContent = contentMessage.params?.msg_content
            if (msgContent.isNullOrEmpty()) {
                return
            }

            val driveMessage = gson.fromJson(msgContent, DigitalHumanDriveMessage::class.java)
            if (driveMessage?.Product != "digitalhuman" || driveMessage.Cmd != 1001 || driveMessage.Data == null) {
                return
            }

            val message = when (driveMessage.Data.Status) {
                2 -> if (driveMessage.Data.DriveId.isNullOrEmpty()) {
                    "Digital human started speaking"
                } else {
                    "Digital human started speaking, DriveID: ${driveMessage.Data.DriveId}"
                }
                4 -> if (driveMessage.Data.DriveId.isNullOrEmpty()) {
                    "Digital human finished speaking"
                } else {
                    "Digital human finished speaking, DriveID: ${driveMessage.Data.DriveId}"
                }
                else -> null
            }

            if (!message.isNullOrEmpty()) {
                updateStatus(message)
            }
        } catch (e: Exception) {
            Log.e("DH", "Handle experimental api failed", e)
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

                // 1. 停止拉流 / Stop playing stream
                currentStreamId?.let {
                    expressEngine?.stopPlayingStream(it)
                }

                // 2. 退出房间 / Logout room
                if (isRoomLoggedIn) {
                    expressEngine?.logoutRoom()
                    isRoomLoggedIn = false
                }

                // 3. 调用服务端停止任务 / Call server to stop task
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
                updateStatus("Ready")
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

    // ==================== 生命周期 ====================
    // ==================== Lifecycle ====================

    override fun onDestroy() {
        super.onDestroy()

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

package com.example.digitalhumanquickstartdemo

import android.os.Bundle
import android.util.Log
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.example.digitalhumanquickstartdemo.config.Config
import com.example.digitalhumanquickstartdemo.model.BroadcastInfo
import com.example.digitalhumanquickstartdemo.model.TokenResponse
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
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.concurrent.Executors

class MainActivity : AppCompatActivity() {

    // UI组件
    // UI components
    private lateinit var tvStatus: TextView
    private lateinit var tvRoomInfo: TextView
    private lateinit var remoteVideoView: android.view.TextureView

    // SDK实例
    // SDK instance
    private var expressEngine: ZegoExpressEngine? = null

    // 房间信息
    // Room information
    private var currentRoomId: String? = null
    private var currentStreamId: String? = null
    private var currentUserId: String? = null
    private var isRoomLoggedIn = false

    private val gson = Gson()
    private val httpClient = OkHttpClient()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        initViews()

        // 检查配置
        // Check configuration
        if (Config.APP_ID == 0L) {
            updateStatus("Please configure APP_ID in Config.kt")
            return
        }

        // 先初始化SDK
        // Initialize SDK first
        initSDK()

        // 启动数字人播放流程
        // Start digital human playback process
        startDigitalHuman()
    }

    private fun initViews() {
        tvStatus = findViewById(R.id.tvStatus)
        tvRoomInfo = findViewById(R.id.tvRoomInfo)
        remoteVideoView = findViewById(R.id.remoteVideoView)
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
        })
    }

    /**
     * 启动数字人播放流程
     * Start digital human playback process
     */
    private fun startDigitalHuman() {
        Executors.newSingleThreadExecutor().execute {
            try {
                // 步骤1: 从业务后台获取播报列表
                // Step 1: Fetch broadcast list from backend
                updateStatus("Fetching broadcast list...")
                val broadcast = fetchBroadcastList()
                if (broadcast == null) {
                    updateStatus("No available broadcast, please start broadcast task on server first")
                    return@execute
                }

                // 保存房间信息
                // Save room information
                currentRoomId = broadcast.roomId
                currentStreamId = broadcast.streamId

                runOnUiThread {
                    tvRoomInfo.text = "Room: ${broadcast.roomId} | Stream: ${broadcast.streamId}"
                }

                // 步骤2: 获取Token并登录房间
                // Step 2: Get token and login to room
                updateStatus("Fetching token...")
                val userId = "user_${System.currentTimeMillis()}"
                currentUserId = userId
                val token = fetchToken(userId)
                if (token == null) {
                    updateStatus("Failed to fetch token")
                    return@execute
                }

                // 步骤3: 登录房间
                // Step 3: Login to room
                updateStatus("Logging in to room...")
                loginRoom(broadcast.roomId, broadcast.streamId, userId, token)

            } catch (e: Exception) {
                Log.e("DigitalHumanDemo", "Startup failed", e)
                updateStatus("Startup failed: ${e.message}")
            }
        }
    }

    /**
     * 登录房间
     * Login to room
     */
    private fun loginRoom(roomId: String, streamId: String, userId: String, token: String) {
        val engine = expressEngine
        if (engine == null) {
            updateStatus("Error: RTC engine not initialized")
            return
        }

        val roomConfig = ZegoRoomConfig()
        roomConfig.isUserStatusNotify = true
        roomConfig.token = token

        val user = ZegoUser(userId, userId)

        engine.loginRoom(roomId, user, roomConfig) { errorCode, _ ->
            if (errorCode == 0) {
                isRoomLoggedIn = true
                updateStatus("Room logged in, waiting for stream...")
            } else {
                Log.e("DigitalHumanDemo", "Room login failed: $errorCode")
                updateStatus("Room login failed: $errorCode")
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

    /**
     * 获取播报列表
     * Fetch broadcast list
     */
    private fun fetchBroadcastList(): BroadcastInfo? {
        val request = Request.Builder()
            .url("${Config.API_BASE_URL}/api/broadcast")
            .build()

        val response = httpClient.newCall(request).execute()
        if (!response.isSuccessful) {
            Log.e("DigitalHumanDemo", "Failed to fetch broadcast list: ${response.code}")
            return null
        }

        val responseBody = response.body?.string() ?: return null
        val json = gson.fromJson(responseBody, Map::class.java)
        val broadcastList = json["broadcastList"] as? Map<*, *> ?: return null

        if (broadcastList.isNotEmpty()) {
            val firstKey = broadcastList.keys.first()
            val broadcast = broadcastList[firstKey] as? Map<*, *>
            if (broadcast != null) {
                val roomId = broadcast["roomId"] as? String
                val streamId = broadcast["streamId"] as? String
                if (roomId != null && streamId != null) {
                    return BroadcastInfo(roomId, streamId)
                }
            }
        }

        return null
    }

    /**
     * 获取Token
     * Fetch token
     */
    private fun fetchToken(userId: String): String? {
        val request = Request.Builder()
            .url("${Config.API_BASE_URL}/api/token?userId=$userId")
            .build()

        val response = httpClient.newCall(request).execute()
        if (!response.isSuccessful) {
            Log.e("DigitalHumanDemo", "Failed to fetch token: ${response.code}")
            return null
        }

        val responseBody = response.body?.string() ?: return null
        val tokenResponse = gson.fromJson(responseBody, TokenResponse::class.java)
        return tokenResponse.token
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

        // 停止拉流
        // Stop playing stream
        currentStreamId?.let {
            expressEngine?.stopPlayingStream(it)
        }

        // 退出房间
        // Logout room
        if (isRoomLoggedIn) {
            currentRoomId?.let {
                expressEngine?.logoutRoom()
            }
        }

        // 销毁引擎
        // Destroy engine
        ZegoExpressEngine.destroyEngine(null)
    }
}

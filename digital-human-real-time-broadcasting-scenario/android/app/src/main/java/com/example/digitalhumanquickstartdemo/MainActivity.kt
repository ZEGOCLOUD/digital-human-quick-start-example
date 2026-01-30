package com.example.digitalhumanquickstartdemo

import android.os.Bundle
import android.util.Log
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.example.digitalhumanquickstartdemo.config.Config
import com.example.digitalhumanquickstartdemo.model.BroadcastInfo
import com.example.digitalhumanquickstartdemo.model.TokenResponse
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
import okhttp3.OkHttpClient
import okhttp3.Request
import java.nio.ByteBuffer
import java.util.concurrent.Executors

class MainActivity : AppCompatActivity(),
    IZegoDigitalMobile.ZegoDigitalMobileListener {

    // UI组件
    private lateinit var tvStatus: TextView
    private lateinit var tvRoomInfo: TextView
    private lateinit var digitalHumanView: ZegoDigitalView

    // SDK实例
    private var expressEngine: ZegoExpressEngine? = null
    private var digitalMobile: IZegoDigitalMobile? = null

    // 房间信息
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
        if (Config.APP_ID == 0L) {
            updateStatus("请在 Config.kt 中配置 APP_ID")
            return
        }

        // 先初始化SDK
        initSDKs()

        // 启动数字人播放流程
        startDigitalHuman()
    }

    private fun initViews() {
        tvStatus = findViewById(R.id.tvStatus)
        tvRoomInfo = findViewById(R.id.tvRoomInfo)
        digitalHumanView = findViewById(R.id.digitalHumanView)
    }

    /**
     * 初始化 Express SDK 和数字人 SDK
     */
    private fun initSDKs() {
        // 初始化 Express SDK
        val profile = ZegoEngineProfile()
        profile.appID = Config.APP_ID
        profile.scenario = ZegoScenario.HIGH_QUALITY_CHATROOM
        profile.application = application
        expressEngine = ZegoExpressEngine.createEngine(profile, null)

        // 初始化数字人SDK
        digitalMobile = ZegoDigitalHuman.create(this)
        digitalMobile?.attach(digitalHumanView)
    }

    /**
     * 启动数字人播放流程
     */
    private fun startDigitalHuman() {
        Executors.newSingleThreadExecutor().execute {
            try {
                // 步骤1: 从业务后台获取播报列表
                updateStatus("获取播报列表中...")
                val broadcast = fetchBroadcastList()
                if (broadcast == null) {
                    updateStatus("没有可用播报，请先在服务端启动播报任务")
                    return@execute
                }

                // 保存房间信息
                currentRoomId = broadcast.roomId
                currentStreamId = broadcast.streamId

                runOnUiThread {
                    tvRoomInfo.text = "房间: ${broadcast.roomId} | 流: ${broadcast.streamId}"
                }

                // 步骤2: 获取Token并登录房间
                updateStatus("获取 Token 中...")
                val userId = "user_${System.currentTimeMillis()}"
                currentUserId = userId
                val token = fetchToken(userId)
                if (token == null) {
                    updateStatus("获取 Token 失败")
                    return@execute
                }

                // 步骤3: 预加载数字人资源
                updateStatus("预加载数字人资源...")
                preloadDigitalHumanResources(userId, token, broadcast.digitalHumanId)

                // 步骤4: 登录房间（登录成功后会启动数字人）
                updateStatus("登录房间中...")
                loginRoom(broadcast.roomId, broadcast.streamId, userId, token, broadcast)

            } catch (e: Exception) {
                Log.e("DigitalHumanDemo", "启动失败", e)
                updateStatus("启动失败: ${e.message}")
            }
        }
    }

    /**
     * 预加载数字人资源
     */
    private fun preloadDigitalHumanResources(userId: String, token: String, digitalHumanId: String) {
        val auth = ZegoDigitalMobileAuth(Config.APP_ID, userId, token)
        ZegoDigitalHumanResource.INSTANCE.preload(
            this,
            auth,
            digitalHumanId,
            object : ZegoDigitalHumanResource.PreloadCallback {
                override fun onSuccess() {
                    Log.e("DigitalHumanDemo", "预加载成功")
                }

                override fun onProgress(progress: Int) {
                    // 预加载进度（可选显示）
                }

                override fun onError(code: Int, msg: String) {
                    Log.e("DigitalHumanDemo", "预加载失败: $code, $msg")
                }
            }
        )
    }

    /**
     * 登录房间
     */
    private fun loginRoom(roomId: String, streamId: String, userId: String, token: String, broadcast: BroadcastInfo) {
        val engine = expressEngine
        if (engine == null) {
            updateStatus("错误：RTC引擎未初始化")
            return
        }

        // 设置高级配置
        val engineConfig = ZegoEngineConfig()
        engineConfig.advancedConfig["set_audio_volume_ducking_mode"] = "1"
        engineConfig.advancedConfig["enable_rnd_volume_adaptive"] = "true"
        engineConfig.advancedConfig["sideinfo_callback_version"] = "3"
        engineConfig.advancedConfig["sideinfo_bound_to_video_decoder"] = "true"
        ZegoExpressEngine.setEngineConfig(engineConfig)

        engine.setRoomScenario(ZegoScenario.HIGH_QUALITY_CHATROOM)

        val roomConfig = ZegoRoomConfig()
        roomConfig.isUserStatusNotify = true
        roomConfig.token = token

        val user = ZegoUser(userId, userId)

        engine.loginRoom(roomId, user, roomConfig) { errorCode, _ ->
            if (errorCode == 0) {
                isRoomLoggedIn = true

                // 登录成功后：开启自定义渲染
                enableCustomVideoRender()

                // 启动数字人SDK
                val base64Config = generateBase64Config(
                    broadcast.digitalHumanId,
                    broadcast.roomId,
                    broadcast.streamId,
                    broadcast.clientInferencePackageUrl,
                    broadcast.isSupportSmallImageMode
                )
                startDigitalHumanSDK(base64Config)
            } else {
                Log.e("DigitalHumanDemo", "登录房间失败: $errorCode")
                updateStatus("登录房间失败: $errorCode")
            }
        }
    }

    /**
     * 开启自定义视频渲染
     */
    private fun enableCustomVideoRender() {
        val renderConfig = ZegoCustomVideoRenderConfig()
        renderConfig.bufferType = ZegoVideoBufferType.RAW_DATA
        renderConfig.frameFormatSeries = ZegoVideoFrameFormatSeries.RGB
        renderConfig.enableEngineRender = false
        expressEngine?.enableCustomVideoRender(true, renderConfig)

        // 设置视频帧回调
        expressEngine?.setCustomVideoRenderHandler(object : IZegoCustomVideoRenderHandler() {
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

                    // 转换format
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

                    // 复制 strides
                    if (param.strides != null && param.strides.size >= 4) {
                        for (i in 0 until 4) {
                            dmParam.strides[i] = param.strides[i]
                        }
                    }

                    // 重要：将视频帧数据设置到数字人 SDK
                    digitalMobile?.onRemoteVideoFrameRawData(data, dataLength, dmParam, streamID)
                }
            }
        })

        // 设置事件处理器（包含SEI回调和流更新回调）
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

            // 重要：将 SEI 信息设置到数字人 SDK
            override fun onPlayerSyncRecvSEI(streamID: String?, data: ByteArray?) {
                if (streamID != null && data != null) {
                    digitalMobile?.onPlayerSyncRecvSEI(streamID, data)
                }
            }
        })
    }

    /**
     * 开始拉流
     */
    private fun startPlayingStream(streamID: String) {
        val engine = expressEngine ?: return

        // 设置拉流缓冲区
        engine.setPlayStreamBufferIntervalRange(streamID, 100, 2000)

        // 开始拉流
        val canvas = im.zego.zegoexpress.entity.ZegoCanvas(null)
        engine.startPlayingStream(streamID, canvas)

        updateStatus("播放中...")
    }

    /**
     * 启动数字人SDK
     */
    private fun startDigitalHumanSDK(base64Config: String) {
        if (digitalMobile == null) {
            updateStatus("数字人SDK未初始化")
            return
        }

        try {
            digitalMobile?.start(base64Config, this)
        } catch (e: Exception) {
            Log.e("DigitalHumanDemo", "数字人SDK启动失败", e)
            updateStatus("数字人SDK启动失败: ${e.message}")
        }
    }

    /**
     * 生成 Base64Config
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
     * 获取播报列表
     */
    private fun fetchBroadcastList(): BroadcastInfo? {
        val request = Request.Builder()
            .url("${Config.API_BASE_URL}/api/broadcast")
            .build()

        val response = httpClient.newCall(request).execute()
        if (!response.isSuccessful) {
            Log.e("DigitalHumanDemo", "获取播报列表失败: ${response.code}")
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
                val clientInferencePackageUrl = broadcast["clientInferencePackageUrl"] as? String
                val digitalHumanId = broadcast["digitalHumanId"] as? String
                val isSupportSmallImageMode = broadcast["isSupportSmallImageMode"] as? Boolean ?: false
                if (roomId != null && streamId != null && clientInferencePackageUrl != null && digitalHumanId != null) {
                    return BroadcastInfo(roomId, streamId, clientInferencePackageUrl, digitalHumanId, isSupportSmallImageMode)
                }
            }
        }

        return null
    }

    /**
     * 获取Token
     */
    private fun fetchToken(userId: String): String? {
        val request = Request.Builder()
            .url("${Config.API_BASE_URL}/api/token?userId=$userId")
            .build()

        val response = httpClient.newCall(request).execute()
        if (!response.isSuccessful) {
            Log.e("DigitalHumanDemo", "获取Token失败: ${response.code}")
            return null
        }

        val responseBody = response.body?.string() ?: return null
        val tokenResponse = gson.fromJson(responseBody, TokenResponse::class.java)
        return tokenResponse.token
    }

    /**
     * 更新状态显示
     */
    private fun updateStatus(msg: String) {
        runOnUiThread {
            tvStatus.text = "状态：$msg"
        }
    }

    // ==================== IZegoDigitalMobile.ZegoDigitalMobileListener 回调 ====================

    override fun onDigitalMobileStartSuccess() {
        updateStatus("数字人启动成功")
    }

    override fun onError(errorCode: Int, errorMsg: String?) {
        Log.e("DigitalHumanDemo", "数字人SDK错误: $errorCode, $errorMsg")
        updateStatus("数字人错误: $errorMsg")
    }

    override fun onSurfaceFirstFrameDraw() {
        updateStatus("数字人播放中")
    }

    // ==================== 生命周期 ====================

    override fun onDestroy() {
        super.onDestroy()

        // 停止数字人
        digitalMobile?.stop()

        // 停止拉流
        currentStreamId?.let {
            expressEngine?.stopPlayingStream(it)
        }

        // 退出房间
        if (isRoomLoggedIn) {
            currentRoomId?.let {
                expressEngine?.logoutRoom()
            }
        }

        // 销毁引擎
        ZegoExpressEngine.destroyEngine(null)
    }
}

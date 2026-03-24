package com.example.zegodigitalhumanquickstart.util;

import android.text.TextUtils;
import android.util.Log;

import com.example.zegodigitalhumanquickstart.model.ZegoQuickStartDigitalHumanDriveMessage;
import com.example.zegodigitalhumanquickstart.model.ZegoQuickStartExperimentalApiMessage;
import com.google.gson.Gson;
import com.google.gson.JsonSyntaxException;

/**
 * RTC 房间消息解析工具类。
 */
public final class ZegoQuickStartRTCRoomMessageParser {

    private static final String TAG = "ZegoQuickStartRTCMsg";
    private static final Gson GSON = new Gson();

    private ZegoQuickStartRTCRoomMessageParser() {
    }

    public static AgentSpeakStatusResult parseSpeakStatusFromExperimentalAPI(String content) {
        if (TextUtils.isEmpty(content)) {
            return new AgentSpeakStatusResult(-1, null);
        }

        try {
            ZegoQuickStartExperimentalApiMessage contentMessage =
                    GSON.fromJson(content, ZegoQuickStartExperimentalApiMessage.class);
            if (contentMessage == null
                    || !"liveroom.room.on_recive_room_channel_message".equals(contentMessage.method)) {
                return new AgentSpeakStatusResult(-1, null);
            }

            if (contentMessage.params == null) {
                Log.w(TAG, "params is null");
                return new AgentSpeakStatusResult(-1, null);
            }

            String msgContent = contentMessage.params.msgContent;
            if (TextUtils.isEmpty(msgContent)) {
                Log.w(TAG, "msg_content is empty");
                return new AgentSpeakStatusResult(-1, null);
            }

            ZegoQuickStartDigitalHumanDriveMessage driveMessage =
                    GSON.fromJson(msgContent, ZegoQuickStartDigitalHumanDriveMessage.class);
            if (driveMessage == null || !"digitalhuman".equals(driveMessage.product)) {
                return new AgentSpeakStatusResult(-1, null);
            }

            if (driveMessage.cmd != 1001) {
                return new AgentSpeakStatusResult(-1, null);
            }

            if (driveMessage.data == null) {
                return new AgentSpeakStatusResult(-1, null);
            }

            return new AgentSpeakStatusResult(
                    driveMessage.data.status,
                    driveMessage.data.driveId
            );
        } catch (IllegalStateException | UnsupportedOperationException | JsonSyntaxException e) {
            Log.e(TAG, "failed to parse experimental api content", e);
            return new AgentSpeakStatusResult(-1, null);
        }
    }

    public static final class AgentSpeakStatusResult {
        public final int speakStatus;
        public final String driveID;

        public AgentSpeakStatusResult(int speakStatus, String driveID) {
            this.speakStatus = speakStatus;
            this.driveID = driveID;
        }
    }
}

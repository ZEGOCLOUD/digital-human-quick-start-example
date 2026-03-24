package com.example.zegodigitalhumanquickstart.model;

import com.google.gson.annotations.SerializedName;

public class ZegoQuickStartExperimentalApiMessage {

    @SerializedName("method")
    public String method;

    @SerializedName("params")
    public Params params;

    public static class Params {
        @SerializedName("msg_content")
        public String msgContent;
    }
}

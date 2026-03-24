package com.example.zegodigitalhumanquickstart.model;

import com.google.gson.annotations.SerializedName;

public class ZegoQuickStartDigitalHumanDriveMessage {

    @SerializedName("Product")
    public String product;

    @SerializedName("Cmd")
    public int cmd;

    @SerializedName("Data")
    public Data data;

    public static class Data {
        @SerializedName("Status")
        public int status;

        @SerializedName("DriveId")
        public String driveId;
    }
}

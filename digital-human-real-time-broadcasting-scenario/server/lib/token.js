import { createCipheriv, randomBytes } from "crypto";

const makeNonce = () => {
  const min = -2147483648;
  const max = 2147483647;
  return Math.ceil(min + (max - min) * Math.random());
};

const makeRandomIv = () => {
  const chars = "0123456789abcdefghijklmnopqrstuvwxyz";
  const out = [];
  for (let i = 0; i < 16; i += 1) {
    out.push(chars.charAt(Math.floor(Math.random() * chars.length)));
  }
  return out.join("");
};

const getAlgorithm = (key) => {
  const length = Buffer.from(key).length;
  if (length === 16) return "aes-128-cbc";
  if (length === 24) return "aes-192-cbc";
  if (length === 32) return "aes-256-cbc";
  throw new Error(`ServerSecret 长度非法: ${length}`);
};

const aesEncrypt = (plainText, key, iv) => {
  const cipher = createCipheriv(getAlgorithm(key), key, iv);
  cipher.setAutoPadding(true);
  const encrypted = Buffer.concat([cipher.update(plainText), cipher.final()]);
  return Uint8Array.from(encrypted).buffer;
};

export const generateToken04 = (
  appId,
  userId,
  secret,
  effectiveTimeInSeconds,
  payload = ""
) => {
  if (!appId || typeof appId !== "number") {
    throw new Error("appId 无效");
  }
  if (!userId) {
    throw new Error("userId 无效");
  }
  if (!secret || secret.length !== 32) {
    throw new Error("ServerSecret 必须为 32 位字符串");
  }
  if (!effectiveTimeInSeconds) {
    throw new Error("effectiveTimeInSeconds 无效");
  }

  const createTime = Math.floor(Date.now() / 1000);
  const tokenInfo = {
    app_id: appId,
    user_id: userId,
    nonce: makeNonce(),
    ctime: createTime,
    expire: createTime + effectiveTimeInSeconds,
    payload,
  };

  const plainText = JSON.stringify(tokenInfo);
  const iv = makeRandomIv();
  const encryptBuf = aesEncrypt(plainText, secret, iv);

  const b1 = new Uint8Array(8);
  const b2 = new Uint8Array(2);
  const b3 = new Uint8Array(2);
  new DataView(b1.buffer).setBigInt64(0, BigInt(tokenInfo.expire), false);
  new DataView(b2.buffer).setUint16(0, iv.length, false);
  new DataView(b3.buffer).setUint16(0, encryptBuf.byteLength, false);

  const buf = Buffer.concat([
    Buffer.from(b1),
    Buffer.from(b2),
    Buffer.from(iv),
    Buffer.from(b3),
    Buffer.from(encryptBuf),
  ]);

  return `04${Buffer.from(buf).toString("base64")}`;
};

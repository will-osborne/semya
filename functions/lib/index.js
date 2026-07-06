"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.cleanupStaleCalls = exports.getTurnCredentials = exports.onNewCall = exports.onNewMessage = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const https_1 = require("firebase-functions/v2/https");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const params_1 = require("firebase-functions/params");
const app_1 = require("firebase-admin/app");
const firestore_2 = require("firebase-admin/firestore");
const messaging_1 = require("firebase-admin/messaging");
const apns2_1 = require("apns2");
(0, app_1.initializeApp)();
const db = (0, firestore_2.getFirestore)();
const messaging = (0, messaging_1.getMessaging)();
// APNs credentials stored as Firebase secrets.
// Set via: firebase functions:secrets:set APNS_KEY_ID, etc.
const apnsKeyId = (0, params_1.defineSecret)("APNS_KEY_ID");
const apnsTeamId = (0, params_1.defineSecret)("APNS_TEAM_ID");
const apnsSigningKey = (0, params_1.defineSecret)("APNS_SIGNING_KEY");
const apnsBundleId = (0, params_1.defineSecret)("APNS_BUNDLE_ID");
// Set to "true" for development/debug builds, "false" (or unset) for
// TestFlight/App Store. Controls which APNs endpoint receives VoIP pushes.
// Set via: firebase functions:secrets:set APNS_SANDBOX
const apnsSandbox = (0, params_1.defineSecret)("APNS_SANDBOX");
// Cloudflare TURN credentials.
// Set via: firebase functions:secrets:set CF_TURN_TOKEN_ID, CF_TURN_API_TOKEN
const cfTurnTokenId = (0, params_1.defineSecret)("CF_TURN_TOKEN_ID");
const cfTurnApiToken = (0, params_1.defineSecret)("CF_TURN_API_TOKEN");
// ---------------------------------------------------------------------------
// Helper: normalize APNs secrets
// ---------------------------------------------------------------------------
function normalizeSecretValue(value) {
    const trimmed = value.trim();
    if ((trimmed.startsWith("\"") && trimmed.endsWith("\"")) ||
        (trimmed.startsWith("'") && trimmed.endsWith("'"))) {
        return trimmed.slice(1, -1).trim();
    }
    return trimmed;
}
function resolveApnsConfig() {
    const keyId = normalizeSecretValue(apnsKeyId.value());
    const team = normalizeSecretValue(apnsTeamId.value());
    const bundleId = normalizeSecretValue(apnsBundleId.value());
    const signingKey = normalizeSecretValue(apnsSigningKey.value())
        .replace(/\\n/g, "\n");
    const sandboxValue = normalizeSecretValue(apnsSandbox.value() ?? "");
    const isSandbox = sandboxValue.toLowerCase() === "true";
    if (!signingKey.includes("BEGIN PRIVATE KEY")) {
        throw new Error("APNS_SIGNING_KEY is not a valid .p8 private key");
    }
    return { keyId, team, bundleId, signingKey, isSandbox };
}
// ---------------------------------------------------------------------------
// Helper: send notifications and clean up invalid tokens
// ---------------------------------------------------------------------------
async function sendToTokens(tokens, title, body, data, userTokenMap) {
    if (tokens.length === 0)
        return;
    const response = await messaging.sendEachForMulticast({
        tokens,
        notification: { title, body },
        data,
        android: { priority: "high" },
        apns: {
            payload: { aps: { sound: "default", contentAvailable: true } },
        },
    });
    // Clean up invalid/expired tokens by overwriting with the valid subset.
    // Using arrayRemove fails if the Firestore field contains nested arrays.
    if (response.failureCount > 0) {
        const invalidCodes = new Set([
            "messaging/invalid-registration-token",
            "messaging/registration-token-not-registered",
        ]);
        // Group invalid tokens by userId.
        const invalidByUser = new Map();
        response.responses.forEach((resp, idx) => {
            if (resp.error && invalidCodes.has(resp.error.code)) {
                const entry = userTokenMap.get(tokens[idx]);
                if (entry) {
                    if (!invalidByUser.has(entry.userId)) {
                        invalidByUser.set(entry.userId, new Set());
                    }
                    invalidByUser.get(entry.userId).add(entry.token);
                }
            }
        });
        // For each affected user, read current tokens, filter, and overwrite.
        const updates = [];
        for (const [userId, badTokens] of invalidByUser) {
            updates.push(db.collection("users").doc(userId).get().then(async (snap) => {
                const raw = snap.data()?.fcmTokens ?? [];
                const clean = raw.filter((t) => typeof t === "string" && !badTokens.has(t));
                await snap.ref.update({ fcmTokens: clean });
            }));
        }
        await Promise.all(updates);
    }
}
// ---------------------------------------------------------------------------
// APNs client cache — reuses the HTTP/2 connection across warm invocations.
// ---------------------------------------------------------------------------
let _cachedApnsClient = null;
let _cachedApnsIsSandbox = null;
function getApnsClient() {
    const { team, keyId, signingKey, bundleId, isSandbox } = resolveApnsConfig();
    if (_cachedApnsClient === null || _cachedApnsIsSandbox !== isSandbox) {
        _cachedApnsClient = new apns2_1.ApnsClient({
            team,
            keyId,
            signingKey,
            defaultTopic: `${bundleId}.voip`,
            host: isSandbox ? apns2_1.Host.development : apns2_1.Host.production,
        });
        _cachedApnsIsSandbox = isSandbox;
    }
    return _cachedApnsClient;
}
// ---------------------------------------------------------------------------
// Helper: send VoIP push via APNs (iOS only)
// ---------------------------------------------------------------------------
async function sendVoipPush(voipToken, callId, callerId, callerName) {
    const client = getApnsClient();
    const notification = new apns2_1.Notification(voipToken, {
        type: "voip",
        priority: 10,
        data: {
            callId,
            callerId,
            callerName,
            uuid: callId,
            nameCaller: callerName,
        },
        aps: {
            "content-available": 1,
        },
    });
    await client.send(notification);
    console.log("VoIP push sent successfully");
}
// ---------------------------------------------------------------------------
// Trigger: new message → notify other participants
// ---------------------------------------------------------------------------
exports.onNewMessage = (0, firestore_1.onDocumentCreated)("conversations/{conversationId}/messages/{messageId}", async (event) => {
    const messageData = event.data?.data();
    if (!messageData)
        return;
    const senderId = messageData.senderId;
    const conversationId = event.params.conversationId;
    // Read conversation to get participants and title.
    const convoSnap = await db
        .collection("conversations")
        .doc(conversationId)
        .get();
    if (!convoSnap.exists)
        return;
    const convoData = convoSnap.data();
    const participantIds = convoData.participantIds ?? [];
    const convoTitle = convoData.title ?? "New message";
    // Get sender display name.
    const senderSnap = await db.collection("users").doc(senderId).get();
    const senderName = senderSnap.data()?.displayName ?? "Someone";
    // Collect FCM tokens for all participants except sender.
    const recipientIds = participantIds.filter((id) => id !== senderId);
    if (recipientIds.length === 0)
        return;
    const tokens = [];
    const tokenMap = new Map();
    const recipientSnaps = await Promise.all(recipientIds.map((id) => db.collection("users").doc(id).get()));
    for (const snap of recipientSnaps) {
        const userData = snap.data();
        if (!userData?.fcmTokens)
            continue;
        for (const token of userData.fcmTokens) {
            tokens.push(token);
            tokenMap.set(token, { userId: snap.id, token });
        }
    }
    // Build notification body from message content.
    const messageText = messageData.type === "voice"
        ? "Voice message"
        : messageData.type === "image"
            ? "Photo"
            : messageData.type === "video"
                ? "Video"
                : messageData.content ?? "";
    const title = participantIds.length > 2 ? `${senderName} in ${convoTitle}` : senderName;
    await sendToTokens(tokens, title, messageText, {
        type: "message",
        conversationId,
        senderId,
    }, tokenMap);
});
// ---------------------------------------------------------------------------
// Trigger: new call (ringing) → notify callee
// ---------------------------------------------------------------------------
exports.onNewCall = (0, firestore_1.onDocumentCreated)({
    document: "calls/{callId}",
    secrets: [apnsKeyId, apnsTeamId, apnsSigningKey, apnsBundleId, apnsSandbox],
}, async (event) => {
    console.log(`onNewCall: triggered for calls/${event.params.callId}`);
    const callData = event.data?.data();
    if (!callData) {
        console.log("onNewCall: no callData, exiting");
        return;
    }
    console.log(`onNewCall: status=${callData.status}, callerId=${callData.callerId}, calleeId=${callData.calleeId}`);
    // Only notify for new ringing calls.
    if (callData.status !== "ringing") {
        console.log(`onNewCall: status is '${callData.status}', not 'ringing' — skipping`);
        return;
    }
    const callerId = callData.callerId;
    const calleeId = callData.calleeId;
    const callId = event.params.callId;
    // Get caller display name.
    const callerSnap = await db.collection("users").doc(callerId).get();
    const callerName = callerSnap.data()?.displayName ?? "Someone";
    // Get callee data (FCM tokens + VoIP token).
    const calleeSnap = await db.collection("users").doc(calleeId).get();
    const calleeData = calleeSnap.data();
    if (!calleeData) {
        console.log(`onNewCall: calleeData is null for calleeId=${calleeId}, exiting`);
        return;
    }
    const promises = [];
    console.log(`onNewCall: callId=${callId}, caller=${callerName} (${callerId}), callee=${calleeId}`);
    // 1. Send VoIP push via APNs for iOS (reliably wakes terminated app).
    const voipToken = calleeData.voipToken;
    console.log(`onNewCall: voipToken=${voipToken ? "present" : "MISSING"}, fcmTokens=${(calleeData.fcmTokens ?? []).length}`);
    if (voipToken) {
        promises.push(sendVoipPush(voipToken, callId, callerId, callerName).catch(async (err) => {
            const reason = err?.response?.reason ?? err?.reason ?? "unknown";
            console.error("VoIP push failed:", err);
            // Clear token only when the device has truly unregistered.
            // BadDeviceToken can also indicate an environment mismatch
            // (sandbox vs production) — deleting the token in that case
            // forces the callee to reopen the app to re-register.
            if (reason === "Unregistered") {
                await db.collection("users").doc(calleeId).update({
                    voipToken: firestore_2.FieldValue.delete(),
                });
            }
            if (reason === "InvalidProviderToken") {
                console.error("APNs auth failed (InvalidProviderToken). " +
                    "Verify APNS_TEAM_ID, APNS_KEY_ID, and APNS_SIGNING_KEY " +
                    "Firebase secrets for onNewCall.");
            }
        }));
    }
    // 2. Send data-only FCM push for Android (and as fallback for iOS).
    const rawTokens = calleeData.fcmTokens ?? [];
    const fcmTokens = rawTokens.filter((t) => typeof t === "string");
    // If the stored array had non-string entries (corrupted data), clean it up.
    if (fcmTokens.length !== rawTokens.length) {
        console.log(`Cleaning up corrupted fcmTokens: ${rawTokens.length} raw → ${fcmTokens.length} valid`);
        promises.push(db.collection("users").doc(calleeId).update({ fcmTokens }));
    }
    if (fcmTokens.length > 0) {
        const response = messaging.sendEachForMulticast({
            tokens: fcmTokens,
            data: {
                type: "call",
                callId,
                callerId,
                callerName,
            },
            android: { priority: "high" },
            apns: {
                payload: { aps: { contentAvailable: true } },
            },
        });
        promises.push(response.then(async (resp) => {
            console.log(`FCM sent: ${resp.successCount} success, ${resp.failureCount} failures`);
            if (resp.failureCount > 0) {
                const invalidCodes = new Set([
                    "messaging/invalid-registration-token",
                    "messaging/registration-token-not-registered",
                ]);
                // Collect valid tokens, excluding invalid ones.
                const invalidTokens = new Set();
                resp.responses.forEach((r, idx) => {
                    if (r.error && invalidCodes.has(r.error.code)) {
                        invalidTokens.add(fcmTokens[idx]);
                    }
                });
                if (invalidTokens.size > 0) {
                    const cleanedTokens = fcmTokens.filter((t) => !invalidTokens.has(t));
                    await db.collection("users").doc(calleeId).update({
                        fcmTokens: cleanedTokens,
                    });
                }
            }
        }));
    }
    await Promise.all(promises);
});
// ---------------------------------------------------------------------------
// Callable: get short-lived TURN credentials from Cloudflare
// ---------------------------------------------------------------------------
exports.getTurnCredentials = (0, https_1.onCall)({ secrets: [cfTurnTokenId, cfTurnApiToken] }, async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Must be signed in");
    }
    const resp = await fetch(`https://rtc.live.cloudflare.com/v1/turn/keys/${cfTurnTokenId.value()}/credentials/generate`, {
        method: "POST",
        headers: {
            "Authorization": `Bearer ${cfTurnApiToken.value()}`,
            "Content-Type": "application/json",
        },
        body: JSON.stringify({ ttl: 86400 }),
    });
    if (!resp.ok) {
        throw new https_1.HttpsError("internal", `Cloudflare TURN API error: ${resp.status}`);
    }
    const data = await resp.json();
    // Cloudflare returns iceServers as a single object; WebRTC expects an array.
    const raw = data.iceServers;
    const servers = Array.isArray(raw) ? raw : [raw];
    // flutter_webrtc on some iOS/Android versions silently fails to parse TURN
    // URLs that contain query parameters (e.g. ?transport=udp). Strip the
    // query strings and split each transport variant into its own entry so
    // WebRTC negotiates UDP for turn: and TCP for turns: independently.
    return servers.flatMap((server) => {
        const allUrls = (Array.isArray(server.urls)
            ? server.urls
            : [server.urls]).map((u) => u.split("?")[0]); // strip ?transport= etc.
        const stun = allUrls.filter((u) => u.startsWith("stun:"));
        const turnUdp = allUrls.filter((u) => u.startsWith("turn:"));
        const turnTls = allUrls.filter((u) => u.startsWith("turns:"));
        // Add port 443 variants for turns: — port 5349 can be blocked by some
        // ISPs/carriers, but port 443 (HTTPS) is universally open.
        // Replace the existing port number directly to avoid URL-class
        // pathname artifacts (e.g. trailing "/") that crash native WebRTC.
        const turnTls443 = turnTls.map((u) => /:\d+$/.test(u) ? u.replace(/:\d+$/, ":443") : `${u}:443`);
        const result = [];
        if (stun.length > 0) {
            result.push({ urls: stun });
        }
        if (turnUdp.length > 0) {
            result.push({ urls: turnUdp, username: server.username, credential: server.credential });
        }
        if (turnTls.length > 0 || turnTls443.length > 0) {
            // Include both port 5349 and port 443 — WebRTC tries them in parallel.
            result.push({
                urls: [...turnTls, ...turnTls443],
                username: server.username,
                credential: server.credential,
            });
        }
        return result;
    });
});
// ---------------------------------------------------------------------------
// Scheduled: clean up stale calls every 2 minutes
// ---------------------------------------------------------------------------
exports.cleanupStaleCalls = (0, scheduler_1.onSchedule)("every 15 minutes", async () => {
    const now = Date.now();
    const ringingCutoff = new Date(now - 60 * 1000); // 60s for ringing
    const connectedCutoff = new Date(now - 4 * 60 * 60 * 1000); // 4h for connected
    // End stale ringing calls (missed).
    const staleRinging = await db
        .collection("calls")
        .where("status", "==", "ringing")
        .where("createdAt", "<", ringingCutoff)
        .limit(50)
        .get();
    // End stale connected calls (error — likely a crash).
    const staleConnected = await db
        .collection("calls")
        .where("status", "==", "connected")
        .where("createdAt", "<", connectedCutoff)
        .limit(50)
        .get();
    const batch = db.batch();
    const endedAt = new Date().toISOString();
    for (const doc of staleRinging.docs) {
        batch.update(doc.ref, {
            status: "missed",
            endedAt,
            endReason: "timeout",
        });
    }
    for (const doc of staleConnected.docs) {
        batch.update(doc.ref, {
            status: "ended",
            endedAt,
            endReason: "error",
        });
    }
    if (staleRinging.size + staleConnected.size > 0) {
        await batch.commit();
        console.log(`Cleaned up ${staleRinging.size} stale ringing, ${staleConnected.size} stale connected calls`);
    }
});
//# sourceMappingURL=index.js.map
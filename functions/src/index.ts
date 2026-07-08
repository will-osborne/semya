import {onDocumentCreated, onDocumentUpdated} from "firebase-functions/v2/firestore";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {defineSecret} from "firebase-functions/params";
import {initializeApp} from "firebase-admin/app";
import {getFirestore, FieldValue} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {ApnsClient, Host, Notification as ApnsNotification} from "apns2";

initializeApp();

const db = getFirestore();
const messaging = getMessaging();

// APNs credentials stored as Firebase secrets.
// Set via: firebase functions:secrets:set APNS_KEY_ID, etc.
const apnsKeyId = defineSecret("APNS_KEY_ID");
const apnsTeamId = defineSecret("APNS_TEAM_ID");
const apnsSigningKey = defineSecret("APNS_SIGNING_KEY");
const apnsBundleId = defineSecret("APNS_BUNDLE_ID");
// Set to "true" for development/debug builds, "false" (or unset) for
// TestFlight/App Store. Controls which APNs endpoint receives VoIP pushes.
// Set via: firebase functions:secrets:set APNS_SANDBOX
const apnsSandbox = defineSecret("APNS_SANDBOX");

// Cloudflare TURN credentials.
// Set via: firebase functions:secrets:set CF_TURN_TOKEN_ID, CF_TURN_API_TOKEN
const cfTurnTokenId = defineSecret("CF_TURN_TOKEN_ID");
const cfTurnApiToken = defineSecret("CF_TURN_API_TOKEN");

// ---------------------------------------------------------------------------
// Helper: normalize APNs secrets
// ---------------------------------------------------------------------------

function normalizeSecretValue(value: string): string {
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

  return {keyId, team, bundleId, signingKey, isSandbox};
}

// ---------------------------------------------------------------------------
// Helper: send notifications and clean up invalid tokens
// ---------------------------------------------------------------------------

async function sendToTokens(
  tokens: string[],
  title: string,
  body: string,
  data: Record<string, string>,
  userTokenMap: Map<string, {userId: string; token: string}>,
): Promise<void> {
  if (tokens.length === 0) return;

  const response = await messaging.sendEachForMulticast({
    tokens,
    notification: {title, body},
    data,
    android: {
      priority: "high",
      notification: {channelId: "semya_messages", sound: "default"},
    },
    apns: {
      payload: {aps: {sound: "default", contentAvailable: true}},
    },
  });

  // Clean up invalid/expired tokens by overwriting with the valid subset.
  // Using arrayRemove fails if the Firestore field contains nested arrays.
  // Cleanup is best-effort: never fail the invocation (which would trigger a
  // retry and duplicate notifications) because of it.
  try {
    await cleanupInvalidTokens(response, tokens, userTokenMap);
  } catch (err) {
    console.error("Token cleanup failed (non-fatal):", err);
  }
}

async function cleanupInvalidTokens(
  response: Awaited<ReturnType<typeof messaging.sendEachForMulticast>>,
  tokens: string[],
  userTokenMap: Map<string, {userId: string; token: string}>,
): Promise<void> {
  if (response.failureCount > 0) {
    const invalidCodes = new Set([
      "messaging/invalid-registration-token",
      "messaging/registration-token-not-registered",
    ]);

    // Group invalid tokens by userId.
    const invalidByUser = new Map<string, Set<string>>();
    response.responses.forEach((resp, idx) => {
      if (resp.error && invalidCodes.has(resp.error.code)) {
        const entry = userTokenMap.get(tokens[idx]);
        if (entry) {
          if (!invalidByUser.has(entry.userId)) {
            invalidByUser.set(entry.userId, new Set());
          }
          invalidByUser.get(entry.userId)!.add(entry.token);
        }
      }
    });

    // For each affected user, read current tokens, filter, and overwrite.
    const updates: Promise<unknown>[] = [];
    for (const [userId, badTokens] of invalidByUser) {
      updates.push(
        db.collection("users").doc(userId).get().then(async (snap) => {
          const raw: unknown[] = snap.data()?.fcmTokens ?? [];
          const clean = raw.filter(
            (t): t is string => typeof t === "string" && !badTokens.has(t),
          );
          await snap.ref.update({fcmTokens: clean});
        }),
      );
    }
    await Promise.all(updates);
  }
}

// ---------------------------------------------------------------------------
// APNs client cache — reuses the HTTP/2 connections across warm invocations.
// One client per environment so a BadDeviceToken retry against the opposite
// host doesn't tear down the primary connection.
// ---------------------------------------------------------------------------

const _cachedApnsClients = new Map<boolean, ApnsClient>();

function getApnsClient(isSandbox: boolean): ApnsClient {
  let client = _cachedApnsClients.get(isSandbox);
  if (!client) {
    const {team, keyId, signingKey, bundleId} = resolveApnsConfig();
    client = new ApnsClient({
      team,
      keyId,
      signingKey,
      defaultTopic: `${bundleId}.voip`,
      host: isSandbox ? Host.development : Host.production,
    });
    _cachedApnsClients.set(isSandbox, client);
  }
  return client;
}

// ---------------------------------------------------------------------------
// Helper: send VoIP push via APNs (iOS only)
// ---------------------------------------------------------------------------

function apnsErrorReason(err: unknown): string {
  const e = err as {response?: {reason?: string}; reason?: string} | null;
  return e?.response?.reason ?? e?.reason ?? "unknown";
}

function apnsEnvName(isSandbox: boolean): string {
  return isSandbox ? "sandbox" : "production";
}

async function sendVoipNotification(
  voipToken: string,
  data: Record<string, string>,
): Promise<void> {
  const {isSandbox} = resolveApnsConfig();

  const buildNotification = () =>
    new ApnsNotification(voipToken, {
      type: "voip" as never,
      priority: 10,
      data,
      aps: {
        "content-available": 1,
      },
    });

  try {
    await getApnsClient(isSandbox).send(buildNotification());
  } catch (err) {
    // BadDeviceToken usually means the token belongs to the opposite APNs
    // environment (sandbox vs production) — retry once against the other host
    // instead of silently dropping the push.
    if (apnsErrorReason(err) !== "BadDeviceToken") throw err;
    await getApnsClient(!isSandbox).send(buildNotification());
    console.log(
      `VoIP push got BadDeviceToken on ${apnsEnvName(isSandbox)} APNs but ` +
      `succeeded on ${apnsEnvName(!isSandbox)} — consider updating the ` +
      "APNS_SANDBOX secret",
    );
  }
}

async function sendVoipPush(
  voipToken: string,
  callId: string,
  callerId: string,
  callerName: string,
): Promise<void> {
  await sendVoipNotification(voipToken, {
    callId,
    callerId,
    callerName,
    uuid: callId,
    nameCaller: callerName,
  });
  console.log("VoIP push sent successfully");
}

// ---------------------------------------------------------------------------
// Trigger: new message → notify other participants
// ---------------------------------------------------------------------------

export const onNewMessage = onDocumentCreated(
  {
    document: "conversations/{conversationId}/messages/{messageId}",
    retry: true,
  },
  async (event) => {
    const messageData = event.data?.data();
    if (!messageData) return;

    const senderId = messageData.senderId as string;
    const conversationId = event.params.conversationId;

    // Read conversation to get participants and title.
    const convoSnap = await db
      .collection("conversations")
      .doc(conversationId)
      .get();
    if (!convoSnap.exists) return;
    const convoData = convoSnap.data()!;
    const participantIds: string[] = convoData.participantIds ?? [];
    const convoTitle: string = convoData.title ?? "New message";

    // Get sender display name.
    const senderSnap = await db.collection("users").doc(senderId).get();
    const senderName: string =
      senderSnap.data()?.displayName ?? "Someone";

    // Collect FCM tokens for all participants except sender.
    const recipientIds = participantIds.filter((id) => id !== senderId);
    if (recipientIds.length === 0) return;

    const tokens: string[] = [];
    const tokenMap = new Map<string, {userId: string; token: string}>();

    const recipientSnaps = await Promise.all(
      recipientIds.map((id) => db.collection("users").doc(id).get()),
    );

    for (const snap of recipientSnaps) {
      const userData = snap.data();
      if (!userData?.fcmTokens) continue;
      for (const token of userData.fcmTokens as string[]) {
        tokens.push(token);
        tokenMap.set(token, {userId: snap.id, token});
      }
    }

    // Build notification body from message content.
    const messageText: string =
      messageData.type === "voice"
        ? "Voice message"
        : messageData.type === "image"
        ? "Photo"
        : messageData.type === "video"
        ? "Video"
        : (messageData.content as string) ?? "";

    const title =
      participantIds.length > 2 ? `${senderName} in ${convoTitle}` : senderName;

    await sendToTokens(tokens, title, messageText, {
      type: "message",
      conversationId,
      senderId,
      senderName,
      messageType: (messageData.type as string) ?? "text",
      preview: messageText.slice(0, 200),
    }, tokenMap);
  },
);

// ---------------------------------------------------------------------------
// Trigger: new call (ringing) → notify callee
// ---------------------------------------------------------------------------

export const onNewCall = onDocumentCreated(
  {
    document: "calls/{callId}",
    secrets: [apnsKeyId, apnsTeamId, apnsSigningKey, apnsBundleId, apnsSandbox],
  },
  async (event) => {
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

    const callerId = callData.callerId as string;
    const calleeId = callData.calleeId as string;
    const callId = event.params.callId;

    // Get caller display name.
    const callerSnap = await db.collection("users").doc(callerId).get();
    const callerName: string =
      callerSnap.data()?.displayName ?? "Someone";

    // Get callee data (FCM tokens + VoIP token).
    const calleeSnap = await db.collection("users").doc(calleeId).get();
    const calleeData = calleeSnap.data();
    if (!calleeData) {
      console.log(`onNewCall: calleeData is null for calleeId=${calleeId}, exiting`);
      return;
    }

    const promises: Promise<unknown>[] = [];

    console.log(
      `onNewCall: callId=${callId}, caller=${callerName} (${callerId}), callee=${calleeId}`,
    );

    // 1. Send VoIP push via APNs for iOS (reliably wakes terminated app).
    const voipToken = calleeData.voipToken as string | undefined;
    console.log(`onNewCall: voipToken=${voipToken ? "present" : "MISSING"}, fcmTokens=${(calleeData.fcmTokens as string[] ?? []).length}`);
    if (voipToken) {
      promises.push(
        sendVoipPush(voipToken, callId, callerId, callerName).catch(
          async (err) => {
            const reason = err?.response?.reason ?? err?.reason ?? "unknown";
            console.error("VoIP push failed:", err);
            // Clear token only when the device has truly unregistered.
            // BadDeviceToken can also indicate an environment mismatch
            // (sandbox vs production) — deleting the token in that case
            // forces the callee to reopen the app to re-register.
            if (reason === "Unregistered") {
              await db.collection("users").doc(calleeId).update({
                voipToken: FieldValue.delete(),
              });
            }
            if (reason === "InvalidProviderToken") {
              console.error(
                "APNs auth failed (InvalidProviderToken). " +
                "Verify APNS_TEAM_ID, APNS_KEY_ID, and APNS_SIGNING_KEY " +
                "Firebase secrets for onNewCall.",
              );
            }
          },
        ),
      );
    }

    // 2. Send data-only FCM push for Android (and as fallback for iOS).
    const rawTokens: unknown[] = calleeData.fcmTokens as unknown[] ?? [];
    const fcmTokens: string[] = rawTokens.filter(
      (t): t is string => typeof t === "string",
    );

    // If the stored array had non-string entries (corrupted data), clean it up.
    if (fcmTokens.length !== rawTokens.length) {
      console.log(`Cleaning up corrupted fcmTokens: ${rawTokens.length} raw → ${fcmTokens.length} valid`);
      promises.push(
        db.collection("users").doc(calleeId).update({fcmTokens}),
      );
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
        android: {priority: "high"},
        apns: {
          payload: {aps: {contentAvailable: true}},
        },
      });

      promises.push(
        response.then(async (resp) => {
          console.log(`FCM sent: ${resp.successCount} success, ${resp.failureCount} failures`);
          if (resp.failureCount > 0) {
            const invalidCodes = new Set([
              "messaging/invalid-registration-token",
              "messaging/registration-token-not-registered",
            ]);

            // Collect valid tokens, excluding invalid ones.
            const invalidTokens = new Set<string>();
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
        }),
      );
    }

    await Promise.all(promises);
  },
);

// ---------------------------------------------------------------------------
// Trigger: call leaves "ringing" → tell the callee's devices to stop ringing
// ---------------------------------------------------------------------------
// When the caller hangs up (or the call times out / is rejected elsewhere)
// while the callee's app process is dead, only a push can dismiss the native
// incoming-call UI. Skipped when the call was answered ("connected") — the
// callee's own device performed that transition and already knows.

export const onCallUpdated = onDocumentUpdated(
  {
    document: "calls/{callId}",
    secrets: [apnsKeyId, apnsTeamId, apnsSigningKey, apnsBundleId, apnsSandbox],
  },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    // Only react when a ringing call stops ringing.
    if (before.status !== "ringing" || after.status === "ringing") return;

    // Answered by the callee — their UI already reflects the call.
    if (after.status === "connected") return;

    const callId = event.params.callId;
    const calleeId = after.calleeId as string;
    console.log(
      `onCallUpdated: callId=${callId} status ringing→${after.status}, ` +
      `notifying callee=${calleeId}`,
    );

    const calleeSnap = await db.collection("users").doc(calleeId).get();
    const calleeData = calleeSnap.data();
    if (!calleeData) {
      console.log(`onCallUpdated: no user doc for calleeId=${calleeId}`);
      return;
    }

    const promises: Promise<unknown>[] = [];

    // 1. iOS: VoIP push so the native CallKit UI dismisses. The client is
    // required (by Apple) to report the push to CallKit and immediately end
    // the call with the matching id; ending an already-dismissed id is a no-op.
    const voipToken = calleeData.voipToken as string | undefined;
    if (voipToken) {
      promises.push(
        sendVoipNotification(voipToken, {
          type: "call_cancelled",
          callId,
          uuid: callId,
        }).catch((err) => {
          console.error("Call-cancelled VoIP push failed:", err);
        }),
      );
    }

    // 2. Android: high-priority data-only FCM to dismiss the incoming-call
    // notification. Best-effort — no token cleanup here (onNewCall handles it).
    const fcmTokens = (calleeData.fcmTokens as unknown[] ?? []).filter(
      (t): t is string => typeof t === "string",
    );
    if (fcmTokens.length > 0) {
      promises.push(
        messaging.sendEachForMulticast({
          tokens: fcmTokens,
          data: {
            type: "call_cancelled",
            callId,
          },
          android: {priority: "high"},
          apns: {
            payload: {aps: {contentAvailable: true}},
          },
        }).then((resp) => {
          console.log(
            `Call-cancelled FCM sent: ${resp.successCount} success, ` +
            `${resp.failureCount} failures`,
          );
        }).catch((err) => {
          console.error("Call-cancelled FCM push failed:", err);
        }),
      );
    }

    await Promise.all(promises);
  },
);

// ---------------------------------------------------------------------------
// Callable: get short-lived TURN credentials from Cloudflare
// ---------------------------------------------------------------------------

export const getTurnCredentials = onCall(
  {secrets: [cfTurnTokenId, cfTurnApiToken]},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in");
    }

    const resp = await fetch(
      `https://rtc.live.cloudflare.com/v1/turn/keys/${cfTurnTokenId.value()}/credentials/generate`,
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${cfTurnApiToken.value()}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ttl: 86400}),
      },
    );

    if (!resp.ok) {
      throw new HttpsError("internal", `Cloudflare TURN API error: ${resp.status}`);
    }

    const data = await resp.json();
    // Cloudflare returns iceServers as a single object; WebRTC expects an array.
    const raw = data.iceServers;
    const servers = Array.isArray(raw) ? raw : [raw];

    // flutter_webrtc on some iOS/Android versions silently fails to parse TURN
    // URLs that contain query parameters (e.g. ?transport=udp). Strip the
    // query strings and split each transport variant into its own entry so
    // WebRTC negotiates UDP for turn: and TCP for turns: independently.
    return servers.flatMap((server: {
      urls: string | string[];
      username?: string;
      credential?: string;
    }) => {
      const allUrls: string[] = (Array.isArray(server.urls)
        ? server.urls
        : [server.urls]
      ).map((u: string) => u.split("?")[0]); // strip ?transport= etc.

      const stun = allUrls.filter((u) => u.startsWith("stun:"));
      const turnUdp = allUrls.filter((u) => u.startsWith("turn:"));
      const turnTls = allUrls.filter((u) => u.startsWith("turns:"));

      // Add port 443 variants for turns: — port 5349 can be blocked by some
      // ISPs/carriers, but port 443 (HTTPS) is universally open.
      // Replace the existing port number directly to avoid URL-class
      // pathname artifacts (e.g. trailing "/") that crash native WebRTC.
      const turnTls443 = turnTls.map((u) =>
        /:\d+$/.test(u) ? u.replace(/:\d+$/, ":443") : `${u}:443`,
      );

      const result: object[] = [];
      if (stun.length > 0) {
        result.push({urls: stun});
      }
      if (turnUdp.length > 0) {
        result.push({urls: turnUdp, username: server.username, credential: server.credential});
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
  },
);

// ---------------------------------------------------------------------------
// Scheduled: clean up stale calls every 5 minutes
// ---------------------------------------------------------------------------

export const cleanupStaleCalls = onSchedule("every 5 minutes", async () => {
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
    console.log(
      `Cleaned up ${staleRinging.size} stale ringing, ${staleConnected.size} stale connected calls`,
    );
  }
});

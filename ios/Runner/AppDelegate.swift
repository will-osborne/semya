import Flutter
import UIKit
import FirebaseCore
import PushKit
import FirebaseAuth
import flutter_webrtc
import flutter_callkit_incoming
import AVFAudio
import CallKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, PKPushRegistryDelegate, CallkitIncomingAppDelegate, CXProviderDelegate {
  // Stored as a property so the registry isn't deallocated after launch.
  private var voipRegistry: PKPushRegistry?

  // UserDefaults key for VoIP token — uses "flutter." prefix so Dart's
  // shared_preferences can read it via getString("voip_push_token").
  private static let voipTokenKey = "flutter.voip_push_token"

  // UserDefaults keys bridging fallback CallKit actions to Dart. When the
  // fallback CXProvider handles answer/decline (app was terminated, Flutter
  // plugin not yet ready), the call id (String) is written under these keys
  // so Dart can read them at startup via shared_preferences
  // (getString("pending_accepted_call") / getString("pending_declined_call")).
  private static let pendingAcceptedCallKey = "flutter.pending_accepted_call"
  private static let pendingDeclinedCallKey = "flutter.pending_declined_call"

  // In-memory copy of the latest VoIP token from PushKit.
  private var pendingVoipToken: String?

  // Maps the CallKit UUID of a fallback-reported call back to the original
  // call id string (Firestore call ids aren't always valid UUIDs).
  private var fallbackCallIds: [UUID: String] = [:]

  // CXProvider used as a fallback when the Flutter plugin isn't ready
  // (e.g. VoIP push arrives while the app is terminated).
  private lazy var fallbackProvider: CXProvider = {
    let config = CXProviderConfiguration(localizedName: "Семья")
    config.supportsVideo = true
    config.maximumCallGroups = 1
    config.maximumCallsPerCallGroup = 1
    config.supportedHandleTypes = [.generic]
    let provider = CXProvider(configuration: config)
    provider.setDelegate(self, queue: .main)
    return provider
  }()

  private func configureFirebaseIfNeeded() {
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    configureFirebaseIfNeeded()
    application.registerForRemoteNotifications()

    #if targetEnvironment(simulator)
    // The iOS simulator cannot receive APNs verification pushes. Enable
    // Firebase Auth's testing bypass so fictional phone numbers work there.
    Auth.auth().settings!.isAppVerificationDisabledForTesting = true
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
      let proberNotification: [AnyHashable: Any] = [
        "com.google.firebase.auth": [
          "warning": "This fake notification should be forwarded to Firebase Auth."
        ]
      ]
      _ = Auth.auth().canHandleNotification(proberNotification)
    }
    #endif

    // Register for VoIP pushes via PushKit so iOS can wake the app
    // from terminated/background state for incoming calls.
    voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
    voipRegistry!.delegate = self
    voipRegistry!.desiredPushTypes = [PKPushType.voIP]

    // Pre-heat the audio session so CallKit's didActivateAudioSession fires
    // reliably (Apple docs: configure category/mode before CallKit activates).
    let audioSession = AVAudioSession.sharedInstance()
    try? audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth])

    // CallKit manages the audio session; WebRTC follows via manual audio mode.
    let rtcAudioSession = RTCAudioSession.sharedInstance()
    rtcAudioSession.useManualAudio = true
    // Keep WebRTC audio enabled by default so non-call audio features
    // (voice-note recording/playback) keep working outside CallKit sessions.
    rtcAudioSession.isAudioEnabled = true

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    configureFirebaseIfNeeded()
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Forward the VoIP token to the plugin now that it's initialized.
    // PushKit often fires before the Flutter engine is ready, so the
    // optional chain in pushRegistry(didUpdate:) silently drops the token.
    if let token = pendingVoipToken ?? UserDefaults.standard.string(forKey: AppDelegate.voipTokenKey) {
      SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP(token)
      NSLog("[VoIP] Forwarded stored token to plugin after engine init")
    }
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    configureFirebaseIfNeeded()
    if Auth.auth().canHandle(url) {
      return true
    }
    return super.application(app, open: url, options: options)
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Foundation.Data
  ) {
    configureFirebaseIfNeeded()
    Auth.auth().setAPNSToken(deviceToken, type: .unknown)
    super.application(
      application,
      didRegisterForRemoteNotificationsWithDeviceToken: deviceToken
    )
  }

  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    configureFirebaseIfNeeded()
    if Auth.auth().canHandleNotification(userInfo) {
      completionHandler(.noData)
      return
    }

    super.application(
      application,
      didReceiveRemoteNotification: userInfo,
      fetchCompletionHandler: completionHandler
    )
  }

  // MARK: - PKPushRegistryDelegate

  func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
    let deviceToken = credentials.token.map { String(format: "%02x", $0) }.joined()
    NSLog("[VoIP] PushKit token received: \(deviceToken.prefix(16))...")

    // Always persist to UserDefaults so Dart (shared_preferences) can read it.
    UserDefaults.standard.set(deviceToken, forKey: AppDelegate.voipTokenKey)
    pendingVoipToken = deviceToken

    // Forward to the Flutter plugin if it's ready.
    if let plugin = SwiftFlutterCallkitIncomingPlugin.sharedInstance {
      plugin.setDevicePushTokenVoIP(deviceToken)
      NSLog("[VoIP] Token forwarded to Flutter plugin")
    } else {
      NSLog("[VoIP] Plugin not ready — token stored in UserDefaults for Dart to read")
    }
  }

  func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
    UserDefaults.standard.removeObject(forKey: AppDelegate.voipTokenKey)
    pendingVoipToken = nil
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP("")
  }

  func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
    NSLog("[VoIP] didReceiveIncomingPush type=\(type.rawValue) payload=\(payload.dictionaryPayload)")
    guard type == .voIP else {
      completion()
      return
    }

    // Server-initiated cancellation (caller hung up / call timed out /
    // rejected while ringing) — dismiss the incoming-call UI instead of
    // reporting a new ring.
    if payload.dictionaryPayload["type"] as? String == "call_cancelled" {
      let callId = payload.dictionaryPayload["callId"] as? String
        ?? payload.dictionaryPayload["uuid"] as? String
        ?? ""
      handleCallCancelledPush(callId: callId, completion: completion)
      return
    }

    let id = payload.dictionaryPayload["uuid"] as? String ?? UUID().uuidString
    let nameCaller = payload.dictionaryPayload["nameCaller"] as? String ?? ""
    NSLog("[VoIP] Showing CallKit for id=\(id) caller=\(nameCaller)")

    // Try the Flutter plugin first (available when app is in foreground/background).
    if let plugin = SwiftFlutterCallkitIncomingPlugin.sharedInstance {
      let data = flutter_callkit_incoming.Data(id: id, nameCaller: nameCaller, handle: "", type: 0)
      data.duration = 45000
      data.extra = payload.dictionaryPayload as NSDictionary
      plugin.showCallkitIncoming(data, fromPushKit: true) {
        completion()
      }
    } else {
      // Plugin not ready (app launched from terminated state). Report the
      // call directly to CallKit so iOS doesn't kill us. The Flutter
      // plugin will pick up the active call when the engine starts.
      NSLog("[VoIP] Plugin not ready, using fallback CXProvider")
      let callUUID = UUID(uuidString: id) ?? UUID()
      fallbackCallIds[callUUID] = id
      let update = CXCallUpdate()
      update.remoteHandle = CXHandle(type: .generic, value: nameCaller)
      update.localizedCallerName = nameCaller
      update.hasVideo = false
      update.supportsHolding = false
      update.supportsGrouping = false
      update.supportsUngrouping = false

      fallbackProvider.reportNewIncomingCall(with: callUUID, update: update) { error in
        if let error = error {
          NSLog("[VoIP] Fallback reportNewIncomingCall failed: \(error)")
        }
        completion()
      }
    }
  }

  // Handles a {type: "call_cancelled"} VoIP push. Apple requires every VoIP
  // push to be reported to CallKit — ending the existing ringing call counts;
  // when no matching call is on screen, report a placeholder call and end it
  // immediately with .remoteEnded so the user never sees it ring.
  private func handleCallCancelledPush(callId: String, completion: @escaping () -> Void) {
    NSLog("[VoIP] Call cancelled for id=\(callId)")

    // Drop any pending fallback accept/decline for this call so a stale
    // accept can't resurrect the cancelled call when Dart starts.
    for key in [AppDelegate.pendingAcceptedCallKey, AppDelegate.pendingDeclinedCallKey]
    where UserDefaults.standard.string(forKey: key)?.lowercased() == callId.lowercased() {
      UserDefaults.standard.removeObject(forKey: key)
    }

    // 1. Plugin is up and showing this call — end it through the plugin so
    // Dart also receives the call-ended event. (Guard the UUID parse: the
    // plugin force-unwraps UUID(uuidString: data.uuid) internally.)
    if let plugin = SwiftFlutterCallkitIncomingPlugin.sharedInstance,
       UUID(uuidString: callId) != nil,
       plugin.activeCalls().contains(where: {
         ($0["id"] as? String)?.lowercased() == callId.lowercased()
       }) {
      NSLog("[VoIP] Ending plugin-managed call \(callId)")
      let data = flutter_callkit_incoming.Data(id: callId, nameCaller: "", handle: "", type: 0)
      plugin.endCall(data)
      completion()
      return
    }

    // 2. The fallback provider is showing this call (terminated-state ring).
    if let callUUID = fallbackCallIds.first(where: { $0.value == callId })?.key {
      NSLog("[VoIP] Ending fallback-managed call \(callId)")
      fallbackCallIds.removeValue(forKey: callUUID)
      fallbackProvider.reportCall(with: callUUID, endedAt: Date(), reason: .remoteEnded)
      completion()
      return
    }

    // 3. Nothing matching on screen — still report the push to CallKit
    // (report a call and end it in the same runloop turn) so iOS doesn't
    // penalize the app for an unreported VoIP push.
    NSLog("[VoIP] No matching call for \(callId) — report-and-end placeholder")
    let placeholderUUID = UUID(uuidString: callId) ?? UUID()
    let update = CXCallUpdate()
    update.localizedCallerName = ""
    update.hasVideo = false
    fallbackProvider.reportNewIncomingCall(with: placeholderUUID, update: update) { [weak self] _ in
      self?.fallbackProvider.reportCall(with: placeholderUUID, endedAt: Date(), reason: .remoteEnded)
      completion()
    }
  }

  // MARK: - CXProviderDelegate (fallback for terminated-state calls)

  func providerDidReset(_ provider: CXProvider) {}

  func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
    // The Flutter engine isn't running yet, so record the acceptance in
    // UserDefaults for Dart to pick up (via shared_preferences) at startup.
    let callId = fallbackCallIds[action.callUUID] ?? action.callUUID.uuidString.lowercased()
    UserDefaults.standard.set(callId, forKey: AppDelegate.pendingAcceptedCallKey)
    NSLog("[VoIP] Fallback answer for call \(callId) — stored for Dart")
    action.fulfill()
  }

  func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
    let callId = fallbackCallIds[action.callUUID] ?? action.callUUID.uuidString.lowercased()
    fallbackCallIds.removeValue(forKey: action.callUUID)
    // Only surface a decline if the call wasn't already accepted — CallKit
    // also delivers CXEndCallAction when an accepted call later hangs up.
    if UserDefaults.standard.string(forKey: AppDelegate.pendingAcceptedCallKey) != callId {
      UserDefaults.standard.set(callId, forKey: AppDelegate.pendingDeclinedCallKey)
      NSLog("[VoIP] Fallback decline for call \(callId) — stored for Dart")
    }
    action.fulfill()
  }

  // Called by the fallback CXProvider when CallKit activates the audio session
  // for a terminated-state incoming call. Without this, RTCAudioSession.isAudioEnabled
  // stays false and the caller/callee hears nothing.
  func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
    let rtcAudioSession = RTCAudioSession.sharedInstance()
    rtcAudioSession.audioSessionDidActivate(audioSession)
    rtcAudioSession.isAudioEnabled = true
  }

  func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
    let rtcAudioSession = RTCAudioSession.sharedInstance()
    rtcAudioSession.audioSessionDidDeactivate(audioSession)
    // Keep WebRTC audio enabled so non-call media features continue working
    // after CallKit deactivates an ended call.
    rtcAudioSession.isAudioEnabled = true
  }

  // MARK: - CallkitIncomingAppDelegate

  func onAccept(_ call: flutter_callkit_incoming.Call, _ action: CXAnswerCallAction) {
    action.fulfill()
  }

  func onDecline(_ call: flutter_callkit_incoming.Call, _ action: CXEndCallAction) {
    action.fulfill()
  }

  func onEnd(_ call: flutter_callkit_incoming.Call, _ action: CXEndCallAction) {
    action.fulfill()
  }

  func onTimeOut(_ call: flutter_callkit_incoming.Call) {
    // No-op — handled in Dart via CallKitService callback.
  }

  func didActivateAudioSession(_ audioSession: AVAudioSession) {
    let rtcAudioSession = RTCAudioSession.sharedInstance()
    rtcAudioSession.audioSessionDidActivate(audioSession)
    rtcAudioSession.isAudioEnabled = true
  }

  func didDeactivateAudioSession(_ audioSession: AVAudioSession) {
    let rtcAudioSession = RTCAudioSession.sharedInstance()
    rtcAudioSession.audioSessionDidDeactivate(audioSession)
    // Keep WebRTC audio enabled so non-call media features continue working
    // after CallKit deactivates an ended call.
    rtcAudioSession.isAudioEnabled = true
  }
}

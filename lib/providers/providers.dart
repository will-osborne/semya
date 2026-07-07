import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:semya/data/datasources/local/secure_storage_service.dart';
import 'package:semya/data/repositories/firebase_auth_repository.dart';
import 'package:semya/data/repositories/firestore_call_repository.dart';
import 'package:semya/data/repositories/firestore_conversation_repository.dart';
import 'package:semya/data/repositories/firestore_message_repository.dart';
import 'package:semya/data/repositories/firestore_user_repository.dart';
import 'package:semya/data/services/call_sound_service.dart';
import 'package:semya/data/services/callkit_service.dart';
import 'package:semya/data/services/media_cache_service.dart';
import 'package:semya/data/services/media_service.dart';
import 'package:semya/data/services/push_notification_service.dart';
import 'package:semya/data/services/voice_note_service.dart';
import 'package:semya/data/services/webrtc_service.dart';
import 'package:semya/domain/repositories/auth_repository.dart';
import 'package:semya/domain/repositories/call_repository.dart';
import 'package:semya/domain/repositories/conversation_repository.dart';
import 'package:semya/domain/repositories/message_repository.dart';
import 'package:semya/domain/repositories/user_repository.dart';

// ---------------------------------------------------------------------------
// Firebase / Firestore repository providers
// ---------------------------------------------------------------------------

final firebaseAuthRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository();
});

final firestoreUserRepositoryProvider = Provider<UserRepository>((ref) {
  return FirestoreUserRepository();
});

final firestoreConversationRepositoryProvider =
    Provider<ConversationRepository>((ref) {
      return FirestoreConversationRepository();
    });

final firestoreMessageRepositoryProvider = Provider<MessageRepository>((ref) {
  return FirestoreMessageRepository();
});

final firestoreCallRepositoryProvider = Provider<CallRepository>((ref) {
  return FirestoreCallRepository();
});

// ---------------------------------------------------------------------------
// Local encrypted storage providers
// ---------------------------------------------------------------------------

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

// ---------------------------------------------------------------------------
// Voice note service
// ---------------------------------------------------------------------------

final voiceNoteServiceProvider = Provider<VoiceNoteService>((ref) {
  final service = VoiceNoteService();
  ref.onDispose(service.dispose);
  return service;
});

// ---------------------------------------------------------------------------
// WebRTC service
// ---------------------------------------------------------------------------

final webRtcServiceProvider = Provider<WebRtcService>((ref) {
  final service = WebRtcService();
  ref.onDispose(service.dispose);
  return service;
});

// ---------------------------------------------------------------------------
// Push notification service
// ---------------------------------------------------------------------------

final pushNotificationServiceProvider = Provider<PushNotificationService>((
  ref,
) {
  return PushNotificationService();
});

// ---------------------------------------------------------------------------
// Call sound service
// ---------------------------------------------------------------------------

final callSoundServiceProvider = Provider<CallSoundService>((ref) {
  final service = CallSoundService();
  ref.onDispose(service.dispose);
  return service;
});

// ---------------------------------------------------------------------------
// CallKit service (native incoming call UI)
// ---------------------------------------------------------------------------

final callKitServiceProvider = Provider<CallKitService>((ref) {
  final service = CallKitService();
  ref.onDispose(service.dispose);
  return service;
});

// ---------------------------------------------------------------------------
// Media service (pick, compress, upload photos/videos)
// ---------------------------------------------------------------------------

final mediaServiceProvider = Provider<MediaService>((ref) {
  final service = MediaService();
  ref.onDispose(service.dispose);
  return service;
});

// ---------------------------------------------------------------------------
// Media cache service (local file caching for downloaded media)
// ---------------------------------------------------------------------------

final mediaCacheServiceProvider = Provider<MediaCacheService>((ref) {
  final service = MediaCacheService();
  ref.onDispose(service.dispose);
  return service;
});

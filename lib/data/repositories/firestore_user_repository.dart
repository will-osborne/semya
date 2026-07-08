import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:semya/domain/entities/user.dart';
import 'package:semya/domain/repositories/user_repository.dart';

class FirestoreUserRepository implements UserRepository {
  FirestoreUserRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String _collection = 'users';

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection(_collection);

  @override
  Future<void> createUser(AppUser user) async {
    await _usersCollection.doc(user.id).set(user.toJson());
  }

  @override
  Future<AppUser?> getUser(String userId) async {
    final doc = await _usersCollection.doc(userId).get();
    if (!doc.exists || doc.data() == null) return null;
    return AppUser.fromJson(_withId(doc.id, doc.data()!));
  }

  @override
  Future<void> updateUser(AppUser user) async {
    await _usersCollection.doc(user.id).update(user.toJson());
  }

  @override
  Future<List<AppUser>> searchUsersByPhone(String phoneNumber) async {
    final snapshot = await _usersCollection
        .where('phoneNumber', isEqualTo: phoneNumber)
        .get();

    return snapshot.docs
        .map((doc) => AppUser.fromJson(_withId(doc.id, doc.data())))
        .toList();
  }

  @override
  Future<List<AppUser>> searchUsersByEmail(String email) async {
    final snapshot = await _usersCollection
        .where('email', isEqualTo: email.toLowerCase().trim())
        .get();

    return snapshot.docs
        .map((doc) => AppUser.fromJson(_withId(doc.id, doc.data())))
        .toList();
  }

  @override
  Future<void> addFcmToken(String userId, String token) async {
    await _usersCollection.doc(userId).update({
      'fcmTokens': FieldValue.arrayUnion([token]),
    });
  }

  @override
  Future<void> removeFcmToken(String userId, String token) async {
    await _usersCollection.doc(userId).update({
      'fcmTokens': FieldValue.arrayRemove([token]),
    });
  }

  @override
  Future<void> setVoipToken(String userId, String? token) async {
    await _usersCollection.doc(userId).update({'voipToken': token});
  }

  Map<String, dynamic> _withId(String id, Map<String, dynamic> data) {
    return {...data, 'id': id};
  }
}

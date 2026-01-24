import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum UserRole { learner, educator, admin, superadmin }

UserRole roleFromString(String? value) {
  switch (value) {
    case 'ADMIN':
      return UserRole.admin;
    case 'EDUCATOR':
      return UserRole.educator;
    case 'SUPERADMIN':
      return UserRole.superadmin;
    case 'LEARNER':
    default:
      return UserRole.learner;
  }
}

String roleToString(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return 'ADMIN';
    case UserRole.educator:
      return 'EDUCATOR';
    case UserRole.superadmin:
      return 'SUPERADMIN';
    case UserRole.learner:
      return 'LEARNER';
  }
}

class RoleService {
  RoleService._();
  static final instance = RoleService._();

  final _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Future<void> ensureUserDocument(User user) async {
    final docRef = _users.doc(user.uid);
    final doc = await docRef.get();
    if (doc.exists) return;

    // Default registration fields
    await docRef.set({
      'uid': user.uid,
      'email': user.email,
      'createdAt': FieldValue.serverTimestamp(),
      'role': 'LEARNER',
      'status': 'ACTIVE',
      'subscription_status': 'NONE',
      'username': 'Firstname Lastname',
    });
  }

  Stream<UserRole> roleStream(String uid) {
    return _users.doc(uid).snapshots().map((snap) {
      final data = snap.data();
      return roleFromString(data?['role'] as String?);
    });
  }

  Future<UserRole> getRole(String uid) async {
    final snap = await _users.doc(uid).get();
    return roleFromString(snap.data()?['role'] as String?);
  }

  Stream<List<Map<String, dynamic>>> allUsersStream() {
    return _users
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((q) => q.docs.map((d) => {'uid': d.id, ...d.data()}).toList());
  }

  Future<void> setUserRole({
    required String uid,
    required UserRole role,
  }) async {
    await _users.doc(uid).update({'role': roleToString(role)});
  }

  Future<void> updateUsername({
    required String uid,
    required String username,
  }) async {
    await _users.doc(uid).update({'username': username});
  }

  Future<void> updateThemePreference({
    required String uid,
    required String theme,
  }) async {
    await _users.doc(uid).update({'theme_preference': theme});
  }

  Future<String?> getThemePreference(String uid) async {
    final snap = await _users.doc(uid).get();
    return snap.data()?['theme_preference'] as String?;
  }
}

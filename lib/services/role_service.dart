import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum UserRole { learner, educator, admin, superadmin, validator }

UserRole roleFromString(String? value) {
  switch (value?.trim().toUpperCase()) {
    case 'ADMIN':
      return UserRole.admin;
    case 'EDUCATOR':
      return UserRole.educator;
    case 'SUPERADMIN':
      return UserRole.superadmin;
    case 'VALIDATOR':
      return UserRole.validator;
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
    case UserRole.validator:
      return 'VALIDATOR';
    case UserRole.learner:
      return 'LEARNER';
  }
}

class RoleService {
  RoleService._();
  static final instance = RoleService._();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  static const String disabledValidatorMessage =
      'Thank you for your interest in applying as a Validator, currently Grammatica has already a Validator. Feel free to reapply next time once this button is no longer disabled.';

  bool isApprovedValidatorData(Map<String, dynamic>? data) {
    if (data == null) return false;
    final role = (data['role'] as String? ?? '').trim().toUpperCase();
    if (role != 'VALIDATOR') return false;

    final status = (data['status'] as String? ?? '').trim().toUpperCase();
    final isArchived = data['isArchived'] == true || status == 'ARCHIVED';
    if (isArchived) return false;
    if (status == 'DEACTIVATED' || status == 'INACTIVE' || status == 'REJECTED') {
      return false;
    }

    final isVerified = data['isVerified'] == true;
    return isVerified && status == 'ACTIVE';
  }

  Stream<bool> isValidatorRegistrationDisabledStream() {
    return _users
        .where('role', whereIn: ['VALIDATOR', 'validator'])
        .snapshots()
        .map((snapshot) {
          int approvedCount = 0;
          for (final doc in snapshot.docs) {
            if (isApprovedValidatorData(doc.data())) {
              approvedCount++;
            }
          }
          return approvedCount >= 2;
        })
        .handleError((_) => false);
  }

  Future<bool> isValidatorRegistrationDisabled() async {
    try {
      final snapshot = await _users
          .where('role', whereIn: ['VALIDATOR', 'validator'])
          .get();
      int approvedCount = 0;
      for (final doc in snapshot.docs) {
        if (isApprovedValidatorData(doc.data())) {
          approvedCount++;
        }
      }
      return approvedCount >= 2;
    } catch (_) {
      return false;
    }
  }

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
      'has_completed_onboarding': true,
    });
  }

  static bool isDefaultAdmin(Map<String, dynamic>? data, [String? uid]) {
    if (data != null && data['isDefaultAdmin'] == true) return true;
    final effectiveUid = uid ?? data?['uid'] as String?;
    if (effectiveUid == 'Rv82Fsd9b4hhVHmzqjwon89lKgj2') return true;
    final email = data?['email'] as String?;
    if (email == 'amiel@gmail.com') return true;
    return false;
  }

  Stream<UserRole> roleStream(String uid) {
    return _users.doc(uid).snapshots().map((snap) {
      final data = snap.data();
      if (isDefaultAdmin(data, uid)) {
        return UserRole.superadmin;
      }
      return roleFromString(data?['role'] as String?);
    });
  }

  Future<UserRole> getRole(String uid) async {
    final snap = await _users.doc(uid).get();
    final data = snap.data();
    if (isDefaultAdmin(data, uid)) {
      return UserRole.superadmin;
    }
    return roleFromString(data?['role'] as String?);
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
    final docRef = _users.doc(uid);
    final doc = await docRef.get();
    final data = doc.data();
    if (isDefaultAdmin(data, uid)) {
      throw Exception('Cannot modify the role of the default Super Admin.');
    }
    final currentRole = data?['role'];
    
    final updates = <String, dynamic>{'role': roleToString(role)};
    
    if (role == UserRole.educator || role == UserRole.validator) {
      updates['isVerified'] = true;
      updates['status'] = 'ACTIVE';
    }

    if (role == UserRole.educator && currentRole != 'EDUCATOR') {
      updates['educatorStartDate'] = FieldValue.serverTimestamp();
      updates['educatorEndDate'] = null;
      // Newer educators start as unsubscribed until they simulate/complete payment
      if (data?['isExistingEducator'] != true) {
        updates['isExistingEducator'] = false;
        updates['has_educator_subscription'] = false;
        updates['hasEducatorSubscription'] = false;
        updates['educator_subscription_status'] = 'INACTIVE';
        updates['subscription_status'] = 'NONE';
      }
    } else if (currentRole == 'EDUCATOR' && role != UserRole.educator) {
      updates['educatorEndDate'] = FieldValue.serverTimestamp();
    }
    
    await docRef.update(updates);
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

  Future<void> updateBio({required String uid, required String bio}) async {
    await _users.doc(uid).update({'bio': bio});
  }
}

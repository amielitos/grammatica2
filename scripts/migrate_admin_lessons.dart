import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:grammatica/firebase_options.dart';

/// One-time Migration Script to migrate all Admin-uploaded lessons
/// to the "Grammatica Official" folder.
///
/// Updates existing admin lessons to:
/// - `isGrammaticaLesson`: true
/// - `validationStatus`: 'approved'
/// - `isVisible`: true
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final firestore = FirebaseFirestore.instance;
  debugPrint('--- Starting Admin Lessons Migration ---');

  try {
    // 1. Identify all admin/superadmin accounts
    final usersSnap = await firestore.collection('users').get();
    final adminUids = <String>{};
    final adminEmails = <String>{};

    for (final doc in usersSnap.docs) {
      final data = doc.data();
      final role = (data['role'] ?? '').toString().toUpperCase();
      final username = (data['username'] ?? '').toString().toLowerCase();
      final email = (data['email'] ?? '').toString().toLowerCase();

      if (role == 'ADMIN' ||
          role == 'SUPERADMIN' ||
          username.contains('admin') ||
          username.contains('espena') ||
          email.contains('admin')) {
        adminUids.add(doc.id);
        if (email.isNotEmpty) adminEmails.add(email);
        debugPrint('Identified Admin User: ${data['username']} ($email, UID: ${doc.id})');
      }
    }

    debugPrint('Found ${adminUids.length} admin accounts.');

    // 2. Scan lessons collection
    final lessonsSnap = await firestore.collection('lessons').get();
    final batch = firestore.batch();
    int count = 0;

    for (final doc in lessonsSnap.docs) {
      final data = doc.data();
      final creatorUid = (data['createdByUid'] ?? '').toString();
      final creatorEmail = (data['createdByEmail'] ?? '').toString().toLowerCase();
      final isGrammatica = data['isGrammaticaLesson'] == true;

      final isCreatedByAdmin = adminUids.contains(creatorUid) ||
          adminEmails.contains(creatorEmail) ||
          creatorEmail.contains('admin');

      if (isCreatedByAdmin && !isGrammatica) {
        batch.update(doc.reference, {
          'isGrammaticaLesson': true,
          'validationStatus': 'approved',
          'isVisible': true,
        });
        count++;
        debugPrint('Migrating lesson: "${data['title']}" (ID: ${doc.id})');
      }
    }

    if (count > 0) {
      await batch.commit();
      debugPrint('Successfully migrated $count lesson(s) to Grammatica Official!');
    } else {
      debugPrint('No lessons required migration. All admin lessons are already in Grammatica Official.');
    }
  } catch (e, st) {
    debugPrint('Error during migration: $e\n$st');
  }

  debugPrint('--- Migration Complete ---');
}

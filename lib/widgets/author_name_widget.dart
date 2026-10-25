import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthorName extends StatelessWidget {
  final String? uid;
  final String? fallbackEmail;
  final TextStyle? style;
  final String prefix;

  const AuthorName({
    super.key,
    required this.uid,
    this.fallbackEmail,
    this.style,
    this.prefix = 'By: ',
  });

  @override
  Widget build(BuildContext context) {
    if (uid == null || uid!.isEmpty) {
      return Text('$prefix${fallbackEmail ?? 'Unknown'}', style: style);
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return Text('$prefix...', style: style);
        }

        final data = snap.data?.data();
        final firstName = (data?['first_name'] as String?)?.trim() ?? '';
        final lastName = (data?['last_name'] as String?)?.trim() ?? '';
        final fullName = '$firstName $lastName'.trim();
        final username = (data?['username'] as String?)?.trim();
        final displayName = (data?['displayName'] as String?)?.trim();
        final email = data?['email'] as String? ?? fallbackEmail;

        String display = 'Unknown';
        if (fullName.isNotEmpty) {
          display = fullName;
        } else if (displayName != null && displayName.isNotEmpty) {
          display = displayName;
        } else if (username != null &&
            username.isNotEmpty &&
            username != 'Firstname Lastname') {
          display = username;
        } else if (email != null && email.isNotEmpty) {
          display = email;
        }

        return Text('$prefix$display', style: style);
      },
    );
  }
}

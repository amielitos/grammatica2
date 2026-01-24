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
        final username = (data?['username'] as String?)?.trim();
        final email = data?['email'] as String? ?? fallbackEmail;

        // Logic: If username is empty or default, use email.
        final display =
            (username != null &&
                username.isNotEmpty &&
                username != 'Firstname Lastname')
            ? username
            : (email ?? 'Unknown');

        return Text('$prefix$display', style: style);
      },
    );
  }
}

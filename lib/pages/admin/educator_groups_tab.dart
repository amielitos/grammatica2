import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/database_service.dart';
import '../../widgets/glass_card.dart';
import '../../theme/app_colors.dart';

class EducatorGroupsTab extends StatelessWidget {
  final User user;
  const EducatorGroupsTab({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Educator Groups',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontSize: 24,
                  color: AppColors.getTextColor(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'View and manage your subscribers.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.getTextColor(context).withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: DatabaseService.instance.streamEducatorSubscribers(
              user.uid,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryGreen,
                  ),
                );
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final subscribers = snapshot.data ?? [];

              if (subscribers.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.person_3,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No subscribers yet.',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Set your subscription fee in profile to start growing your group!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: subscribers.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final sub = subscribers[index];
                  final photoUrl = sub['photoUrl'] as String?;
                  final username =
                      sub['username'] as String? ??
                      sub['email'] as String? ??
                      'Learner';
                  final email = sub['email'] as String? ?? 'No email';

                  return GlassCard(
                    backgroundColor: AppColors.getCardColor(context),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primaryGreen.withValues(
                          alpha: 0.1,
                        ),
                        backgroundImage:
                            (photoUrl != null && photoUrl.isNotEmpty)
                            ? NetworkImage(photoUrl)
                            : null,
                        child: (photoUrl == null || photoUrl.isEmpty)
                            ? const Icon(
                                CupertinoIcons.person_fill,
                                color: AppColors.primaryGreen,
                              )
                            : null,
                      ),
                      title: Text(
                        username,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.getTextColor(context),
                        ),
                      ),
                      subtitle: Text(
                        email,
                        style: TextStyle(
                          color: AppColors.getTextColor(
                            context,
                          ).withValues(alpha: 0.7),
                        ),
                      ),
                      trailing: const Icon(
                        CupertinoIcons.checkmark_seal_fill,
                        color: Colors.green,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

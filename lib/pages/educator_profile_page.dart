import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import '../widgets/glass_card.dart';
import '../theme/app_colors.dart';
import 'lesson_page.dart';
import 'quiz_detail_page.dart';

class EducatorProfilePage extends StatelessWidget {
  final Map<String, dynamic> educator;
  final User currentUser;

  const EducatorProfilePage({
    super.key,
    required this.educator,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    final photoUrl = educator['photoUrl'] as String?;
    final username = educator['username'] as String? ?? 'Educator';
    final bio = educator['bio'] as String? ?? 'No bio description provided.';
    final uid = educator['uid'] as String;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryGreen.withValues(alpha: 0.1),
              Colors.blue.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Header
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey.withValues(alpha: 0.2),
                        backgroundImage:
                            (photoUrl != null && photoUrl.isNotEmpty)
                            ? NetworkImage(photoUrl)
                            : null,
                        child: (photoUrl == null || photoUrl.isEmpty)
                            ? const Icon(CupertinoIcons.person_fill, size: 60)
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        username,
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 28,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          bio,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey[600], height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Subscribe Button
                Center(
                  child: StreamBuilder<bool>(
                    stream: DatabaseService.instance.isSubscribedStream(uid),
                    builder: (context, subSnap) {
                      final isSubscribed = subSnap.data ?? false;
                      final fee = educator['subscription_fee'] ?? 3;

                      if (isSubscribed) {
                        return OutlinedButton.icon(
                          onPressed: () => DatabaseService.instance
                              .unsubscribeFromEducator(uid),
                          icon: const Icon(
                            CupertinoIcons.checkmark_seal_fill,
                            color: Colors.green,
                          ),
                          label: const Text('Subscribed - Cancel'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        );
                      } else {
                        return FilledButton.icon(
                          onPressed: () =>
                              DatabaseService.instance.subscribeToEducator(uid),
                          icon: const Icon(CupertinoIcons.creditcard),
                          label: Text('Subscribe for \$$fee/mo'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(height: 40),

                Text(
                  'Public Content',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                // Lessons Section
                _ContentSection(
                  title: 'Lessons',
                  stream: DatabaseService.instance.streamEducatorLessons(
                    uid,
                    publicOnly: true,
                  ),
                  itemBuilder: (context, lesson) {
                    return GlassCard(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                LessonPage(user: currentUser, lesson: lesson),
                          ),
                        );
                      },
                      child: ListTile(
                        leading: const Icon(
                          CupertinoIcons.book,
                          color: Colors.blue,
                        ),
                        title: Text(lesson.title),
                        subtitle: Text(
                          lesson.prompt,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(
                          CupertinoIcons.chevron_right,
                          size: 16,
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Quizzes Section
                _ContentSection(
                  title: 'Quizzes',
                  stream: DatabaseService.instance.streamEducatorQuizzes(
                    uid,
                    publicOnly: true,
                  ),
                  itemBuilder: (context, quiz) {
                    return GlassCard(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                QuizDetailPage(user: currentUser, quiz: quiz),
                          ),
                        );
                      },
                      child: ListTile(
                        leading: const Icon(
                          CupertinoIcons.question_circle,
                          color: Colors.teal,
                        ),
                        title: Text(quiz.title),
                        subtitle: Text(
                          quiz.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(
                          CupertinoIcons.chevron_right,
                          size: 16,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContentSection<T> extends StatelessWidget {
  final String title;
  final Stream<List<T>> stream;
  final Widget Function(BuildContext, T) itemBuilder;

  const _ContentSection({
    required this.title,
    required this.stream,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.grey[700],
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<T>>(
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(
                    color: AppColors.primaryGreen,
                  ),
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No public ${title.toLowerCase()} available.',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              );
            }
            final items = snapshot.data!;
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  itemBuilder(context, items[index]),
            );
          },
        ),
      ],
    );
  }
}


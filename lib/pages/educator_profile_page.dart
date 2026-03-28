import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/database_service.dart';
import '../pages/lesson_page.dart';
import '../widgets/subscription_tier_dialog.dart';
import '../theme/app_colors.dart';
import '../widgets/design_ornaments.dart';
import '../main.dart';

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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          username,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: BackgroundWrapper(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Header Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                              ? NetworkImage(photoUrl)
                              : null,
                          child: (photoUrl == null || photoUrl.isEmpty)
                              ? const Icon(Icons.person_rounded, size: 50, color: AppColors.primary)
                              : null,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          username,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          bio,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            height: 1.5,
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 24),
                        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(uid)
                              .snapshots(),
                          builder: (context, snapshot) {
                            final data = snapshot.data?.data() ?? educator;
                            final avgRating = (data['averageRating'] ?? 0.0).toDouble();
                            final reviewCount = data['reviewCount'] ?? 0;

                            return StreamBuilder<Map<String, int>>(
                              stream: DatabaseService.instance.getTieredSubscriberCounts(uid),
                              builder: (context, subSnapshot) {
                                final counts = subSnapshot.data ??
                                    {'Basic': 0, 'Standard': 0, 'Premium': 0};
                                return Container(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    color: AppColors.backgroundBase.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildStatColumn('Viewers', '${counts['Basic']}'),
                                      _buildStatColumn('Subs', '${counts['Standard']}'),
                                      _buildStatColumn('Mentors', '${counts['Premium']}'),
                                      _buildStatColumn(
                                        'Rating',
                                        avgRating.toStringAsFixed(1),
                                        icon: Icons.star_rounded,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        // Actions Row
                        StreamBuilder<bool>(
                          stream: DatabaseService.instance.isSubscribedStream(uid),
                          builder: (context, subSnap) {
                            final isSubscribed = subSnap.data ?? false;
                            return Row(
                              children: [
                                Expanded(
                                  child: isSubscribed
                                      ? ElevatedButton.icon(
                                          onPressed: () =>
                                              DatabaseService.instance.unsubscribeFromEducator(uid),
                                          icon: const Icon(Icons.check_circle_rounded),
                                          label: const Text('Subscribed'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary.withOpacity(0.1),
                                            foregroundColor: AppColors.primary,
                                            elevation: 0,
                                          ),
                                        )
                                      : ElevatedButton(
                                          onPressed: () async {
                                            final tier = await showDialog<String>(
                                              context: context,
                                              builder: (context) => SubscriptionTierDialog(
                                                pricing: educator['subscription_pricing'],
                                                educatorName: educator['username'] ?? 'Educator',
                                              ),
                                            );

                                            if (tier != null) {
                                              await DatabaseService.instance
                                                  .subscribeToEducator(uid, tier);
                                            }
                                          },
                                          child: const Text('Subscribe'),
                                        ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: isSubscribed
                                        ? () => _showReviewDialog(context, uid)
                                        : () {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Subscribe to leave a review'),
                                              ),
                                            );
                                          },
                                    icon: Icon(
                                      Icons.rate_review_rounded,
                                      size: 20,
                                      color: isSubscribed
                                          ? AppColors.primary
                                          : AppColors.textSecondary.withOpacity(0.5),
                                    ),
                                    label: Text(
                                      'Review',
                                      style: TextStyle(
                                        color: isSubscribed
                                            ? AppColors.textPrimary
                                            : AppColors.textSecondary.withOpacity(0.5),
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: isSubscribed
                                            ? AppColors.primary.withOpacity(0.5)
                                            : AppColors.divider,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Public Content',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 16),
                // Lessons Section
                _ContentSection(
                  title: 'Lessons',
                  stream: DatabaseService.instance.streamEducatorLessons(
                    uid,
                    publicOnly: true,
                  ),
                  itemBuilder: (context, lesson) {
                    return Card(
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LessonPage(user: currentUser, lesson: lesson),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(24),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.book_rounded, color: AppColors.primary, size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      lesson.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      lesson.prompt,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40),
                Text(
                  'Reviews',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 16),
                StreamBuilder<List<Review>>(
                  stream: DatabaseService.instance.streamReviews(uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final reviews = snapshot.data ?? [];
                    if (reviews.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            'No reviews yet.',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: reviews.length,
                      separatorBuilder: (c, i) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final review = reviews[index];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.secondary.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.person_rounded, size: 20, color: AppColors.secondary),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        review.reviewerName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: List.generate(5, (i) {
                                        return Icon(
                                          i < review.rating
                                              ? Icons.star_rounded
                                              : Icons.star_outline_rounded,
                                          size: 16,
                                          color: AppColors.accent,
                                        );
                                      }),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  review.comment,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    height: 1.4,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, {IconData? icon}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: AppColors.accent),
              const SizedBox(width: 4),
            ],
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  void _showReviewDialog(BuildContext context, String educatorUid) {
    double selectedRating = 5.0;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text(
            'Leave a Review',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    onPressed: () => setDialogState(() => selectedRating = index + 1.0),
                    icon: Icon(
                      index < selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: AppColors.accent,
                      size: 36,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                decoration: InputDecoration(
                  hintText: 'Share your thoughts...',
                  filled: true,
                  fillColor: AppColors.backgroundBase,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.all(16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final review = Review(
                  id: '',
                  reviewerUid: currentUser.uid,
                  reviewerName: currentUser.displayName ?? 'Learner',
                  rating: selectedRating,
                  comment: commentController.text,
                );
                await DatabaseService.instance.addReview(educatorUid, review);
                if (context.mounted) Navigator.pop(context);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Review submitted!')),
                  );
                }
              },
              child: const Text('Submit'),
            ),
          ],
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
    return StreamBuilder<List<T>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No public ${title.toLowerCase()} available.',
              style: const TextStyle(
                color: AppColors.textSecondary,
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
          itemBuilder: (context, index) => itemBuilder(context, items[index]),
        );
      },
    );
  }
}

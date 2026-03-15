import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:grammatica/services/database_service.dart';
import 'package:grammatica/widgets/subscription_tier_dialog.dart';
import 'lesson_page.dart';

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
      appBar: AppBar(title: Text(username)),
      body: SafeArea(
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
                      backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                          ? NetworkImage(photoUrl)
                          : null,
                      child: (photoUrl == null || photoUrl.isEmpty)
                          ? const Icon(Icons.person, size: 60)
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      username,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        bio,
                        textAlign: TextAlign.center,
                        style: const TextStyle(height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        final data = snapshot.data?.data() ?? educator;
                        final avgRating = (data['averageRating'] ?? 0.0)
                            .toDouble();
                        final reviewCount = data['reviewCount'] ?? 0;

                        return Column(
                          children: [
                            StreamBuilder<Map<String, int>>(
                              stream: DatabaseService.instance
                                  .getTieredSubscriberCounts(uid),
                              builder: (context, subSnapshot) {
                                final counts =
                                    subSnapshot.data ??
                                    {'Basic': 0, 'Standard': 0, 'Premium': 0};
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildStatColumn(
                                        '${counts['Basic']}',
                                        'Viewers',
                                      ),
                                      _buildStatColumn(
                                        '${counts['Standard']}',
                                        'Subscribers',
                                      ),
                                      _buildStatColumn(
                                        '${counts['Premium']}',
                                        'Mentored',
                                      ),
                                      _buildStatColumn(
                                        avgRating.toStringAsFixed(1),
                                        'Rating ($reviewCount)',
                                        icon: Icons.star,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Subscribe & Review Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  StreamBuilder<bool>(
                    stream: DatabaseService.instance.isSubscribedStream(uid),
                    builder: (context, subSnap) {
                      final isSubscribed = subSnap.data ?? false;
                      return Row(
                        children: [
                          if (isSubscribed)
                            OutlinedButton.icon(
                              onPressed: () => DatabaseService.instance
                                  .unsubscribeFromEducator(uid),
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Subscribed'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.error,
                              ),
                            )
                          else
                            ElevatedButton(
                              onPressed: () async {
                                final tier = await showDialog<String>(
                                  context: context,
                                  builder: (context) => SubscriptionTierDialog(
                                    pricing: educator['subscription_pricing'],
                                    educatorName:
                                        educator['username'] ?? 'Educator',
                                  ),
                                );

                                if (tier != null) {
                                  await DatabaseService.instance
                                      .subscribeToEducator(uid, tier);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.onPrimary,
                              ),
                              child: const Text('Subscribe'),
                            ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: isSubscribed
                                ? () => _showReviewDialog(context, uid)
                                : () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Subscribe to leave a review',
                                        ),
                                      ),
                                    );
                                  },
                            icon: Icon(
                              Icons.rate_review_outlined,
                              color: isSubscribed
                                  ? null
                                  : Theme.of(context).colorScheme.onSurface
                                        .withValues(alpha: 0.38),
                            ),
                            label: Text(
                              'Review',
                              style: TextStyle(
                                color: isSubscribed
                                    ? null
                                    : Theme.of(context).colorScheme.onSurface
                                          .withValues(alpha: 0.38),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
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
                  return Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
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
                        leading: const Icon(Icons.book),
                        title: Text(lesson.title),
                        subtitle: Text(
                          lesson.prompt,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 16),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),
              const SizedBox(height: 40),
              Text(
                'Reviews',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
                    return const Text(
                      'No reviews yet.',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: reviews.length,
                    itemBuilder: (context, index) {
                      final review = reviews[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Row(
                            children: [
                              Text(
                                review.reviewerName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Row(
                                children: List.generate(5, (i) {
                                  return Icon(
                                    i < review.rating
                                        ? Icons.star
                                        : Icons.star_border,
                                    size: 16,
                                    color: Colors.amber,
                                  );
                                }),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(review.comment),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String value, String label, {IconData? icon}) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: Colors.amber),
              const SizedBox(width: 4),
            ],
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
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
          title: const Text('Leave a Review'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    onPressed: () =>
                        setDialogState(() => selectedRating = index + 1.0),
                    icon: Icon(
                      index < selectedRating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                decoration: const InputDecoration(
                  hintText: 'Write your comment here...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final review = Review(
                  id: '', // Will be set by reviewerUid in addReview
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<T>>(
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

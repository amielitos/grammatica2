import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/database_service.dart';
import '../pages/lesson_page.dart';
import '../widgets/subscription_tier_dialog.dart';
import '../widgets/paymongo_qr_dialog.dart';

import '../widgets/design_ornaments.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/notification_widgets.dart';


class EducatorProfilePage extends StatefulWidget {
  final Map<String, dynamic> educator;
  final User currentUser;

  const EducatorProfilePage({
    super.key,
    required this.educator,
    required this.currentUser,
  });

  @override
  State<EducatorProfilePage> createState() => _EducatorProfilePageState();
}

class _EducatorProfilePageState extends State<EducatorProfilePage> {
  int? _starFilter; // null means "All Ratings"

  @override
  Widget build(BuildContext context) {
    final photoUrl = widget.educator['photoUrl'] as String?;
    final username = widget.educator['username'] as String? ?? 'Educator';
    final bio = widget.educator['bio'] as String? ?? 'Bio Description';
    final uid = widget.educator['uid'] as String;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: CustomAppBar(
        user: widget.currentUser,
        onNotificationTap: () {
          showDialog(
            context: context,
            barrierColor: Colors.transparent,
            builder: (context) => NotificationsDialog(userId: widget.currentUser.uid),
          );
        },
      ),
      body: BackgroundWrapper(
        imageAssetPath: 'assets/subscriptionbg.png',
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800; // Determine if it's wide screen layout

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 100, 24, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Back to Subscription Button
                        TextButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios, size: 16, color: Colors.black54),
                          label: const Text('Back to Subscription', style: TextStyle(color: Colors.black54)),
                        ),
                        const SizedBox(height: 16),

                        // Profile Header Card
                        Container(
                          padding: const EdgeInsets.all(32.0),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, 5))
                            ],
                            border: Border.all(color: Colors.black87, width: 1.0),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 40,
                                    backgroundColor: Colors.grey.shade300,
                                    backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
                                    child: (photoUrl == null || photoUrl.isEmpty) ? const Icon(Icons.person, size: 40, color: Colors.grey) : null,
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          username,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.black87),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          bio,
                                          style: const TextStyle(color: Colors.black54, fontSize: 16),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),
                              
                              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                                stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
                                builder: (context, snapshot) {
                                  final data = snapshot.data?.data() ?? widget.educator;
                                  final avgRating = (data['averageRating'] ?? 0.0).toDouble();

                                  return StreamBuilder<Map<String, int>>(
                                    stream: DatabaseService.instance.getTieredSubscriberCounts(uid),
                                    builder: (context, subSnapshot) {
                                      final counts = subSnapshot.data ?? {'Basic': 0, 'Standard': 0, 'Premium': 0};
                                      List<Widget> stats = [
                                        _buildStatColumn('Viewers', '${counts['Basic']}', Icons.remove_red_eye_outlined, const Color(0xFF81B655)),
                                        _buildStatColumn('Subscribers', '${counts['Standard']}', Icons.people, const Color(0xFF81B655)),
                                        _buildStatColumn('Mentors', '${counts['Premium']}', Icons.school, const Color(0xFF81B655)),
                                        _buildStatColumn('Rating', avgRating.toStringAsFixed(1), Icons.star, Colors.amber, suffix: ' out of 5'),
                                      ];

                                      return isWide ? Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: stats.map((w) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 16.0), child: w))).toList(),
                                      ) : Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: stats.map((w) => Padding(padding: const EdgeInsets.only(bottom: 16.0), child: w)).toList(),
                                      );
                                    },
                                  );
                                },
                              ),
                              const SizedBox(height: 32),
                              
                              // Actions Row
                              StreamBuilder<bool>(
                                stream: DatabaseService.instance.isSubscribedStream(uid),
                                builder: (context, subSnap) {
                                  final isSubscribed = subSnap.data ?? false;
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: SizedBox(
                                          height: 50,
                                          child: ElevatedButton.icon(
                                            onPressed: isSubscribed ? () => DatabaseService.instance.unsubscribeFromEducator(uid) : () async {
                                              final tier = await showDialog<String>(
                                                context: context,
                                                builder: (context) => SubscriptionTierDialog(pricing: widget.educator['subscription_pricing'], educatorName: username),
                                              );
                                              if (tier != null) {
                                                if (tier == 'Basic') {
                                                  await DatabaseService.instance.subscribeToEducator(uid, tier);
                                                  if (context.mounted) {
                                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Successfully subscribed to Free Tier.')));
                                                  }
                                                } else {
                                                  final pricingData = widget.educator['subscription_pricing'] ?? {};
                                                  double amountInUSD = tier == 'Standard' 
                                                      ? (pricingData['standard']?.toDouble() ?? 3.0) 
                                                      : (pricingData['premium']?.toDouble() ?? 7.0);
                                                  double amountInPhp = amountInUSD * 56.0; // Conversion for QR PH demo
                                                
                                                  if (!context.mounted) return;
                                                  final success = await showDialog<bool>(
                                                    context: context,
                                                    barrierDismissible: false,
                                                    builder: (context) => PaymongoQrDialog(
                                                      tier: tier, 
                                                      amount: amountInPhp, 
                                                      educatorName: username,
                                                    ),
                                                  );
                                                  
                                                  if (success == true) {
                                                    await DatabaseService.instance.subscribeToEducator(uid, tier);
                                                    if (context.mounted) {
                                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment Successful! You are now subscribed to $tier.')));
                                                    }
                                                  }
                                                }
                                              }
                                            },
                                            icon: Icon(isSubscribed ? Icons.check : Icons.add),
                                            label: Text(isSubscribed ? 'Subscribed' : 'Subscribe'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isSubscribed ? Colors.grey : const Color(0xFF81B655),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              elevation: 0,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: SizedBox(
                                          height: 50,
                                          child: OutlinedButton.icon(
                                            onPressed: isSubscribed ? () => _showReviewDialog(context, uid) : () {
                                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subscribe to leave a review')));
                                            },
                                            icon: const Icon(Icons.edit_outlined),
                                            label: const Text('Write a Review'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.black87,
                                              side: const BorderSide(color: Colors.black87),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                        const SizedBox(height: 24),

                        // Bottom Section
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildPublicContentCard(uid, widget.currentUser)),
                              const SizedBox(width: 24),
                              Expanded(child: _buildReviewsCard(uid)),
                            ],
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildPublicContentCard(uid, widget.currentUser),
                              const SizedBox(height: 24),
                              _buildReviewsCard(uid),
                            ],
                          ),
                          const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              );
            }
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, IconData icon, Color iconColor, {String? suffix}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFEEEEEE),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 24, color: iconColor),
              const SizedBox(width: 8),
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87))),
            ],
          ),
          const SizedBox(height: 12),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: value, style: const TextStyle(fontSize: 24, color: Colors.black87)),
                if (suffix != null)
                  TextSpan(text: suffix, style: const TextStyle(fontSize: 16, color: Colors.black54)),
              ]
            )
          ),
        ],
      ),
    );
  }

  Widget _buildPublicContentCard(String uid, User currentUser) {
    return _buildBottomCard(
      title: 'Public Content',
      child: StreamBuilder<List<Lesson>>(
        stream: DatabaseService.instance.streamEducatorLessons(uid, publicOnly: true),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final lessons = snapshot.data ?? [];
          if (lessons.isEmpty) {
            return Row(
              children: [
                const Icon(Icons.menu_book_outlined, color: Color(0xFF81B655), size: 32),
                const SizedBox(width: 12),
                const Expanded(child: Text('No lessons yet. Check back soon.', style: TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.bold))),
              ],
            );
          }
          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: lessons.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final lesson = lessons[index];
              return ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
                leading: const Icon(Icons.book_rounded, color: Color(0xFF81B655)),
                title: Text(lesson.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(lesson.prompt, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LessonPage(user: currentUser, lesson: lesson))),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildReviewsCard(String uid) {
    return _buildBottomCard(
      title: 'Reviews',
      child: StreamBuilder<List<Review>>(
        stream: DatabaseService.instance.streamReviews(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final allReviews = snapshot.data ?? [];
          final reviews = _starFilter == null 
              ? allReviews 
              : allReviews.where((r) => r.rating.toInt() == _starFilter).toList();

          if (reviews.isEmpty) {
            return Column(
              children: [
                _buildFilterDropdown(),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 32),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_starFilter == null ? 'No reviews yet.' : 'No $_starFilter star reviews yet.', style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.bold))),
                  ],
                ),
              ],
            );
          }
          return Column(
            children: [
              _buildFilterDropdown(),
              const SizedBox(height: 16),
              ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: reviews.length,
            separatorBuilder: (c, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final review = reviews[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.grey.shade200,
                          child: const Icon(Icons.person, size: 16, color: Colors.grey),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                review.reviewerName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                              ),
                              if (review.createdAt != null)
                                Text(
                                  _formatDate(review.createdAt!),
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                            ],
                          ),
                        ),
                        Row(
                          children: List.generate(
                            5,
                            (i) => Icon(
                              i < review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                              size: 18,
                              color: Colors.amber,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      review.comment,
                      style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.4),
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
);
}

  Widget _buildFilterDropdown() {
    return Row(
      children: [
        const Icon(Icons.filter_list_rounded, size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        const Text('Sort by:', style: TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: _starFilter,
              hint: const Text('All Ratings'),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
              style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500),
              onChanged: (val) => setState(() => _starFilter = val),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Ratings')),
                const DropdownMenuItem(value: 5, child: Text('5 Stars')),
                const DropdownMenuItem(value: 4, child: Text('4 Stars')),
                const DropdownMenuItem(value: 3, child: Text('3 Stars')),
                const DropdownMenuItem(value: 2, child: Text('2 Stars')),
                const DropdownMenuItem(value: 1, child: Text('1 Star')),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(Timestamp ts) {
    final d = ts.toDate();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  Widget _buildBottomCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black87, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  void _showReviewDialog(BuildContext context, String educatorUid) {
    double selectedRating = 0.0;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: const Color(0xFFF6F3EC),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
            side: const BorderSide(color: Colors.black, width: 1.0),
          ),
          child: Container(
            width: 440, // Limits the dialog so it doesn't take up the whole screen
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                const Text(
                  'Leave a Review',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w400,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Rating:',
                      style: TextStyle(fontSize: 18, color: Colors.black87),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (index) {
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedRating = index + 1.0),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: Icon(
                              index < selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: index < selectedRating ? Colors.amber : Colors.black87,
                              size: 40,
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: commentController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Share your thoughts...',
                    hintStyle: const TextStyle(color: Colors.black38),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(16),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.black54, width: 1.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.black87, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 120, // Equal width for Cancel button
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF7CB342), width: 1.0),
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                          foregroundColor: const Color(0xFF7CB342),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 120, // Equal width for Submit button
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () async {
                          final review = Review(id: '', reviewerUid: widget.currentUser.uid, reviewerName: widget.currentUser.displayName ?? 'Learner', rating: selectedRating, comment: commentController.text);
                          await DatabaseService.instance.addReview(educatorUid, review);
                          if (context.mounted) Navigator.pop(context);
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Review submitted!')));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7CB342),
                          foregroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                          elevation: 0,
                        ),
                        child: const Text('Submit', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

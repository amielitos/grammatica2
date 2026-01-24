import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'quizzes_page.dart';
import 'lesson_folder_page.dart';
import 'profile_page.dart';
import '../widgets/glass_card.dart';
import '../widgets/responsive_wrapper.dart';
import '../widgets/modern_bottom_nav.dart';
import '../services/role_service.dart';
import 'browse_educators_tab.dart';
import 'practice_tab.dart';

class HomePage extends StatefulWidget {
  final User user;
  const HomePage({super.key, required this.user});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tabIndex =
      0; // 0=Lessons, 1=Practice, 2=Quizzes, 3=Subscription, 4=Profile
  final _profileKey = GlobalKey<ProfilePageState>();

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Grammatica',
          style: Theme.of(
            context,
          ).textTheme.displayLarge?.copyWith(fontSize: 28),
        ),
      ),
      bottomNavigationBar: ModernBottomNav(
        currentIndex: _tabIndex,
        onTap: (index) {
          setState(() => _tabIndex = index);
          if (index == 4) {
            _profileKey.currentState?.fetchProfile();
          }
        },
        items: [
          const ModernNavItem(icon: CupertinoIcons.book, label: 'Lessons'),
          ModernNavItem(
            icon: CupertinoIcons.sparkles,
            label: 'Practice',
            selectedColor: Colors.orange.shade400,
          ),
          const ModernNavItem(
            icon: CupertinoIcons.question_circle,
            label: 'Quizzes',
          ),
          const ModernNavItem(
            icon: CupertinoIcons.creditcard,
            label: 'Subscription',
          ),
          ModernNavItem(
            icon: CupertinoIcons.person,
            label: user.displayName?.split(' ').first ?? 'Profile',
          ),
        ],
      ),
      body: ResponsiveWrapper(
        child: IndexedStack(
          index: _tabIndex,
          children: [
            _LessonsList(user: user),
            const PracticeTab(),
            QuizzesPage(user: user),
            BrowseEducatorsTab(user: user),
            ProfilePage(key: _profileKey, user: user),
          ],
        ),
      ),
    );
  }
}

class _LessonsList extends StatelessWidget {
  const _LessonsList({required this.user});
  final User user;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserRole>(
      stream: RoleService.instance.roleStream(user.uid),
      builder: (context, roleSnapshot) {
        final role = roleSnapshot.data;

        return StreamBuilder<List<Lesson>>(
          stream: DatabaseService.instance.streamLessons(
            userRole: role,
            userId: user.uid,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No lessons available.'));
            }
            final lessons = snapshot.data!;

            return StreamBuilder<Map<String, dynamic>>(
              stream: DatabaseService.instance
                  .streamLearnerSubscriptions(user.uid)
                  .map(
                    (subs) => {
                      for (var s in subs)
                        s['educatorUid']: s['status'] == 'active',
                    },
                  ),
              builder: (context, subsSnap) {
                final subscriptions = subsSnap.data ?? const {};

                // 1. Grammatica Lessons
                final grammaticaLessons = lessons
                    .where((l) => l.isGrammaticaLesson == true)
                    .toList();

                // 2. Subscribed Educator Lessons (grouped)
                final subscribedLessons = <String, List<Lesson>>{};
                for (var l in lessons) {
                  if (l.isGrammaticaLesson) continue; // Already handled
                  if (subscriptions[l.createdByUid] == true) {
                    // Include if not hidden members only (though if subscribed, they should see all)
                    // The streamSchools already filters visibility based on role/subscription,
                    // but let's be safe.
                    subscribedLessons
                        .putIfAbsent(l.createdByUid ?? 'Unknown', () => [])
                        .add(l);
                  }
                }

                // 3. Public Content
                final publicLessons = lessons.where((l) {
                  if (l.isGrammaticaLesson) return false;
                  if (subscriptions[l.createdByUid] == true)
                    return false; // Already in subscribed
                  if (l.createdByUid == user.uid)
                    return false; // Own lessons don't go to public folder (maybe separate tab?)
                  // Logic for "Public Content": content available publicly.
                  // Stream already filters for validationStatus != awaiting_approval
                  // and isVisible or visibleTo contains userId.

                  // Filter out members only content if not subscribed?
                  // But we want to show the folder?
                  // The prompt says: "DO NOT show the folder if the content is members only."
                  // So we only include lessons that are NOT members only here if not subscribed.
                  if (l.isMembersOnly) return false;

                  return true;
                }).toList();

                // If admin/educator, they might see their own lessons.
                // Let's decide where own lessons go. Maybe "Public" for now or ignored as this view is for consuming content.
                // The current implementation hides own lessons from public folder above.

                final List<Widget> folderCards = [];

                // Grammatica Folder
                if (grammaticaLessons.isNotEmpty) {
                  folderCards.add(
                    _buildFolderCard(
                      context,
                      title: 'Grammatica',
                      description: 'Official lessons from the team',
                      pillLabel: 'From Grammatica',
                      pillColor: Colors.purple,
                      iconColor: Colors.purpleAccent,
                      onTap: () => _openFolder(
                        context,
                        title: 'Grammatica Lessons',
                        pillLabel: 'From Grammatica',
                        lessons: grammaticaLessons,
                      ),
                    ),
                  );
                }

                // Subscribed Educators Folders
                subscribedLessons.forEach((uid, educatorLessons) {
                  // We need author name. We can fetch it or pass unknown.
                  // Since we're inside a stream, fetching for each might be expensive if many.
                  // Use a widget that fetches name.
                  if (educatorLessons.isNotEmpty) {
                    folderCards.add(
                      _buildFolderCardWithAuthor(
                        context,
                        uid: uid,
                        fallbackEmail: educatorLessons.first.createdByEmail,
                        description: 'Content from this educator',
                        pillLabel: 'Educator',
                        pillColor: Colors.green,
                        iconColor: Colors.greenAccent,
                        onTap: () => _openFolder(
                          context,
                          title:
                              'Educator Lessons', // Will be updated by author name ideally
                          pillLabel: 'From your Educator',
                          lessons: educatorLessons,
                        ),
                      ),
                    );
                  }
                });

                // Public Content Folder
                if (publicLessons.isNotEmpty) {
                  folderCards.add(
                    _buildFolderCard(
                      context,
                      title: 'Public',
                      description: 'Community lessons',
                      pillLabel: 'Public',
                      pillColor: Colors.blue,
                      iconColor: Colors.lightBlueAccent,
                      onTap: () => _openFolder(
                        context,
                        title: 'Public Content',
                        pillLabel: 'Public',
                        lessons: publicLessons,
                        isPublicFolder: true,
                      ),
                    ),
                  );
                }

                if (folderCards.isEmpty) {
                  return const Center(child: Text('No lessons available.'));
                }

                return GridView.count(
                  padding: const EdgeInsets.all(16),
                  crossAxisCount: 3,
                  childAspectRatio: 0.75, // Adjust for new width
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  children: folderCards,
                );
              },
            );
          },
        );
      },
    );
  }

  void _openFolder(
    BuildContext context, {
    required String title,
    required String pillLabel,
    required List<Lesson> lessons,
    bool isPublicFolder = false,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LessonFolderPage(
          user: user,
          title: title,
          pillLabel: pillLabel,
          lessons: lessons,
          isPublicContentFolder: isPublicFolder,
        ),
      ),
    );
  }

  Widget _buildFolderCard(
    BuildContext context, {
    required String title,
    required String description,
    required String pillLabel,
    required Color pillColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(10.0), // Reduced padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                CupertinoIcons.folder_solid,
                size: 32,
                color: iconColor,
              ), // Smaller icon, dynamic color
              const Spacer(),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontSize: 10),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: pillColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: pillColor.withOpacity(0.5)),
                ),
                child: Text(
                  pillLabel,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: pillColor.withOpacity(1.0), // Ensure text is visible
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFolderCardWithAuthor(
    BuildContext context, {
    required String uid,
    required String? fallbackEmail,
    required String description,
    required String pillLabel,
    required Color pillColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(CupertinoIcons.folder_solid, size: 32, color: iconColor),
              const Spacer(),
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .snapshots(),
                builder: (context, snap) {
                  final data = snap.data?.data();
                  final username = (data?['username'] as String?)?.trim();
                  final display = (username != null && username.isNotEmpty)
                      ? username
                      : (fallbackEmail ?? 'Unknown');
                  return Text(
                    display,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                },
              ),
              const SizedBox(height: 2),
              Text(
                description, // "Check out content made by this educator!"
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontSize: 10),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: pillColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: pillColor.withOpacity(0.5)),
                ),
                child: Text(
                  pillLabel,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: pillColor.withOpacity(1.0),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

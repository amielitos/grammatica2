import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';

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
  final bool showProfileWarning;
  const HomePage({
    super.key,
    required this.user,
    this.showProfileWarning = false,
  });

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
          const ModernNavItem(icon: Icons.book, label: 'Lessons'),
          ModernNavItem(
            icon: Icons.auto_awesome,
            label: 'Practice',
            selectedColor: Colors.orange.shade400,
          ),
          const ModernNavItem(icon: Icons.help_outline, label: 'Quizzes'),
          const ModernNavItem(icon: Icons.credit_card, label: 'Subscription'),
          ModernNavItem(
            icon: Icons.person,
            label: user.displayName?.split(' ').first ?? 'Profile',
          ),
        ],
        showProfileWarning: widget.showProfileWarning,
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

                // 2. Subscribed Educator Lessons (Members Only)
                final subscribedLessons = lessons.where((l) {
                  if (l.isGrammaticaLesson) return false;
                  // Only include if subscribed AND members only?
                  // User said: "Educator ... > Content from educators that are 'members only'"
                  // So if subscription is active, include ONLY if isMembersOnly (or maybe all content from them?)
                  // "Content from educators that are 'members only'" implies filtering for membersOnly flag.
                  if (subscriptions[l.createdByUid] == true &&
                      l.isMembersOnly) {
                    return true;
                  }
                  return false;
                }).toList();

                // 3. Public Content
                final publicLessons = lessons.where((l) {
                  if (l.isGrammaticaLesson) return false;
                  // Public content logic:
                  // "Content from educators / admins that are available publicly"
                  // So anything NOT members only.
                  if (l.isMembersOnly) return false;
                  // Even if subscribed, if it's public, it arguably goes to public folder?
                  // Or should subscribed folder have ALL subscribed content?
                  // User said: "Public > Content from educators / admins that are available publicly".
                  // This implies Public folder gets ALL public content.
                  if (!l.isVisible) return false;
                  return true;
                }).toList();

                final List<Widget> folderCards = [];

                // Grammatica Folder
                if (grammaticaLessons.isNotEmpty) {
                  folderCards.add(
                    _buildFolderCard(
                      context,
                      title: 'Grammatica',
                      description: 'Official lessons',
                      pillLabel: 'Grammatica',
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

                // Your Educators Folder (Groups Subscribed Content)
                if (subscribedLessons.isNotEmpty) {
                  folderCards.add(
                    _buildFolderCard(
                      context,
                      title: 'Your Educators',
                      description: 'Members-only content',
                      pillLabel: 'Subscribed',
                      pillColor: Colors.green,
                      iconColor: Colors.greenAccent,
                      onTap: () => _openFolder(
                        context,
                        title: 'Your Educators',
                        pillLabel: 'Members Only',
                        lessons: subscribedLessons,
                        isPublicFolder: true, // Use nesting logic
                      ),
                    ),
                  );
                }

                // Public Folder
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

                return LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight:
                              constraints.maxHeight - 32, // Adjust for padding
                        ),
                        child: Center(
                          child: Wrap(
                            spacing: 16, // Increased spacing
                            runSpacing: 16,
                            alignment: WrapAlignment.center,
                            children: folderCards
                                .map(
                                  (w) => SizedBox(
                                    width: 234, // 50% Bigger card width
                                    height: 324, // 50% Bigger card height
                                    child: w,
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    );
                  },
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
          padding: const EdgeInsets.all(12.0), // Increased padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.folder,
                size: 42, // Increased icon size
                color: iconColor,
              ),
              const Spacer(),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: pillColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: pillColor.withOpacity(0.5)),
                ),
                child: Text(
                  pillLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
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

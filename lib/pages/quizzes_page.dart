import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'quiz_detail_page.dart';
import '../widgets/glass_card.dart';
import '../services/role_service.dart';
import '../theme/app_colors.dart';

class QuizzesPage extends StatefulWidget {
  final User user;
  const QuizzesPage({super.key, required this.user});

  @override
  State<QuizzesPage> createState() => _QuizzesPageState();
}

class _QuizzesPageState extends State<QuizzesPage> {
  final _searchCtrl = TextEditingController();
  Map<String, String> _usernames = {}; // uid -> username

  @override
  void initState() {
    super.initState();
    _fetchUsernames();
    // Removed listener to prevent rebuild on every keystroke
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchUsernames() async {
    try {
      final users = await DatabaseService.instance.fetchUsers();
      if (mounted) {
        setState(() {
          _usernames = {
            for (var u in users) u['uid'] as String: u['username'] as String,
          };
        });
      }
    } catch (e) {
      debugPrint('Error fetching usernames: $e');
    }
  }

  Widget _authorName({
    required String? uid,
    required String? fallbackEmail,
    TextStyle? style,
  }) {
    final username = _usernames[uid] ?? '';
    final display = username.isNotEmpty
        ? username
        : (fallbackEmail ?? 'Unknown');
    return Text('By: $display', style: style);
  }

  String _fmt(Timestamp ts) {
    final d = ts.toDate().toLocal();
    final m = d.month.toString().padLeft(2, '0');
    final da = d.day.toString().padLeft(2, '0');
    final y = d.year.toString();
    return '$m-$da-$y';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grammatica'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<UserRole>(
        stream: RoleService.instance.roleStream(widget.user.uid),
        builder: (context, roleSnapshot) {
          final role = roleSnapshot.data;

          return StreamBuilder<List<Quiz>>(
            stream: DatabaseService.instance.streamQuizzes(
              userRole: role,
              userId: widget.user.uid,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading quizzes: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }

              final allQuizzes = snapshot.data ?? [];
              final query = _searchCtrl.text.toLowerCase().trim();
              final quizzes = allQuizzes.where((q) {
                if (query.isEmpty) return true;
                final title = q.title.toLowerCase();
                final email = (q.createdByEmail ?? '').toLowerCase();
                final author = (_usernames[q.createdByUid] ?? '').toLowerCase();
                return title.contains(query) ||
                    email.contains(query) ||
                    author.contains(query);
              }).toList();

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: TextField(
                      controller: _searchCtrl,
                      onSubmitted: (_) => setState(() {}),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search by title, author name',
                        prefixIcon: const Icon(CupertinoIcons.search),
                        suffixIcon: IconButton(
                          icon: const Icon(
                            CupertinoIcons.arrow_right_circle_fill,
                          ),
                          color: AppColors.primaryGreen,
                          onPressed: () => setState(() {}),
                        ),
                        filled: true,
                        fillColor:
                            Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.grey.withValues(alpha: 0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (quizzes.isEmpty)
                    const Expanded(
                      child: Center(child: Text('No quizzes found.')),
                    )
                  else
                    Expanded(
                      child: StreamBuilder<Map<String, Map<String, dynamic>>>(
                        stream: DatabaseService.instance.quizProgressStream(
                          widget.user,
                        ),
                        builder: (context, progSnap) {
                          final progress = progSnap.data ?? const {};
                          return ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: quizzes.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final q = quizzes[index];
                              final progData = progress[q.id];
                              final completed = progData?['completed'] == true;
                              final isCorrect = progData?['isCorrect'] == true;
                              final attempts =
                                  (progData?['attemptsUsed'] as int?) ?? 0;
                              final max = q.maxAttempts;

                              bool failed = !isCorrect && attempts >= max;

                              String createdAtStr = q.createdAt != null
                                  ? _fmt(q.createdAt!)
                                  : 'N/A';

                              return GlassCard(
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => QuizDetailPage(
                                      user: widget.user,
                                      quiz: q,
                                    ),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: ListTile(
                                    title: Text(
                                      q.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Flexible(
                                              child: _authorName(
                                                uid: q.createdByUid,
                                                fallbackEmail: q.createdByEmail,
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodySmall,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          'Created: $createdAtStr',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        if (completed)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withOpacity(
                                                0.2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: Colors.green,
                                              ),
                                            ),
                                            child: const Text(
                                              'Passed',
                                              style: TextStyle(
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          )
                                        else if (failed)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withOpacity(
                                                0.2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: Colors.red,
                                              ),
                                            ),
                                            child: const Text(
                                              'Failed',
                                              style: TextStyle(
                                                color: Colors.red,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          )
                                        else
                                          Icon(
                                            CupertinoIcons.chevron_right,
                                            color: Colors.grey[400],
                                          ),
                                      ],
                                    ),
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
            },
          );
        },
      ),
    );
  }
}

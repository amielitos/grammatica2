import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../widgets/interactive_markdown.dart';
import '../widgets/notification_widgets.dart';
import '../pages/quiz_detail_page.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/universal_drawer.dart';

class LessonPage extends StatefulWidget {
  final User user;
  final Lesson lesson;
  final bool previewMode;

  const LessonPage({
    super.key,
    required this.user,
    required this.lesson,
    this.previewMode = false,
  });

  @override
  State<LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends State<LessonPage> {
  bool _isLoadingQuiz = false;
  late Lesson _lesson;
  bool get _previewMode => widget.previewMode;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _lesson = widget.lesson;
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final data = await DatabaseService.instance.getUserData(widget.user.uid);
    if (mounted) setState(() => _userData = data);
  }

  String _fmt(Timestamp ts) {
    final d = ts.toDate().toLocal();
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  Widget _authorName({required String? uid, required String? fallbackEmail, TextStyle? style}) {
    if (uid == null || uid.isEmpty) {
      return Text(fallbackEmail ?? 'Unknown', style: style);
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final username = (data?['username'] as String?)?.trim();
        final display = (username != null && username.isNotEmpty) ? username : (fallbackEmail ?? 'Unknown');
        return Text(display, style: style);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : AppColors.backgroundBase;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: CustomAppBar(
        user: widget.user,
        userData: _userData,
        showBackButton: widget.previewMode,
        onNotificationTap: () {
          showDialog(
            context: context,
            barrierColor: Colors.transparent,
            builder: (context) => NotificationsDialog(userId: widget.user.uid),
          );
        },
      ),
      drawer: UniversalDrawer(
        user: widget.user,
        userData: _userData ?? {},
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 900;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              isWide ? 40 : 20, 32, isWide ? 40 : 20, 40,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: _buildMainCard(isDark, isWide)),
                          const SizedBox(width: 28),
                          SizedBox(width: 320, child: _buildQuizSidebar(isDark)),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildMainCard(isDark, isWide),
                          const SizedBox(height: 24),
                          _buildQuizSidebar(isDark),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainCard(bool isDark, bool isWide) {
    final cardColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E1E1E);
    final subtleColor = isDark ? Colors.white54 : Colors.grey.shade600;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Area ──
          Padding(
            padding: EdgeInsets.fromLTRB(isWide ? 48 : 32, isWide ? 48 : 32, isWide ? 48 : 32, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Back button & Tag
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () => Navigator.maybePop(context),
                      borderRadius: BorderRadius.circular(100),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white12 : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_back_rounded, size: 16, color: titleColor),
                            const SizedBox(width: 8),
                            Text('Back', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: titleColor)),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF88B342).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: const Color(0xFF88B342).withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        _lesson.isMembersOnly ? 'MEMBERS ONLY' : 'PUBLIC LESSON',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: const Color(0xFF88B342),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Title
                Text(
                  _lesson.title,
                  style: GoogleFonts.outfit(
                    fontSize: isWide ? 48 : 36,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                    height: 1.1,
                    letterSpacing: -1.0,
                  ),
                ),
                const SizedBox(height: 24),

                // Meta info row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_outline_rounded, size: 16, color: subtleColor),
                      const SizedBox(width: 8),
                      _authorName(
                        uid: _lesson.createdByUid,
                        fallbackEmail: _lesson.createdByEmail,
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: subtleColor),
                      ),
                      if (_lesson.createdAt != null) ...[
                        Container(
                          width: 1,
                          height: 16,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          color: isDark ? Colors.white24 : Colors.grey.shade300,
                        ),
                        Icon(Icons.calendar_today_rounded, size: 16, color: subtleColor),
                        const SizedBox(width: 8),
                        Text(
                          _fmt(_lesson.createdAt!),
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: subtleColor),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey.shade200),

          // ── Body Content ──
          Padding(
            padding: EdgeInsets.all(isWide ? 48 : 32),
            child: InteractiveMarkdown(data: _lesson.prompt.trim()),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizSidebar(bool isDark) {
    final isValidator = _userData?['role'] == 'VALIDATOR';
    if (_previewMode || _lesson.quizId == null || isValidator) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<Map<String, Map<String, dynamic>>>(
      stream: DatabaseService.instance.quizProgressStream(widget.user),
      builder: (context, snapshot) {
        final progressMap = snapshot.data ?? {};
        final myProgress = progressMap[_lesson.quizId];
        final attempts = (myProgress?['attemptsUsed'] as num?)?.toInt() ?? 0;

        if (attempts > 0) {
          return _buildQuizResultsCard(myProgress!, isDark);
        }

        return _buildTakeQuizCard(isDark);
      },
    );
  }

  Widget _buildTakeQuizCard(bool isDark) {
    final cardColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(28),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF81B655), Color(0xFF6A9943)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.quiz_rounded, size: 36, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text(
                  'Knowledge Check',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Test your understanding of this lesson.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          // CTA
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _isLoadingQuiz ? null : _takeQuizAction,
                    icon: _isLoadingQuiz
                        ? const SizedBox(
                            height: 18, width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.play_arrow_rounded, size: 22),
                    label: Text(
                      'Take Quiz',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _takeQuizAction() async {
    setState(() => _isLoadingQuiz = true);
    try {
      await DatabaseService.instance.markLessonCompleted(
        user: widget.user,
        lessonId: _lesson.id,
      );

      final doc = await FirebaseFirestore.instance
          .collection('quizzes')
          .doc(_lesson.quizId)
          .get();

      if (doc.exists && mounted) {
        final quiz = Quiz.fromDoc(doc);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => QuizDetailPage(user: widget.user, quiz: quiz),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingQuiz = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading quiz: $e')),
        );
      }
    }
  }

  Widget _buildQuizResultsCard(Map<String, dynamic> progress, bool isDark) {
    final cardColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final score = progress['score'] ?? 0;
    final total = progress['totalQuestions'] ?? 0;
    final passed = progress['passed'] == true;
    final timeTaken = progress['timeTaken'] as int? ?? 0;
    final minutes = timeTaken ~/ 60;
    final seconds = timeTaken % 60;
    final timeStr = minutes > 0 ? '$minutes m $seconds s' : '$seconds s';
    final passColor = passed ? AppColors.primary : const Color(0xFFD32F2F);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: passColor.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Result header
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: passed
                    ? [const Color(0xFF76A34F), const Color(0xFF5A8A38)]
                    : [const Color(0xFFD32F2F), const Color(0xFFB71C1C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    passed ? Icons.verified_rounded : Icons.cancel_rounded,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  passed ? 'Quiz Passed!' : 'Quiz Failed',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Stats & Retake
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statItem('Score', '$score/$total', isDark),
                    _statItem('Time', timeStr, isDark),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: passColor),
                      foregroundColor: passColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _isLoadingQuiz ? null : _takeQuizAction,
                    icon: _isLoadingQuiz
                        ? SizedBox(
                            height: 18, width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: passColor),
                          )
                        : const Icon(Icons.refresh_rounded, size: 20),
                    label: Text(
                      passed ? 'Retake Quiz' : 'Try Again',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, bool isDark) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

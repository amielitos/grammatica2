import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import '../services/database_service.dart';
import '../theme/app_colors.dart';
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
            child: _lesson.hasContentBlocks
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _lesson.contentBlocks
                        .map((b) => _buildContentBlock(b, isDark))
                        .toList(),
                  )
                : _buildContentBlock({'type': 'text', 'data': _lesson.prompt}, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildContentBlock(Map<String, dynamic> blockMap, bool isDark) {
    final typeStr = (blockMap['type'] ?? 'text').toString();
    final data = blockMap['data'];
    final caption = (blockMap['caption'] ?? '').toString();

    if (typeStr == 'image') {
      final url = (data ?? '').toString();
      if (!url.startsWith('http')) return const SizedBox.shrink();

      return Padding(
        padding: const EdgeInsets.only(bottom: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    backgroundColor: Colors.transparent,
                    insetPadding: const EdgeInsets.all(16),
                    child: Stack(
                      alignment: Alignment.topRight,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(url, fit: BoxFit.contain),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 28),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(
                    url,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 160,
                      color: isDark ? const Color(0xFF333333) : Colors.grey.shade200,
                      child: const Center(child: Icon(Icons.broken_image_rounded, size: 40, color: Colors.grey)),
                    ),
                  ),
                ),
              ),
            ),
            if (caption.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                caption,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: isDark ? Colors.white60 : AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Default: Text Block — render with Markdown for rich formatting
    final textStr = (data ?? '').toString();
    if (textStr.trim().isEmpty) return const SizedBox.shrink();

    final textColor = isDark ? Colors.white.withValues(alpha: 0.9) : AppColors.textPrimary;
    final codeBlockBg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F2EB);
    final tableBorderColor = isDark ? Colors.white24 : const Color(0xFFD4D4D4);
    final tableHeaderBg = isDark ? const Color(0xFF2D4A1A) : const Color(0xFFF0F7E8);
    final tableRowBg = isDark ? const Color(0xFF333333) : Colors.white;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF333333) : const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
        ),
        child: MarkdownBody(
          data: textStr.trim(),
          selectable: true,
          extensionSet: md.ExtensionSet(
            md.ExtensionSet.gitHubFlavored.blockSyntaxes,
            [md.EmojiSyntax(), ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes],
          ),
          styleSheet: MarkdownStyleSheet(
          // Regular text
          p: GoogleFonts.inter(
            fontSize: 16,
            height: 1.7,
            color: textColor,
          ),
          // Bold text — darker green
          strong: GoogleFonts.inter(
            fontSize: 16,
            height: 1.7,
            fontWeight: FontWeight.w800,
            color: isDark ? const Color(0xFFA8D870) : const Color(0xFF4A7C23),
          ),
          // Italic text — slate blue
          em: GoogleFonts.inter(
            fontSize: 16,
            height: 1.7,
            fontStyle: FontStyle.italic,
            color: isDark ? const Color(0xFF9BB8D3) : const Color(0xFF546E7A),
          ),
          // Headings
          h1: GoogleFonts.outfit(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF1E1E1E),
            height: 1.3,
          ),
          h2: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF2A2A2A),
            height: 1.3,
          ),
          h3: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF333333),
            height: 1.4,
          ),
          // Bullet lists
          listBullet: GoogleFonts.inter(
            fontSize: 16,
            height: 1.7,
            color: AppColors.primary,
          ),
          // Inline code
          code: GoogleFonts.firaCode(
            fontSize: 14,
            color: isDark ? const Color(0xFFCE9178) : const Color(0xFFC7254E),
            backgroundColor: codeBlockBg,
          ),
          // Code blocks
          codeblockDecoration: BoxDecoration(
            color: codeBlockBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE0E0E0)),
          ),
          codeblockPadding: const EdgeInsets.all(16),
          // Blockquotes
          blockquoteDecoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A3A1E) : const Color(0xFFF8FAF5),
            border: Border(
              left: BorderSide(
                color: AppColors.primary,
                width: 4,
              ),
            ),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(8),
              bottomRight: Radius.circular(8),
            ),
          ),
          blockquotePadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          // Table styling
          tableHead: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF2A2A2A),
          ),
          tableBody: GoogleFonts.inter(
            fontSize: 14,
            height: 1.5,
            color: textColor,
          ),
          tableBorder: TableBorder.all(
            color: tableBorderColor,
            width: 1,
            borderRadius: BorderRadius.circular(8),
          ),
          tableHeadAlign: TextAlign.left,
          tableCellsPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          tableColumnWidth: const IntrinsicColumnWidth(),
          // Horizontal rules
          horizontalRuleDecoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                width: 1,
              ),
            ),
          ),
          // Spacing
          h1Padding: const EdgeInsets.only(top: 24, bottom: 12),
          h2Padding: const EdgeInsets.only(top: 20, bottom: 10),
          h3Padding: const EdgeInsets.only(top: 16, bottom: 8),
          pPadding: const EdgeInsets.only(bottom: 8),
          listIndent: 24,
          blockSpacing: 12,
        ),
        builders: {
          'table': _StyledTableBuilder(
            headerBg: tableHeaderBg,
            rowBg: tableRowBg,
            isDark: isDark,
          ),
        },
      ),
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

/// Custom builder for markdown tables to add header and row background styling.
class _StyledTableBuilder extends MarkdownElementBuilder {
  final Color headerBg;
  final Color rowBg;
  final bool isDark;

  _StyledTableBuilder({
    required this.headerBg,
    required this.rowBg,
    required this.isDark,
  });

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    // We don't override table rendering here — styling is handled via
    // MarkdownStyleSheet's table properties. This builder is a hook
    // for future per-cell customizations.
    return null;
  }
}

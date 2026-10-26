import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../widgets/interactive_markdown.dart';
import '../widgets/notification_widgets.dart';
import '../services/auth_service.dart';
import '../services/navigation_service.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/universal_drawer.dart';
import '../widgets/linked_companion_toolbar.dart';
import '../models/playlist.dart';

class LessonPage extends StatefulWidget {
  final User user;
  final Lesson lesson;
  final bool previewMode;
  final LessonPlaylist? playlist;

  const LessonPage({
    super.key,
    required this.user,
    required this.lesson,
    this.previewMode = false,
    this.playlist,
  });

  @override
  State<LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends State<LessonPage> {
  bool _isLoadingQuiz = false;
  late Lesson _lesson;
  bool get _previewMode => widget.previewMode;
  Map<String, dynamic>? _userData;

  /// Live user object to preserve auth session continuity.
  User get _effectiveUser => AuthService.maybeLiveUser ?? widget.user;

  final ScrollController _scrollController = ScrollController();
  double _progress = 0.0;
  bool _isCompleted = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _lesson = widget.lesson;
    _fetchUserData();
    _initProgress();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _initProgress() async {
    if (widget.previewMode) return;
    DatabaseService.instance.recordLessonViewed(
      user: _effectiveUser,
      lessonId: widget.lesson.id,
    );
    final data = await DatabaseService.instance.getLessonProgress(_effectiveUser.uid, widget.lesson.id);
    if (data != null && mounted) {
      setState(() {
        _isCompleted = data['completed'] == true;
        _progress = _isCompleted ? 1.0 : (data['progress'] as double? ?? 0.0);
      });
    }
  }

  void _onScroll() {
    if (_isCompleted || widget.previewMode) return;
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    // Do not auto-complete on initial layout or small/unscrollable content
    if (maxScroll <= 50) return;

    final currentScroll = _scrollController.position.pixels;
    if (currentScroll <= 0) return;

    double newProgress = (currentScroll / maxScroll).clamp(0.0, 1.0);
    final reachedBottom = currentScroll >= (maxScroll - 30);
    if (!reachedBottom && newProgress >= 1.0) {
      newProgress = 0.95;
    }

    if (newProgress > _progress) {
      setState(() {
        _progress = newProgress;
        if (reachedBottom) {
          _isCompleted = true;
        }
      });
      if (_isCompleted) {
        _updateProgressToDb();
      } else {
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(seconds: 2), _updateProgressToDb);
      }
    }
  }

  void _updateProgressToDb() {
    if (widget.previewMode || !mounted) return;
    DatabaseService.instance.updateLessonProgress(
      user: _effectiveUser,
      lessonId: widget.lesson.id,
      progress: _progress,
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    final data = await DatabaseService.instance.getUserData(_effectiveUser.uid);
    if (mounted) setState(() => _userData = data);
  }

  String _fmt(Timestamp ts) {
    final d = ts.toDate().toLocal();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final hour = d.hour == 0 ? 12 : (d.hour > 12 ? d.hour - 12 : d.hour);
    final minute = d.minute.toString().padLeft(2, '0');
    final amPm = d.hour >= 12 ? 'PM' : 'AM';
    return '${months[d.month - 1]} ${d.day}, ${d.year} at $hour:$minute $amPm';
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
        user: _effectiveUser,
        userData: _userData,
        showBackButton: widget.previewMode || Navigator.canPop(context),
        onNotificationTap: () {
          showDialog(
            context: context,
            barrierColor: Colors.transparent,
            builder: (context) => NotificationsDialog(userId: _effectiveUser.uid),
          );
        },
      ),
      drawer: UniversalDrawer(
        user: _effectiveUser,
        userData: _userData ?? {},
      ),
      body: Column(
        children: [
          if (widget.previewMode || _lesson.validationStatus == 'awaiting_approval')
            Container(
              width: double.infinity,
              color: _lesson.isUpdate ? const Color(0xFF6366F1) : const Color(0xFFE8A838),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: SafeArea(
                bottom: false,
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _lesson.isUpdate ? Icons.edit_note_rounded : Icons.schedule_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _lesson.isUpdate
                            ? 'Creator wants to update already existing lesson • Submitted: ${_lesson.createdAt != null ? _fmt(_lesson.createdAt!) : 'N/A'}'
                            : 'Pending Approval • Submitted: ${_lesson.createdAt != null ? _fmt(_lesson.createdAt!) : 'N/A'}',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (!widget.previewMode)
            LinearProgressIndicator(
              value: _progress,
              minHeight: 4,
              backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;
                return SingleChildScrollView(
                  controller: _scrollController,
                  padding: EdgeInsets.fromLTRB(
                    isWide ? 40 : 20, 32, isWide ? 40 : 20, 40,
                  ),
                  child: SizedBox(
                    width: constraints.maxWidth,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: isWide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 3, child: _buildMainCard(isDark, isWide)),
                                  const SizedBox(width: 28),
                                  SizedBox(
                                    width: 340,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        _buildQuizSidebar(isDark),
                                        LinkedCompanionSidebar(
                                          user: _effectiveUser,
                                          notebookId: _lesson.notebookId,
                                          currentLesson: _lesson,
                                          activeType: CompanionMediaType.lesson,
                                          excludeLesson: true,
                                          excludeQuiz: _lesson.quizId != null && _lesson.quizId!.isNotEmpty,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildMainCard(isDark, isWide),
                                  const SizedBox(height: 24),
                                  _buildQuizSidebar(isDark),
                                  LinkedCompanionSidebar(
                                    user: _effectiveUser,
                                    notebookId: _lesson.notebookId,
                                    currentLesson: _lesson,
                                    activeType: CompanionMediaType.lesson,
                                    excludeLesson: true,
                                    excludeQuiz: _lesson.quizId != null && _lesson.quizId!.isNotEmpty,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainCard(bool isDark, bool isWide) {
    final cardColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final headerGradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF1E3A2B), Color(0xFF0F1E19)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFF88B342), Color(0xFF5B8927)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Gradient Hero Header Area ──
          Container(
            decoration: BoxDecoration(
              gradient: headerGradient,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF88B342).withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: EdgeInsets.fromLTRB(isWide ? 40 : 24, isWide ? 40 : 24, isWide ? 40 : 24, 36),
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
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_back_rounded, size: 16, color: Colors.white),
                            const SizedBox(width: 8),
                            Text('Back', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _lesson.isMembersOnly ? 'MEMBERS ONLY' : 'PUBLIC LESSON',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Title
                Text(
                  _lesson.title,
                  style: GoogleFonts.outfit(
                    fontSize: isWide ? 44 : 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.15,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 20),

                // Meta info row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 16, color: Colors.white70),
                      _authorName(
                        uid: _lesson.createdByUid,
                        fallbackEmail: _lesson.createdByEmail,
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
                      ),
                      if (_lesson.createdAt != null) ...[
                        Container(
                          width: 1,
                          height: 14,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          color: Colors.white30,
                        ),
                        const Icon(Icons.calendar_today_rounded, size: 16, color: Colors.white70),
                        Text(
                          _fmt(_lesson.createdAt!),
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // ── Body Content (Interactive Block Cards) ──
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isWide ? 32 : 16, vertical: isWide ? 32 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_lesson.isUpdate) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.edit_note_rounded, color: Color(0xFF6366F1), size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Creator wants to update already existing lesson.',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: const Color(0xFF6366F1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                if (widget.playlist != null) ...[
                  _buildPlaylistTopBanner(context, isDark),
                  const SizedBox(height: 20),
                ],
                _buildContentBlockCards(_lesson.prompt.trim(), isDark),
                if (widget.playlist != null) ...[
                  const SizedBox(height: 24),
                  _buildPlaylistControls(context, isDark),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistTopBanner(BuildContext context, bool isDark) {
    final playlist = widget.playlist!;
    final currentIndex = playlist.lessonIds.indexOf(_lesson.id);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.playlist_play_rounded, color: AppColors.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Playlist: ${playlist.title}',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              currentIndex != -1 ? 'Lesson ${currentIndex + 1} of ${playlist.lessonIds.length}' : 'Playlist Mode',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistControls(BuildContext context, bool isDark) {
    final playlist = widget.playlist!;
    final currentIndex = playlist.lessonIds.indexOf(_lesson.id);
    final hasNext = currentIndex != -1 && currentIndex < playlist.lessonIds.length - 1;
    final hasPrev = currentIndex > 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.playlist_play_rounded, color: AppColors.primary, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sequential Journey: ${playlist.title}',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Keep going in the order intended by the creator.',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (hasPrev)
                OutlinedButton.icon(
                  onPressed: () async {
                    final prevId = playlist.lessonIds[currentIndex - 1];
                    final prevLesson = await DatabaseService.instance.getLesson(prevId);
                    if (prevLesson != null && context.mounted) {
                      NavigationService.instance.goToLesson(context, prevLesson, replace: true, playlist: playlist);
                    }
                  },
                  icon: const Icon(Icons.skip_previous_rounded),
                  label: const Text('Previous Lesson'),
                ),
              const Spacer(),
              if (hasNext)
                FilledButton.icon(
                  onPressed: () async {
                    final nextId = playlist.lessonIds[currentIndex + 1];
                    final nextLesson = await DatabaseService.instance.getLesson(nextId);
                    if (nextLesson != null && context.mounted) {
                      NavigationService.instance.goToLesson(context, nextLesson, replace: true, playlist: playlist);
                    }
                  },
                  icon: const Icon(Icons.skip_next_rounded),
                  label: const Text('Next in Playlist'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.celebration_rounded, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Text('You finished all lessons in this playlist!',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContentBlockCards(String fullContent, bool isDark) {
    final rawBlocks = fullContent.split('\n\n').where((b) => b.trim().isNotEmpty).toList();
    if (rawBlocks.isEmpty) {
      return const Text('No content available.');
    }

    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final cardBorder = isDark ? Colors.white12 : Colors.grey.shade200;

    final accentColors = [
      const Color(0xFF88B342), // Grammatica Green
      const Color(0xFF2563EB), // Indigo Blue
      const Color(0xFFD97706), // Amber
      const Color(0xFF0D9488), // Teal
      const Color(0xFF7C3AED), // Purple
    ];

    int blockIndex = 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rawBlocks.map((blockText) {
        final trimmed = blockText.trim();
        final accentColor = accentColors[blockIndex % accentColors.length];
        blockIndex++;
        
        // Image Markdown Pattern: ![alt](url)
        final imgRegex = RegExp(r'!\[([\s\S]*?)\]\((https?://[^\s)]+|\S+?)\)');
        final match = imgRegex.firstMatch(trimmed);

        if (match != null) {
          var imageUrl = match.group(2) ?? '';
          final altText = match.group(1) ?? '';
          if (imageUrl.endsWith(')')) {
            imageUrl = imageUrl.substring(0, imageUrl.length - 1);
          }
          return Container(
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: isDark ? 0.2 : 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(color: cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: isDark ? 0.15 : 0.08),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    border: Border(bottom: BorderSide(color: accentColor.withValues(alpha: 0.2))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.image_rounded, size: 16, color: accentColor),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'VISUAL AID',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              padding: const EdgeInsets.all(24),
                              alignment: Alignment.center,
                              child: Text('[Image: $altText]', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                            );
                          },
                        ),
                      ),
                      if (altText.isNotEmpty && altText != 'Image' && altText != 'Generated Image') ...[
                        const SizedBox(height: 12),
                        Text(
                          altText,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white60 : Colors.black54),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        String sectionTag = 'LESSON CONTENT';
        IconData sectionIcon = Icons.article_rounded;
        if (trimmed.startsWith('# ') || trimmed.startsWith('## ')) {
          sectionTag = 'KEY TOPIC';
          sectionIcon = Icons.auto_awesome_rounded;
        } else if (trimmed.contains('|') && trimmed.contains('---')) {
          sectionTag = 'COMPARISON TABLE';
          sectionIcon = Icons.table_chart_rounded;
        } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ') || trimmed.startsWith('• ')) {
          sectionTag = 'KEY POINTS';
          sectionIcon = Icons.checklist_rounded;
        }

        // Standard Text/List/Table Block Card
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: isDark ? 0.2 : 0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: isDark ? 0.15 : 0.08),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border(bottom: BorderSide(color: accentColor.withValues(alpha: 0.2))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(sectionIcon, size: 16, color: accentColor),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      sectionTag,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(28),
                child: InteractiveMarkdown(data: trimmed),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQuizSidebar(bool isDark) {
    if (_lesson.quizId == null || _lesson.quizId!.isEmpty) {
      return const SizedBox.shrink();
    }

    final isValidator = _userData?['role'] == 'VALIDATOR';
    if (_previewMode || isValidator) {
      return _buildPreviewQuizCard(isDark);
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

  Widget _buildPreviewQuizCard(bool isDark) {
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
          Container(
            padding: const EdgeInsets.all(24),
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.quiz_rounded, size: 32, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  'Knowledge Quiz',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Linked assessment for validation preview.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: _isLoadingQuiz ? null : _previewQuizAction,
                icon: _isLoadingQuiz
                    ? const SizedBox(
                        height: 18, width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.visibility_rounded, size: 20),
                label: Text(
                  'Preview Quiz',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
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

  Future<void> _previewQuizAction() async {
    if (_lesson.quizId == null || _lesson.quizId!.isEmpty) return;
    setState(() => _isLoadingQuiz = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('quizzes')
          .doc(_lesson.quizId)
          .get();

      if (doc.exists && mounted) {
        final quiz = Quiz.fromDoc(doc);
        NavigationService.instance.goToQuiz(
          context,
          quiz,
          notebookId: _lesson.notebookId,
          lesson: _lesson,
          replace: false,
          previewMode: true,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading quiz: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingQuiz = false);
      }
    }
  }

  Future<void> _takeQuizAction() async {
    if (_previewMode) {
      await _previewQuizAction();
      return;
    }
    setState(() => _isLoadingQuiz = true);
    try {
      await DatabaseService.instance.markLessonCompleted(
        user: _effectiveUser,
        lessonId: _lesson.id,
      );

      final doc = await FirebaseFirestore.instance
          .collection('quizzes')
          .doc(_lesson.quizId)
          .get();

      if (doc.exists && mounted) {
        final quiz = Quiz.fromDoc(doc);
        NavigationService.instance.goToQuiz(
          context,
          quiz,
          notebookId: _lesson.notebookId,
          lesson: _lesson,
          replace: true,
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

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
import '../services/role_service.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/universal_drawer.dart';
import '../widgets/linked_companion_toolbar.dart';
import '../widgets/author_name_widget.dart';
import '../models/playlist.dart';
import '../models/notebook_models.dart';
import '../widgets/sti_modules_view.dart';

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
  UserRole? _userRole;
  bool _roleLoaded = false;
  bool _showTimelineTab = false;
  List<Lesson> _curriculumLessons = [];

  bool get _canAccessLesson {
    if (_lesson.isArchived) return false;
    if (_lesson.validationStatus == 'approved') return true;
    if (_lesson.createdByUid != null &&
        _lesson.createdByUid == _effectiveUser.uid) {
      return true;
    }
    return _userRole == UserRole.validator;
  }

  bool get _needsRoleCheckBeforeRender {
    if (_lesson.isArchived) return false;
    if (_lesson.validationStatus == 'approved') return false;
    if (_lesson.createdByUid != null &&
        _lesson.createdByUid == _effectiveUser.uid) {
      return false;
    }
    return !_roleLoaded;
  }

  bool get _isEducator {
    final role = _userData?['role']?.toString().toUpperCase();
    return role == 'EDUCATOR' ||
        role == 'TEACHER' ||
        role == 'ADMIN' ||
        role == 'SUPERADMIN' ||
        _lesson.createdByUid == _effectiveUser.uid;
  }

  /// Live user object to preserve auth session continuity.
  User get _effectiveUser => AuthService.maybeLiveUser ?? widget.user;

  final ScrollController _scrollController = ScrollController();
  double _progress = 0.0;
  bool _isCompleted = false;
  Timer? _debounceTimer;
  Future<LinkedContentBundle>? _bundleFuture;

  StreamSubscription<List<Lesson>>? _curriculumSub;

  @override
  void initState() {
    super.initState();
    _lesson = widget.lesson;
    _curriculumLessons = [_lesson];
    _fetchUserDataAndInit();
    _scrollController.addListener(_onScroll);
    _bundleFuture = DatabaseService.instance.getLinkedContentBundle(
      notebookId: _lesson.notebookId,
      currentLesson: _lesson,
    );
  }

  void _listenCurriculumLessons() {
    _curriculumSub?.cancel();
    _curriculumSub = DatabaseService.instance
        .streamLessons(userRole: _userRole, userId: _effectiveUser.uid)
        .listen((all) {
      if (!mounted) return;
      if (widget.playlist != null && widget.playlist!.lessonIds.isNotEmpty) {
        final pl = all.where((l) => widget.playlist!.lessonIds.contains(l.id)).toList();
        if (pl.isNotEmpty) {
          setState(() => _curriculumLessons = pl);
          return;
        }
      }
      final related = all.where((l) =>
          l.isGrammaticaLesson == widget.lesson.isGrammaticaLesson && l.isVisible).toList();
      if (related.isNotEmpty) {
        setState(() => _curriculumLessons = related);
      }
    });
  }

  void _openMobileTimelineDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.85,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: STIModulesTimelineDrawer(
            lessons: _curriculumLessons,
            activeLessonId: _lesson.id,
            onSelectLesson: (l) {
              Navigator.pop(ctx);
              if (l.id != _lesson.id) {
                NavigationService.instance.goToLesson(context, l, replace: true, playlist: widget.playlist);
              }
            },
            onClose: () => Navigator.pop(ctx),
          ),
        ),
      ),
    );
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
    // Do not update on initial layout or unscrollable content
    if (maxScroll <= 50) return;

    final currentScroll = _scrollController.position.pixels;
    if (currentScroll <= 0) return;

    final hasLinkedQuiz = _lesson.quizId != null && _lesson.quizId!.isNotEmpty;
    // If it has a quiz, reading accounts for up to 50% of the lesson progress.
    final double maxReadingProgress = hasLinkedQuiz ? 0.5 : 0.95;
    final double rawRatio = (currentScroll / maxScroll).clamp(0.0, 1.0);
    final double newProgress = (rawRatio * maxReadingProgress).clamp(0.0, maxReadingProgress);

    if (newProgress > _progress) {
      setState(() {
        _progress = newProgress;
      });
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(seconds: 2), _updateProgressToDb);
    }
  }

  void _updateProgressToDb() {
    if (widget.previewMode || !mounted) return;
    if (_isCompleted) {
      DatabaseService.instance.markLessonCompleted(
        user: _effectiveUser,
        lessonId: widget.lesson.id,
        completed: true,
      );
    } else {
      DatabaseService.instance.updateLessonProgress(
        user: _effectiveUser,
        lessonId: widget.lesson.id,
        progress: _progress,
      );
    }
  }

  @override
  void dispose() {
    _curriculumSub?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchUserDataAndInit() async {
    final results = await Future.wait([
      DatabaseService.instance.getUserData(_effectiveUser.uid),
      RoleService.instance.getRole(_effectiveUser.uid),
    ]);
    if (!mounted) return;
    setState(() {
      _userData = results[0] as Map<String, dynamic>?;
      _userRole = results[1] as UserRole;
      _roleLoaded = true;
    });
    if (_canAccessLesson) {
      _initProgress();
      _listenCurriculumLessons();
    }
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
      final fallback = fallbackEmail != null && fallbackEmail.contains('@')
          ? fallbackEmail.split('@')[0]
          : (fallbackEmail ?? 'Grammatica');
      return Text(fallback, style: style);
    }
    return AuthorName(
      uid: uid,
      fallbackEmail: fallbackEmail,
      prefix: '',
      isClickable: true,
      style: style,
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
        onLogoTap: () {
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
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

      body: _needsRoleCheckBeforeRender
          ? const Center(child: CircularProgressIndicator())
          : !_canAccessLesson
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.lock_clock_rounded,
                          size: 56,
                          color: Color(0xFFE8A838),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Lesson Unavailable',
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This lesson is awaiting validator approval and is currently only visible to its author and validators.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Go Back'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
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
            child: Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 900;
                          final hasQuiz = _lesson.quizId != null && _lesson.quizId!.isNotEmpty;

                          return FutureBuilder<LinkedContentBundle>(
                            future: _bundleFuture,
                            builder: (context, bundleSnap) {
                              final bundle = bundleSnap.data;
                              final hasCompanionItems = bundle != null && (
                                (bundle.quiz != null && bundle.quiz!.id != _lesson.quizId) ||
                                bundle.publishedItems.isNotEmpty
                              );
                              final hasSideContent = hasQuiz || hasCompanionItems;

                              return SingleChildScrollView(
                                controller: _scrollController,
                                padding: EdgeInsets.fromLTRB(
                                  isWide ? 40 : 20, 32, isWide ? 40 : 20, 40,
                                ),
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(maxWidth: hasSideContent ? 1200 : 880),
                                    child: (hasSideContent && isWide)
                                        ? Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(flex: 3, child: _buildMainCard(isDark, isWide, bundle)),
                                              const SizedBox(width: 28),
                                              SizedBox(
                                                width: 340,
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                                  children: [
                                                    if (hasQuiz) _buildQuizSidebar(isDark),
                                                    if (hasCompanionItems)
                                                      LinkedCompanionSidebar(
                                                        user: _effectiveUser,
                                                        notebookId: _lesson.notebookId,
                                                        currentLesson: _lesson,
                                                        activeType: CompanionMediaType.lesson,
                                                        excludeLesson: true,
                                                        excludeQuiz: hasQuiz,
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          )
                                        : Column(
                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                            children: [
                                              _buildMainCard(isDark, isWide, bundle),
                                              if (hasSideContent) ...[
                                                const SizedBox(height: 24),
                                                if (hasQuiz) _buildQuizSidebar(isDark),
                                                if (hasCompanionItems)
                                                  LinkedCompanionSidebar(
                                                    user: _effectiveUser,
                                                    notebookId: _lesson.notebookId,
                                                    currentLesson: _lesson,
                                                    activeType: CompanionMediaType.lesson,
                                                    excludeLesson: true,
                                                    excludeQuiz: hasQuiz,
                                                  ),
                                              ],
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
                    if (_showTimelineTab && MediaQuery.of(context).size.width >= 1100)
                      STIModulesTimelineDrawer(
                        lessons: _curriculumLessons,
                        activeLessonId: _lesson.id,
                        onSelectLesson: (l) {
                          if (l.id != _lesson.id) {
                            NavigationService.instance.goToLesson(context, l, replace: true, playlist: widget.playlist);
                          }
                        },
                        onClose: () => setState(() => _showTimelineTab = false),
                      ),
                  ],
                ),

                // Floating side tab trigger button on edge of screen (Screenshot 4)
                Positioned(
                  top: 70,
                  right: 0,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () {
                        final isDesktop = MediaQuery.of(context).size.width >= 1100;
                        if (isDesktop) {
                          setState(() => _showTimelineTab = !_showTimelineTab);
                        } else {
                          _openMobileTimelineDrawer(context);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            bottomLeft: Radius.circular(12),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(-2, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.format_list_bulleted_rounded,
                                color: Colors.white, size: 16),
                            const SizedBox(width: 4),
                            RotatedBox(
                              quarterTurns: 3,
                              child: Text(
                                'MODULES',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildMainCard(bool isDark, bool isWide, [LinkedContentBundle? bundle]) {
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final headerGradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF1E3A20), Color(0xFF0F1E14)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFF81B655), Color(0xFF5A8E30)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    final wordCount = _lesson.prompt.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final readTimeMinutes = ((wordCount / 160).ceil()).clamp(1, 60);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Signature Lush Gradient Hero Header ──
          Container(
            decoration: BoxDecoration(
              gradient: headerGradient,
            ),
            padding: EdgeInsets.fromLTRB(isWide ? 36 : 20, isWide ? 32 : 20, isWide ? 36 : 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Back button & Status Badges
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: InkWell(
                        onTap: () => Navigator.maybePop(context),
                        borderRadius: BorderRadius.circular(100),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.arrow_back_rounded, size: 15, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(
                                'Back to Lessons',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (_isCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF22C55E).withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle_rounded, size: 14, color: Colors.white),
                                  const SizedBox(width: 5),
                                  Text(
                                    'COMPLETED',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _lesson.isMembersOnly ? Icons.lock_outline_rounded : Icons.public_rounded,
                                  size: 13,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _lesson.isMembersOnly ? 'MEMBERS ONLY' : 'PUBLIC LESSON',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // Lesson Title
                Text(
                  _lesson.title,
                  style: GoogleFonts.outfit(
                    fontSize: isWide ? 36 : 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 18),

                // Sleek Metadata Chips
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_rounded, size: 15, color: Colors.white70),
                          const SizedBox(width: 6),
                          _authorName(
                            uid: _lesson.createdByUid,
                            fallbackEmail: _lesson.createdByEmail,
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ],
                      ),
                      if (_lesson.createdAt != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.white70),
                            const SizedBox(width: 6),
                            Text(
                              _fmt(_lesson.createdAt!),
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
                            ),
                          ],
                        ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.schedule_rounded, size: 15, color: Colors.white70),
                          const SizedBox(width: 5),
                          Text(
                            '$readTimeMinutes min read',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt_rounded, size: 15, color: Colors.amberAccent),
                          const SizedBox(width: 4),
                          Text(
                            'Self-Paced Practice',
                            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Immediate Included Packages Bar ──
                _buildIncludedPackagesBar(bundle, isDark),
              ],
            ),
          ),

          // ── Clean Unified Reading Canvas ──
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isWide ? 36 : 20, vertical: isWide ? 32 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_lesson.isUpdate) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
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
                            'Creator updated this lesson content.',
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

                // Main Reading Body - flows directly on the card canvas
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: _buildRichLessonContent(_lesson.prompt.trim(), isDark),
                ),

                const SizedBox(height: 32),

                // Interactive Completion Card
                _buildLessonCompletionActionCard(isDark),

                // Attached Quiz Callout (if quiz exists)
                if (_lesson.quizId != null && _lesson.quizId!.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildLessonQuizCTA(isDark),
                ],

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
                    if (!context.mounted) return;
                    final canOpen = prevLesson != null &&
                        !prevLesson.isArchived &&
                        (prevLesson.validationStatus == 'approved' ||
                            prevLesson.createdByUid == _effectiveUser.uid ||
                            _userRole == UserRole.validator);
                    if (canOpen) {
                      NavigationService.instance.goToLesson(context, prevLesson, replace: true, playlist: playlist);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('That lesson is awaiting approval and is not yet available.')),
                      );
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
                    if (!context.mounted) return;
                    final canOpen = nextLesson != null &&
                        !nextLesson.isArchived &&
                        (nextLesson.validationStatus == 'approved' ||
                            nextLesson.createdByUid == _effectiveUser.uid ||
                            _userRole == UserRole.validator);
                    if (canOpen) {
                      NavigationService.instance.goToLesson(context, nextLesson, replace: true, playlist: playlist);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('That lesson is awaiting approval and is not yet available.')),
                      );
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

  Widget _buildRichLessonContent(String fullContent, bool isDark) {
    if (fullContent.isEmpty) {
      return Text(
        'No content available.',
        style: GoogleFonts.inter(fontSize: 15, color: Colors.grey),
      );
    }

    final imgRegex = RegExp(r'!\[([\s\S]*?)\]\((https?://[^\s)]+|\S+?)\)');
    final matches = imgRegex.allMatches(fullContent).toList();

    if (matches.isEmpty) {
      return InteractiveMarkdown(data: fullContent);
    }

    final List<Widget> widgets = [];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        final textChunk = fullContent.substring(lastEnd, match.start).trim();
        if (textChunk.isNotEmpty) {
          widgets.add(InteractiveMarkdown(data: textChunk));
          widgets.add(const SizedBox(height: 16));
        }
      }

      final altText = match.group(1) ?? '';
      var imageUrl = match.group(2) ?? '';
      if (imageUrl.endsWith(')')) imageUrl = imageUrl.substring(0, imageUrl.length - 1);

      widgets.add(
        Container(
          margin: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: const Color(0xFF81B655).withValues(alpha: 0.1),
                child: Row(
                  children: [
                    const Icon(Icons.image_rounded, size: 16, color: Color(0xFF81B655)),
                    const SizedBox(width: 8),
                    Text(
                      'VISUAL AID',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: const Color(0xFF81B655),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        child: Text('[Image: $altText]', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      );
                    },
                  ),
                ),
              ),
              if (altText.isNotEmpty && altText != 'Image' && altText != 'Generated Image')
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Text(
                    altText,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white60 : Colors.black54),
                  ),
                ),
            ],
          ),
        ),
      );

      lastEnd = match.end;
    }

    if (lastEnd < fullContent.length) {
      final tail = fullContent.substring(lastEnd).trim();
      if (tail.isNotEmpty) {
        widgets.add(const SizedBox(height: 16));
        widgets.add(InteractiveMarkdown(data: tail));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widgets,
    );
  }

  Widget _buildLessonCompletionActionCard(bool isDark) {
    if (widget.previewMode) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Colors.amber),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Preview Mode: Lesson progress and completion tracking are disabled.',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    if (!_isCompleted) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF142417), const Color(0xFF0F1E14)]
                : [const Color(0xFFF2FBF0), const Color(0xFFE8F7E4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF81B655).withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF81B655).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.task_alt_rounded, color: Color(0xFF81B655), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ready to wrap up this lesson?',
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF14532D),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Marking this lesson as completed updates your learning stats and folder progress.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: isDark ? Colors.white70 : const Color(0xFF166534),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await DatabaseService.instance.markLessonCompleted(
                    user: _effectiveUser,
                    lessonId: _lesson.id,
                    completed: true,
                  );
                  if (mounted) {
                    setState(() {
                      _isCompleted = true;
                      _progress = 1.0;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.celebration_rounded, color: Colors.white),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Great job! "${_lesson.title}" marked as completed! 🎉',
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: const Color(0xFF81B655),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                label: Text(
                  'Mark as Completed ✓',
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF81B655),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF142417) : const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF81B655).withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFF81B655),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lesson Completed! 🎉',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDark ? const Color(0xFF86EFAC) : const Color(0xFF166534),
                  ),
                ),
                Text(
                  "You've completed this material. Keep up the great study streak!",
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: isDark ? const Color(0xFFBBF7D0) : const Color(0xFF15803D),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              await DatabaseService.instance.markLessonCompleted(
                user: _effectiveUser,
                lessonId: _lesson.id,
                completed: false,
              );
              if (mounted) {
                setState(() {
                  _isCompleted = false;
                  _progress = 0.0;
                });
              }
            },
            child: Text(
              'Reset',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF86EFAC) : const Color(0xFF166534),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonQuizCTA(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.quiz_rounded, color: Color(0xFF2563EB), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lesson Assessment',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  (_isEducator || _previewMode)
                      ? 'Review the linked assessment questions and answer keys.'
                      : 'Reinforce what you just learned with a quick interactive quiz.',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: isDark ? Colors.white70 : const Color(0xFF1E40AF),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _isLoadingQuiz ? null : ((_isEducator || _previewMode) ? _previewQuizAction : _takeQuizAction),
            icon: _isLoadingQuiz
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(
                    (_isEducator || _previewMode) ? Icons.visibility_rounded : Icons.play_arrow_rounded,
                    size: 20,
                  ),
            label: Text(
              (_isEducator || _previewMode) ? 'View Quiz' : 'Take Quiz',
              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncludedPackagesBar(LinkedContentBundle? liveBundle, bool isDark) {
    final bundle = liveBundle ??
        DatabaseService.instance.getCachedBundle(_lesson.notebookId) ??
        DatabaseService.instance.getCachedBundle(_lesson.id);

    final bool hasExplicitQuiz = _lesson.quizId != null && _lesson.quizId!.isNotEmpty;
    final bool hasBundleQuiz = bundle?.quiz != null;
    final bool showQuiz = hasExplicitQuiz || hasBundleQuiz;

    final flashcardItems = bundle?.publishedItems
            .where((i) => i.type == NotebookOutputType.flashcards)
            .toList() ??
        [];
    final presentationItems = bundle?.publishedItems
            .where((i) => i.type == NotebookOutputType.presentation)
            .toList() ??
        [];
    final mindMapItems = bundle?.publishedItems
            .where((i) => i.type == NotebookOutputType.mindMap)
            .toList() ??
        [];
    final studyGuideItems = bundle?.publishedItems
            .where((i) =>
                i.type == NotebookOutputType.studyGuide ||
                i.type == NotebookOutputType.briefing ||
                i.type == NotebookOutputType.faq)
            .toList() ??
        [];

    final bool hasAnyPackage = showQuiz ||
        flashcardItems.isNotEmpty ||
        presentationItems.isNotEmpty ||
        mindMapItems.isNotEmpty ||
        studyGuideItems.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2_rounded, size: 14, color: Color(0xFFFBBF24)),
              const SizedBox(width: 6),
              Text(
                'INCLUDED PACKAGES & TOOLS',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              if (bundle == null && !hasExplicitQuiz) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white70),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (!hasAnyPackage && bundle != null)
            Text(
              'No additional packages attached to this lesson.',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // 1. Quiz Package Chip
                if (showQuiz)
                  _buildPackageChip(
                    icon: Icons.quiz_rounded,
                    label: 'Quiz',
                    subtitle: bundle?.quiz != null
                        ? '${bundle!.quiz!.questions.length} Qs'
                        : 'Interactive',
                    color: const Color(0xFFF59E0B),
                    onTap: () {
                      if (bundle?.quiz != null) {
                        NavigationService.instance.goToQuiz(
                          context,
                          bundle!.quiz!,
                          lesson: _lesson,
                        );
                      } else {
                        _scrollController.animateTo(
                          _scrollController.position.maxScrollExtent,
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                  ),

                // 2. Flashcards Deck
                for (final item in flashcardItems)
                  _buildPackageChip(
                    icon: Icons.style_rounded,
                    label: 'Flashcards',
                    subtitle: 'Study Deck',
                    color: const Color(0xFF3B82F6),
                    onTap: () {
                      NavigationService.instance.goToContent(context, item);
                    },
                  ),

                // 3. Presentation Slides
                for (final item in presentationItems)
                  _buildPackageChip(
                    icon: Icons.slideshow_rounded,
                    label: 'Presentation',
                    subtitle: 'Slide Deck',
                    color: const Color(0xFF6366F1),
                    onTap: () {
                      NavigationService.instance.goToContent(context, item);
                    },
                  ),

                // 4. Mind Map
                for (final item in mindMapItems)
                  _buildPackageChip(
                    icon: Icons.hub_rounded,
                    label: 'Mind Map',
                    subtitle: 'Visual Map',
                    color: const Color(0xFFEC4899),
                    onTap: () {
                      NavigationService.instance.goToContent(context, item);
                    },
                  ),

                // 5. Study Guide
                for (final item in studyGuideItems)
                  _buildPackageChip(
                    icon: Icons.auto_stories_rounded,
                    label: item.title.isNotEmpty ? item.title : 'Study Guide',
                    subtitle: 'Overview',
                    color: const Color(0xFF10B981),
                    onTap: () {
                      NavigationService.instance.goToContent(context, item);
                    },
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPackageChip({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.7), width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuizSidebar(bool isDark) {
    if (_lesson.quizId == null || _lesson.quizId!.isEmpty) {
      return const SizedBox.shrink();
    }

    final isValidator = _userData?['role'] == 'VALIDATOR';
    if (_previewMode || isValidator || _isEducator) {
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
                  'View Quiz',
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
    if (_previewMode || _isEducator) {
      await _previewQuizAction();
      return;
    }
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

  Future<void> _viewLastAttemptAction() async {
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

  Widget _buildQuizResultsCard(Map<String, dynamic> progress, bool isDark) {
    final cardColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final score = progress['score'] ?? 0;
    final total = progress['totalQuestions'] ?? 0;
    final passed = progress['passed'] == true;
    final attemptsUsed = (progress['attemptsUsed'] as num?)?.toInt() ?? 0;
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

          // Stats & Actions
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statItem('Score', '$score/$total', isDark),
                    _statItem('Time', timeStr, isDark),
                    _statItem('Attempts', '$attemptsUsed', isDark),
                  ],
                ),
                const SizedBox(height: 20),
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
                    onPressed: _isLoadingQuiz ? null : _viewLastAttemptAction,
                    icon: _isLoadingQuiz
                        ? SizedBox(
                            height: 18, width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: passColor),
                          )
                        : const Icon(Icons.visibility_rounded, size: 20),
                    label: Text(
                      'View Last Attempt',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: passColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _isLoadingQuiz ? null : _takeQuizAction,
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    label: Text(
                      'Retake Quiz',
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

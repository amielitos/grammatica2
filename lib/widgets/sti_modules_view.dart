import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/notebook_models.dart';
import '../models/published_content_item.dart';
import '../services/navigation_service.dart';
import '../services/database_service.dart';
import '../services/notebook_service.dart';

String _resolveLessonFileLabel(Lesson l) {
  final att = (l.attachmentName ?? '').trim();
  if (att.isNotEmpty) return att;
  final nbSource = NotebookService.instance.getPrimarySourceName(l.notebookId);
  if (nbSource != null && nbSource.isNotEmpty) return nbSource;
  if (l.title.trim().isNotEmpty) return l.title.trim();
  return 'Lesson Material';
}

/// Data structure representing a section item within an STI eLMS module
class STIModuleSection {
  final String id;
  final String title;
  final String typeLabel; // Handout, Laboratory Exercise, Slides, Seatwork, Quiz
  final IconData icon;
  final bool isSubmitted;
  final String? score;
  final String? due;
  final String status; // 'completed', 'partial', 'available'
  final VoidCallback onTap;

  const STIModuleSection({
    required this.id,
    required this.title,
    required this.typeLabel,
    required this.icon,
    this.isSubmitted = false,
    this.score,
    this.due,
    required this.status,
    required this.onTap,
  });
}

/// STI eLMS inspired Module Card (Screenshot 2 & 3)
/// Displays thumbnail on left, title, progress pill, and collapsible table of sections.
class STIModuleCard extends StatefulWidget {
  final int index;
  final Lesson lesson;
  final bool isCompleted;
  final double progress;
  final bool isExpanded;
  final ValueChanged<bool> onExpansionChanged;
  final List<PublishedContentItem> companionItems;
  final String? quizScore;
  final Map<String, dynamic>? progressMap;

  const STIModuleCard({
    super.key,
    required this.index,
    required this.lesson,
    required this.isCompleted,
    required this.progress,
    required this.isExpanded,
    required this.onExpansionChanged,
    this.companionItems = const [],
    this.quizScore,
    this.progressMap,
  });

  @override
  State<STIModuleCard> createState() => _STIModuleCardState();
}

class _STIModuleCardState extends State<STIModuleCard> {
  // Curated educational thumbnail gradients / asset fallbacks
  static const List<List<Color>> _thumbGradients = [
    [Color(0xFF2563EB), Color(0xFF1D4ED8)], // Blue
    [Color(0xFF0D9488), Color(0xFF0F766E)], // Teal
    [Color(0xFF7C3AED), Color(0xFF6D28D9)], // Purple
    [Color(0xFFEA580C), Color(0xFFC2410C)], // Orange
    [Color(0xFF16A34A), Color(0xFF15803D)], // Green
    [Color(0xFFDB2777), Color(0xFFBE185D)], // Rose
  ];

  List<STIModuleSection> _buildSections(BuildContext context) {
    final l = widget.lesson;
    final isDone = widget.isCompleted;
    final isPart = widget.progress > 0 && !isDone;

    final hasQuiz = l.quizId != null && l.quizId!.isNotEmpty;
    final presItems = widget.companionItems.where((i) => i.type == NotebookOutputType.presentation).toList();
    final fcItems = widget.companionItems.where((i) => i.type == NotebookOutputType.flashcards).toList();
    final mmItems = widget.companionItems.where((i) => i.type == NotebookOutputType.mindMap).toList();
    final guideItems = widget.companionItems.where((i) => i.type == NotebookOutputType.studyGuide).toList();

    final hasOtherPackages = hasQuiz || presItems.isNotEmpty || fcItems.isNotEmpty || mmItems.isNotEmpty || guideItems.isNotEmpty;
    final fileLabel = _resolveLessonFileLabel(l);

    if (!hasOtherPackages) {
      return [
        STIModuleSection(
          id: 'lesson_${l.id}',
          title: fileLabel,
          typeLabel: fileLabel,
          icon: Icons.menu_book_rounded,
          isSubmitted: isDone,
          status: isDone ? 'completed' : (isPart ? 'partial' : 'available'),
          onTap: () => NavigationService.instance.goToLesson(context, l),
        ),
      ];
    }

    final List<STIModuleSection> sections = [];
    int itemNumber = 1;

    // 1. Uploaded File / Reading Material
    sections.add(
      STIModuleSection(
        id: 'handout_${l.id}',
        title: '${itemNumber.toString().padLeft(2, '0')} $fileLabel',
        typeLabel: fileLabel,
        icon: Icons.description_outlined,
        isSubmitted: isDone,
        status: isDone ? 'completed' : (isPart ? 'partial' : 'available'),
        onTap: () => NavigationService.instance.goToLesson(context, l),
      ),
    );
    itemNumber++;

    // 2. Slides / Presentation
    for (final pres in presItems) {
      final isPresDone = widget.progressMap?[pres.id]?['completed'] == true;
      final isPresStarted = widget.progressMap?[pres.id] != null && !isPresDone;
      sections.add(
        STIModuleSection(
          id: 'slides_${pres.id}',
          title: '${itemNumber.toString().padLeft(2, '0')} Slides: ${pres.title.isNotEmpty ? pres.title : l.title}',
          typeLabel: 'Slides',
          icon: Icons.slideshow_rounded,
          isSubmitted: isPresDone,
          status: isPresDone ? 'completed' : (isPresStarted ? 'partial' : 'available'),
          onTap: () => NavigationService.instance.goToContent(context, pres),
        ),
      );
      itemNumber++;
    }

    // 3. Flashcards
    for (final fc in fcItems) {
      final isFcDone = widget.progressMap?[fc.id]?['completed'] == true;
      final isFcStarted = widget.progressMap?[fc.id] != null && !isFcDone;
      sections.add(
        STIModuleSection(
          id: 'flashcards_${fc.id}',
          title: '${itemNumber.toString().padLeft(2, '0')} Flashcards: ${fc.title.isNotEmpty ? fc.title : l.title}',
          typeLabel: 'Flashcards',
          icon: Icons.style_outlined,
          isSubmitted: isFcDone,
          status: isFcDone ? 'completed' : (isFcStarted ? 'partial' : 'available'),
          onTap: () => NavigationService.instance.goToContent(context, fc),
        ),
      );
      itemNumber++;
    }

    // 4. Mind Map
    for (final mm in mmItems) {
      final isMmDone = widget.progressMap?[mm.id]?['completed'] == true;
      final isMmStarted = widget.progressMap?[mm.id] != null && !isMmDone;
      sections.add(
        STIModuleSection(
          id: mm.id,
          title: '${itemNumber.toString().padLeft(2, '0')} Mind Map: ${mm.title}',
          typeLabel: 'Mind Map',
          icon: Icons.hub_outlined,
          isSubmitted: isMmDone,
          status: isMmDone ? 'completed' : (isMmStarted ? 'partial' : 'available'),
          onTap: () => NavigationService.instance.goToContent(context, mm),
        ),
      );
      itemNumber++;
    }

    // 5. Study Guide
    for (final sg in guideItems) {
      final isSgDone = widget.progressMap?[sg.id]?['completed'] == true;
      final isSgStarted = widget.progressMap?[sg.id] != null && !isSgDone;
      sections.add(
        STIModuleSection(
          id: sg.id,
          title: '${itemNumber.toString().padLeft(2, '0')} Study Guide: ${sg.title}',
          typeLabel: 'Study Guide',
          icon: Icons.menu_book_rounded,
          isSubmitted: isSgDone,
          status: isSgDone ? 'completed' : (isSgStarted ? 'partial' : 'available'),
          onTap: () => NavigationService.instance.goToContent(context, sg),
        ),
      );
      itemNumber++;
    }

    // 6. Quiz / Assessment
    if (hasQuiz) {
      final isQuizDone = widget.quizScore != null;
      sections.add(
        STIModuleSection(
          id: 'quiz_${l.id}',
          title: '${itemNumber.toString().padLeft(2, '0')} Quiz Assessment',
          typeLabel: 'Quiz',
          icon: Icons.quiz_outlined,
          isSubmitted: isQuizDone,
          score: widget.quizScore,
          status: isQuizDone ? 'completed' : 'available',
          onTap: () async {
            if (l.quizId != null && l.quizId!.isNotEmpty) {
              try {
                final qDoc = await DatabaseService.instance.getQuiz(l.quizId!);
                if (qDoc != null && context.mounted) {
                  NavigationService.instance.goToQuiz(
                    context,
                    qDoc,
                    notebookId: l.notebookId,
                    lesson: l,
                  );
                  return;
                }
              } catch (_) {}
            }
            if (context.mounted) {
              NavigationService.instance.goToLesson(context, l);
            }
          },
        ),
      );
    }

    return sections;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sections = _buildSections(context);
    final percent = (widget.progress * 100).toInt();

    final thumbGrad = _thumbGradients[widget.index % _thumbGradients.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Module Header (Screenshot 2) ─────────────────────────────
          InkWell(
            onTap: () {
              if (sections.length == 1 && sections.first.title == 'View Lesson') {
                sections.first.onTap();
              } else {
                widget.onExpansionChanged(!widget.isExpanded);
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left: Rounded Book/Subject Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 100,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: thumbGrad,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            right: -10,
                            bottom: -10,
                            child: Icon(
                              Icons.menu_book_rounded,
                              size: 48,
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                          Icon(
                            Icons.auto_stories_rounded,
                            color: Colors.white.withValues(alpha: 0.9),
                            size: 28,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Center: Title + Progress/Resume Pill
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${widget.index + 1}. ${widget.lesson.title}',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),

                        // Progress / Resume Pill
                        _buildResumePill(percent, isDark),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Right: N sections ∨ / ∧ or View Lesson button
                  InkWell(
                    onTap: () {
                      if (sections.length == 1 && sections.first.title == 'View Lesson') {
                        sections.first.onTap();
                      } else {
                        widget.onExpansionChanged(!widget.isExpanded);
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            sections.length == 1 && sections.first.title == 'View Lesson'
                                ? 'View Lesson'
                                : (sections.length == 1 ? '1 section' : '${sections.length} sections'),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: (sections.length == 1 && sections.first.title == 'View Lesson')
                                  ? const Color(0xFF0284C7)
                                  : (isDark ? Colors.white70 : const Color(0xFF475569)),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            (sections.length == 1 && sections.first.title == 'View Lesson')
                                ? Icons.arrow_forward_rounded
                                : (widget.isExpanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded),
                            color: (sections.length == 1 && sections.first.title == 'View Lesson')
                                ? const Color(0xFF0284C7)
                                : (isDark ? Colors.white70 : const Color(0xFF475569)),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded Sections Table (Screenshot 3) ───────────────────
          if (widget.isExpanded) ...[
            Divider(
              height: 1,
              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
            ),
            _buildSectionsTable(sections, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildResumePill(int percent, bool isDark) {
    final isDone = percent >= 100;
    final isStart = percent == 0;

    final pillBg = isDone
        ? const Color(0xFFDCFCE7)
        : (isStart
            ? (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9))
            : (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF)));

    final pillText = isDone
        ? '100% Completed'
        : (isStart ? '0% Start' : '$percent% Resume');

    final pillColor = isDone
        ? const Color(0xFF16A34A)
        : (isStart
            ? (isDark ? Colors.white70 : const Color(0xFF64748B))
            : const Color(0xFF2563EB));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: pillBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: pillColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circular progress ring
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              value: percent / 100.0,
              strokeWidth: 2.2,
              backgroundColor: pillColor.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(pillColor),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            pillText,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: pillColor,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            isDone ? Icons.check_rounded : Icons.play_arrow_rounded,
            size: 14,
            color: pillColor,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionsTable(List<STIModuleSection> sections, bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.3) : const Color(0xFFFAFAFA),
      child: Column(
        children: [
          // Table Header (Removed Due and Score columns as requested)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            child: Row(
              children: [
                Expanded(
                  flex: 6,
                  child: Text(
                    'Section',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Center(
                    child: Text(
                      'Submitted',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Center(
                    child: Text(
                      'Status',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Section Rows
          ...sections.map((sec) {
            return InkWell(
              onTap: sec.onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? const Color(0xFF334155).withValues(alpha: 0.4) : const Color(0xFFF1F5F9),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Section Name with Icon
                    Expanded(
                      flex: 6,
                      child: Row(
                        children: [
                          Icon(
                            sec.icon,
                            size: 18,
                            color: isDark ? Colors.white70 : const Color(0xFF334155),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              sec.title,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Submitted Column
                    Expanded(
                      flex: 3,
                      child: Center(
                        child: sec.isSubmitted
                            ? const Icon(Icons.check_rounded, color: Color(0xFF10B981), size: 16)
                            : const Text('-', style: TextStyle(color: Colors.grey)),
                      ),
                    ),

                    // Status Column
                    Expanded(
                      flex: 3,
                      child: Center(
                        child: _buildStatusIcon(sec.status),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(String status) {
    if (status == 'completed') {
      return const Icon(Icons.check_rounded, color: Color(0xFF10B981), size: 18);
    } else if (status == 'partial') {
      return const Text(
        '~',
        style: TextStyle(
          color: Color(0xFF334155),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      );
    }
    return const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 18);
  }
}

/// Stepped Vertical Timeline Side Tab (Screenshot 4)
/// Appears when opening a lesson, allowing learners to view course structure and navigate packages.
class STIModulesTimelineDrawer extends StatefulWidget {
  final List<Lesson> lessons;
  final String activeLessonId;
  final ValueChanged<Lesson> onSelectLesson;
  final VoidCallback? onClose;

  const STIModulesTimelineDrawer({
    super.key,
    required this.lessons,
    required this.activeLessonId,
    required this.onSelectLesson,
    this.onClose,
  });

  @override
  State<STIModulesTimelineDrawer> createState() => _STIModulesTimelineDrawerState();
}

class _STIModulesTimelineDrawerState extends State<STIModulesTimelineDrawer> {
  bool _expandAll = true;
  late Set<String> _expandedModuleIds;

  @override
  void initState() {
    super.initState();
    _expandedModuleIds = widget.lessons.map((l) => l.id).toSet();
  }

  void _toggleExpandAll() {
    setState(() {
      _expandAll = !_expandAll;
      if (_expandAll) {
        _expandedModuleIds = widget.lessons.map((l) => l.id).toSet();
      } else {
        _expandedModuleIds = {widget.activeLessonId};
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          left: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: _toggleExpandAll,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _expandAll
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 20,
                            color: isDark ? Colors.white70 : const Color(0xFF0F172A),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _expandAll ? 'Collapse all' : 'Expand all',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (widget.onClose != null)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: widget.onClose,
                      tooltip: 'Close sidebar',
                    ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Stepped Timeline List (Screenshot 4)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                itemCount: widget.lessons.length,
                itemBuilder: (context, i) {
                  final lesson = widget.lessons[i];
                  final isActive = lesson.id == widget.activeLessonId;
                  final isExpanded = _expandedModuleIds.contains(lesson.id);
                  final isLast = i == widget.lessons.length - 1;

                  return _buildTimelineStep(
                    index: i + 1,
                    lesson: lesson,
                    isActive: isActive,
                    isExpanded: isExpanded,
                    isLast: isLast,
                    isDark: isDark,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineStep({
    required int index,
    required Lesson lesson,
    required bool isActive,
    required bool isExpanded,
    required bool isLast,
    required bool isDark,
  }) {
    const activeColor = Color(0xFF0284C7); // STI cyan/blue tone
    final circleBg = isActive
        ? activeColor
        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));
    final circleText = isActive
        ? Colors.white
        : (isDark ? Colors.white70 : const Color(0xFF475569));

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step Circle & Connecting Vertical Line (Screenshot 4)
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: circleBg,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$index',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: circleText,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isActive ? activeColor : const Color(0xFF0284C7).withValues(alpha: 0.4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),

          // Module Title and Subsections
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Module Title Row
                InkWell(
                  onTap: () {
                    setState(() {
                      if (_expandedModuleIds.contains(lesson.id)) {
                        _expandedModuleIds.remove(lesson.id);
                      } else {
                        _expandedModuleIds.add(lesson.id);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            lesson.title,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isActive
                                  ? (isDark ? const Color(0xFF38BDF8) : activeColor)
                                  : (isDark ? Colors.white : const Color(0xFF0F172A)),
                            ),
                          ),
                        ),
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: isDark ? Colors.white54 : const Color(0xFF64748B),
                        ),
                      ],
                    ),
                  ),
                ),

                // Indented Sub-items
                if (isExpanded) ...[
                  const SizedBox(height: 6),
                  Builder(
                    builder: (builderContext) {
                      final hasQuiz = lesson.quizId != null && lesson.quizId!.isNotEmpty;
                      final notebookId = lesson.notebookId;
                      final fileLabel = _resolveLessonFileLabel(lesson);

                      if (!hasQuiz && (notebookId == null || notebookId.isEmpty)) {
                        return _buildSubItem(
                          icon: Icons.menu_book_rounded,
                          iconColor: const Color(0xFF0284C7),
                          label: fileLabel,
                          isDark: isDark,
                          onTap: () => widget.onSelectLesson(lesson),
                        );
                      }

                      return FutureBuilder<LinkedContentBundle>(
                        future: DatabaseService.instance.getLinkedContentBundle(
                          notebookId: notebookId,
                          currentLesson: lesson,
                        ),
                        builder: (ctx, snapshot) {
                          final bundle = snapshot.data;
                          final presItem = bundle?.publishedItems
                              .where((i) => i.type == NotebookOutputType.presentation)
                              .firstOrNull;
                          final fcItem = bundle?.publishedItems
                              .where((i) => i.type == NotebookOutputType.flashcards)
                              .firstOrNull;
                          final mmItem = bundle?.publishedItems
                              .where((i) => i.type == NotebookOutputType.mindMap)
                              .firstOrNull;
                          final sgItem = bundle?.publishedItems
                              .where((i) => i.type == NotebookOutputType.studyGuide)
                              .firstOrNull;

                          final hasCompanions = hasQuiz ||
                              presItem != null ||
                              fcItem != null ||
                              mmItem != null ||
                              sgItem != null;

                          if (!hasCompanions) {
                            return _buildSubItem(
                              icon: Icons.menu_book_rounded,
                              iconColor: const Color(0xFF0284C7),
                              label: fileLabel,
                              isDark: isDark,
                              onTap: () => widget.onSelectLesson(lesson),
                            );
                          }

                          int subNum = 1;
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildSubItem(
                                icon: Icons.check_rounded,
                                iconColor: const Color(0xFF0284C7),
                                label: '${subNum.toString().padLeft(2, '0')} $fileLabel',
                                isDark: isDark,
                                onTap: () => widget.onSelectLesson(lesson),
                              ),
                              if (presItem != null) ...[
                                Builder(builder: (_) {
                                  subNum++;
                                  return _buildSubItem(
                                    icon: Icons.slideshow_rounded,
                                    iconColor: const Color(0xFF2563EB),
                                    label: '${subNum.toString().padLeft(2, '0')} Presentation Slides',
                                    isDark: isDark,
                                    onTap: () => NavigationService.instance.goToContent(builderContext, presItem),
                                  );
                                }),
                              ],
                              if (fcItem != null) ...[
                                Builder(builder: (_) {
                                  subNum++;
                                  return _buildSubItem(
                                    icon: Icons.style_outlined,
                                    iconColor: const Color(0xFFEA580C),
                                    label: '${subNum.toString().padLeft(2, '0')} Flashcard Deck',
                                    isDark: isDark,
                                    onTap: () => NavigationService.instance.goToContent(builderContext, fcItem),
                                  );
                                }),
                              ],
                              if (mmItem != null) ...[
                                Builder(builder: (_) {
                                  subNum++;
                                  return _buildSubItem(
                                    icon: Icons.hub_outlined,
                                    iconColor: const Color(0xFF0D9488),
                                    label: '${subNum.toString().padLeft(2, '0')} Mind Map',
                                    isDark: isDark,
                                    onTap: () => NavigationService.instance.goToContent(builderContext, mmItem),
                                  );
                                }),
                              ],
                              if (sgItem != null) ...[
                                Builder(builder: (_) {
                                  subNum++;
                                  return _buildSubItem(
                                    icon: Icons.menu_book_rounded,
                                    iconColor: const Color(0xFF059669),
                                    label: '${subNum.toString().padLeft(2, '0')} Study Guide',
                                    isDark: isDark,
                                    onTap: () => NavigationService.instance.goToContent(builderContext, sgItem),
                                  );
                                }),
                              ],
                              if (hasQuiz) ...[
                                Builder(builder: (_) {
                                  subNum++;
                                  return _buildSubItem(
                                    icon: Icons.quiz_outlined,
                                    iconColor: const Color(0xFF8B5CF6),
                                    label: '${subNum.toString().padLeft(2, '0')} Quiz Assessment',
                                    isDark: isDark,
                                    onTap: () async {
                                      if (lesson.quizId != null && lesson.quizId!.isNotEmpty) {
                                        try {
                                          final q = await DatabaseService.instance.getQuiz(lesson.quizId!);
                                          if (q != null && builderContext.mounted) {
                                            NavigationService.instance.goToQuiz(
                                              builderContext,
                                              q,
                                              notebookId: lesson.notebookId,
                                              lesson: lesson,
                                            );
                                            return;
                                          }
                                        } catch (_) {}
                                      }
                                      widget.onSelectLesson(lesson);
                                    },
                                  );
                                }),
                              ],
                            ],
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ] else
                  const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubItem({
    IconData? icon,
    String? iconText,
    Color iconColor = const Color(0xFF64748B),
    required String label,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            if (icon != null)
              Icon(icon, size: 14, color: iconColor)
            else if (iconText != null)
              Text(
                iconText,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white60 : const Color(0xFF475569),
                ),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'spelling_bee_page.dart';
import 'pronunciation_quiz_page.dart';
import '../services/role_service.dart';
import 'admin/admin_assessments_tab.dart';
import 'ai_assessment_generator_page.dart';


class PracticeTab extends StatefulWidget {
  static final ValueNotifier<bool> isGenerating = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> isInPracticeActivity = ValueNotifier<bool>(false);
  static Future<bool> Function()? confirmExitActiveSession;

  static Future<bool> canLeavePracticeSession() async {
    final callback = confirmExitActiveSession;
    if (callback == null) return true;
    return await callback();
  }

  final int? initialSubTab;
  final bool initialShowEditor;
  const PracticeTab({
    super.key,
    this.initialSubTab,
    this.initialShowEditor = false,
  });

  @override
  State<PracticeTab> createState() => _PracticeTabState();
}

class _PracticeTabState extends State<PracticeTab> {
  late int? _selectedSubTab;
  bool _showAssessmentEditor = false;

  @override
  void initState() {
    super.initState();
    _selectedSubTab = widget.initialSubTab;
    _showAssessmentEditor = widget.initialShowEditor;
    PracticeTab.isInPracticeActivity.value = _selectedSubTab != null;
  }

  void _setSubTab(int? subTab, {bool? showEditor}) {
    setState(() {
      _selectedSubTab = subTab;
      if (showEditor != null) {
        _showAssessmentEditor = showEditor;
      }
    });
    PracticeTab.isInPracticeActivity.value = subTab != null;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Please login first'));

    return StreamBuilder<UserRole>(
      stream: RoleService.instance.roleStream(user.uid),
      builder: (context, roleSnap) {
        final role = roleSnap.data;
        final isAdmin =
            role == UserRole.admin ||
            role == UserRole.superadmin ||
            role == UserRole.educator;

        if (_selectedSubTab == 0) {
          return SpellingBeePage(
            user: user,
            onBack: () => _setSubTab(null),
          );
        }
        if (_selectedSubTab == 1) {
          return PronunciationQuizPage(
            user: user,
            onBack: () => _setSubTab(null),
          );
        }
        // English Assessment sub-tab
        if (_selectedSubTab == 2) {
          return Column(
            children: [
              // Top toolbar with AI Assessment button + optional Manage toggle
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Spacer(),
                    if (isAdmin)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                              value: false,
                              label: Text('View'),
                              icon: Icon(Icons.visibility),
                            ),
                            ButtonSegment(
                              value: true,
                              label: Text('Manage'),
                              icon: Icon(Icons.edit),
                            ),
                          ],
                          selected: {_showAssessmentEditor},
                          onSelectionChanged: (val) {
                            setState(() => _showAssessmentEditor = val.first);
                          },
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: _showAssessmentEditor
                    ? Scaffold(
                        appBar: AppBar(
                          leading: IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () => _setSubTab(null, showEditor: false),
                          ),
                          title: const Text('Assessment Editor'),
                        ),
                        body: const AdminAssessmentsTab(isEmbedded: false),
                      )
                    : AiAssessmentGeneratorPage(
                        user: user,
                        onBack: () => _setSubTab(null),
                      ),
              ),
            ],
          );
        }


        return _PracticeToolsHome(
          onSelectTool: (index) => _setSubTab(index),
        );
      },
    );
  }
}

// ─── Practice Tools Home ──────────────────────────────────────────────────────

class _PracticeToolsHome extends StatelessWidget {
  final void Function(int index) onSelectTool;
  const _PracticeToolsHome({required this.onSelectTool});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      color: isDark
          ? const Color(0xFF121212)
          : const Color(0xFFFAFAFA), // Soft minimalist off-white or dark
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            top: isDesktop ? 68 : 36,
            bottom: isDesktop ? 64 : 36,
            left: isDesktop ? 36 : 16,
            right: isDesktop ? 36 : 16,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Main Centered Header
                Text(
                  'Practice & Master',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: isDesktop ? 38 : 28,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    height: 1.15,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 12),

                // Subtitle
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Text(
                    'Choose a tool below to practice spelling, perfect your pronunciation, review spaced-repetition decks, or take assessments.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      color: isDark
                          ? Colors.grey[400]
                          : const Color(0xFF64748B),
                      height: 1.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),

                SizedBox(height: isDesktop ? 48 : 28),

                // Cards Row / Column - balanced proportions
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1060),
                  child: isDesktop
                      ? IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _PracticeCard(
                                  title: 'Spelling Bee',
                                  subtitle:
                                      'Interactive spelling challenges with audio prompts across difficulty levels.',
                                  tag: 'VOCABULARY',
                                  icon: Icons.emoji_nature_rounded,
                                  themeColor: const Color(0xFFF59E0B),
                                  highlights: const [
                                    'Audio pronunciation cues',
                                    'Adaptive difficulty tiers',
                                    'Score & streak tracking',
                                  ],
                                  onTap: () => onSelectTool(0),
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: _PracticeCard(
                                  title: 'Pronunciation',
                                  subtitle:
                                      'Practice speaking with real-time speech recognition & accuracy scoring.',
                                  tag: 'SPEAKING',
                                  icon: Icons.graphic_eq_rounded,
                                  themeColor: const Color(0xFF81B655),
                                  highlights: const [
                                    'Speech AI evaluation',
                                    'Instant accent & clarity feedback',
                                    'Real-time phonetic guidance',
                                  ],
                                  onTap: () => onSelectTool(1),
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: _PracticeCard(
                                  title: 'English Assessment',
                                  subtitle:
                                      'Comprehensive grammar tests with instant evaluation & certificates.',
                                  tag: 'EVALUATION',
                                  icon: Icons.verified_rounded,
                                  themeColor: const Color(0xFFEF4444),
                                  highlights: const [
                                    'Standardized grammar tests',
                                    'Instant scoring & analytics',
                                    'Certificate of achievement',
                                  ],
                                  onTap: () => onSelectTool(2),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            _PracticeCard(
                              title: 'Spelling Bee',
                              subtitle:
                                  'Interactive spelling challenges with audio prompts across difficulty levels.',
                              tag: 'VOCABULARY',
                              icon: Icons.emoji_nature_rounded,
                              themeColor: const Color(0xFFF59E0B),
                              highlights: const [
                                'Audio pronunciation cues',
                                'Adaptive difficulty tiers',
                                'Score & streak tracking',
                              ],
                              onTap: () => onSelectTool(0),
                            ),
                            const SizedBox(height: 20),
                            _PracticeCard(
                              title: 'Pronunciation',
                              subtitle:
                                  'Practice speaking with real-time speech recognition & accuracy scoring.',
                              tag: 'SPEAKING',
                              icon: Icons.graphic_eq_rounded,
                              themeColor: const Color(0xFF81B655),
                              highlights: const [
                                'Speech AI evaluation',
                                'Instant accent & clarity feedback',
                                'Real-time phonetic guidance',
                              ],
                              onTap: () => onSelectTool(1),
                            ),
                            const SizedBox(height: 20),
                            _PracticeCard(
                              title: 'English Assessment',
                              subtitle:
                                  'Comprehensive grammar tests with instant evaluation & certificates.',
                              tag: 'EVALUATION',
                              icon: Icons.verified_rounded,
                              themeColor: const Color(0xFFEF4444),
                              highlights: const [
                                'Standardized grammar tests',
                                'Instant scoring & analytics',
                                'Certificate of achievement',
                              ],
                              onTap: () => onSelectTool(2),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Practice Card ────────────────────────────────────────────────────────────

class _PracticeCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String tag;
  final IconData icon;
  final Color themeColor;
  final List<String> highlights;
  final VoidCallback onTap;

  const _PracticeCard({
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.icon,
    required this.themeColor,
    this.highlights = const [],
    required this.onTap,
  });

  @override
  State<_PracticeCard> createState() => _PracticeCardState();
}

class _PracticeCardState extends State<_PracticeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 1.025,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) {
        setState(() => _hovered = true);
        _ctrl.forward();
      },
      onExit: (_) {
        setState(() => _hovered = false);
        _ctrl.reverse();
      },
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _scale,
          builder: (context, child) =>
              Transform.scale(scale: _scale.value, child: child),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            constraints: BoxConstraints(minHeight: isDesktop ? 410 : 330),
            padding: EdgeInsets.symmetric(
              horizontal: 28,
              vertical: isDesktop ? 36 : 24,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _hovered
                    ? widget.themeColor.withValues(alpha: 0.5)
                    : (isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0)),
                width: _hovered ? 1.8 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: _hovered
                      ? widget.themeColor.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.03),
                  blurRadius: _hovered ? 24 : 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row: Tag & Icon
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: widget.themeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            widget.tag,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: widget.themeColor,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: _hovered
                                ? widget.themeColor
                                : widget.themeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            widget.icon,
                            color: _hovered ? Colors.white : widget.themeColor,
                            size: 26,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Title
                    Text(
                      widget.title,
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Subtitle
                    Text(
                      widget.subtitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        height: 1.55,
                        color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                      ),
                    ),

                    // Key Highlights (makes the card taller, informative & balanced)
                    if (widget.highlights.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      ...widget.highlights.map(
                        (h) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 16,
                                color: widget.themeColor,
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  h,
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 28),

                // Action Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: _hovered
                          ? widget.themeColor
                          : widget.themeColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _hovered
                            ? Colors.transparent
                            : widget.themeColor.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Start Practice',
                            style: GoogleFonts.outfit(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: _hovered
                                  ? Colors.white
                                  : widget.themeColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: _hovered ? Colors.white : widget.themeColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

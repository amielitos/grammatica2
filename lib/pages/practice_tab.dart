import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'spelling_bee_page.dart';
import 'pronunciation_quiz_page.dart';
import '../services/role_service.dart';
import 'admin/admin_assessments_tab.dart';
import 'ai_assessment_generator_page.dart';

class PracticeTab extends StatefulWidget {
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
            onBack: () => setState(() => _selectedSubTab = null),
          );
        }
        if (_selectedSubTab == 1) {
          return PronunciationQuizPage(
            user: user,
            onBack: () => setState(() => _selectedSubTab = null),
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
                            onPressed: () => setState(() {
                              _showAssessmentEditor = false;
                              _selectedSubTab = null;
                            }),
                          ),
                          title: const Text('Assessment Editor'),
                        ),
                        body: const AdminAssessmentsTab(isEmbedded: false),
                      )
                    : AiAssessmentGeneratorPage(
                        user: user,
                        onBack: () => setState(() => _selectedSubTab = null),
                      ),
              ),
            ],
          );
        }

        return _PracticeToolsHome(
          onSelectTool: (index) => setState(() => _selectedSubTab = index),
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
      color: isDark ? const Color(0xFF121212) : const Color(0xFFFAFAFA), // Soft minimalist off-white or dark
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 48 : 20,
            vertical: 48,
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
                    fontSize: isDesktop ? 44 : 32,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    height: 1.15,
                    letterSpacing: -1.0,
                  ),
                ),
                const SizedBox(height: 10),

                // Subtitle
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Text(
                    'Choose a tool below to practice spelling, perfect your pronunciation, or take English assessments.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                      height: 1.55,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                // Cards Row / Column
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: isDesktop
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: _PracticeCard(
                                title: 'Spelling Bee',
                                subtitle:
                                    'Interactive spelling challenges with audio prompts across difficulty levels.',
                                tag: 'VOCABULARY',
                                icon: Icons.emoji_nature_rounded,
                                themeColor: const Color(0xFFF59E0B),
                                onTap: () => onSelectTool(0),
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: _PracticeCard(
                                title: 'Pronunciation',
                                subtitle:
                                    'Practice speaking with real-time speech recognition & accuracy scoring.',
                                tag: 'SPEAKING',
                                icon: Icons.graphic_eq_rounded,
                                themeColor: const Color(0xFF81B655),
                                onTap: () => onSelectTool(1),
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: _PracticeCard(
                                title: 'English Assessment',
                                subtitle:
                                    'Comprehensive grammar tests with instant evaluation & certificates.',
                                tag: 'EVALUATION',
                                icon: Icons.verified_rounded,
                                themeColor: const Color(0xFFEF4444),
                                onTap: () => onSelectTool(2),
                              ),
                            ),
                          ],
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
  final VoidCallback onTap;

  const _PracticeCard({
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.icon,
    required this.themeColor,
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
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _hovered
                    ? widget.themeColor.withValues(alpha: 0.5)
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                width: _hovered ? 1.8 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: _hovered
                      ? widget.themeColor.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.03),
                  blurRadius: _hovered ? 30 : 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top Tag Chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: widget.themeColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.tag,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: widget.themeColor,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Icon Box
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: _hovered
                        ? widget.themeColor
                        : widget.themeColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.icon,
                    color: _hovered ? Colors.white : widget.themeColor,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),

                // Subtitle
                Text(
                  widget.subtitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    height: 1.55,
                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 32),

                // Action Button
                SizedBox(
                  width: double.infinity,
                  height: 46,
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
                              fontSize: 14,
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

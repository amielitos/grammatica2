import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../config/ai_config.dart';
import 'ai_lesson_generator_tab.dart';
import 'ai_quiz_generator_tab.dart';
import 'ai_spelling_studio_tab.dart';

/// The AI Studio / AI Hub — a dedicated workspace for all AI-powered features.
///
/// Accessible from the admin/educator navigation drawer. Provides tabbed
/// access to Lesson Generation, Quiz Generation, and Vocabulary Studio.
class AiHubPage extends StatefulWidget {
  const AiHubPage({super.key});

  @override
  State<AiHubPage> createState() => _AiHubPageState();
}

class _AiHubPageState extends State<AiHubPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<_AiTab> _tabs = const [
    _AiTab(icon: Icons.auto_stories, label: 'Lesson Generator'),
    _AiTab(icon: Icons.quiz, label: 'Quiz Generator'),
    _AiTab(icon: Icons.spellcheck, label: 'Vocabulary Studio'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 800;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // ── Header with gradient ───────────────────────────────────────
          _buildHeader(context, isDark, isWide),

          // ── Tab bar ────────────────────────────────────────────────────
          _buildTabBar(isDark),

          // ── Tab content ────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                AiLessonGeneratorTab(),
                AiQuizGeneratorTab(),
                AiSpellingStudioTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Header
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, bool isDark, bool isWide) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1A2744), const Color(0xFF0D1B2A)]
              : [const Color(0xFF4A7C59), AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 48 : 20,
        vertical: isWide ? 32 : 20,
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back button + title row
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Back',
                ),
                const SizedBox(width: 8),
                // Animated sparkle icon
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) => Transform.scale(
                    scale: value,
                    child: child,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child:
                        const Icon(Icons.psychology, color: Colors.white, size: 28),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Studio',
                        style: GoogleFonts.outfit(
                          fontSize: isWide ? 28 : 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Powered by Gemini',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                // Mode badge
                _buildModeBadge(isDark),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeBadge(bool isDark) {
    Color badgeColor;
    IconData badgeIcon;
    String badgeLabel;

    switch (AIConfig.mode) {
      case AIExecutionMode.firebaseAI:
        badgeColor = Colors.amberAccent;
        badgeIcon = Icons.local_fire_department;
        badgeLabel = 'Firebase AI';
        break;
      case AIExecutionMode.directClientSide:
        badgeColor = Colors.tealAccent;
        badgeIcon = Icons.bolt;
        badgeLabel = 'Client-Side';
        break;
      case AIExecutionMode.pythonBackend:
        badgeColor = Colors.orangeAccent;
        badgeIcon = Icons.cloud;
        badgeLabel = 'Backend';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: 14, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            badgeLabel,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Tab Bar
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTabBar(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF252525) : Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: AppColors.primary,
        unselectedLabelColor:
            isDark ? Colors.white54 : AppColors.textSecondary,
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        labelStyle: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 14,
        ),
        tabs: _tabs
            .map((t) => Tab(
                  icon: Icon(t.icon, size: 20),
                  text: t.label,
                ))
            .toList(),
      ),
    );
  }
}

class _AiTab {
  final IconData icon;
  final String label;
  const _AiTab({required this.icon, required this.label});
}

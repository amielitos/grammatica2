import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/design_ornaments.dart';
import '../widgets/terms_and_conditions_dialog.dart';
import '../services/auth_service.dart';

class OnboardingPage extends StatefulWidget {
  final User user;
  const OnboardingPage({super.key, required this.user});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _agreedToTerms = false;
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (AuthService.justSignedUpWithGoogle) {
        AuthService.justSignedUpWithGoogle = false;
        _showWelcomeModal();
      }
    });
  }

  void _showWelcomeModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF81B655), Color(0xFF5A8E30)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF81B655).withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.check_circle_rounded, color: Colors.white, size: 52),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "Welcome to Grammatica!",
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  "We've sent a temporary password to your email. You can use it to login directly next time!",
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF81B655),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        "Let's Explore!",
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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

  final List<OnboardingStep> _steps = [
    OnboardingStep(
      pill: 'WELCOME',
      title: 'Welcome to Grammatica',
      description: 'Your journey to mastering the English language starts here. Let\'s get you settled into your new learning sanctuary.',
      icon: Icons.auto_awesome_rounded,
      accentColor: const Color(0xFF81B655),
    ),
    OnboardingStep(
      pill: 'LESSONS',
      title: 'Interactive Lessons',
      description: 'Explore bite-sized, engaging lessons designed by experts to make grammar intuitive, structured, and fun.',
      icon: Icons.menu_book_rounded,
      accentColor: const Color(0xFF3B82F6),
    ),
    OnboardingStep(
      pill: 'CHALLENGES',
      title: 'Real-time Challenges',
      description: 'Test your skills with interactive quizzes, spelling bee tests, and track your achievements as you level up.',
      icon: Icons.psychology_rounded,
      accentColor: const Color(0xFFF59E0B),
    ),
    OnboardingStep(
      pill: 'COMMUNITY',
      title: 'Expert Community',
      description: 'Connect with verified educators and fellow learners in a supportive, growth-oriented environment.',
      icon: Icons.groups_rounded,
      accentColor: const Color(0xFF8B5CF6),
    ),
    OnboardingStep(
      pill: 'GET STARTED',
      title: 'Ready to Begin?',
      description: 'Dive into your first lesson and unlock your full linguistic potential with verified feedback.',
      icon: Icons.rocket_launch_rounded,
      accentColor: const Color(0xFF10B981),
      isLast: true,
    ),
  ];

  Future<void> _completeOnboarding() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .update({'has_completed_onboarding': true});
    } catch (e) {
      debugPrint('Error updating onboarding status: $e');
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isLarge = size.width >= 768;

    return Scaffold(
      body: BackgroundWrapper(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isLarge ? 32 : 16,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header Bar
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Image.asset(
                                  'assets/logo.png',
                                  height: 28,
                                  errorBuilder: (context, error, stackTrace) => const Icon(
                                    Icons.auto_stories_rounded,
                                    color: Color(0xFF81B655),
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Grammatica',
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: TextButton(
                                onPressed: _completeOnboarding,
                                style: TextButton.styleFrom(
                                  foregroundColor: isDark ? Colors.white60 : const Color(0xFF64748B),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                ),
                                child: Text(
                                  'Skip',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Divider(height: 1),

                      // Carousel Body
                      SizedBox(
                        height: 400,
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() => _currentPage = index);
                          },
                          itemCount: _steps.length,
                          itemBuilder: (context, index) {
                            final step = _steps[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 36.0, vertical: 20),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Step Category Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: step.accentColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(100),
                                      border: Border.all(
                                        color: step.accentColor.withValues(alpha: 0.25),
                                      ),
                                    ),
                                    child: Text(
                                      'STEP ${index + 1} OF ${_steps.length} • ${step.pill}',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: step.accentColor,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // Glowing Themed Icon
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          step.accentColor.withValues(alpha: 0.2),
                                          step.accentColor.withValues(alpha: 0.05),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      border: Border.all(
                                        color: step.accentColor.withValues(alpha: 0.3),
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: step.accentColor.withValues(alpha: 0.15),
                                          blurRadius: 20,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Icon(
                                        step.icon,
                                        size: 46,
                                        color: step.accentColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 28),

                                  // Title
                                  Text(
                                    step.title,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.outfit(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Description
                                  Text(
                                    step.description,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                                      height: 1.55,
                                    ),
                                  ),

                                  // Terms and conditions on last step
                                  if (step.isLast) ...[
                                    const SizedBox(height: 18),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.6) : const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          MouseRegion(
                                            cursor: SystemMouseCursors.click,
                                            child: Checkbox(
                                              value: _agreedToTerms,
                                              activeColor: const Color(0xFF81B655),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                              onChanged: (val) async {
                                                if (val == true) {
                                                  final accepted = await showDialog<bool>(
                                                    context: context,
                                                    builder: (context) => const TermsAndConditionsDialog(),
                                                  );
                                                  if (accepted == true) {
                                                    setState(() => _agreedToTerms = true);
                                                  }
                                                } else {
                                                  setState(() => _agreedToTerms = false);
                                                }
                                              },
                                            ),
                                          ),
                                          Expanded(
                                            child: MouseRegion(
                                              cursor: SystemMouseCursors.click,
                                              child: GestureDetector(
                                                onTap: () async {
                                                  if (!_agreedToTerms) {
                                                    final accepted = await showDialog<bool>(
                                                      context: context,
                                                      builder: (context) => const TermsAndConditionsDialog(),
                                                    );
                                                    if (accepted == true) {
                                                      setState(() => _agreedToTerms = true);
                                                    }
                                                  } else {
                                                    setState(() => _agreedToTerms = false);
                                                  }
                                                },
                                                child: Text.rich(
                                                  TextSpan(
                                                    text: 'I agree to the ',
                                                    style: GoogleFonts.inter(fontSize: 12.5, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                                                    children: const [
                                                      TextSpan(
                                                        text: 'Terms & Conditions',
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          color: Color(0xFF81B655),
                                                          decoration: TextDecoration.underline,
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
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      const Divider(height: 1),

                      // Bottom Navigation Area
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Progress dots
                            Row(
                              children: List.generate(
                                _steps.length,
                                (index) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  margin: const EdgeInsets.only(right: 8),
                                  height: 8,
                                  width: _currentPage == index ? 28 : 8,
                                  decoration: BoxDecoration(
                                    color: _currentPage == index
                                        ? _steps[_currentPage].accentColor
                                        : (isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),

                            // Next / Finish Button
                            if (_steps[_currentPage].isLast)
                              MouseRegion(
                                cursor: _agreedToTerms ? SystemMouseCursors.click : SystemMouseCursors.basic,
                                child: ElevatedButton(
                                  onPressed: _agreedToTerms ? _completeOnboarding : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF81B655),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: _isCompleting
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : Text(
                                          'GET STARTED',
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                ),
                              )
                            else
                              MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: ElevatedButton(
                                  onPressed: () {
                                    _pageController.nextPage(
                                      duration: const Duration(milliseconds: 400),
                                      curve: Curves.fastOutSlowIn,
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _steps[_currentPage].accentColor,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Next',
                                        style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.arrow_forward_rounded, size: 16),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingStep {
  final String pill;
  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;
  final bool isLast;

  OnboardingStep({
    required this.pill,
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
    this.isLast = false,
  });
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';
import '../widgets/terms_and_conditions_dialog.dart';

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

  final List<OnboardingStep> _steps = [
    OnboardingStep(
      title: 'Welcome to Grammatica!',
      description:
          'Your journey to mastering grammar starts here. Let\'s get you settled in.',
      icon: CupertinoIcons.sparkles,
      color: AppColors.salmonBackground,
    ),
    OnboardingStep(
      title: 'Learn with Lessons',
      description:
          'Explore interactive lessons designed to make grammar easy and fun.',
      icon: CupertinoIcons.book,
      color: AppColors.primaryGreen,
    ),
    OnboardingStep(
      title: 'Test Your Skills',
      description:
          'Take quizzes to track your progress and reinforce what you\'ve learned.',
      icon: CupertinoIcons.question_circle,
      color: Colors.blue,
    ),
    OnboardingStep(
      title: 'Personalize Your Profile',
      description:
          'Keep track of your achievements and customize your learning experience.',
      icon: CupertinoIcons.person,
      color: Colors.purple,
    ),
    OnboardingStep(
      title: 'You\'re all set!',
      description: 'Ready to dive in? Click finish to start your first lesson.',
      icon: CupertinoIcons.check_mark_circled,
      color: AppColors.primaryGreen,
      isLast: true,
    ),
  ];

  Future<void> _completeOnboarding() async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid)
        .update({'has_completed_onboarding': true});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              AppColors.salmonBackground.withOpacity(0.1),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemCount: _steps.length,
                  itemBuilder: (context, index) {
                    final step = _steps[index];
                    return Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(30),
                            decoration: BoxDecoration(
                              color: step.color.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              step.icon,
                              size: 100,
                              color: step.color,
                            ),
                          ),
                          const SizedBox(height: 48),
                          Text(
                            step.title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.displaySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            step.description,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.color,
                                ),
                          ),

                          if (step.isLast) ...[
                            const SizedBox(height: 24),
                            // Terms and Conditions Logic
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Checkbox(
                                  value: _agreedToTerms,
                                  activeColor: AppColors.primaryGreen,
                                  onChanged: (val) async {
                                    if (val == true) {
                                      // User trying to check - show dialog
                                      final accepted = await showDialog<bool>(
                                        context: context,
                                        builder: (context) =>
                                            const TermsAndConditionsDialog(),
                                      );
                                      if (accepted == true) {
                                        setState(() => _agreedToTerms = true);
                                      }
                                    } else {
                                      // User unchecking - allow immediately
                                      setState(() => _agreedToTerms = false);
                                    }
                                  },
                                ),
                                Flexible(
                                  child: GestureDetector(
                                    onTap: () async {
                                      if (!_agreedToTerms) {
                                        final accepted = await showDialog<bool>(
                                          context: context,
                                          builder: (context) =>
                                              const TermsAndConditionsDialog(),
                                        );
                                        if (accepted == true) {
                                          setState(() => _agreedToTerms = true);
                                        }
                                      } else {
                                        setState(() => _agreedToTerms = false);
                                      }
                                    },
                                    child: Text(
                                      'I agree to the Terms and Conditions',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            decoration:
                                                TextDecoration.underline,
                                            color: Colors.blue,
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 20,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Indicator
                    Row(
                      children: List.generate(
                        _steps.length,
                        (index) => Container(
                          margin: const EdgeInsets.only(right: 8),
                          height: 8,
                          width: _currentPage == index ? 24 : 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? AppColors.salmonBackground
                                : Colors.grey.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    // Button
                    if (_steps[_currentPage].isLast)
                      ElevatedButton(
                        onPressed: _agreedToTerms ? _completeOnboarding : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          disabledBackgroundColor: Colors.grey.shade300,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                        child: const Text('Finish'),
                      )
                    else
                      IconButton(
                        onPressed: () {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        iconSize: 32,
                        color: AppColors.salmonBackground,
                        icon: const Icon(
                          CupertinoIcons.arrow_right_circle_fill,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingStep {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isLast;

  OnboardingStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.isLast = false,
  });
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import '../services/email_validator_service.dart';

import 'package:flutter/services.dart';
import '../widgets/google_sign_in_button.dart';
import '../widgets/design_ornaments.dart';

import '../widgets/top_nav_bar.dart';
import 'otp_verification_page.dart';
import '../services/notification_service.dart';
import '../widgets/tagline_hero_text.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _pageController = PageController();
  int _currentStep = 0;

  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();
  final _formKey3 = GlobalKey<FormState>();

  // Role Selection
  String _selectedRole = 'learner'; // 'learner' or 'validator'

  // Step 1 Controllers
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _dobController = TextEditingController();
  String? _selectedSuffix;
  final List<String> _suffixes = ['None', 'Jr.', 'Sr.', 'III', 'IV', 'V'];

  // Step 2 Controllers
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isEmailTaken = false;
  bool _isInvalidDomain = false;
  bool _isValidatingEmail = false;
  Timer? _emailDebounceTimer;

  // Step 3 Controllers
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  bool _isLoading = false;
  DateTime? _selectedDate;
  bool _agreedToTerms = false;
  bool _hasScrolledToBottom = false;
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    AuthService.preferredGoogleRole = _selectedRole;
    _authSubscription = AuthService.instance.authStateChanges().listen((user) {
      if (user != null && mounted) {
        final isGoogleUser = user.providerData.any(
          (p) => p.providerId == GoogleAuthProvider.PROVIDER_ID,
        );
        if (isGoogleUser) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    });
  }

  void _onEmailChanged(String val) {
    _emailDebounceTimer?.cancel();
    if (_isEmailTaken || _isInvalidDomain) {
      setState(() {
        _isEmailTaken = false;
        _isInvalidDomain = false;
      });
    }
    final email = val.trim();
    if (email.isEmpty) return;

    _emailDebounceTimer = Timer(const Duration(milliseconds: 700), () async {
      if (!mounted) return;
      final current = _emailController.text.trim();
      if (current.isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(current)) {
        return;
      }

      if (!EmailValidatorService.isAllowedEmail(current)) {
        if (mounted) {
          setState(() {
            _isInvalidDomain = true;
            _isEmailTaken = false;
            _isValidatingEmail = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() => _isValidatingEmail = true);
      }
      final taken = await AuthService.instance.isEmailTaken(current);
      if (mounted && _emailController.text.trim() == current) {
        setState(() {
          _isEmailTaken = taken;
          _isValidatingEmail = false;
        });
      }
    });
  }


  Future<void> _selectDate(BuildContext context) async {
    final bool isValidator = _selectedRole == 'validator';
    final DateTime maxAllowedDate = isValidator
        ? DateTime(2005, 12, 31)
        : DateTime(2014, 12, 31);
    DateTime defaultInitDate = isValidator
        ? DateTime(2005, 1, 1)
        : DateTime(2014, 1, 1);
    if (_selectedDate != null) {
      defaultInitDate = _selectedDate!.isAfter(maxAllowedDate) ? maxAllowedDate : _selectedDate!;
    }
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: defaultInitDate,
      firstDate: DateTime(1900),
      lastDate: maxAllowedDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF81B655),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dobController.text = "${picked.month}/${picked.day}/${picked.year}";
      });
    }
  }

  bool _hasMinLength(String p) => p.length >= 8;
  bool _hasUppercase(String p) => p.contains(RegExp(r'[A-Z]'));
  bool _hasLowercase(String p) => p.contains(RegExp(r'[a-z]'));
  bool _hasDigit(String p) => p.contains(RegExp(r'[0-9]'));
  bool _hasSpecial(String p) => p.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>~_\-+=]'));

  String _getPasswordStrength() {
    String pass = _passwordController.text;
    if (pass.isEmpty) return "";
    int score = 0;
    if (_hasMinLength(pass)) score++;
    if (_hasUppercase(pass)) score++;
    if (_hasLowercase(pass)) score++;
    if (_hasDigit(pass)) score++;
    if (_hasSpecial(pass)) score++;

    if (score == 5) return "Strong";
    if (score >= 3) return "Medium";
    return "Weak";
  }

  Color _getStrengthColor() {
    String strength = _getPasswordStrength();
    if (strength == "Strong") return const Color(0xFF16A34A);
    if (strength == "Medium") return Colors.orange;
    if (strength.contains("Weak")) return Colors.red;
    return Colors.grey;
  }

  void _showTermsModal() {
    final scrollController = ScrollController();
    _hasScrolledToBottom = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            scrollController.addListener(() {
              if (scrollController.position.pixels >= scrollController.position.maxScrollExtent - 10) {
                if (!_hasScrolledToBottom) {
                  setModalState(() => _hasScrolledToBottom = true);
                  setState(() => _agreedToTerms = true);
                }
              }
            });

            final isDark = Theme.of(context).brightness == Brightness.dark;
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text("Terms & Privacy Policy", style: TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 500,
                height: 400,
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? Colors.white12 : Colors.grey[300]!),
                        ),
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "GRAMMATICA — TERMS AND CONDITIONS",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Effective Date: October 31, 2026",
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontStyle: FontStyle.italic,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "1. Introduction\n"
                                "Grammatica is an AI-assisted English learning application that provides interactive lessons, educational activities, assessments, and learning support. By using the platform, users agree to these Terms and Conditions.\n\n"
                                "2. User Roles\n"
                                "Grammatica supports four user roles:\n"
                                "• Learners: Access lessons, complete activities, track progress, enroll in Educators, and apply for the Educator role.\n"
                                "• Educators: Create lessons, quizzes, and learning materials, manage enrolled learners, and conduct mentorship sessions.\n"
                                "• Validators: Review educational content and applications, then approve or reject submissions.\n"
                                "• Super-Admins: Manage accounts, official lessons, applications, platform content, and system settings.\n\n"
                                "3. Accounts and Security\n"
                                "Users must provide accurate registration details and protect their login credentials. Unauthorized account access and misuse of another user's information are prohibited.\n\n"
                                "4. Educator Applications\n"
                                "Applicants must submit the required credentials for review. Approval depends on the platform's validation process and does not guarantee acceptance.\n\n"
                                "5. Enrollment and Access\n"
                                "Learners may browse Educators and enroll to access eligible courses, custom lessons, members-only content, and mentorship sessions. Removing an enrollment may affect access to restricted materials.\n\n"
                                "6. Educational Content\n"
                                "Users must submit appropriate educational materials and respect intellectual property rights. Grammatica may reject or archive content that violates platform guidelines. Archived lessons may be permanently deleted after 30 days if not restored.\n\n"
                                "7. Artificial Intelligence\n"
                                "Grammatica uses Google Gemini cloud services to assist in generating lessons, quizzes, and other educational materials. AI-generated content may contain errors and should be reviewed before educational use.\n\n"
                                "8. Practice and Assessments\n"
                                "Grammatica offers grammar, spelling, pronunciation, and English assessment activities. Speech recognition and pronunciation analysis are limited to English. Results do not guarantee specific learning outcomes.\n\n"
                                "9. Mentorship Sessions\n"
                                "Learners may schedule one-on-one sessions with Educators through supported conferencing services, including Google Meet, Zoom, and Microsoft Teams. Users must follow agreed schedules and respect other participants.\n\n"
                                "10. User Conduct\n"
                                "Users must not engage in harassment, upload harmful content, manipulate learning results, bypass security controls, or use Grammatica for unlawful activities. Violations may result in account restrictions or suspension.\n\n"
                                "11. Intellectual Property\n"
                                "Grammatica's software, branding, and original materials are protected by applicable laws. Users must not reproduce or distribute protected content without authorization.\n\n"
                                "12. Account Deactivation and Deletion\n"
                                "Eligible Learners, Educators, and Validators may deactivate or delete their accounts through available settings. Super-Admin accounts cannot be deleted through standard profile settings. Certain records may be retained when required by law.\n\n"
                                "13. Service Limitations\n"
                                "Grammatica depends on internet connectivity and external services for certain features. AI generation uses cloud-based models, while institutional multi-tenant administration, LMS LTI 1.3, and SCORM compliance are not supported.\n\n"
                                "14. Limitation of Liability\n"
                                "Grammatica does not guarantee uninterrupted service, error-free AI-generated content, or specific educational results. Nothing in these terms excludes liability that cannot legally be excluded.\n\n"
                                "15. Changes to Terms\n"
                                "Grammatica may update these terms as its features and services change. Revised terms will include an updated effective date.\n\n"
                                "16. Governing Law\n"
                                "These terms are governed by applicable laws of the Republic of the Philippines.\n\n"
                                "17. Contact Information\n"
                                "For questions or concerns, contact Grammatica through its official support channel.\n"
                                "Email: grammatica.support@gmail.com",
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Divider(),
                              const SizedBox(height: 16),
                              Text(
                                "GRAMMATICA — PRIVACY POLICY",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Effective Date: October 31, 2026",
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontStyle: FontStyle.italic,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "1. Introduction\n"
                                "Grammatica values the privacy of its users. This Privacy Policy explains how personal information is collected, used, stored, and protected when using the platform.\n\n"
                                "2. Information We Collect\n"
                                "Grammatica may collect the following information:\n"
                                "• Personal details, including name, email address, phone number, and date of birth.\n"
                                "• Account and profile information.\n"
                                "• Educator and Validator application documents.\n"
                                "• Learning activities, assessment results, and progress records.\n"
                                "• Enrollment details and mentorship schedules.\n"
                                "• Technical information related to account and application usage.\n\n"
                                "3. Use of Personal Information\n"
                                "Collected information may be used to:\n"
                                "• Create and manage user accounts.\n"
                                "• Verify user identities and applications.\n"
                                "• Monitor learning progress and achievements.\n"
                                "• Manage Educator enrollment and mentorship sessions.\n"
                                "• Provide AI-assisted learning features.\n"
                                "• Maintain application security and improve services.\n\n"
                                "4. Information Access and Sharing\n"
                                "Personal information may be accessed by authorized users according to their roles:\n"
                                "• Educators: Access relevant information about their enrolled Learners.\n"
                                "• Validators: Review Educator applications and submitted educational materials.\n"
                                "• Super-Admins: Manage accounts, applications, and platform activities.\n"
                                "Information may also be processed by third-party providers necessary for Grammatica's services.\n\n"
                                "5. Third-Party Services\n"
                                "Grammatica uses Google Sign-In for authentication and Google Gemini for AI-assisted features. Google Meet, Zoom, and Microsoft Teams may be used for mentorship sessions. These providers have their own privacy policies and data-handling practices.\n\n"
                                "6. AI-Assisted Processing\n"
                                "Information and documents submitted through AI Notebook may be processed by Google Gemini to generate lessons, quizzes, and other educational materials. Users should avoid uploading unnecessary personal or confidential information.\n\n"
                                "7. Speech and Pronunciation Data\n"
                                "Grammatica uses Vosk and Web Speech APIs for English speech recognition and pronunciation activities. Audio processing depends on the technology and features used.\n\n"
                                "8. Data Storage and Security\n"
                                "Grammatica applies reasonable security measures to protect personal information against unauthorized access, disclosure, alteration, or loss.\n\n"
                                "9. Data Retention\n"
                                "Personal information is retained only as long as necessary for educational, operational, and legal purposes. Records may be deleted or anonymized when no longer needed, subject to applicable requirements.\n\n"
                                "10. User Privacy Rights\n"
                                "Under the Philippine Data Privacy Act of 2012, users may exercise their applicable rights, including:\n"
                                "• Accessing their personal information.\n"
                                "• Correcting inaccurate details.\n"
                                "• Requesting deletion or blocking when legally permitted.\n"
                                "• Objecting to certain data processing activities.\n"
                                "• Requesting a copy of their information when applicable.\n"
                                "• Filing a complaint with the National Privacy Commission.\n\n"
                                "11. Account Deactivation and Deletion\n"
                                "Eligible users may deactivate or request deletion of their accounts through available account settings. Certain records may be retained when required by law or for legitimate purposes.\n\n"
                                "12. Privacy of Minors\n"
                                "Grammatica recognizes that some users may be below 18 years old. Parental or legal guardian consent will be obtained when required by applicable laws.\n\n"
                                "13. Changes to This Policy\n"
                                "Grammatica may revise this Privacy Policy when its services or data-handling practices change. Updated versions will be made available through the platform.\n\n"
                                "14. Contact Information\n"
                                "For privacy-related questions, requests, or concerns, users may contact:\n"
                                "Grammatica Privacy Support\n"
                                "Email: grammatica.support@gmail.com",
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : Colors.black87,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                "End of Document",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Thank you for choosing Grammatica! Now you can proceed.",
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Checkbox(
                          value: _agreedToTerms,
                          onChanged: _hasScrolledToBottom ? (val) => setModalState(() => _agreedToTerms = val!) : null,
                          activeColor: const Color(0xFF81B655),
                        ),
                        Expanded(
                          child: Text(
                            "I have read and agree to the terms.",
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(_hasScrolledToBottom ? "Accept & Close" : "Close", style: TextStyle(color: _hasScrolledToBottom ? const Color(0xFF81B655) : Colors.grey)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _register() async {
    if (!_formKey3.currentState!.validate()) return;

    final email = _emailController.text.trim();
    if (!EmailValidatorService.isAllowedEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only @gmail.com, @yahoo.com, and @hotmail.com emails are accepted.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      setState(() => _isInvalidDomain = true);
      return;
    }

    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please read and agree to the Terms')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final first = _firstNameController.text.trim();
      final middle = _middleNameController.text.trim();
      final last = _lastNameController.text.trim();
      String fullName = first;
      if (middle.isNotEmpty) fullName += " $middle";
      if (last.isNotEmpty) fullName += " $last";
      if (_selectedSuffix != null && _selectedSuffix != 'None') fullName += " $_selectedSuffix";

      // Register directly via Firebase Authentication
      final cred = await AuthService.instance.registerWithEmailPassword(
        email: email,
        password: _passwordController.text,
        fullName: fullName,
        phoneNumber: '',
        dateOfBirth: _selectedDate ?? DateTime.now(),
        role: _selectedRole,
      );

      final user = cred.user;
      if (user != null) {
        await NotificationService.instance.sendWelcomeNotification(user.uid);
      }

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationPage(
              email: email,
              fullName: fullName,
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Registration failed'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_formKey1.currentState!.validate()) {
        _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      }
    } else if (_currentStep == 1) {
      final email = _emailController.text.trim();
      if (email.isEmpty) {
        _formKey2.currentState?.validate();
        return;
      }
      if (!EmailValidatorService.isAllowedEmail(email)) {
        setState(() => _isInvalidDomain = true);
        _formKey2.currentState?.validate();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only @gmail.com, @yahoo.com, and @hotmail.com emails are accepted.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      if (_formKey2.currentState!.validate() && !_isEmailTaken && !_isValidatingEmail && !_isInvalidDomain) {
        _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      }
    }
  }

  Future<void> _signUpWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      AuthService.preferredGoogleRole = _selectedRole;
      await AuthService.instance.googleSignIn(role: _selectedRole);
      // Now that sign-up/sign-in is successful, pop this page so the AuthWrapper in main.dart
      // can show the dashboard.
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Google Sign-Up failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const PreferredSize(preferredSize: Size.fromHeight(80), child: TopNavBar()),
      body: BackgroundWrapper(
        imageAssetPath: 'assets/signinbgs.png',
        child: LayoutBuilder(builder: (context, constraints) {
          final isLargeScreen = constraints.maxWidth > 800;
          
          final authCard = ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08), blurRadius: 24, offset: const Offset(0, 12)),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(isDark),
                  _buildProgress(),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    height: _getStepHeight(),
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (idx) => setState(() => _currentStep = idx),
                      children: [
                        _buildStep1(),
                        _buildStep2(),
                        _buildStep3(),
                      ],
                    ),
                  ),
                  _buildFooter(isDark),
                ],
              ),
            ),
          );

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
              child: isLargeScreen
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Expanded(
                          child: TaglineHeroText(title: 'Join Today!'),
                        ),
                        const SizedBox(width: 40),
                        authCard,
                      ],
                    )
                  : Align(
                      alignment: Alignment.center,
                      child: authCard,
                    ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
      ),
      padding: const EdgeInsets.only(top: 32, bottom: 16, left: 32, right: 32),
      child: Column(
        children: [
          Image.asset(
            'assets/logotext.png',
            height: 38,
            errorBuilder: (ctx, err, st) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.language_rounded,
                  color: Color(0xFF81B655),
                  size: 32,
                ),
                const SizedBox(width: 8),
                Text(
                  'Grammatica',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Create Account",
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labels = ["Personal Info", "Contact", "Security"];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (index) {
          if (index % 2 != 0) {
            int stepIndex = index ~/ 2;
            return Expanded(
              child: Container(
                height: 3,
                margin: const EdgeInsets.only(bottom: 14, left: 4, right: 4),
                color: stepIndex < _currentStep ? const Color(0xFF81B655) : (isDark ? Colors.white12 : Colors.grey[200]),
              ),
            );
          }
          int stepIndex = index ~/ 2;
          bool isActive = stepIndex <= _currentStep;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF81B655) : (isDark ? const Color(0xFF334155) : Colors.grey[200]),
                  shape: BoxShape.circle,
                  boxShadow: isActive ? [BoxShadow(color: const Color(0xFF81B655).withValues(alpha: 0.3), blurRadius: 8)] : [],
                ),
                child: Center(
                  child: Text("${stepIndex + 1}", style: TextStyle(color: isActive ? Colors.white : (isDark ? Colors.white38 : Colors.grey), fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 4),
              Text(labels[stepIndex], style: TextStyle(fontSize: 11, color: isActive ? const Color(0xFF81B655) : (isDark ? Colors.white54 : Colors.grey), fontWeight: FontWeight.bold)),
            ],
          );
        }),
      ),
    );
  }

  double _getStepHeight() {
    switch (_currentStep) {
      case 0:
        return _selectedRole == 'validator' ? 535 : 515;
      case 1:
        return 190;
      case 2:
        return 530;
      default:
        return 515;
    }
  }

  Widget _buildStep1() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 0),
      child: Form(
        key: _formKey1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Register As", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white70 : Colors.black54)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() {
                      _selectedRole = 'learner';
                      AuthService.preferredGoogleRole = 'learner';
                    }),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      decoration: BoxDecoration(
                        color: _selectedRole == 'learner'
                            ? const Color(0xFF81B655).withValues(alpha: 0.12)
                            : (isDark ? Colors.white10 : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedRole == 'learner' ? const Color(0xFF81B655) : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.school_rounded, size: 20, color: _selectedRole == 'learner' ? const Color(0xFF81B655) : Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            'Learner',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _selectedRole == 'learner' ? const Color(0xFF81B655) : (isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() {
                      _selectedRole = 'validator';
                      AuthService.preferredGoogleRole = 'validator';
                      if (_selectedDate != null && _selectedDate!.isAfter(DateTime(2005, 12, 31))) {
                        _selectedDate = null;
                        _dobController.clear();
                      }
                    }),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      decoration: BoxDecoration(
                        color: _selectedRole == 'validator'
                            ? const Color(0xFF3B82F6).withValues(alpha: 0.12)
                            : (isDark ? Colors.white10 : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedRole == 'validator' ? const Color(0xFF3B82F6) : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.verified_rounded, size: 20, color: _selectedRole == 'validator' ? const Color(0xFF3B82F6) : Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            'Validator',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _selectedRole == 'validator' ? const Color(0xFF3B82F6) : (isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_selectedRole == 'validator') ...[
              const SizedBox(height: 6),
              Text(
                'Note: Validators must upload a PRC Teacher Certificate after account setup.',
                style: TextStyle(fontSize: 11, color: Colors.blue.shade400, fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: 16),
            Text("Personal Information", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white70 : Colors.black54)),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _firstNameController,
              hintText: 'First Name *',
              prefixIcon: const Icon(Icons.person_outline),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s\-]')),
                _CapitalizerFormatter(),
              ],
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'First name is required';
                if (!RegExp(r'^[a-zA-Z\s\-]+$').hasMatch(val.trim())) return 'Only letters allowed';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _middleNameController,
              hintText: 'Middle Name (Optional)',
              prefixIcon: const Icon(Icons.person_outline),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s\-]')),
                _CapitalizerFormatter(),
              ],
              validator: (val) {
                if (val != null && val.trim().isNotEmpty && !RegExp(r'^[a-zA-Z\s\-]+$').hasMatch(val.trim())) {
                  return 'Only letters allowed';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _lastNameController,
              hintText: 'Last Name *',
              prefixIcon: const Icon(Icons.person_outline),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s\-]')),
                _CapitalizerFormatter(),
              ],
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Last name is required';
                if (!RegExp(r'^[a-zA-Z\s\-]+$').hasMatch(val.trim())) return 'Only letters allowed';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _buildDropdownField(),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _dobController,
              hintText: _selectedRole == 'validator'
                  ? 'Date of Birth (2005 or earlier) *'
                  : 'Date of Birth (2014 or earlier) *',
              prefixIcon: const Icon(Icons.calendar_month_outlined),
              readOnly: true,
              onTap: () => _selectDate(context),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Date of birth is required';
                if (_selectedRole == 'validator') {
                  if (_selectedDate != null && _selectedDate!.isAfter(DateTime(2005, 12, 31))) {
                    return 'Must be born in 2005 or earlier (minimum 21 years old)';
                  }
                } else {
                  if (_selectedDate != null && _selectedDate!.isAfter(DateTime(2014, 12, 31))) {
                    return 'Must be born in 2014 or earlier (minimum 12 years old)';
                  }
                }
                return null;
              },
            ),
            if (_selectedRole != 'Validator') ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.amber.withValues(alpha: 0.1)
                      : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? Colors.amber.withValues(alpha: 0.3)
                        : Colors.amber.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 14,
                      color: isDark ? Colors.amber.shade300 : Colors.amber.shade800,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Date of birth can only be edited once after registration.',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStep2() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final emailTooltip = _isEmailTaken
        ? 'This email has already been taken'
        : (_isInvalidDomain ? 'Only @gmail.com, @yahoo.com, and @hotmail.com are allowed' : '');

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 0),
      child: Form(
        key: _formKey2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Account Email",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white70 : Colors.black54),
            ),
            const SizedBox(height: 16),
            Tooltip(
              message: emailTooltip,
              child: _buildTextField(
                controller: _emailController,
                hintText: 'Email Address *',
                prefixIcon: const Icon(Icons.email_outlined),
                keyboardType: TextInputType.emailAddress,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Email is required';
                  final clean = val.trim();
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(clean)) return 'Enter valid email';
                  if (!EmailValidatorService.isAllowedEmail(clean) || _isInvalidDomain) {
                    return 'Only @gmail.com, @yahoo.com, and @hotmail.com are allowed';
                  }
                  if (_isEmailTaken) return 'This email has already been taken';
                  return null;
                },
                onChanged: _onEmailChanged,
                suffixIcon: _isValidatingEmail 
                  ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)))
                  : _isInvalidDomain
                    ? const Tooltip(message: 'Only @gmail.com, @yahoo.com, and @hotmail.com allowed', child: Icon(Icons.block_rounded, color: Colors.red))
                    : _isEmailTaken
                        ? const Tooltip(message: 'This email has already been taken', child: Icon(Icons.error_outline, color: Colors.red))
                        : null,
              ),
            ),
            if (_isEmailTaken) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'This email has already been taken',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_isInvalidDomain) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Row(
                  children: [
                    const Icon(Icons.block_rounded, color: Colors.red, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Only @gmail.com, @yahoo.com, and @hotmail.com are allowed',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordRequirementItem(String text, bool met, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 14,
            color: met ? const Color(0xFF16A34A) : (isDark ? Colors.white38 : Colors.grey[400]),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: met ? FontWeight.w600 : FontWeight.normal,
                color: met
                    ? (isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D))
                    : (isDark ? Colors.white60 : Colors.grey[600]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pass = _passwordController.text;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 0),
      child: Form(
        key: _formKey3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Security", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white70 : Colors.black54)),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _passwordController,
              hintText: 'Password *',
              obscureText: _obscurePassword,
              onChanged: (v) => setState(() {}),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: const Color(0xFF81B655),
                  size: 22,
                ),
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Password is required';
                if (!_hasMinLength(val)) return 'At least 8 characters required';
                if (!_hasUppercase(val)) return 'At least 1 uppercase letter required';
                if (!_hasLowercase(val)) return 'At least 1 lowercase letter required';
                if (!_hasDigit(val)) return 'At least 1 number required';
                if (!_hasSpecial(val)) return 'At least 1 special character required';
                return null;
              },
            ),
            if (pass.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Text("Strength: ", style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87)),
                  Text(_getPasswordStrength(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _getStrengthColor())),
                ],
              ),
            ],
            const SizedBox(height: 8),
            // Password Requirements Guidance Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.6) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shield_outlined, size: 14, color: Color(0xFF81B655)),
                      const SizedBox(width: 6),
                      Text(
                        "Password Requirements",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildPasswordRequirementItem("At least 8 characters", _hasMinLength(pass), isDark),
                  _buildPasswordRequirementItem("At least 1 uppercase letter (A-Z)", _hasUppercase(pass), isDark),
                  _buildPasswordRequirementItem("At least 1 lowercase letter (a-z)", _hasLowercase(pass), isDark),
                  _buildPasswordRequirementItem("At least 1 number (0-9)", _hasDigit(pass), isDark),
                  _buildPasswordRequirementItem("At least 1 special character", _hasSpecial(pass), isDark),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "Allowed special characters: ! @ # \$ % ^ & * ( ) , . ? \" : { } | < > ~ _ - + =",
                      style: TextStyle(
                        fontSize: 9.5,
                        fontFamily: 'monospace',
                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _confirmPasswordController,
              hintText: 'Confirm Password *',
              obscureText: _obscureConfirmPassword,
              onChanged: (v) => setState(() {}),
              prefixIcon: const Icon(Icons.lock_reset),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: const Color(0xFF81B655),
                  size: 22,
                ),
                tooltip: _obscureConfirmPassword ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Confirm password is required';
                if (val != _passwordController.text) return 'Passwords do not match';
                return null;
              },
            ),
            if (_confirmPasswordController.text.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                _passwordController.text == _confirmPasswordController.text ? "✓ Passwords match" : "✗ Passwords do not match",
                style: TextStyle(fontSize: 12, color: _passwordController.text == _confirmPasswordController.text ? Colors.green : Colors.red),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _agreedToTerms,
                  onChanged: (v) => _showTermsModal(),
                  activeColor: const Color(0xFF81B655),
                ),
                Expanded(
                  child: InkWell(
                    onTap: _showTermsModal,
                    child: const Text(
                      "Terms & Conditions and Privacy Policy",
                      style: TextStyle(fontSize: 12, decoration: TextDecoration.underline, color: Color(0xFF75A94B), fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        children: [
          Row(
            children: [
              if (_currentStep > 0)
                Expanded(
                  child: Container(
                    height: 50,
                    margin: const EdgeInsets.only(right: 12),
                    child: OutlinedButton(
                      onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: Color(0xFF81B655), width: 1.5),
                      ),
                      child: const Text("Back", style: TextStyle(color: Color(0xFF81B655), fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ),
              Expanded(
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(colors: [Color(0xFF81B655), Color(0xFF75A94B)]),
                    boxShadow: [BoxShadow(color: const Color(0xFF81B655).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : (_currentStep == 2 ? _register : _nextStep),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_currentStep == 2 ? "Finish" : "Next", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildDivider(),
          const SizedBox(height: 20),
          GoogleSignInButton(
            onPressed: _isLoading ? () {} : _signUpWithGoogle,
            enabled: !_isLoading,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Already have an account? ", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13)),
              InkWell(
                onTap: () => Navigator.pop(context),
                child: const Text("Sign In", style: TextStyle(color: Color(0xFF81B655), fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Row(
      children: [
        Expanded(child: Divider()),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            "Or continue with",
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
        Expanded(child: Divider()),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required Widget prefixIcon,
    Widget? suffixIcon,
    bool obscureText = false,
    String? Function(String?)? validator,
    bool readOnly = false,
    VoidCallback? onTap,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isRequired = hintText.trim().endsWith('*');
    final String cleanHint = isRequired
        ? hintText.replaceAll(RegExp(r'\s*\*'), '').trim()
        : hintText;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF334155) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04), blurRadius: 8, spreadRadius: 2, offset: const Offset(0, 4))],
        border: Border.all(color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05)),
      ),
      child: TextFormField(
        inputFormatters: inputFormatters,
        controller: controller,
        obscureText: obscureText,
        readOnly: readOnly,
        onTap: onTap,
        onChanged: onChanged,
        keyboardType: keyboardType,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          label: isRequired
              ? Text.rich(
                  TextSpan(
                    text: cleanHint,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    children: const [
                      TextSpan(
                        text: ' *',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              : null,
          hintText: isRequired ? null : cleanHint,
          hintStyle: TextStyle(
            color: isDark ? Colors.white70 : Colors.black54,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.never,
          prefixIcon: IconTheme(data: IconThemeData(color: isDark ? Colors.white70 : Colors.black54), child: prefixIcon),
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildDropdownField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF334155) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _selectedSuffix,
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          icon: Icon(
            Icons.arrow_drop_down,
            color: isDark ? Colors.white60 : Colors.black45,
          ),
          hint: Text(
            "Suffix (Optional)",
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          items: _suffixes.map((s) {
            return DropdownMenuItem<String>(
              value: s,
              child: Text(
                s,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
          onChanged: (val) => setState(() => _selectedSuffix = val),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailDebounceTimer?.cancel();
    _authSubscription?.cancel();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dobController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _pageController.dispose();
    super.dispose();
  }
}

class _CapitalizerFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final text = newValue.text;
    final words = text.split(' ');
    final capitalized = words.map((w) {
      if (w.isEmpty) return '';
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
    
    return TextEditingValue(
      text: capitalized,
      selection: newValue.selection,
    );
  }
}

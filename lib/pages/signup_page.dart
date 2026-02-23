import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../theme/app_colors.dart';
import '../services/notification_service.dart';
import 'package:flutter/services.dart';
import '../widgets/google_sign_in_button.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  DateTime? _selectedDate;
  String? _completePhoneNumber;

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedDate ??
          DateTime.now().subtract(const Duration(days: 365 * 7 + 2)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 7)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dobController.text = "${picked.month}/${picked.day}/${picked.year}";
      });
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await AuthService.instance.registerWithEmailPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
        phoneNumber: _completePhoneNumber ?? _phoneController.text.trim(),
        dateOfBirth: _selectedDate ?? DateTime.now(),
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await NotificationService.instance.sendWelcomeNotification(user.uid);
      }
      if (mounted) {
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Registration failed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _registerWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await AuthService.instance.googleSignIn();
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Google Sign-In failed: $e')));
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
    final screenHeight = MediaQuery.of(context).size.height;
    final isShortScreen = screenHeight < 700;
    final isCompact = screenHeight < 800;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: AppColors.getMainGradient(context)),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              vertical: isShortScreen ? 12 : 24,
              horizontal: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 320,
              ), // Reduced from 450
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(
                    isShortScreen ? 14 : 18,
                  ), // Reduced from 20/32
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Column(
                            children: [
                              Text(
                                'Grammatica',
                                style: TextStyle(
                                  fontSize: isShortScreen
                                      ? 22
                                      : 30, // Reduced from 36/48
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.registrationGreen,
                                  letterSpacing: -1.5,
                                  fontFamily: 'Serif',
                                ),
                              ),
                              SizedBox(
                                height: isShortScreen ? 2 : 6,
                              ), // Reduced from 4/12
                              Text(
                                "Create Account",
                                style: TextStyle(
                                  fontSize: isShortScreen ? 14 : 16,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.titleLarge?.color,
                                ),
                              ),
                              if (!isShortScreen) const SizedBox(height: 2),
                              if (!isShortScreen)
                                Text(
                                  "Sign up to start your learning journey",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.getSecondaryTextColor(
                                      context,
                                    ),
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: isShortScreen ? 12 : 20,
                        ), // Reduced from 20/32
                        _buildLabel("Full Name", isCompact),
                        TextFormField(
                          controller: _fullNameController,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'John Doe',
                            prefixIcon: Icon(Icons.person_outline, size: 20),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your full name';
                            }
                            return null;
                          },
                        ),
                        SizedBox(
                          height: isCompact ? 8 : 10,
                        ), // Reduced from 12/16
                        _buildLabel("Phone Number", isCompact),
                        IntlPhoneField(
                          controller: _phoneController,
                          initialCountryCode: 'PH',
                          style: const TextStyle(fontSize: 13),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          decoration: const InputDecoration(
                            hintText: '+1 (555) 000-0000',
                            border: OutlineInputBorder(),
                            counterText: '',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          onChanged: (phone) {
                            _completePhoneNumber = phone.completeNumber;
                          },
                        ),
                        SizedBox(height: isCompact ? 8 : 10),
                        _buildLabel("Date of Birth", isCompact),
                        TextFormField(
                          controller: _dobController,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'mm/dd/yyyy',
                            prefixIcon: Icon(
                              Icons.calendar_today_outlined,
                              size: 20,
                            ),
                            suffixIcon: Icon(Icons.calendar_month, size: 20),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          readOnly: true,
                          onTap: () => _selectDate(context),
                        ),
                        SizedBox(height: isCompact ? 8 : 10),
                        _buildLabel("Email", isCompact),
                        TextFormField(
                          controller: _emailController,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'your@email.com',
                            prefixIcon: Icon(Icons.email_outlined, size: 20),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!RegExp(
                              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                            ).hasMatch(value)) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: isCompact ? 8 : 10),
                        _buildLabel("Password", isCompact),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Enter password',
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              size: 20,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            suffixIcon: IconButton(
                              iconSize: 20,
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: isCompact ? 8 : 10),
                        _buildLabel("Confirm Password", isCompact),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscurePassword,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Confirm password',
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              size: 20,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            suffixIcon: IconButton(
                              iconSize: 20,
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please confirm your password';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: isShortScreen ? 14 : 20),
                        SizedBox(
                          width: double.infinity,
                          height: isShortScreen ? 34 : 38, // Reduced from 48/54
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _register,
                            style: ElevatedButton.styleFrom(
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primaryGreen,
                                    ),
                                  )
                                : const Text('Create Account'),
                          ),
                        ),
                        SizedBox(height: isShortScreen ? 14 : 20),
                        _buildDivider(isCompact),
                        SizedBox(height: isShortScreen ? 14 : 20),
                        GoogleSignInButton(
                          onPressed: _isLoading ? () {} : _registerWithGoogle,
                          enabled: !_isLoading,
                        ),
                        SizedBox(
                          height: isShortScreen ? 10 : 14,
                        ), // Reduced from 16/24
                        Center(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: RichText(
                              text: TextSpan(
                                text: "Already have an account? ",
                                style: TextStyle(
                                  color: AppColors.getSecondaryTextColor(
                                    context,
                                  ),
                                  fontSize: 12, // Reduced from 14
                                ),
                                children: [
                                  TextSpan(
                                    text: "Sign In",
                                    style: TextStyle(
                                      color: AppColors.registrationGreen,
                                      fontWeight: FontWeight.bold,
                                    ),
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
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(bool isCompact) {
    return Row(
      children: [
        const Expanded(child: Divider(thickness: 1, color: Color(0xFFE0E0E0))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            "OR",
            style: TextStyle(
              color: AppColors.getSecondaryTextColor(context),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Expanded(child: Divider(thickness: 1, color: Color(0xFFE0E0E0))),
      ],
    );
  }

  Widget _buildLabel(String label, bool isCompact) {
    return Padding(
      padding: EdgeInsets.only(bottom: isCompact ? 2 : 4, left: 2), // Reduced
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    super.dispose();
  }
}

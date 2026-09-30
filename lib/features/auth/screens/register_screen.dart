import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/recall_field.dart';
import '../../../core/widgets/recall_button.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter an email and password.', style: AppTypography.bodyMedium),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password must be at least 6 characters long.', style: AppTypography.bodyMedium),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    final authService = context.read<AuthService>();
    final success = await authService.register(
      email, 
      password,
      displayName: name.isNotEmpty ? name : null,
    );
    
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      context.go('/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration failed. Please check your credentials.', style: AppTypography.bodyMedium),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleGoogleSignUp() async {
    setState(() => _isLoading = true);
    final authService = context.read<AuthService>();
    final errorMsg = await authService.signInWithGoogle();

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (errorMsg == null) {
      context.go('/home');
    } else if (errorMsg != 'Sign-In canceled by user.') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg, style: AppTypography.bodyMedium),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Create Account', style: AppTypography.display),
              const SizedBox(height: 8),
              Text(
                'Start your learning journey today',
                style: AppTypography.body.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 48),
              
              RecallField(
                controller: _nameController,
                label: 'Full Name',
              ),
              const SizedBox(height: 16),
              RecallField(
                controller: _emailController,
                label: 'Email Address',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              RecallField(
                controller: _passwordController,
                label: 'Password',
                isObscure: true,
              ),
              
              const SizedBox(height: 48),
              
              if (_isLoading)
                Center(child: CircularProgressIndicator(color: AppColors.accent))
              else ...[
                RecallButton(
                  label: 'Create Account',
                  onPressed: _handleRegister,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(child: Divider(color: AppColors.surface)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('OR', style: AppTypography.caption),
                    ),
                    const Expanded(child: Divider(color: AppColors.surface)),
                  ],
                ),
                const SizedBox(height: 24),
                RecallButton(
                  label: 'Sign up with Google',
                  variant: RecallButtonVariant.google,
                  onPressed: _handleGoogleSignUp,
                ),
              ],

              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account?',
                    style: AppTypography.bodyMedium,
                  ),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: Text(
                      'Sign In',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

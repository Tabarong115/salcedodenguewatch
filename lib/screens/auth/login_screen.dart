import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final authService = context.read<AuthService>();
    final result = await authService.signIn(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result.success) {
      // Navigate back to let AuthWrapper handle routing
      if (mounted) {
        Navigator.pop(context); // Go back to previous screen
        // AuthWrapper will automatically redirect to the appropriate dashboard
      }
    } else if (mounted) {
      _showErrorDialog(result);
    }
  }

  void _showErrorDialog(AuthResult result) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _getErrorIcon(result.error),
              color: _getErrorColor(result.error),
            ),
            const SizedBox(width: 8),
            Text('Login Failed'.tr()),
          ],
        ),
        content: Text(result.message ?? 'An error occurred'.tr()),
        actions: [
          if (result.error == AuthError.emailNotVerified)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _resendVerificationEmail();
              },
              child: Text('Resend Verification'.tr()),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'.tr()),
          ),
        ],
      ),
    );
  }

  IconData _getErrorIcon(AuthError? error) {
    switch (error) {
      case AuthError.invalidCredentials:
        return Icons.lock_outline;
      case AuthError.emailNotVerified:
        return Icons.email_outlined;
      case AuthError.accountInactive:
        return Icons.block;
      case AuthError.networkError:
        return Icons.wifi_off;
      default:
        return Icons.error_outline;
    }
  }

  Color _getErrorColor(AuthError? error) {
    switch (error) {
      case AuthError.emailNotVerified:
        return Colors.orange;
      case AuthError.accountInactive:
        return Colors.red;
      case AuthError.networkError:
        return Colors.blue;
      default:
        return Colors.red;
    }
  }

  Future<void> _resendVerificationEmail() async {
    final authService = context.read<AuthService>();
    final result = await authService.resendVerificationEmail();
    
    if (!mounted) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Verification email sent'.tr()),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _showForgotPasswordDialog() {
    if (!mounted) return;
    
    final emailController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text('Reset Password'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter your email address to receive a password reset link.'.tr()),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email'.tr(),
                prefixIcon: const Icon(Icons.email),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              if (emailController.text.trim().isEmpty) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please enter your email'.tr()),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return;
              }
              
              Navigator.pop(dialogContext);
              final authService = context.read<AuthService>();
              final result = await authService.resetPassword(emailController.text.trim());
              
              if (!mounted) return;
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(result.message ?? 'Password reset email sent'.tr()),
                  backgroundColor: result.success ? Colors.green : Colors.red,
                ),
              );
            },
            child: Text('Send Reset Link'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLogo(),
                  const SizedBox(height: 32),
                  _buildTitle(),
                  const SizedBox(height: 48),
                  _buildEmailField(),
                  const SizedBox(height: 16),
                  _buildPasswordField(),
                  const SizedBox(height: 8),
                  _buildForgotPasswordButton(),
                  const SizedBox(height: 24),
                  _buildLoginButton(),
                  const SizedBox(height: 16),
                  _buildBackButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.green.shade100,
        borderRadius: BorderRadius.circular(60),
      ),
      child: Icon(
        Icons.health_and_safety,
        size: 80,
        color: Colors.green.shade700,
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        Text(
          'Salcedo Dengue Watch'.tr(),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Staff Login'.tr(),
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      autocorrect: false,
      decoration: InputDecoration(
        labelText: 'Email'.tr(),
        prefixIcon: const Icon(Icons.email),
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter your email'.tr();
        }
        // Simple email validation
        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
        if (!emailRegex.hasMatch(value.trim())) {
          return 'Please enter a valid email address'.tr();
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: 'Password'.tr(),
        prefixIcon: const Icon(Icons.lock),
        suffixIcon: IconButton(
          icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your password'.tr();
        }
        if (value.length < 6) {
          return 'Password must be at least 6 characters'.tr();
        }
        return null;
      },
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text('Login'.tr()),
      ),
    );
  }

  Widget _buildForgotPasswordButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: _showForgotPasswordDialog,
        child: Text(
          'Forgot Password?'.tr(),
          style: TextStyle(
            color: Colors.green.shade700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return TextButton(
      onPressed: () {
        Navigator.pop(context);
      },
      child: Text('Back to Public View'.tr()),
    );
  }
}

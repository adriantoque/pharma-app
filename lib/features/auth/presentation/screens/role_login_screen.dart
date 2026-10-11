import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../domain/user_role.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_button.dart';
import '../widgets/auth_text_field.dart';

/// A full-screen sign-in page for one role.
///
/// Two routes point at this screen -- `/admin-login` and `/staff-login` --
/// with a different [role] each. Layout and validation are shared; only the
/// icon, the copy, and the destination after signing in differ. Two files
/// would be two places to fix the same bug.
///
/// Unlike the sheet on the landing screen, this refuses an account whose
/// role does not match the door. A staff credential entered here is signed
/// back out with a message, so the admin entry cannot be used as a shortcut
/// past the staff flow.
class RoleLoginScreen extends StatefulWidget {
  const RoleLoginScreen({super.key, required this.role});

  /// Which door this is. Determines the copy and which accounts are accepted.
  final UserRole role;

  @override
  State<RoleLoginScreen> createState() => _RoleLoginScreenState();
}

class _RoleLoginScreenState extends State<RoleLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;

  bool get _isAdmin => widget.role == UserRole.admin;

  String get _title =>
      _isAdmin ? 'Administrator Sign In' : 'Staff Sign In';

  String get _subtitle => _isAdmin
      ? 'This is a restricted area. Only administrator accounts may enter.'
      : 'Sign in with your staff account.';

  String get _buttonLabel =>
      _isAdmin ? 'Sign in as Admin' : 'Sign in as Staff';

  IconData get _icon => _isAdmin
      ? Icons.admin_panel_settings_outlined
      : Icons.badge_outlined;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _submitting = true);

    final success = _isAdmin
        ? await auth.loginAsAdmin(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          )
        : await auth.loginAsStaff(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (success) {
      // The router's redirect carries the user to /admin or /home the moment
      // the auth state flips. Nothing navigates here -- by the time this
      // method resumes, the frame is already on the destination.
      return;
    }

    // A failed sign-in stays on this screen so the credentials survive and
    // the user can correct whatever was wrong.
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Sign-in failed.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Username or email is required';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isBusy = context.watch<AuthProvider>().isLoading || _submitting;

    return Scaffold(
      appBar: AppBar(
        // Pushed from the landing screen, so the back arrow returns there.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: isBusy ? null : () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Center(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(
                      _icon,
                      size: 40,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _subtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                AuthTextField(
                  controller: _emailController,
                  label: 'Username or email',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  enabled: !isBusy,
                  validator: _validateEmail,
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _passwordController,
                  label: 'Password',
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  enabled: !isBusy,
                  onFieldSubmitted: (_) => _submit(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  validator: _validatePassword,
                ),
                const SizedBox(height: 24),
                AuthButton(
                  label: _buttonLabel,
                  isLoading: isBusy,
                  onPressed: _submit,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: isBusy ? null : () => context.pop(),
                  child: const Text('Back to landing'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
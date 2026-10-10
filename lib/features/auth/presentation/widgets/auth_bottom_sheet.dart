import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'auth_button.dart';
import 'auth_text_field.dart';

enum AuthSheetMode { login, signup }

class AuthBottomSheet extends StatefulWidget {
  final AuthSheetMode mode;

  /// What the sheet calls itself. Defaults to the mode's own label so a
  /// caller that does not care about admin-versus-staff still gets a sensible
  /// title.
  final String? title;

  const AuthBottomSheet({super.key, required this.mode, this.title});

  @override
  State<AuthBottomSheet> createState() => _AuthBottomSheetState();
}

class _AuthBottomSheetState extends State<AuthBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;

  bool get _isLogin => widget.mode == AuthSheetMode.login;

  String get _title =>
      widget.title ?? (_isLogin ? 'Login' : 'Create account');

  String get _buttonLabel => _isLogin ? 'Login' : 'Signup';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Reachable from the keyboard action and the button, so guard against a
    // second in-flight attempt.
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _submitting = true);

    final success = _isLogin
        ? await auth.login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          )
        : await auth.signup(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (success) {
      // The auth state change has already fired the router's redirect, which
      // is navigating away from the landing screen in this same frame.
      // Popping the sheet immediately would arrive while that transition has
      // the Navigator locked, which trips the framework's `_debugLocked`
      // assertion. Deferring the pop to the next frame lets the redirect
      // finish first, then the sheet is dismissed cleanly on top of the
      // destination it revealed.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) navigator.pop();
      });
      return;
    }

    // Shown through the messenger captured above: a messenger resolved from
    // the sheet's own context would render behind the modal barrier.
    messenger.showSnackBar(
      SnackBar(content: Text(auth.error ?? 'Something went wrong')),
    );
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return _isLogin ? 'Username is required' : 'Email is required';
    }
    // The demo accounts sign in with a bare username, so the strict email
    // check is only applied when the sheet is creating an account.
    if (_isLogin) return null;

    if (!RegExp(r'^[^@\s]+@[^@\s.]+(\.[^@\s.]+)+$').hasMatch(email)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLoading = context.watch<AuthProvider>().isLoading || _submitting;

    return SingleChildScrollView(
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
            Text(
              _title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            if (!_isLogin) ...[
              AuthTextField(
                controller: _nameController,
                label: 'Full name',
                textInputAction: TextInputAction.next,
                enabled: !isLoading,
                validator: _validateName,
              ),
              const SizedBox(height: 16),
            ],
            AuthTextField(
              controller: _emailController,
              // The demo backend signs in with a username; a real one would
              // sign in with an email. The label changes with the backend,
              // the field does not.
              label: _isLogin ? 'Username' : 'Email',
              keyboardType: _isLogin
                  ? TextInputType.text
                  : TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              enabled: !isLoading,
              validator: _validateEmail,
            ),
            const SizedBox(height: 16),
            AuthTextField(
              controller: _passwordController,
              label: 'Password',
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              enabled: !isLoading,
              onFieldSubmitted: (_) => _submit(),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              validator: _validatePassword,
            ),
            const SizedBox(height: 24),
            AuthButton(
              label: _buttonLabel,
              isLoading: isLoading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

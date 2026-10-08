import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth/data/models/user_model.dart';
import '../../../auth/domain/user_role.dart';
import '../providers/users_provider.dart';

/// Opens the add-or-edit sheet for a user.
///
/// Passing a [user] turns it into an edit; leaving it null opens a fresh
/// form. The same sheet for both because they share every field and every
/// validation, and the two screens that would result from splitting them
/// would drift apart in a month.
Future<void> showUserEditSheet(
  BuildContext context, {
  UserModel? user,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
    builder: (_) => _UserEditSheet(user: user),
  );
}

class _UserEditSheet extends StatefulWidget {
  const _UserEditSheet({this.user});

  /// The user being edited, or null when adding.
  final UserModel? user;

  @override
  State<_UserEditSheet> createState() => _UserEditSheetState();
}

class _UserEditSheetState extends State<_UserEditSheet> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.user?.name ?? '',
  );
  late final TextEditingController _emailController = TextEditingController(
    text: widget.user?.email ?? '',
  );
  final TextEditingController _passwordController = TextEditingController();

  late UserRole _role = widget.user?.role ?? UserRole.staff;
  bool _obscurePassword = true;

  bool get _isEditing => widget.user != null;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _snack('Enter a name.');
      return;
    }

    final provider = context.read<UsersProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final success = _isEditing
        ? await provider.updateUser(
            widget.user!,
            name: name,
            role: _role,
          )
        : await _create(provider, name: name);

    if (!mounted) return;

    if (success) {
      navigator.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _isEditing ? 'Saved.' : 'Account created.',
            ),
          ),
        );
      return;
    }

    // A failure leaves the sheet open so the values survive and the user can
    // correct whatever was wrong -- an email already in use, most often.
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Something went wrong.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
  }

  Future<bool> _create(UsersProvider provider, {required String name}) async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _snack('Enter a valid email address.');
      return false;
    }
    final password = _passwordController.text;
    if (password.length < 6) {
      _snack('Password must be at least 6 characters.');
      return false;
    }

    return provider.createUser(
      name: name,
      email: email,
      password: password,
      role: _role,
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<UsersProvider>();
    final isSaving = provider.isSaving;

    // A role the guardrails would refuse is dropped from the picker rather
    // than shown-and-disabled: a chip that does nothing when tapped is a
    // worse explanation than not being there.
    final availableRoles = UserRole.values.where((role) {
      if (!_isEditing) return true;
      return provider.canChangeRole(widget.user!, role);
    }).toList();

    // If the current role was filtered out by the guardrails, keep it in the
    // list anyway -- the value has to be in the dropdown's items for the
    // dropdown to be valid, even if the user cannot change it away from
    // there.
    if (!availableRoles.contains(_role)) {
      availableRoles.insert(0, _role);
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditing ? 'Edit user' : 'New user',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              enabled: !isSaving,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Full name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              // Email is fixed once created: Firebase Auth does not allow an
              // admin to change somebody else's address without that user's
              // own re-authentication.
              enabled: !isSaving && !_isEditing,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Email',
                border: const OutlineInputBorder(),
                helperText: _isEditing
                    ? 'Email cannot be changed after creation.'
                    : null,
              ),
            ),
            if (!_isEditing) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                enabled: !isSaving,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                decoration: InputDecoration(
                  labelText: 'Initial password',
                  border: const OutlineInputBorder(),
                  helperText: 'At least 6 characters.',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () => setState(
                      () => _obscurePassword = !_obscurePassword,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text('Role', style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final role in availableRoles)
                  ChoiceChip(
                    label: Text(role.label),
                    selected: _role == role,
                    onSelected: isSaving
                        ? null
                        : (_) => setState(() => _role = role),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: isSaving ? null : _save,
                    child: isSaving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isEditing ? 'Save changes' : 'Create account'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
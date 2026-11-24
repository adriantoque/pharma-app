import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

/// Which part of the PIN flow a screen is serving.
enum OfflinePinMode {
  /// No PIN exists yet: choose one, confirm it, then start offline mode.
  create,

  /// A PIN exists and the app booted into a locked offline session.
  unlock,

  /// Set or replace the PIN from the profile, without starting offline mode.
  ///
  /// The previous PIN is not asked for: anyone who can reach this screen is
  /// already signed in and can see everything the PIN protects. It is also the
  /// way back in for a person who has forgotten theirs.
  update,
}

/// The 4-digit PIN pad in front of offline mode.
///
/// A keypad rather than a text field on purpose: four digits are pressed faster
/// than a soft keyboard can be raised and dismissed, and the pad keeps the
/// screen's own layout — dots and an error line — instead of the keyboard
/// covering half of it at a pharmacy counter.
///
/// The screen never decides where to go next. Setting or verifying the PIN
/// flips [AuthProvider]'s state, and the router's redirect moves the app; the
/// exceptions are "Sign in instead", which ends offline mode and asks the
/// router for the login screen explicitly, and [OfflinePinScreen.onSaved],
/// which lets the profile's route pop back to the page that opened the pad.
class OfflinePinScreen extends StatefulWidget {
  const OfflinePinScreen({super.key, required this.mode, this.onSaved});

  final OfflinePinMode mode;

  /// Called after the PIN in [OfflinePinMode.update] mode has been stored.
  ///
  /// The screen still does not decide where to go next: the route that mounted
  /// it supplies the exit, usually a `pop` back to the profile.
  final VoidCallback? onSaved;

  @override
  State<OfflinePinScreen> createState() => _OfflinePinScreenState();
}

class _OfflinePinScreenState extends State<OfflinePinScreen> {
  static const int _pinLength = 4;

  /// One entry per visible PIN row. The active row receives the keypad input.
  List<String> _values = const [];

  /// Index into [_values] of the row currently receiving input.
  int _active = 0;

  String? _error;
  bool _busy = false;

  /// Whether update mode must prove knowledge of the existing PIN first.
  bool _needsVerify = false;
  bool _verified = false;

  /// False until [hasOfflinePin] has been resolved in update mode, so the pad
  /// is not shown with the wrong title for a frame.
  bool _pinChecked = true;

  /// Repaints the countdown while a cooldown is running, so the pad comes back
  /// on its own rather than after the next unrelated rebuild.
  Timer? _cooldownTicker;

  bool get _isCreate => widget.mode == OfflinePinMode.create;
  bool get _isUpdate => widget.mode == OfflinePinMode.update;
  bool get _isUnlock => widget.mode == OfflinePinMode.unlock;

  /// Whether the screen is part of a page the person chose to open (and can
  /// therefore back out of).
  bool get _isSetup => !_isUnlock;

  @override
  void initState() {
    super.initState();
    if (_isUnlock) {
      _values = [''];
      _active = 0;
    } else if (_isCreate) {
      _values = ['', ''];
      _active = 0;
    } else {
      _pinChecked = false;
    }
    if (_isUpdate) {
      unawaited(_resolveVerifyRequirement());
    }
  }

  Future<void> _resolveVerifyRequirement() async {
    final has = await context.read<AuthProvider>().hasOfflinePin;
    if (!mounted) return;
    setState(() {
      _needsVerify = has;
      _verified = !has;
      _pinChecked = true;
      if (has) {
        _values = ['', '', ''];
      } else {
        _values = ['', ''];
      }
      _active = 0;
    });
  }

  @override
  void dispose() {
    _cooldownTicker?.cancel();
    super.dispose();
  }

  /// Index of the row holding the new PIN.
  int get _newIndex {
    if (_isUnlock) return 0;
    if (_isUpdate && _needsVerify) return 1;
    return 0;
  }

  /// Index of the row holding the confirmation.
  int get _confirmIndex => _values.length - 1;

  String get _title {
    if (_isUnlock) return 'Enter your offline PIN';
    if (_isUpdate && _needsVerify && !_verified) return 'Enter current PIN';
    if (_active == _newIndex) return 'Choose a 4-digit PIN';
    return 'Confirm your PIN';
  }

  String get _subtitle {
    if (_isUnlock) {
      return 'This tablet was left in offline mode. The PIN keeps the price '
          'list and order history to the people who work here.';
    }
    if (_isUpdate) {
      if (_needsVerify && !_verified) {
        return 'Verify your identity before changing the offline PIN.';
      }
      if (_active == _newIndex) {
        return 'The PIN unlocks offline mode on this device. Setting a new one '
            'replaces the old PIN.';
      }
      return 'Type the same four digits again.';
    }
    if (_active == _newIndex) {
      return 'The PIN unlocks offline mode on this device. Choose something you '
          'will remember at the counter.';
    }
    return 'Type the same four digits again.';
  }

  List<String> get _labels {
    if (_isUnlock) return const ['PIN'];
    if (_isUpdate && _needsVerify) {
      return const ['Current PIN', 'New PIN', 'Confirm PIN'];
    }
    return const ['New PIN', 'Confirm PIN'];
  }

  void _activate(int index) {
    if (_busy) return;
    if (_isUpdate && _needsVerify && !_verified && index > 0) return;
    setState(() {
      if (index == 0 && _isUpdate && _needsVerify && _verified) {
        _verified = false;
      }
      _active = index;
      for (var j = index + 1; j < _values.length; j++) {
        _values[j] = '';
      }
    });
  }

  void _press(String digit) {
    if (!_pinChecked || _busy || _active >= _values.length) return;
    if (context.read<AuthProvider>().pinCooldownRemaining > Duration.zero) {
      return;
    }
    if (_values[_active].length >= _pinLength) return;
    setState(() {
      _values[_active] += digit;
      _error = null;
      if (_active == _newIndex && _values[_confirmIndex].isNotEmpty) {
        _values[_confirmIndex] = '';
      }
    });
    if (_values[_active].length == _pinLength) {
      unawaited(_handleComplete(_active));
    }
  }

  void _backspace() {
    if (_busy || _active >= _values.length || _values[_active].isEmpty) return;
    setState(() {
      _values[_active] =
          _values[_active].substring(0, _values[_active].length - 1);
      if (_active == _newIndex) {
        _values[_confirmIndex] = '';
      }
    });
  }

  Future<void> _handleComplete(int index) async {
    final auth = context.read<AuthProvider>();
    setState(() => _busy = true);

    // Update mode must prove knowledge of the existing PIN first.
    if (_isUpdate && _needsVerify && !_verified && index == 0) {
      final pin = _values[0];
      final ok = await auth.unlockOffline(pin);
      if (!mounted) return;
      if (ok) {
        setState(() {
          _verified = true;
          _values[0] = pin;
          _active = _newIndex;
          _busy = false;
          _error = null;
        });
      } else {
        final remaining = auth.pinCooldownRemaining;
        setState(() {
          _values[0] = '';
          _active = 0;
          _busy = false;
          _error = remaining > Duration.zero
              ? 'Too many attempts.'
              : 'Wrong PIN — ${AuthProvider.maxPinAttempts - auth.failedPinAttempts} '
                    'tries left.';
        });
        if (remaining > Duration.zero) _startCooldownTicker();
      }
      return;
    }

    // Unlock mode: verify and enter offline mode.
    if (_isUnlock) {
      final pin = _values[0];
      final ok = await auth.unlockOffline(pin);
      if (!mounted) return;
      if (ok) {
        if (!auth.isOffline) await auth.enterOfflineMode();
        if (!mounted) return;
        setState(() {
          _values[0] = '';
          _busy = false;
        });
      } else {
        final remaining = auth.pinCooldownRemaining;
        setState(() {
          _values[0] = '';
          _busy = false;
          _error = remaining > Duration.zero
              ? 'Too many attempts.'
              : 'Wrong PIN — ${AuthProvider.maxPinAttempts - auth.failedPinAttempts} '
                    'tries left.';
        });
        if (remaining > Duration.zero) _startCooldownTicker();
      }
      return;
    }

    final newIdx = _newIndex;
    final confirmIdx = _confirmIndex;

    // New PIN just completed: move to confirmation.
    if (index == newIdx) {
      setState(() {
        _active = confirmIdx;
        _busy = false;
      });
      return;
    }

    // Confirmation completed: compare and store.
    if (index == confirmIdx) {
      final newPin = _values[newIdx];
      final confirmPin = _values[confirmIdx];
      if (newPin != confirmPin) {
        setState(() {
          _values[confirmIdx] = '';
          _active = newIdx;
          _busy = false;
          _error = "Those PINs don't match. Try again.";
        });
        return;
      }

      await auth.setOfflinePin(newPin);
      // Only the create flow opens offline mode. The profile's update flow
      // stores the PIN and returns the person to where they were.
      if (_isCreate) await auth.enterOfflineMode();
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < _values.length; i++) {
          _values[i] = '';
        }
        _active = 0;
        _busy = false;
        _error = null;
      });
      if (_isUpdate) widget.onSaved?.call();
    }
  }

  void _startCooldownTicker() {
    _cooldownTicker?.cancel();
    _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {});
      if (context.read<AuthProvider>().pinCooldownRemaining <= Duration.zero) {
        timer.cancel();
        setState(() => _error = null);
      }
    });
  }

  Future<void> _signInInstead() async {
    // Ending the offline session clears the flag and flips the status. On a
    // cold start the pad is the whole stack, so go to the login screen; when it
    // was pushed over the landing screen, popping returns there.
    await context.read<AuthProvider>().exitOfflineMode();
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed('login');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_pinChecked) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_isUpdate ? 'Offline PIN' : 'Offline mode'),
          automaticallyImplyLeading: _isSetup,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final auth = context.watch<AuthProvider>();
    final cooldown = auth.pinCooldownRemaining;
    final cooling = cooldown > Duration.zero;
    final enabled = !_busy && !cooling;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isUpdate ? 'Offline PIN' : 'Offline mode'),
        // The lock screen is not somewhere to go back to; the create and update
        // flows are pages pushed from another screen and can be backed out of.
        automaticallyImplyLeading: _isSetup,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                  const SizedBox(height: 28),
                  for (var i = 0; i < _values.length; i++) ...[
                    _PinFieldRow(
                      label: _labels[i],
                      length: _values[i].length,
                      total: _pinLength,
                      isActive: i == _active,
                      onTap: () => _activate(i),
                    ),
                    SizedBox(height: i == _values.length - 1 ? 20 : 12),
                  ],
                  SizedBox(
                    height: 40,
                    child: Text(
                      cooling
                          ? 'Too many attempts. Try again in '
                                '${cooldown.inSeconds}s.'
                          : (_error ?? ''),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.error,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _PinKeypad(
                    enabled: enabled,
                    onDigit: _press,
                    onBackspace: _backspace,
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : (_isSetup
                              ? () => context.pop()
                              : _signInInstead),
                    child: Text(_isSetup ? 'Cancel' : 'Sign in instead'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A labelled PIN row. Tapping it makes it the active input target.
class _PinFieldRow extends StatelessWidget {
  const _PinFieldRow({
    required this.label,
    required this.length,
    required this.total,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final int length;
  final int total;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? scheme.primary : scheme.outlineVariant,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isActive
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    ),
              ),
            ),
            _PinDots(length: length, total: total, isActive: isActive),
          ],
        ),
      ),
    );
  }
}

/// Four dots, filled as digits are pressed.
class _PinDots extends StatelessWidget {
  const _PinDots({
    required this.length,
    required this.total,
    this.isActive = false,
  });

  final int length;
  final int total;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < length ? scheme.primary : Colors.transparent,
              border: Border.all(
                color: i < length
                    ? scheme.primary
                    : (isActive ? scheme.primary : scheme.outline),
                width: 2,
              ),
            ),
          ),
      ],
    );
  }
}

/// The digit grid: 1-9, a gap, 0, backspace — the layout every PIN pad uses.
class _PinKeypad extends StatelessWidget {
  const _PinKeypad({
    required this.enabled,
    required this.onDigit,
    required this.onBackspace,
  });

  final bool enabled;
  final void Function(String digit) onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final digit in row)
                _PinKey(
                  label: digit,
                  enabled: enabled,
                  onPressed: () => onDigit(digit),
                ),
            ],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 76, height: 64),
            _PinKey(
              label: '0',
              enabled: enabled,
              onPressed: () => onDigit('0'),
            ),
            SizedBox(
              width: 76,
              height: 64,
              child: Center(
                child: IconButton(
                  key: const Key('pinBackspace'),
                  tooltip: 'Delete last digit',
                  onPressed: enabled ? onBackspace : null,
                  icon: const Icon(Icons.backspace_outlined),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PinKey extends StatelessWidget {
  const _PinKey({
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(6),
      child: SizedBox(
        width: 76,
        height: 64,
        child: TextButton(
          key: Key('pinKey$label'),
          onPressed: enabled ? onPressed : null,
          style: TextButton.styleFrom(
            backgroundColor: AppColors.brandGreenSurface,
            foregroundColor: AppColors.brandGreen,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}
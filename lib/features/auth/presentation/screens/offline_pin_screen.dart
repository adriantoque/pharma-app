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

  String _entry = '';

  /// The first PIN of the create/update flow, waiting to be confirmed.
  String? _firstPin;

  String? _error;
  bool _busy = false;

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
  void dispose() {
    _cooldownTicker?.cancel();
    super.dispose();
  }

  String get _title {
    if (_isUnlock) return 'Enter your offline PIN';
    return _firstPin == null ? 'Choose a 4-digit PIN' : 'Confirm your PIN';
  }

  String get _subtitle {
    if (_isUnlock) {
      return 'This tablet was left in offline mode. The PIN keeps the price '
          'list and order history to the people who work here.';
    }
    if (_isUpdate) {
      return _firstPin == null
          ? 'The PIN unlocks offline mode on this device. Setting a new one '
                'replaces the old PIN.'
          : 'Type the same four digits again.';
    }
    return _firstPin == null
        ? 'The PIN unlocks offline mode on this device. Choose something you '
              'will remember at the counter.'
        : 'Type the same four digits again.';
  }

  void _press(String digit) {
    if (_busy || _entry.length >= _pinLength) return;
    if (context.read<AuthProvider>().pinCooldownRemaining > Duration.zero) {
      return;
    }
    setState(() {
      _entry += digit;
      _error = null;
    });
    if (_entry.length == _pinLength) {
      unawaited(_submit());
    }
  }

  void _backspace() {
    if (_busy || _entry.isEmpty) return;
    setState(() => _entry = _entry.substring(0, _entry.length - 1));
  }

  Future<void> _submit() async {
    final pin = _entry;
    final auth = context.read<AuthProvider>();
    setState(() => _busy = true);

    if (_isCreate || _isUpdate) {
      // Stage one only records the choice; nothing is stored until the person
      // has typed it twice.
      if (_firstPin == null) {
        setState(() {
          _firstPin = pin;
          _entry = '';
          _busy = false;
        });
        return;
      }

      if (_firstPin != pin) {
        setState(() {
          _firstPin = null;
          _entry = '';
          _busy = false;
          _error = "Those PINs don't match. Start again.";
        });
        return;
      }

      await auth.setOfflinePin(pin);
      // Only the create flow opens offline mode. The profile's update flow
      // stores the PIN and returns the person to where they were.
      if (_isCreate) await auth.enterOfflineMode();
      if (!mounted) return;
      setState(() {
        _entry = '';
        _busy = false;
      });
      if (_isUpdate) widget.onSaved?.call();
      return;
    }

    final ok = await auth.unlockOffline(pin);
    if (!mounted) return;

    if (ok) {
      // The pad has two callers: a cold start that restored an offline session
      // (already offline, only the lock was shut) and "Continue Offline" on the
      // landing screen (no session yet). In the second case the right PIN is what
      // starts offline mode; the router's redirect then leaves the pad.
      if (!auth.isOffline) await auth.enterOfflineMode();
      if (!mounted) return;
      setState(() {
        _entry = '';
        _busy = false;
      });
      return;
    }

    final remaining = auth.pinCooldownRemaining;
    setState(() {
      _entry = '';
      _busy = false;
      _error = remaining > Duration.zero
          ? 'Too many attempts.'
          : 'Wrong PIN — ${AuthProvider.maxPinAttempts - auth.failedPinAttempts} '
                'tries left.';
    });
    if (remaining > Duration.zero) _startCooldownTicker();
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
                  _PinDots(length: _entry.length, total: _pinLength),
                  const SizedBox(height: 20),
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

/// Four dots, filled as digits are pressed.
class _PinDots extends StatelessWidget {
  const _PinDots({required this.length, required this.total});

  final int length;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < total; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < length ? scheme.primary : Colors.transparent,
              border: Border.all(
                color: i < length ? scheme.primary : scheme.outline,
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

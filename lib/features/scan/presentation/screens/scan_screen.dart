import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../orders/presentation/providers/order_provider.dart';
import '../../../search/data/models/medicine_model.dart';
import '../../../search/data/repositories/medicine_repository.dart';
import '../../../search/presentation/widgets/quantity_sheet.dart';
import '../../data/camera_prescription_camera.dart';
import '../../data/mlkit_text_recognizer.dart';
import '../../data/prescription_matcher.dart';
import '../../domain/prescription_camera.dart';
import '../../domain/prescription_recognizer.dart';

/// Scan tab: photographs a printed prescription and offers what it names.
///
/// The tab is a camera rather than a canvas: ML Kit's text recognition reads
/// printed words off a picture, which is what a paper prescription arrives as.
/// The preview is live in the tab, the user taps Scan it, and the photo is read
/// by Google's text model on the device. Picking a picture from the gallery is
/// the fallback for a denied camera.
///
/// Nothing is ever added to the order by itself. Printed text is still read
/// wrong now and then — a "5" that is a "6", an "o" that is an "a" — and
/// silently filing a misread drug is worse than making the user tap it, so
/// every suggestion waits behind its own button.
///
/// The recognizer and the camera arrive as constructor arguments, which is
/// what lets this whole flow run in a widget test: the real ones are platform
/// channels, and the tests use fakes that return canned readings.
class ScanScreen extends StatefulWidget {
  const ScanScreen({
    super.key,
    this.repository = const StaticMedicineRepository(),
    this.recognizer,
    this.camera,
  });

  final MedicineRepository repository;

  /// The printed-text reader, injected by the tests. Left null in the app,
  /// where the state builds the real platform-backed one.
  final PrescriptionRecognizer? recognizer;

  /// The camera and gallery picker, injected by the tests. Left null in the
  /// app, where the state builds the real platform-backed one.
  final PrescriptionCamera? camera;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  late final PrescriptionRecognizer _recognizer =
      widget.recognizer ?? MlKitTextRecognizer();
  late final PrescriptionCamera _camera =
      widget.camera ?? CameraPrescriptionCamera();

  late final PrescriptionMatcher _matcher =
      PrescriptionMatcher(widget.repository);

  /// Null until the camera has been asked about, so the pane can say "opening"
  /// without a spinner that would never stop.
  bool? _cameraReady;
  String? _cameraError;
  bool _isReading = false;
  String? _error;

  /// Every reading ML Kit offered, per line, so a corrected line can be
  /// re-matched without the photo being read again.
  List<List<String>> _candidates = const [];
  List<String> _readings = const [];
  List<PrescriptionSuggestion> _suggestions = const [];

  @override
  void initState() {
    super.initState();
    if (_recognizer.isSupported && _camera.isSupported) {
      unawaited(_initCamera());
    }
  }

  @override
  void dispose() {
    // Both are disposed whether they were handed in or built here, so a fake
    // can assert they were released and the real ones cannot outlive the tab.
    unawaited(_recognizer.dispose());
    unawaited(_camera.dispose());
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      await _camera.initialize();
      if (!mounted) return;
      setState(() => _cameraReady = true);
    } on PrescriptionRecognitionException catch (error) {
      if (!mounted) return;
      setState(() {
        _cameraReady = false;
        _cameraError = error.message;
      });
    }
  }

  void _retryCamera() {
    setState(() {
      _cameraReady = null;
      _cameraError = null;
      _error = null;
    });
    unawaited(_initCamera());
  }

  /// Takes the photo the preview is showing and reads it.
  Future<void> _scan() async {
    if (_isReading || _cameraReady != true) return;

    final Uint8List bytes;
    try {
      bytes = await _camera.takePicture();
    } on PrescriptionRecognitionException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
      return;
    }
    await _readBytes(bytes);
  }

  /// Lets the user choose a photo of the prescription instead of using the
  /// camera. Works even when the camera was refused.
  Future<void> _pickFromGallery() async {
    if (_isReading) return;

    final Uint8List? bytes;
    try {
      bytes = await _camera.pickFromGallery();
    } on PrescriptionRecognitionException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
      return;
    }
    if (bytes == null) return; // the user backed out of the picker
    await _readBytes(bytes);
  }

  Future<void> _readBytes(Uint8List bytes) async {
    setState(() {
      _isReading = true;
      _error = null;
    });

    try {
      final readings = await _recognizer.recognize(bytes);
      if (!mounted) return;

      final suggestions = _matcher.suggest(readings);
      setState(() {
        _candidates = [
          for (final line in readings) List<String>.of(line.candidates),
        ];
        _readings = [
          for (var i = 0; i < readings.length; i++)
            _displayFor(i, readings[i], suggestions),
        ];
        _suggestions = suggestions;
        _isReading = false;
      });
    } on PrescriptionRecognitionException catch (error) {
      if (!mounted) return;
      setState(() {
        _isReading = false;
        _error = error.message;
      });
    }
  }

  /// What to show as line [index]'s reading.
  ///
  /// The catalog's pick wins over ML Kit's own first choice: the top candidate
  /// is sometimes a misread, and the reading that produced a real match is the
  /// more useful one to put in front of the user.
  String _displayFor(
    int index,
    RecognizedLine line,
    List<PrescriptionSuggestion> suggestions,
  ) {
    String? bestReading;
    var bestConfidence = 0.0;
    for (final suggestion in suggestions) {
      if (suggestion.lineIndex != index) continue;
      if (suggestion.confidence <= bestConfidence) continue;
      bestConfidence = suggestion.confidence;
      bestReading = suggestion.reading;
    }
    return bestReading ?? line.best ?? '';
  }

  /// Re-matches a line the user corrected, without the photo being read again.
  void _setReading(int index, String text) {
    final candidates = [
      for (final line in _candidates) List<String>.of(line),
    ];
    final readings = [..._readings];
    candidates[index] = [text];
    readings[index] = text;

    setState(() {
      _candidates = candidates;
      _readings = readings;
      _suggestions = _matcher.suggest([
        for (final line in candidates) RecognizedLine(line),
      ]);
    });
  }

  Future<void> _editReading(int index) async {
    final text = await showDialog<String>(
      context: context,
      builder: (context) =>
          _EditLineDialog(lineNumber: index + 1, initialText: _readings[index]),
    );
    if (!mounted || text == null) return;
    _setReading(index, text);
  }

  /// Adds a suggestion to the order behind the same quantity sheet the search
  /// rows use, so the stock ceiling is enforced in one place.
  Future<void> _add(MedicineModel medicine) async {
    final order = context.read<OrderProvider>();
    final quantity = await showQuantitySheet(context, medicine: medicine);
    if (quantity == null) return;

    order.add(medicine, quantity);

    // After the await, so the confirmation is not swallowed by the sheet on its
    // way off screen.
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added $quantity × ${medicine.name}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canScanOnPlatform = _recognizer.isSupported && _camera.isSupported;
    return Scaffold(
      appBar: AppBar(title: const Text('Scan'), centerTitle: true),
      body: Column(
        children: [
          const _Intro(),
          if (canScanOnPlatform) ...[
            _cameraSection(),
            _CameraControls(
              cameraReady: _cameraReady == true,
              isReading: _isReading,
              onScan: _scan,
              onPick: _pickFromGallery,
            ),
            if (_error case final error?)
              _ErrorCard(
                message: error,
                onRetry: _scan,
              ),
          ] else
            const _Notice(
              icon: Icons.camera_outlined,
              message: 'Camera text recognition is not available on this '
                  'platform. Search for a medicine below instead.',
            ),
          Expanded(
            child: _Results(
              readings: _readings,
              candidates: _candidates,
              suggestions: _suggestions,
              isReading: _isReading,
              onEdit: _editReading,
              onAdd: _add,
            ),
          ),
        ],
      ),
    );
  }

  /// Live preview, or why it is not showing yet.
  Widget _cameraSection() {
    if (_cameraReady == true) {
      final preview = _camera.preview;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          height: 300,
          child: preview ??
              Center(
                child: Text('No preview', style: Theme.of(context).textTheme.bodySmall),
              ),
        ),
      );
    }
    if (_cameraReady == false) {
      return _CameraGate(
        message: _cameraError ?? 'The camera could not start.',
        onRetry: _retryCamera,
      );
    }
    return const _Notice(
      icon: Icons.hourglass_empty,
      message: 'Opening the camera…',
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Frame the printed prescription, then scan it',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Scan and pick a photo in one row under the preview.
class _CameraControls extends StatelessWidget {
  const _CameraControls({
    required this.cameraReady,
    required this.isReading,
    required this.onScan,
    required this.onPick,
  });

  final bool cameraReady;
  final bool isReading;
  final VoidCallback onScan;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final canUseCamera = cameraReady && !isReading;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          FilledButton.icon(
            key: const Key('scanButton'),
            onPressed: canUseCamera ? onScan : null,
            icon: const Icon(Icons.camera_alt),
            label: Text(isReading ? 'Reading…' : 'Scan it'),
          ),
          const SizedBox(width: 8),
          IconButton.outlined(
            key: const Key('pickPhotoButton'),
            onPressed: isReading ? null : onPick,
            icon: const Icon(Icons.photo_library_outlined),
            tooltip: 'Pick a prescription from the gallery',
          ),
        ],
      ),
    );
  }
}

/// Why the preview is not showing: the camera was refused, missing, or broke.
/// Picking a photo from the gallery is still open to the user.
class _CameraGate extends StatelessWidget {
  const _CameraGate({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.videocam_off_outlined,
                  size: 20,
                  color: theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('retryCameraButton'),
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

/// One card per printed line: what the recognizer made of it, and the medicines
/// that reading could name.
class _Results extends StatelessWidget {
  const _Results({
    required this.readings,
    required this.candidates,
    required this.suggestions,
    required this.isReading,
    required this.onEdit,
    required this.onAdd,
  });

  final List<String> readings;
  final List<List<String>> candidates;
  final List<PrescriptionSuggestion> suggestions;
  final bool isReading;
  final void Function(int index) onEdit;
  final void Function(MedicineModel medicine) onAdd;

  @override
  Widget build(BuildContext context) {
    final lines = [
      for (var i = 0; i < readings.length; i++) _LineResult(
        index: i,
        reading: readings[i],
        isEmpty: candidates[i].isEmpty,
        suggestions: [
          for (final suggestion in suggestions)
            if (suggestion.lineIndex == i) suggestion,
        ],
        onEdit: () => onEdit(i),
        onAdd: onAdd,
      ),
    ];

    if (lines.isEmpty) {
      return const _Empty(
        message: 'Nothing read yet. Point the camera at a printed prescription '
            'and tap Scan it.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: lines.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) => lines[index],
    );
  }
}

class _LineResult extends StatelessWidget {
  const _LineResult({
    required this.index,
    required this.reading,
    required this.isEmpty,
    required this.suggestions,
    required this.onEdit,
    required this.onAdd,
  });

  /// The line this card belongs to, or -1 for the search results.
  final int index;
  final String reading;
  final bool isEmpty;
  final List<PrescriptionSuggestion> suggestions;
  final VoidCallback onEdit;
  final void Function(MedicineModel medicine) onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  index < 0
                      ? reading
                      : 'Line ${index + 1}: ${isEmpty ? 'nothing readable' : '"$reading"'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (index >= 0)
                TextButton(
                  key: Key('editReading$index'),
                  onPressed: onEdit,
                  child: const Text('Fix'),
                ),
            ],
          ),
          if (suggestions.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                index < 0
                    ? 'Nothing in the price list looks like that.'
                    : 'No medicine in the price list looks like that. Try '
                          'Fix, or search below.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            )
          else
            for (final suggestion in suggestions)
              _SuggestionRow(
                suggestion: suggestion,
                onAdd: () => onAdd(suggestion.medicine),
              ),
        ],
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.suggestion, required this.onAdd});

  final PrescriptionSuggestion suggestion;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final medicine = suggestion.medicine;
    // Label and severity come back together from the model so a healthy count
    // can never be rendered in the error colour.
    final (stockLabel, isStockWarning) = medicine.stockLine;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  medicine.name,
                  maxLines: 2,
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  '$stockLabel · '
                  '${(suggestion.confidence * 100).round()}% match',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isStockWarning
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            medicine.formattedPrice,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            key: Key('add${medicine.name}'),
            onPressed: medicine.isOutOfStock ? null : onAdd,
            icon: const Icon(Icons.add),
            tooltip: 'Add ${medicine.name}',
          ),
        ],
      ),
    );
  }
}

class _EditLineDialog extends StatefulWidget {
  const _EditLineDialog({
    required this.lineNumber,
    required this.initialText,
  });

  final int lineNumber;
  final String initialText;

  @override
  State<_EditLineDialog> createState() => _EditLineDialogState();
}

class _EditLineDialogState extends State<_EditLineDialog> {
  /// Owned here rather than by the screen: the dialog is still animating out
  /// when `showDialog` returns, so disposing the controller in the caller
  /// would tear the field out from under that transition.
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Line ${widget.lineNumber}'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(labelText: 'What it said'),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Use this'),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
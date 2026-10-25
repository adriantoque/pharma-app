import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../orders/presentation/providers/order_provider.dart';
import '../../../search/data/models/medicine_model.dart';
import '../../../search/data/repositories/medicine_repository.dart';
import '../../../search/presentation/providers/medicine_provider.dart';
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
    this.repository,
    this.recognizer,
    this.camera,
    this.embedded = false,
    this.previewHeight,
    this.introMessage = 'Frame the printed prescription, then scan it',
  });

  /// The catalogue a scanned line is matched against.
  ///
  /// Null in the app, where the live [MedicineProvider] is used instead, so that
  /// a scan searches the same hundreds of products the counter actually stocks
  /// rather than the 64-line list baked into the binary. The tests pass a static
  /// list, which keeps their suggestions predictable.
  final MedicineRepository? repository;

  /// The printed-text reader, injected by the tests. Left null in the app,
  /// where the state builds the real platform-backed one.
  final PrescriptionRecognizer? recognizer;

  /// The camera and gallery picker, injected by the tests. Left null in the
  /// app, where the state builds the real platform-backed one.
  final PrescriptionCamera? camera;

  /// Whether to render without this screen's own Scaffold and AppBar.
  ///
  /// The Scan SKU tab already supplies the POS chrome, so it embeds the scanner
  /// inline rather than pushing a second screen with a second app bar.
  final bool embedded;

  /// A fixed preview height for an embedded host. Null keeps this screen's own
  /// 300/160 logic, which the pushed camera route still uses.
  final double? previewHeight;

  /// The one-line instruction above the camera.
  final String introMessage;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  late final PrescriptionRecognizer _recognizer =
      widget.recognizer ?? MlKitTextRecognizer();
  late final PrescriptionCamera _camera =
      widget.camera ?? CameraPrescriptionCamera();

  /// Built on first use rather than in a field initialiser, because it needs the
  /// provider and `context.read` is not valid during field initialisation.
  ///
  /// Read once and held. The catalogue is a few hundred lines and a scan matches
  /// against it per line, so rebuilding the matcher for every keystroke would
  /// re-normalise the whole list each time; a line corrected mid-scan is matched
  /// against the same matcher, which is the same list the suggestions already
  /// came from.
  late final PrescriptionMatcher _matcher = PrescriptionMatcher(
    widget.repository ?? context.read<MedicineProvider>(),
  );

  /// How tall the preview stays while the results own the screen: enough to
  /// recognise what is still being framed, little enough to leave the matches
  /// the room they were missing when the preview took three fifths of it.
  static const double _collapsedPreviewHeight = 140;

  /// Null until the camera has been asked about, so the pane can say "opening"
  /// without a spinner that would never stop.
  bool? _cameraReady;
  String? _cameraError;
  bool _isReading = false;
  String? _error;

  /// Whether the last read's results are taking the screen.
  ///
  /// A scan is the moment the user wants room to read, so a successful read
  /// collapses the preview to a strip and hands the space to the results;
  /// "Scan again" hands it back so the next photo can be framed. The readings
  /// themselves stay in state either way, so nothing already read is thrown
  /// away by changing the layout.
  bool _showResults = false;

  /// Whether the last failure was the missing model rather than the photo.
  ///
  /// The two want opposite things from the same button. A misread photo is worth
  /// asking about again immediately; a model that could not be downloaded is not,
  /// and pressing it again on a phone with no signal only produces the same
  /// failure while the message says it will work this time.
  bool _errorNeedsConnection = false;

  /// The text read on each line of the photo, in the order they appeared.
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
      _errorNeedsConnection = false;
    });
    unawaited(_initCamera());
  }

  /// Records a failure the way the screen will later describe it.
  ///
  /// One place so the flag that decides the wording can never get out of step
  /// with the message it belongs to.
  void _reportError(PrescriptionRecognitionException error) {
    if (!mounted) return;
    setState(() {
      _error = error.message;
      _errorNeedsConnection = error.isOffline;
    });
  }

  /// Takes the photo the preview is showing and reads it.
  Future<void> _scan() async {
    if (_isReading || _cameraReady != true) return;

    final Uint8List bytes;
    try {
      bytes = await _camera.takePicture();
    } on PrescriptionRecognitionException catch (error) {
      if (!mounted) return;
      _reportError(error);
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
      _reportError(error);
      return;
    }
    if (bytes == null) return; // the user backed out of the picker
    await _readBytes(bytes);
  }

  Future<void> _readBytes(Uint8List bytes) async {
    setState(() {
      _isReading = true;
      _error = null;
      _errorNeedsConnection = false;
    });

    try {
      final readings = await _recognizer.recognize(bytes);
      if (!mounted) return;

      setState(() {
        _readings = [for (final line in readings) line.text];
        _suggestions = _matcher.suggest(readings);
        _isReading = false;
        // Nothing read means nothing to give the room to, so the preview
        // stays where it is rather than collapsing onto an empty result.
        _showResults = readings.isNotEmpty;
      });
    } on PrescriptionRecognitionException catch (error) {
      if (!mounted) return;
      _reportError(error);
      setState(() => _isReading = false);
    }
  }

  /// Re-matches a line the user corrected, without the photo being read again.
  void _setReading(int index, String text) {
    final readings = [..._readings];
    readings[index] = text;

    setState(() {
      _readings = readings;
      _suggestions = _matcher.suggest([
        for (final line in readings) RecognizedLine(line),
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

  /// Hands the screen back to the camera so the next photo can be framed.
  ///
  /// The readings stay in state: only the layout changes, and a later
  /// successful scan simply replaces them.
  void _scanAgain() => setState(() => _showResults = false);

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

  /// Shows medicine details in a dialog when the user taps the info button on
  /// a suggestion.
  ///
  /// The confidence quoted here is the matcher's own number, not a fixed word:
  /// the row beside it prints the percentage, and a dialog that called every
  /// match "high" would contradict a row saying 61%.
  void _showMedicineDetails(PrescriptionSuggestion suggestion) {
    final medicine = suggestion.medicine;
    final theme = Theme.of(context);
    final (stockLabel, stockState) = medicine.stockLine;
    Color stockColor;
    if (stockState == StockState.outOfStock || stockState == StockState.low) {
      stockColor = theme.colorScheme.error;
    } else if (stockState == StockState.unknown) {
      stockColor = theme.colorScheme.outline;
    } else {
      stockColor = theme.colorScheme.onSurfaceVariant;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(medicine.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Match confidence: '
                '${(suggestion.confidence * 100).round()}%',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Stock: $stockLabel',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: stockColor,
                ),
              ),
              const SizedBox(height: 8),
              if (medicine.dosageInfo case final dosage?)
                Text('Dosage: $dosage',
                  style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              if (medicine.ageGuidance case final age?)
                Text('Age guidance: ${age.kids}',
                  style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canScanOnPlatform = _recognizer.isSupported && _camera.isSupported;
    final body = Column(
      children: [
        _Intro(message: widget.introMessage),
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
              needsConnection: _errorNeedsConnection,
              onRetry: _scan,
            ),
        ] else
          const _Notice(
            icon: Icons.camera_outlined,
            message:
                'Camera text recognition is not available on this '
                'platform. Search for a medicine below instead.',
          ),
        Expanded(
          child: _Results(
            readings: _readings,
            suggestions: _suggestions,
            isReading: _isReading,
            showResults: _showResults,
            onEdit: _editReading,
            onAdd: _add,
            onScanAgain: _scanAgain,
            onDetails: _showMedicineDetails,
          ),
        ),
      ],
    );

    // Embedded in a host that already has chrome (the Scan SKU tab).
    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(title: const Text('Scan')),
      body: body,
    );
  }

  /// Live preview, or why it is not showing yet.
  Widget _cameraSection() {
    if (_cameraReady == true) {
      final preview = _camera.preview;
      // An error card below is worth more room than a live feed the user
      // cannot act on while it is up, and on a short phone the two together
      // overflow the column. Reclaim the preview's height only when there is
      // something more important underneath it.
      //
      // An embedded host (the Scan SKU tab) asks for a big preview as a
      // fraction of the screen; the pushed camera route keeps 300/160.
      final requested = widget.previewHeight;
      final fullHeight = requested == null
          ? (_error == null ? 300.0 : 160.0)
          : (_error == null ? requested : requested * 0.55);
      final previewHeight =
          _showResults ? _collapsedPreviewHeight : fullHeight;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          height: previewHeight,
          child:
              preview ??
              Center(
                child: Text(
                  'No preview',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
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
  const _Intro({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          message,
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
          OutlinedButton.icon(
            key: const Key('scanButton'),
            onPressed: canUseCamera ? onScan : null,
            style: OutlinedButton.styleFrom(
              backgroundColor: AppColors.brandGreenSurface,
              foregroundColor: AppColors.brandGreen,
              side: const BorderSide(
                color: AppColors.brandGreenSurfaceBorder,
              ),
            ),
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
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.brandGreen,
                ),
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
  const _ErrorCard({
    required this.message,
    required this.onRetry,
    this.needsConnection = false,
  });

  final String message;
  final VoidCallback onRetry;

  /// The failure was the model download rather than the photograph, so retrying
  /// is worth nothing until the device has a connection again.
  final bool needsConnection;

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
              // Says what has to change before the button will do anything. A
              // retry that cannot possibly succeed, offered without saying so, is
              // worse than no button: it teaches the user that the app does not
              // know what went wrong.
              needsConnection
                  ? '$message\nWaiting for a connection — text recognition needs to '
                        'download its model once, then it works offline.'
                  : message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          TextButton(
            key: const Key('retryReadingButton'),
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.brandGreen,
            ),
            child: Text(needsConnection ? 'Try again' : 'Retry'),
          ),
        ],
      ),
    );
  }
}

/// One card per printed line: what the recognizer made of it, and the medicines
/// that reading could name.
///
/// Above the cards sits the header that turns a scan into one event: how much
/// was read, how much of it matched, and the way back to the full preview.
class _Results extends StatelessWidget {
  const _Results({
    required this.readings,
    required this.suggestions,
    required this.isReading,
    required this.showResults,
    required this.onEdit,
    required this.onAdd,
    required this.onScanAgain,
    required this.onDetails,
  });

  final List<String> readings;
  final List<PrescriptionSuggestion> suggestions;
  final bool isReading;

  /// Whether the results are meant to be on screen at all.
  ///
  /// False while the camera has the room, so an older result is not shown
  /// under a preview that has already been framed for the next photo.
  final bool showResults;

  final void Function(int index) onEdit;
  final void Function(MedicineModel medicine) onAdd;
  final VoidCallback onScanAgain;
  final void Function(PrescriptionSuggestion suggestion) onDetails;

  static const String _nothingRead =
      'Nothing read yet. Point the camera at printed text and tap Scan it.';

  @override
  Widget build(BuildContext context) {
    if (!showResults) {
      return _Empty(
        message: readings.isEmpty
            ? _nothingRead
            : 'Results hidden — tap Scan it to read a new photo.',
      );
    }

    final lines = [
      for (var i = 0; i < readings.length; i++)
        _LineResult(
          index: i,
          reading: readings[i],
          isEmpty: readings[i].isEmpty,
          suggestions: [
            for (final suggestion in suggestions)
              if (suggestion.lineIndex == i) suggestion,
          ],
          onEdit: () => onEdit(i),
          onAdd: onAdd,
          onDetails: onDetails,
        ),
    ];

    if (lines.isEmpty) {
      return const _Empty(message: _nothingRead);
    }

    return Column(
      children: [
        _ResultHeader(
          lineCount: readings.length,
          matchCount: suggestions.length,
          onScanAgain: onScanAgain,
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            itemCount: lines.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) => lines[index],
          ),
        ),
      ],
    );
  }
}

/// What one scan produced, in numbers, and the way back to the big preview.
///
/// The counts are the whole point of the header: "3 lines · 2 matches" says
/// at a glance whether the photo was read and whether anything came of it,
/// which is the question the cards below only answer one card at a time.
class _ResultHeader extends StatelessWidget {
  const _ResultHeader({
    required this.lineCount,
    required this.matchCount,
    required this.onScanAgain,
  });

  final int lineCount;
  final int matchCount;
  final VoidCallback onScanAgain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = lineCount == 1 ? '1 line' : '$lineCount lines';
    final matches = matchCount == 1 ? '1 match' : '$matchCount matches';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Scan result · $lines · $matches',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            key: const Key('scanAgainButton'),
            onPressed: onScanAgain,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.brandGreen,
            ),
            child: const Text('Scan again'),
          ),
        ],
      ),
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
    required this.onDetails,
  });

  /// The line this card belongs to, or -1 for the search results.
  final int index;
  final String reading;
  final bool isEmpty;
  final List<PrescriptionSuggestion> suggestions;
  final VoidCallback onEdit;
  final void Function(MedicineModel medicine) onAdd;
  final void Function(PrescriptionSuggestion suggestion) onDetails;

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
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.brandGreen,
                  ),
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
                onDetailsPress: () => onDetails(suggestion),
              ),
        ],
      ),
    );
  }
}/// One matched medicine under the line that named it.
///
/// The chips carry the facts worth knowing before tapping Add: what is on the
/// shelf, how sure the match is, whether a prescription is needed, and how
/// many are already in the order. The Add and info buttons keep their places
/// and their keys, so the row answers to everything that already finds it.
class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.suggestion,
    required this.onAdd,
    required this.onDetailsPress,
  });

  final PrescriptionSuggestion suggestion;
  final VoidCallback onAdd;
  final VoidCallback onDetailsPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final medicine = suggestion.medicine;
    // Label and severity come back together from the model so a healthy count
    // can never be rendered in the error colour.
    final (stockLabel, stockState) = medicine.stockLine;
    final stockColor = switch (stockState) {
      // Matched to the search row: a shortage is called out, an uncounted item
      // is merely muted, so a whole scan full of imported-but-uncounted
      // products does not read as an inventory alert.
      StockState.outOfStock || StockState.low => theme.colorScheme.error,
      StockState.unknown => theme.colorScheme.outline,
      StockState.available => theme.colorScheme.onSurfaceVariant,
    };
    final inCart = context.watch<OrderProvider>().quantityOf(medicine);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        medicine.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
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
                  ],
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      stockLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: stockColor,
                      ),
                    ),
                    Text(
                      '${(suggestion.confidence * 100).round()}% match',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (medicine.requiresRx) _rxPill(theme),
                    if (inCart > 0)
                      Text(
                        '×$inCart in cart',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            key: Key('add${medicine.name}'),
            onPressed: medicine.isOutOfStock ? null : onAdd,
            icon: const Icon(Icons.add),
            tooltip: 'Add ${medicine.name}',
          ),
          IconButton.outlined(
            key: Key('details${medicine.name}'),
            onPressed: onDetailsPress,
            icon: const Icon(Icons.info_outlined),
            tooltip: 'Medicine details',
          ),
        ],
      ),
    );
  }

  /// The prescription badge, in the surface colours this screen already uses
  /// for its error and camera cards rather than the product card's hardcoded
  /// reds: the scan tab is themed, and a pill that ignored the theme would be
  /// the one thing on the card that did not fit.
  static Widget _rxPill(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Rx required',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onErrorContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EditLineDialog extends StatefulWidget {
  const _EditLineDialog({required this.lineNumber, required this.initialText});

  final int lineNumber;
  final String initialText;

  @override
  State<_EditLineDialog> createState() => _EditLineDialogState();
}

class _EditLineDialogState extends State<_EditLineDialog> {
  /// Owned here rather than by the screen: the dialog is still animating out
  /// when `showDialog` returns, so disposing the controller in the caller
  /// would tear the field out from under that transition.
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );

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
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          style: OutlinedButton.styleFrom(
            backgroundColor: AppColors.brandGreenSurface,
            foregroundColor: AppColors.brandGreen,
            side: const BorderSide(
              color: AppColors.brandGreenSurfaceBorder,
            ),
          ),
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

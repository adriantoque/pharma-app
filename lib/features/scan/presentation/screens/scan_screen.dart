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
/// While the feed is live its frames are also being read continuously: matched
/// medicine names surface under the frame as chips, tap-for-tap the same Add
/// as a deliberate result, so pointing the camera at a name already answers
/// "do we stock this?" before a photo is taken. The Scan button stays the
/// deliberate commit — it freezes the frame, reads it, and hands its lines to
/// the results the way it always has.
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
    widget.repository ?? const StaticMedicineRepository(),
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

  /// Live scanning: the preview frames are read continuously while the camera
  /// has the room, so what a deliberate photo would find surfaces the moment
  /// it is framed — candidates appear under the frame as the user points at
  /// the text, and the Scan button remains the deliberate commit.
  ///
  /// A single-frame gate: recognition costs far more than a frame arrives, so
  /// at most one read is ever in flight and anything the camera hands over
  /// meanwhile is skipped instead of queued. Pacing is the camera wrapper's
  /// job (a frame is converted at a fraction of camera rate); the reader only
  /// refuses to queue.
  bool _liveOn = false;
  bool _liveFrameBusy = false;

  /// Whether the frames have shown any readable text, so the live bar can say
  /// "found printed text" instead of a stateless "looking".
  bool _liveTextSeen = false;

  /// Candidates the live reads have matched so far, deduplicated by the
  /// matcher like any other reading list.
  List<PrescriptionSuggestion> _liveSuggestions = const [];

  /// True when living scanning is simply not on offer — no frame support in
  /// the recognizer or the camera, or the stream refused to start. The tab
  /// downgrades quietly: the deliberate flow already works everywhere, so a
  /// missing live view is an upgrade not taken, never an error.
  bool _liveUnavailable = false;

  // ── Stage 2: the stability gate and the committed sheet ───────────────────

  /// The medicine identities the last read matched, ordered. Two frames
  /// holding the same set are one reading; any change restarts the count.
  List<String>? _stableIds;

  /// Consecutive reads that have produced [_stableIds] unchanged.
  int _stabilityCount = 0;

  /// Reads in a row that must agree before the screen commits by itself.
  ///
  /// At the camera wrapper's ~8 frames a second this is about a third of a
  /// second of agreement — long enough to disqualify a lucky misread, short
  /// enough not to feel slow when the frame is already steady.
  static const int _commitStableFrames = 3;

  /// How sure a candidate must be to count towards a self-commit.
  ///
  /// Deliberately above the matcher's 0.6 offer threshold: a live commit raises
  /// the stakes of a misread (the sheet presents itself as done), so only
  /// strong matches are allowed to trigger it. Weaker candidates still display
  /// in the committed sheet — they just cannot vote for it.
  static const double _commitConfidence = 0.75;

  /// Whether auto-commit has already produced a sheet the user is reviewing.
  /// While it is up the gate holds still: a sheet re-committing itself out
  /// from under a hand moving towards a Fix button is the one failure the
  /// scanner must never cause.
  bool _sheetOpen = false;

  /// The auto-commit sheet. The data behind it is the ordinary `_readings` /
  /// `_suggestions` pair, so Fix, Add, and the details dialog work through
  /// exactly the paths they work through in the deliberate results.

  /// The photo currently being read, shown frozen in place of the live feed
  /// while recognition runs, so the screen always answers "which frame am I
  /// reading about?" with a picture. It survives the results — the collapsed
  /// preview shows it too — and is dropped when the camera is woken again.
  Uint8List? _frozenPhoto;

  /// Whether the torch is lit. Held here rather than asked back from the
  /// camera, so the toggle stays honest even on a device that quietly refuses.
  bool _torchOn = false;

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
    // The camera stops its own stream first; a listening live loop is not
    // relevant once this state is gone.
    _liveOn = false;
    _liveFrameBusy = false;
    unawaited(_recognizer.dispose());
    unawaited(_camera.dispose());
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      await _camera.initialize();
      if (!mounted) return;
      setState(() => _cameraReady = true);
      // Live scanning rides on the same permission the deliberate flow needs:
      // a preview that just opened is already framing, so its frames may as
      // well start being read while the user lines up the photo.
      unawaited(_startLive());
    } on PrescriptionRecognitionException catch (error) {
      if (!mounted) return;
      setState(() {
        _cameraReady = false;
        _cameraError = error.message;
      });
    }
  }

  /// Turns live scanning on, or records quietly that this device will not do
  /// it. Either way the deliberate flow is untouched — the live bar is an
  /// upgrade over "frame it and scan it", never a new thing to go wrong loudly.
  Future<void> _startLive() async {
    if (_liveOn ||
        _liveUnavailable ||
        _isReading ||
        _showResults ||
        !_recognizer.supportsFrames ||
        !_camera.supportsLiveFrames) {
      return;
    }
    try {
      await _camera.startLiveFrames(_onLiveFrame);
      if (!mounted) return;
      _liveOn = true;
      setState(() {});
    } on PrescriptionRecognitionException {
      _liveUnavailable = true;
    }
  }

  /// Stops the stream the way stopping is cheap: called before reading a
  /// deliberate capture (the wrapper pauses around [takePicture] anyway, but
  /// a gallery photo read has no such pause of its own), when results take the
  /// screen, and before the tab goes away.
  Future<void> _stopLive() async {
    if (!_liveOn) return;
    _liveOn = false;
    _liveFrameBusy = false;
    await _camera.stopLiveFrames();
  }

  /// One preview frame, read on the recognizer's own pace.
  ///
  /// A transient failure (a badly lit frame, a flaky channel) is skipped
  /// rather than surfaced — the next frame re-reads the same text anyway, and
  /// an error flapping over the feed would outlast the bad frame it came
  /// from. A model that cannot be downloaded is different: every frame would
  /// fail the same way until the connection exists, so the live loop stops and
  /// the deliberate flow's error card takes over.
  Future<void> _onLiveFrame(PrescriptionFrame frame) async {
    if (!mounted ||
        !_liveOn ||
        _liveFrameBusy ||
        _isReading ||
        _showResults) {
      return;
    }
    _liveFrameBusy = true;
    try {
      final lines = await _recognizer.recognizeFrame(frame);
      if (!mounted || !_liveOn || _isReading || _showResults || _sheetOpen) {
        return;
      }
      final suggestions = _matcher.suggest(lines, perLine: 3);
      setState(() {
        _liveTextSeen = lines.isNotEmpty;
        _liveSuggestions = suggestions;
      });

      // The gate only steps while the screen is the route the user is actually
      // on — a Fix dialog or quantity sheet above it means a hand heading for
      // a button, and nothing must commit out from under that. Inside it, a
      // stable read with at least one strong match commits itself into the
      // sheet; no match at all is not a reading, only text.
      final route = ModalRoute.of(context);
      if (route != null && !route.isCurrent) return;
      if (_stepGate(lines, suggestions)) return;
    } on PrescriptionRecognitionException catch (error) {
      if (!mounted) return;
      if (error.isOffline) {
        await _stopLive();
        _reportError(error);
      } else if (error.isUnsupportedPlatform) {
        await _stopLive();
      }
    } finally {
      _liveFrameBusy = false;
    }
  }

  /// One tick of the stability gate. Returns whether it committed.
  ///
  /// The gate asks one question per frame: what would this screen show if the
  /// user had tapped Scan it right now? When that answer stays the same for
  /// [_commitStableFrames] reads in a row — measured by the medicine
  /// identities the strong matches resolve to, because a misread dose line is
  /// exactly the noise a repeat read corrects — the answer is good enough to
  /// present, and the sheet opens with it.
  bool _stepGate(
    List<RecognizedLine> lines,
    List<PrescriptionSuggestion> suggestions,
  ) {
    // Identity above display: the product id when the dataset supplies one,
    // the name otherwise. Sorting makes the set comparable across frames.
    final ids = [
      for (final suggestion in suggestions)
        if (suggestion.confidence >= _commitConfidence)
          (suggestion.medicine.productId ?? suggestion.medicine.name)
              .toLowerCase(),
    ]..sort();

    if (ids.isEmpty) {
      // Text with nothing matched is not a reading yet; holding it would
      // present shelves of near-misses the moment a page prints its header.
      _stableIds = null;
      _stabilityCount = 0;
      return false;
    }

    final unchanged = _stableIds != null && _listsEqual(_stableIds!, ids);
    if (unchanged) {
      _stabilityCount++;
    } else {
      _stableIds = ids;
      _stabilityCount = 1;
    }
    if (_stabilityCount < _commitStableFrames) return false;

    _stabilityCount = 0;
    setState(() {
      _readings = [for (final line in lines) line.text];
      _suggestions = suggestions;
      _sheetOpen = true;
    });
    return true;
  }

  /// Element-by-element equality on a list the gate guarantees is sorted.
  static bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Lowers the commit sheet and hands the screen back to the live feed.
  ///
  /// The gate restarts from cold ([_stepGate] has already zeroed itself), so
  /// the same scene takes the full run of stable frames to commit again — a
  /// pause the closing hand effectively dialed in.
  void _closeSheet() {
    setState(() {
      _sheetOpen = false;
      _readings = const [];
      _suggestions = const [];
    });
  }

  /// Lights or douses the torch from the preview's own toggle.
  Future<void> _setTorch(bool enabled) async {
    try {
      await _camera.setTorch(enabled);
      if (!mounted) return;
      setState(() => _torchOn = enabled);
    } on PrescriptionRecognitionException {
      // The device refused; the toggle stays where it was, which is the one
      // honest state for a torch that does not exist.
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

  Future<void> _readBytes(Uint8List bytes) async {
    setState(() {
      _isReading = true;
      _frozenPhoto = bytes;
      _error = null;
      _errorNeedsConnection = false;
      // A deliberate scan is the user choosing their own reading; any sheet
      // the live frames committed is superseded the moment they touch it.
      _sheetOpen = false;
    });
    // Reading one photo is a single-threaded moment: the live bar would only
    // compete with it, and a gallery read has no capture around which the
    // camera pauses its own stream.
    await _stopLive();

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
  /// The readings stay in state for now — a later successful scan simply
  /// replaces them — and the live scanner wakes back up with the preview,
  /// since a frame the camera is showing again is the next thing to read.
  void _scanAgain() {
    setState(() {
      _showResults = false;
      _frozenPhoto = null;
      _liveTextSeen = false;
      _liveSuggestions = const [];
      _sheetOpen = false;
    });
    unawaited(_startLive());
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
    final cameraColumn = Column(
      children: [
        _Intro(message: widget.introMessage),
        if (canScanOnPlatform) ...[
          _cameraSection(),
          // The deliberate trigger. Rendered even when the camera was refused,
          // where it is disabled: the gate above it explains why.
          _CameraControls(
            cameraReady: _cameraReady == true,
            isReading: _isReading,
            onScan: _scan,
          ),
          if (_showResults)
            _ResultsBelowCamera(
              readings: _readings,
              suggestions: _suggestions,
              onReset: _scanAgain,
              onEdit: _editReading,
              onDetails: _showMedicineDetails,
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

    // The deliberate flow's results own the results area beneath the preview;
    // a self-committed reading rides over the screen as a sheet, so the feed
    // the user was aiming keeps its place above it.
    final body = Stack(
      children: [
        cameraColumn,
        if (_sheetOpen)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _CommitSheet(
              readings: _readings,
              suggestions: _suggestions,
              onEdit: _editReading,
              onAdd: _add,
              onDetails: _showMedicineDetails,
              onClose: _closeSheet,
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

  /// Live preview — or the frame being read, or why neither is showing.
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
      final previewHeight = _showResults ? _collapsedPreviewHeight : fullHeight;
      // An error card and the reclaimed preview room have to land in the same
      // frame: a card sliding in over a preview that is still animating down
      // overflows the short-viewport moment between the two. The collapse into
      // results has no such card beside it, so it alone animates.
      final erroring = _error != null;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: AnimatedContainer(
          // The preview's change from full frame to strip is a spatial fact
          // — the results took its room — so it moves rather than jumps.
          duration: erroring ? Duration.zero : const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          height: previewHeight,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GestureDetector(
              // The collapsed strip is the sleeping camera; waking it is the
              // same gesture every camera app teaches, so the strip answers it.
              key: const Key('previewStrip'),
              behavior: HitTestBehavior.opaque,
              onTap: _showResults ? _scanAgain : null,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _previewContent(preview),
                  if (_frozenPhoto == null && !_showResults) ...[
                    // Framing guide and chrome belong to the live feed only: a
                    // frozen photo is already framed, and a collapsed strip is
                    // too small to spend on anything but waking up.
                    const Positioned.fill(
                      child: IgnorePointer(child: _ScanFrameGuide()),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _PreviewIconButton(
                        key: const Key('torchButton'),
                        icon: _torchOn ? Icons.flash_on : Icons.flash_off,
                        tooltip: _torchOn ? 'Torch is on' : 'Light the preview',
                        onPressed: () => unawaited(_setTorch(!_torchOn)),
                      ),
                    ),
                    if (_liveOn && !_isReading)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: IgnorePointer(
                          ignoring: _liveSuggestions.isEmpty,
                          child: _LiveBar(
                            suggestions: _liveSuggestions,
                            textSeen: _liveTextSeen,
                            liveSupported:
                                _recognizer.supportsFrames &&
                                _camera.supportsLiveFrames &&
                                !_liveUnavailable,
                            onAdd: _add,
                          ),
                        ),
                      ),
                  ],
                  if (_isReading)
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: _ReadingVeil(),
                      ),
                    ),
                ],
              ),
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

  /// What the preview box holds: the live feed, or the frozen photo being
  /// read, or the quiet stand-in when the camera has neither yet.
  Widget _previewContent(Widget? preview) {
    final bytes = _frozenPhoto;
    if (bytes case final photo?) {
      // errorBuilder because the frame is OCR fuel, not a display asset: if a
      // codec refuses it (a truncated read, a gallery type the platform
      // disliked) the flow has already captured what matters — the reading
      // itself — and the preview simply falls back to a still-coloured pane
      // instead of letting a decode failure interrupt anything.
      return Image.memory(
        photo,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) =>
            const ColoredBox(color: Color(0xFF103B21)),
      );
    }
    return preview ?? Center(
      child: Text('No preview', style: Theme.of(context).textTheme.bodySmall),
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

/// The four corner brackets that mark where printed text goes.
///
/// The instruction above the preview says "frame the printed prescription";
/// the brackets are that same instruction as geometry. Eyes find corners
/// faster than words, and a camera with no guide reads as a window rather
/// than an instrument.
class _ScanFrameGuide extends StatelessWidget {
  const _ScanFrameGuide();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(painter: _FrameCornerPainter());
  }
}

class _FrameCornerPainter extends CustomPainter {
  const _FrameCornerPainter();

  /// How far into the preview the brackets sit, and how long each leg runs.
  /// Long enough to be seen at a glance on the collapsed strip, short enough
  /// to stay out of the way of the text being framed.
  static const double _inset = 14;
  static const double _leg = 30;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= _inset * 2 || size.height <= _inset * 2) return;
    final rect = Rect.fromLTWH(
      _inset,
      _inset,
      size.width - _inset * 2,
      size.height - _inset * 2,
    );
    final leg = _leg.clamp(0.0, rect.shortestSide / 2);
    final brush = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    // One path per corner: in from the edge along one leg, out along the other.
    canvas.drawPath(
      Path()
        ..moveTo(rect.left, rect.top + leg)
        ..lineTo(rect.left, rect.top)
        ..lineTo(rect.left + leg, rect.top),
      brush,
    );
    canvas.drawPath(
      Path()
        ..moveTo(rect.right - leg, rect.top)
        ..lineTo(rect.right, rect.top)
        ..lineTo(rect.right, rect.top + leg),
      brush,
    );
    canvas.drawPath(
      Path()
        ..moveTo(rect.right, rect.bottom - leg)
        ..lineTo(rect.right, rect.bottom)
        ..lineTo(rect.right - leg, rect.bottom),
      brush,
    );
    canvas.drawPath(
      Path()
        ..moveTo(rect.left + leg, rect.bottom)
        ..lineTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.bottom - leg),
      brush,
    );
  }

  @override
  bool shouldRepaint(_FrameCornerPainter oldDelegate) => false;
}

/// The round button that floats on the preview's own corner: torch, in the
/// spot where a camera app always puts it.
class _PreviewIconButton extends StatelessWidget {
  const _PreviewIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: ShapeDecoration(
        shape: const CircleBorder(),
        color: Colors.black.withValues(alpha: 0.45),
      ),
      child: IconButton(
        padding: const EdgeInsets.all(8),
        color: Colors.white,
        icon: Icon(icon, size: 22),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}

/// What the screen shows over the feed while a photo is being read: the photo
/// itself lies underneath (the preview already swapped it in), so the veil
/// only needs to say which moment it is and stay out of the way.
class _ReadingVeil extends StatelessWidget {
  const _ReadingVeil();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.25)),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: ShapeDecoration(
            shape: const StadiumBorder(),
            color: Colors.black.withValues(alpha: 0.6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Reading the photo…',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The bar under the frame that makes scanning live: what the frames have
/// matched so far, as chips to tap — the Google-scan move of acting on what
/// you can see — or, while nothing useful has come out of the frames yet, a
/// quiet line about which state it is in.
///
/// Kept to the bottom of the preview rather than floating on the text itself:
/// chips that follow phoneme-sized zones need bounding boxes the lines do not
/// carry, and a set of candidates under the frame answers the same question
/// ("is what I am pointing at on the shelf?") without guessing at geometry.
class _LiveBar extends StatelessWidget {
  const _LiveBar({
    required this.suggestions,
    required this.textSeen,
    required this.liveSupported,
    required this.onAdd,
  });

  final List<PrescriptionSuggestion> suggestions;
  final bool textSeen;
  final bool liveSupported;
  final void Function(MedicineModel medicine) onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Widget content;
    if (suggestions.isNotEmpty) {
      content = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final suggestion in suggestions)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _LiveChip(
                  key: Key('liveChip${suggestion.medicine.name}'),
                  suggestion: suggestion,
                  onAdd: () => onAdd(suggestion.medicine),
                ),
              ),
          ],
        ),
      );
    } else if (textSeen) {
      content = _barLabel(
        theme: theme,
        label: 'Printed text found — no medicine matched yet',
      );
    } else {
      content = _barLabel(theme: theme, label: 'Looking for a medicine name…');
    }

    return Container(
      // Grounded scrim: legibility over any feed — a counter's white paper or
      // a dim shelf — without hiding what it describes.
      padding: const EdgeInsets.fromLTRB(8, 20, 8, 10),
      alignment: Alignment.bottomCenter,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.55),
          ],
        ),
      ),
      child: content,
    );
  }

  Widget _barLabel({
    required ThemeData theme,
    required String label,
  }) => Text(
    label,
    style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
  );
}

/// One live candidate: the name, the price, and a tap that feeds it through
/// the same quantity sheet as every other Add, so nothing about the live chip
/// is a second path into the order.
class _LiveChip extends StatelessWidget {
  const _LiveChip({
    super.key,
    required this.suggestion,
    required this.onAdd,
  });

  final PrescriptionSuggestion suggestion;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final medicine = suggestion.medicine;
    final enabled = !medicine.isOutOfStock;

    return Material(
      color: Colors.black.withValues(alpha: enabled ? 0.65 : 0.35),
      shape: StadiumBorder(
        side: BorderSide(
          color: AppColors.brandGreen.withValues(alpha: 0.55),
          width: 1,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: enabled ? onAdd : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (enabled) ...[
                Icon(
                  Icons.add_circle_outline,
                  size: 16,
                  color: AppColors.brandGreen,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                medicine.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                medicine.formattedPrice,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The deliberate scan trigger, under the preview.
class _CameraControls extends StatelessWidget {
  const _CameraControls({
    required this.cameraReady,
    required this.isReading,
    required this.onScan,
  });

  final bool cameraReady;
  final bool isReading;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final canUseCamera = cameraReady && !isReading;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: OutlinedButton.icon(
        key: const Key('scanButton'),
        onPressed: canUseCamera ? onScan : null,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          backgroundColor: AppColors.brandGreenSurface,
          foregroundColor: AppColors.brandGreen,
          side: const BorderSide(
            color: AppColors.brandGreenSurfaceBorder,
          ),
        ),
        icon: const Icon(Icons.camera_alt),
        label: Text(isReading ? 'Reading…' : 'Scan it'),
      ),
    );
  }
}

/// Why the preview is not showing: the camera was refused, missing, or broke.
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
          hasMatches: suggestions.any((suggestion) => suggestion.lineIndex == i),
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

/// Results shown below the camera widget after a scan, listing the scanned
/// medicines with options to reset, edit, or view details.
class _ResultsBelowCamera extends StatelessWidget {
  const _ResultsBelowCamera({
    required this.readings,
    required this.suggestions,
    required this.onReset,
    required this.onEdit,
    required this.onDetails,
  });

  final List<String> readings;
  final List<PrescriptionSuggestion> suggestions;
  final VoidCallback onReset;
  final void Function(int index) onEdit;
  final void Function(PrescriptionSuggestion suggestion) onDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasReadings = readings.where((r) => r.isNotEmpty).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasReadings > 0)
            Text(
              '$hasReadings medicines found',
              style: theme.textTheme.bodyMedium,
            ),
          const SizedBox(height: 8),
          // Sized to its contents: this block is a non-flex child of the
          // screen's Column, so an Expanded here has no height to divide.
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: readings.length,
              itemBuilder: (context, index) {
                final reading = readings[index];
                final matches = suggestions.where((s) => s.lineIndex == index).toList();
                return ListTile(
                  title: Text(
                    reading.isNotEmpty ? reading : 'Line ${index + 1}',
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: matches.isNotEmpty
                      ? Tooltip(
                          message: 'Add ${matches.first.medicine.name}',
                          child: IconButton(
                            icon: const Icon(Icons.add_circle_outline, size: 18),
                            onPressed: () => onDetails(matches.first),
                          ),
                        )
                      : null,
                );
            },
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onReset,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.brandGreen,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
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
    required this.hasMatches,
    required this.suggestions,
    required this.onEdit,
    required this.onAdd,
    required this.onDetails,
  });

  /// The line this card belongs to, or -1 for the search results.
  final int index;
  final String reading;
  final bool isEmpty;
  final bool hasMatches;
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
        // The audit glance: a green rail says "this line came of the scan"
        // before its contents are read, so a whole prescription can be checked
        // in one sweep the way the shortage reds already carry the trouble.
        border: hasMatches
            ? Border(
                left: BorderSide(
                  color: AppColors.brandGreen,
                  width: 3,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
              )
            : null,
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
                    : 'No medicine in the price list looks like that. '
                          'Try Fix.',
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

/// What a self-committed reading rides in: a sheet from the bottom, over the
/// feed that produced it.
///
/// The cards are the same `_LineResult`s the deliberate results use, wired to
/// the same Add, Fix, and details paths — nothing here is a second path into
/// the order or a second place to correct a misread. The sheet presents the
/// reading as one thing (the header counts it like the deliberate flow does)
/// and pairs it with exactly one way back: Done, which returns the screen to
/// the live feed the reading came from.
class _CommitSheet extends StatelessWidget {
  const _CommitSheet({
    required this.readings,
    required this.suggestions,
    required this.onEdit,
    required this.onAdd,
    required this.onDetails,
    required this.onClose,
  });

  final List<String> readings;
  final List<PrescriptionSuggestion> suggestions;
  final void Function(int index) onEdit;
  final void Function(MedicineModel medicine) onAdd;
  final void Function(PrescriptionSuggestion suggestion) onDetails;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = [
      for (var i = 0; i < readings.length; i++)
        _LineResult(
          index: i,
          reading: readings[i],
          isEmpty: readings[i].isEmpty,
          hasMatches: suggestions.any((suggestion) => suggestion.lineIndex == i),
          suggestions: [
            for (final suggestion in suggestions)
              if (suggestion.lineIndex == i) suggestion,
          ],
          onEdit: () => onEdit(i),
          onAdd: onAdd,
          onDetails: onDetails,
        ),
    ];

    final linesLabel = readings.length == 1 ? '1 line' : '${readings.length} lines';
    final matchesLabel = suggestions.length == 1
        ? '1 match'
        : '${suggestions.length} matches';

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      elevation: 8,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          // Room to read, never enough to take the whole screen: the feed
          // behind the sheet stays part of the story — committed from it.
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The grab handle: the sheet's one decoration that says
              // "drag me away" without any copy being spent on it.
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 8, bottom: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Scan result · $linesLabel · $matchesLabel',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      key: const Key('commitSheetClose'),
                      onPressed: onClose,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.brandGreen,
                      ),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: lines.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => lines[index],
                ),
              ),
            ],
          ),
        ),
      ),
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

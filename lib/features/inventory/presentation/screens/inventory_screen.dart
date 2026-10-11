import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/currency.dart';
import '../../../search/data/models/medicine_model.dart';
import '../../../search/presentation/providers/medicine_provider.dart';
import '../../../dashboard/presentation/widgets/stock_sheet.dart';
/// Reached from the bottom-nav Inventory tab.
///
/// Where the shelf counts are actually taken. The price list knows what
/// everything costs and, for the imported lines, nothing at all about how many
/// are on the shelf -- so this screen opens on mostly-uncounted data and its real
/// job is turning those into numbers. That is why the uncounted filter is the
/// default rather than a nicety: after a stock-take the useful question is what
/// is still unknown, and the answer changes as the work goes on.
///
/// The list is paged rather than infinitely scrolled. A pharmacist counting
/// shelves moves through the catalogue in chunks and needs to know where they
/// left off; a scroll that loses that position every time the tab is reopened
/// would make the screen harder to work with the longer it is used.
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

/// Which lines the list is showing.
///
/// A filter on [StockState] rather than a free-text one, because the three states
/// are exactly the three things worth acting on and they cannot be expressed as
/// a search term.
enum _StockFilter {
  uncounted('Not counted'),
  outOfStock('Out of stock'),
  low('Low'),
  all('All');

  const _StockFilter(this.label);

  final String label;

  /// Whether a line in [state] belongs in this filter.
  bool accepts(StockState state) => switch (this) {
        _StockFilter.uncounted => state == StockState.unknown,
        _StockFilter.outOfStock => state == StockState.outOfStock,
        _StockFilter.low => state == StockState.low,
        _StockFilter.all => true,
      };
}

enum _MenuAction { bulkCount, export }

/// Everything the screen needs from one pass over the catalogue.
class _Summary {
  const _Summary({
    required this.total,
    required this.counted,
    required this.units,
    required this.valueCentavos,
    required this.counts,
    required this.visible,
  });

  final int total;
  final int counted;
  final int units;
  final int valueCentavos;
  final Map<_StockFilter, int> counts;
  final List<MedicineModel> visible;

  double get progress => total == 0 ? 0 : counted / total;
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  _StockFilter _filter = _StockFilter.uncounted;
  bool _scanning = false;
  bool _fromScan = false;

  /// Rows per page. Ten is what fits a phone without the last row sitting
  /// half under the pager, and ten is a round enough number for a count.
  static const int _pageSize = 10;

  /// Which page of the visible list is on screen. One-based for the label.
  ///
  /// Not clamped here -- the number of pages depends on the filter, the query
  /// and the data, all of which can change while this value sits still. The
  /// clamp happens once per build in [_effectivePage], which is the only place
  /// that knows all three.
  int _currentPage = 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Pagination
  // -------------------------------------------------------------------------

  /// The page number actually rendered, which is [_currentPage] pulled back
  /// inside the current range of pages.
  ///
  /// A count typed on another device, or on this one, can drop the visible list
  /// below the page the user was on -- a filter change from All to Uncounted
  /// with a "Not counted" count of two leaves page forty pointing at nothing.
  /// Rather than reset on every mutation, which would also bounce the user off
  /// a valid page, the value is corrected on read.
  int _effectivePage(int pageCount) => _currentPage.clamp(1, pageCount);

  /// Pages the current filter and query produce, always at least one so the
  /// range arithmetic below has something to hold onto even for an empty list.
  static int _pageCountFor(int itemCount) =>
      itemCount == 0 ? 1 : (itemCount + _pageSize - 1) ~/ _pageSize;

  Future<void> _jumpToPage(int pageCount) async {
    final entered = await showDialog<int>(
      context: context,
      builder: (ctx) => _JumpToPageDialog(
        current: _effectivePage(pageCount),
        maxPage: pageCount,
      ),
    );
    if (entered == null || !mounted) return;
    setState(() => _currentPage = entered);
  }

  // -------------------------------------------------------------------------
  // Filtering and totals (one pass)
  // -------------------------------------------------------------------------

  static final RegExp _splitter = RegExp(r'[^a-z0-9]+');

  static Set<String> _tokens(String text) => text
      .toLowerCase()
      .split(_splitter)
      .where((token) => token.length >= 3)
      .toSet();

  /// Typed or scanned text selects a line if the model's own matcher accepts it,
  /// or if every word of the query appears somewhere in the name. The second
  /// rule is what lets "amoxicillin capsule" find "Amoxicillin 500 mg capsule".
  static bool _matchesQuery(MedicineModel medicine, String needle) {
    if (medicine.matches(needle)) return true;
    final words = _tokens(needle);
    if (words.isEmpty) return false;
    final name = medicine.name.toLowerCase();
    return words.every(name.contains);
  }

  /// The lines the current filter and query select, in price-list order, with
  /// the tally and chip counts, computed together.
  _Summary _summarise(List<MedicineModel> all) {
    final needle = _controller.text.trim();
    final counts = {for (final filter in _StockFilter.values) filter: 0};
    final visible = <MedicineModel>[];
    var counted = 0;
    var units = 0;
    var value = 0;

    for (final medicine in all) {
      final state = medicine.stockState;

      for (final filter in _StockFilter.values) {
        if (filter.accepts(state)) counts[filter] = counts[filter]! + 1;
      }

      final stock = medicine.stock;
      if (stock != null) {
        counted++;
        units += stock;
        value += medicine.priceCentavos * stock;
      }

      if (_filter.accepts(state) &&
          (needle.isEmpty || _matchesQuery(medicine, needle))) {
        visible.add(medicine);
      }
    }

    return _Summary(
      total: all.length,
      counted: counted,
      units: units,
      valueCentavos: value,
      counts: counts,
      visible: visible,
    );
  }

  // -------------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------------

  Future<void> _edit(MedicineModel medicine) async {
    await showStockSheet(context, medicine: medicine);
  }

  void _comingSoon(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _clearSearch() {
    setState(() {
      _controller.clear();
      _fromScan = false;
      // A new query means a new result set, and page seven of the old one is
      // not page seven of this one.
      _currentPage = 1;
    });
  }

  void _onFilterSelected(_StockFilter filter) {
    setState(() {
      _filter = filter;
      _currentPage = 1;
    });
  }

  void _onQueryChanged(String _) {
    setState(() {
      _fromScan = false;
      _currentPage = 1;
    });
  }

  /// Photograph a label, read it on the device, and put the product name in the
  /// search field. The filter widens to All so a line that is already counted
  /// still turns up.
  Future<void> _scanName(List<MedicineModel> catalogue) async {
    if (_scanning) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _scanning = true);

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (photo == null) return;

      final result = await recognizer.processImage(
        InputImage.fromFilePath(photo.path),
      );
      final query = _queryFromScan(result, catalogue);
      if (!mounted) return;

      if (query == null) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Could not find a product name. Try again closer.'),
            ),
          );
        return;
      }

      setState(() {
        _controller.text = query;
        _controller.selection = TextSelection.collapsed(offset: query.length);
        _filter = _StockFilter.all;
        _fromScan = true;
        // The scanned query is a fresh filter, so start at the top.
        _currentPage = 1;
      });
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Could not read the label. Try again.')),
        );
    } finally {
      await recognizer.close();
      if (mounted) setState(() => _scanning = false);
    }
  }

  /// Two words are the same word if they are equal, or one is a plural or
  /// truncation of the other ("capsule" / "capsules").
  static bool _sameWord(String a, String b) =>
      a == b ||
      (a.length > 3 && b.length > 3 && (a.startsWith(b) || b.startsWith(a)));

  /// Finds the product the label most likely belongs to and returns a short
  /// query made of that product's own most distinctive words.
  ///
  /// Scoring is by word length, so a drug name outweighs "tablet", and a match
  /// must include at least one long word so a label that only says "tablet"
  /// selects nothing.
  String? _queryFromScan(RecognizedText text, List<MedicineModel> catalogue) {
    final scanned = _tokens(text.text);
    if (scanned.isEmpty) return null;

    List<String>? bestHits;
    var bestScore = 0.0;

    for (final medicine in catalogue) {
      final words = _tokens(medicine.name);
      if (words.isEmpty) continue;

      final hits = words
          .where((word) => scanned.any((seen) => _sameWord(seen, word)))
          .toList();
      if (hits.isEmpty || !hits.any((word) => word.length >= 5)) continue;

      final hitWeight = hits.fold<int>(0, (sum, word) => sum + word.length);
      final totalWeight = words.fold<int>(0, (sum, word) => sum + word.length);
      final score = hitWeight / totalWeight;

      if (score > bestScore) {
        bestScore = score;
        bestHits = hits;
      }
    }

    if (bestHits == null || bestScore < 0.5) return null;
    bestHits.sort((a, b) => b.length.compareTo(a.length));
    return bestHits.take(2).join(' ');
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Watched: a count saved on this screen, or by another device, has to move
    // both the list and the tally.
    final catalogue = context.watch<MedicineProvider>();
    final all = catalogue.all();
    final summary = _summarise(all);
    final needle = _controller.text.trim();

    final pageCount = _pageCountFor(summary.visible.length);
    final page = _effectivePage(pageCount);
    final startIndex = (page - 1) * _pageSize;
    final pageItems = summary.visible
        .skip(startIndex)
        .take(_pageSize)
        .toList(growable: false);
    final firstItem = summary.visible.isEmpty ? 0 : startIndex + 1;
    final lastItem = summary.visible.isEmpty
        ? 0
        : (startIndex + pageItems.length).clamp(0, summary.visible.length);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        centerTitle: true,
        actions: [
          PopupMenuButton<_MenuAction>(
            tooltip: 'More actions',
            onSelected: (action) => switch (action) {
              _MenuAction.bulkCount =>
                _comingSoon('Bulk count entry — coming soon'),
              _MenuAction.export => _comingSoon('Export CSV — coming soon'),
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _MenuAction.bulkCount,
                child: Text('Bulk count entry'),
              ),
              PopupMenuItem(
                value: _MenuAction.export,
                child: Text('Export counted list'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _SearchRow(
            controller: _controller,
            scanning: _scanning,
            onChanged: _onQueryChanged,
            onClear: _clearSearch,
            onScan: () => _scanName(all),
          ),
          if (_fromScan) const _ScanHint(),
          _ProgressCard(summary: summary),
          _FilterBar(
            selected: _filter,
            counts: summary.counts,
            onSelected: _onFilterSelected,
          ),
          Expanded(
            child: switch ((catalogue.error, catalogue.isLoading)) {
              (final String message, _) => _Message(
                  icon: Icons.cloud_off_outlined,
                  title: 'The price list did not load',
                  detail: message,
                  colour: theme.colorScheme.error,
                ),
              (_, true) => const Center(child: CircularProgressIndicator()),
              _ when all.isEmpty => const _Message(
                  icon: Icons.inventory_2_outlined,
                  title: 'No products yet',
                  detail: 'The price list has to be imported before stock can '
                      'be counted.',
                ),
              _ when summary.visible.isEmpty => _Message(
                  icon: Icons.check_circle_outline,
                  title: needle.isEmpty && _filter == _StockFilter.uncounted
                      ? 'Everything is counted'
                      : 'Nothing here',
                  detail: needle.isEmpty
                      ? (_filter == _StockFilter.uncounted
                          ? 'Every product has a stock count.'
                          : 'No product is in this state.')
                      : 'No match for "$needle" in this state.',
                ),
              _ => ListView.separated(
                  // Keyed on the page so the list scroll position resets when
                  // the page changes. Without this, a page of similar-length
                  // rows keeps the previous page's offset and lands the user
                  // halfway down a list they have not seen yet.
                  key: ValueKey('inventory-page-$page'),
                  itemCount: pageItems.length,
                  separatorBuilder: (context, index) => const Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                  itemBuilder: (context, index) {
                    final medicine = pageItems[index];
                    return _StockRow(
                      medicine: medicine,
                      onTap: () => _edit(medicine),
                    );
                  },
                ),
            },
          ),
          // The pager is drawn only when there is more than one page. An
          // empty list, an error, or a page worth of results all render the
          // body alone -- a pager reading "Page 1 of 1" is chrome with nothing
          // to say.
          if (pageCount > 1 &&
              catalogue.error == null &&
              !catalogue.isLoading &&
              summary.visible.isNotEmpty)
            _Pager(
              page: page,
              pageCount: pageCount,
              firstItem: firstItem,
              lastItem: lastItem,
              totalItems: summary.visible.length,
              onPrevious: page > 1
                  ? () => setState(() => _currentPage = page - 1)
                  : null,
              onNext: page < pageCount
                  ? () => setState(() => _currentPage = page + 1)
                  : null,
              onTapPage: () => _jumpToPage(pageCount),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pagination widgets
// ---------------------------------------------------------------------------

/// Prev / label / Next, pinned under the list.
///
/// The label is tappable so a user who knows they want page thirty does not
/// have to tap Next twenty-nine times. The row itself is compact on purpose:
/// a paginator that takes a whole bar of a phone screen is a paginator that
/// gets in the way of the work.
class _Pager extends StatelessWidget {
  const _Pager({
    required this.page,
    required this.pageCount,
    required this.firstItem,
    required this.lastItem,
    required this.totalItems,
    required this.onPrevious,
    required this.onNext,
    required this.onTapPage,
  });

  final int page;
  final int pageCount;
  final int firstItem;
  final int lastItem;
  final int totalItems;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onTapPage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Material(
      // Raised so the boundary between the list and the pager is a surface
      // change rather than a hairline that the eye has to find.
      elevation: 4,
      color: theme.colorScheme.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Previous page',
                icon: const Icon(Icons.chevron_left),
                onPressed: onPrevious,
              ),
              Expanded(
                child: InkWell(
                  onTap: onTapPage,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Page $page of $pageCount',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '$firstItem–$lastItem of $totalItems',
                          textAlign: TextAlign.center,
                          style: muted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Next page',
                icon: const Icon(Icons.chevron_right),
                onPressed: onNext,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ask for a page number directly.
///
/// Its own widget rather than a method with a TextEditingController built in
/// the caller, so the controller has an owner that disposes it and the field
/// survives the dialog being rebuilt by the keyboard appearing.
class _JumpToPageDialog extends StatefulWidget {
  const _JumpToPageDialog({
    required this.current,
    required this.maxPage,
  });

  final int current;
  final int maxPage;

  @override
  State<_JumpToPageDialog> createState() => _JumpToPageDialogState();
}

class _JumpToPageDialogState extends State<_JumpToPageDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.current.toString(),
  );
  String? _error;

  @override
  void initState() {
    super.initState();
    // Select the existing number so typing replaces it rather than appending
    // to a value the user did not choose.
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final n = int.tryParse(_controller.text.trim());
    if (n == null || n < 1 || n > widget.maxPage) {
      setState(() => _error = 'Enter a number from 1 to ${widget.maxPage}.');
      return;
    }
    Navigator.of(context).pop(n);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Go to page'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.go,
        decoration: InputDecoration(
          labelText: 'Page number',
          helperText: '1 to ${widget.maxPage}',
          errorText: _error,
        ),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Go'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Search and scan
// ---------------------------------------------------------------------------

class _SearchRow extends StatelessWidget {
  const _SearchRow({
    required this.controller,
    required this.scanning,
    required this.onChanged,
    required this.onClear,
    required this.onScan,
  });

  final TextEditingController controller;
  final bool scanning;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              autocorrect: false,
              decoration: InputDecoration(
                hintText: 'Find a product',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Clear',
                        onPressed: onClear,
                      ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: 'Scan product name',
            onPressed: scanning ? null : onScan,
            icon: scanning
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.photo_camera_outlined),
          ),
        ],
      ),
    );
  }
}

class _ScanHint extends StatelessWidget {
  const _ScanHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          Icon(
            Icons.photo_camera_outlined,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Read from the label. Check it matches.',
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

// ---------------------------------------------------------------------------
// Progress
// ---------------------------------------------------------------------------

/// "142 of 490 counted", with the value of what is there.
///
/// The value is of the counted lines only. Putting a peso total next to an
/// uncounted list would read as a stock valuation, and stock value is
/// something this app doesn't know -- it has counts and unit prices, not costs,
/// and those are different numbers. The label says "at retail price" for that
/// reason.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.summary});

  final _Summary summary;

  static String _group(int number) => number.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (_) => ',',
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final percent = (summary.progress * 100).round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      '${summary.counted} of ${summary.total} counted',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  Text('$percent%', style: muted),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: summary.progress,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              if (summary.counted > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '${_group(summary.units)} units · '
                  '${formatCentavos(summary.valueCentavos)} at retail price',
                  style: muted,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filters
// ---------------------------------------------------------------------------

/// The stock-state chips. Single choice, so [ChoiceChip] rather than
/// [FilterChip].
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selected,
    required this.counts,
    required this.onSelected,
  });

  final _StockFilter selected;
  final Map<_StockFilter, int> counts;
  final ValueChanged<_StockFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          for (final filter in _StockFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                showCheckmark: false,
                selected: filter == selected,
                onSelected: (_) => onSelected(filter),
                avatar: switch (filter) {
                  _StockFilter.outOfStock => _Dot(
                      _StockColors.status(context, StockState.outOfStock),
                    ),
                  _StockFilter.low => _Dot(
                      _StockColors.status(context, StockState.low),
                    ),
                  _ => null,
                },
                label: Text('${filter.label} ${counts[filter] ?? 0}'),
              ),
            ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.colour);

  final Color colour;

  @override
  Widget build(BuildContext context) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
      );
}

// ---------------------------------------------------------------------------
// Rows
// ---------------------------------------------------------------------------

/// Colours for each stock state. Out of stock uses the theme's error colours;
/// low uses amber so the two read differently.
abstract final class _StockColors {
  /// Text and dot colour for a state.
  static Color status(BuildContext context, StockState state) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return switch (state) {
      StockState.outOfStock => scheme.error,
      StockState.low =>
        dark ? const Color(0xFFFFD98A) : const Color(0xFF8A5A00),
      StockState.unknown => scheme.outline,
      StockState.available => scheme.onSurfaceVariant,
    };
  }

  /// Pill background and foreground for a counted state.
  static (Color background, Color foreground) pill(
    BuildContext context,
    StockState state,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return switch (state) {
      StockState.outOfStock => (
          scheme.errorContainer,
          scheme.onErrorContainer,
        ),
      StockState.low => dark
          ? (const Color(0xFF4A3600), const Color(0xFFFFD98A))
          : (const Color(0xFFFFE8B8), const Color(0xFF6B4A00)),
      _ => (scheme.surfaceContainerHighest, scheme.onSurface),
    };
  }
}

class _StockRow extends StatelessWidget {
  const _StockRow({required this.medicine, required this.onTap});

  final MedicineModel medicine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, state) = medicine.stockLine;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: medicine.formattedPrice,
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const TextSpan(text: ' · '),
                        TextSpan(
                          text: label,
                          style: TextStyle(
                            color: _StockColors.status(context, state),
                          ),
                        ),
                      ],
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: state == StockState.unknown
                  ? IconButton.filledTonal(
                      tooltip: 'Count stock',
                      icon: const Icon(Icons.add),
                      onPressed: onTap,
                    )
                  : _StockPill(state: state, quantity: medicine.stock),
            ),
          ],
        ),
      ),
    );
  }
}

/// The counted quantity, tinted by state.
class _StockPill extends StatelessWidget {
  const _StockPill({required this.state, required this.quantity});

  final StockState state;
  final int? quantity;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = _StockColors.pill(context, state);

    return Container(
      constraints: const BoxConstraints(minWidth: 48),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '${quantity ?? 0}',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty and error bodies
// ---------------------------------------------------------------------------

/// The empty and error bodies, so a screen with nothing to list says which of
/// the several reasons it is.
class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.detail,
    this.colour,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Color? colour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: colour ?? theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

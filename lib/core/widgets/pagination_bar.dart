import 'package:flutter/material.dart';

/// Prev / label / Next, pinned under a list.
///
/// Shared rather than private to any one screen because Inventory and Order
/// History both page the same way and neither should drift from the other in
/// how a page change looks or reads. The label is tappable so a user who knows
/// they want page thirty does not have to tap Next twenty-nine times.
class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
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

/// Asks for a page number directly.
///
/// Its own widget rather than a method with a [TextEditingController] built in
/// the caller, so the controller has an owner that disposes it and the field
/// survives the dialog being rebuilt by the keyboard appearing.
class JumpToPageDialog extends StatefulWidget {
  const JumpToPageDialog({
    super.key,
    required this.current,
    required this.maxPage,
  });

  final int current;
  final int maxPage;

  @override
  State<JumpToPageDialog> createState() => _JumpToPageDialogState();
}

class _JumpToPageDialogState extends State<JumpToPageDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.current.toString(),
  );
  String? _error;

  @override
  void initState() {
    super.initState();
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
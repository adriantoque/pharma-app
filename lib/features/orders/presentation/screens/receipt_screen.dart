import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/snackbar_helper.dart';
import '../../data/repositories/receipt_repository.dart';
import '../../data/models/receipt_model.dart';
import '../../presentation/providers/receipt_provider.dart';
import '../widgets/receipt_preview.dart';

/// The receipt page: a preview of the receipt followed by save / share /
/// open actions.
///
/// Pushed from the Order History screen (or from anywhere with an
/// [OrderHistory]) so the cashier can show the customer the receipt on screen,
/// save it as a PDF, and share it by message or email.
///
/// The provider is scoped to this screen: generating a receipt is a
/// one-off action tied to a single order, not long-lived app state.
class ReceiptScreen extends StatelessWidget {
  const ReceiptScreen({super.key, required this.receipt});

  /// The receipt to render and save.
  final ReceiptModel receipt;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ReceiptProvider>(
      create: (_) => ReceiptProvider(
        repository: context.read<ReceiptRepository>(),
      ),
      child: _ReceiptScreenBody(receipt: receipt),
    );
  }
}

class _ReceiptScreenBody extends StatelessWidget {
  const _ReceiptScreenBody({required this.receipt});

  final ReceiptModel receipt;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReceiptProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt'),
        centerTitle: true,
        actions: [
          if (provider.hasSavedFile)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, size: 20),
              tooltip: 'Open saved PDF',
              onPressed: provider.isGenerating ? null : provider.open,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: ReceiptPreview(receipt: receipt),
            ),
          ),
          _ActionBar(
            provider: provider,
            receipt: receipt,
          ),
        ],
      ),
    );
  }
}

/// The save / share / open bar at the bottom of the receipt screen.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.provider,
    required this.receipt,
  });

  final ReceiptProvider provider;
  final ReceiptModel receipt;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (provider.isGenerating)
              const LinearProgressIndicator(),
            if (provider.error != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 18,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        provider.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                // Save as PDF — always available.
                Expanded(
                  child: FilledButton.icon(
                    onPressed: provider.isGenerating ? null : () => _save(context),
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: provider.hasSavedFile
                        ? const Text('Save Again')
                        : const Text('Save as PDF'),
                  ),
                ),
                const SizedBox(width: 12),
                // Share — only after saving.
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        provider.isGenerating || !provider.hasSavedFile
                            ? null
                            : () => _share(context),
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Open — only after saving.
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                    provider.isGenerating || !provider.hasSavedFile
                        ? null
                        : () => _open(context),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('Open PDF'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    final ok = await context.read<ReceiptProvider>().generateAndSave(receipt);
    if (!ok && context.mounted) {
      SnackbarHelper.showError(
        context,
        context.read<ReceiptProvider>().error ?? 'Could not save the receipt.',
      );
    }
  }

  Future<void> _share(BuildContext context) async {
    final ok = await context.read<ReceiptProvider>().share();
    if (!ok && context.mounted) {
      SnackbarHelper.showError(
        context,
        'Nothing to share. Save the receipt first.',
      );
    }
  }

  Future<void> _open(BuildContext context) async {
    final ok = await context.read<ReceiptProvider>().open();
    if (!ok && context.mounted) {
      SnackbarHelper.showError(
        context,
        context.read<ReceiptProvider>().error ?? 'Could not open the receipt.',
      );
    }
  }
}

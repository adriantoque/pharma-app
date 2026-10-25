import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/age_guidance.dart';
import '../../data/models/medicine_model.dart';

/// The counter's one card: a search row, a cart line and a suggestion.
///
/// One product on the shelf, drawn as a card.
///
/// The PharmaStaff POS shape: a row of tags saying who it is for and whether it
/// needs a prescription, the name, the generic underneath it, the dose, what is
/// left on the shelf, and the price with the control that puts it in the order.
///
/// Shared by the sale shelf and the symptom finder, so a product looks the same
/// wherever the counter meets it.
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.medicine,
    required this.quantity,
    required this.onRemove,
    this.onTap,
    this.guidance,
  });

  final MedicineModel medicine;

  /// How many units of this product are already in the order.
  final int quantity;

  /// Called when the counter taps the card to choose an amount.
  ///
  /// The whole card is the control: there is no separate add button, because
  /// the amount is set in a panel rather than guessed from a single tap.
  final VoidCallback? onTap;

  /// Called when the counter takes the product back out.
  final VoidCallback onRemove;

  /// How to use it, and what to watch for.
  ///
  /// The pharmacist's own words, shown on the card when they are recorded. Null
  /// for a product the guide has nothing to say about.
  final ProductGuidance? guidance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (stockLabel, stockState) = medicine.stockLine;
    final generic = medicine.genericKey;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // An out-of-stock line is not tappable, the same way it cannot be sold.
        onTap: medicine.isOutOfStock ? null : onTap,
        child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_badges().isNotEmpty) ...[
              Row(
                // The sample pins the prescription tag to the far edge, so the
                // eye finds the one red thing on the card without scanning
                // between the badges.
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _badges(),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              medicine.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (generic != null && generic.trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                generic,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (medicine.usageIndication case final indication?
                when indication.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      indication,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (medicine.dosageInfo case final dosage?) ...[
              const SizedBox(height: 6),
              Text('Dosage: $dosage', style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 6),
            Text(
              stockLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: switch (stockState) {
                  StockState.outOfStock || StockState.low =>
                    theme.colorScheme.error,
                  StockState.unknown => theme.colorScheme.outline,
                  StockState.available => theme.colorScheme.onSurfaceVariant,
                },
              ),
            ),
            if (guidance case final guidance?) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.medication_outlined,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'How to use: ${guidance.howToUse}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF0C27B)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 15,
                      color: Color(0xFF9A5B00),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'Warning: ${guidance.cautions}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF7A4A00),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  medicine.formattedPrice,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandGreen,
                  ),
                ),
                const SizedBox(width: 8),
                // The control takes what is left rather than its natural
                // width: a long hint beside a long price must not overflow a
                // counter's 360dp screen.
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _QuantityControl(
                      medicine: medicine,
                      quantity: quantity,
                      onRemove: onRemove,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }

  /// The small tags above the name: who the line is for, and whether it needs
  /// a prescription.
  ///
  /// Empty for most lines, because most of the price list records neither.
  /// A line with no tags shows no row at all rather than an empty one.
  List<Widget> _badges() {
    final badges = <Widget>[];
    final ageGuidance = medicine.ageGuidance;

    if (ageGuidance != null) {
      // With per-age ratings, "adult" is the norm for most of the shelf and a
      // badge on three quarters of the cards would be noise. The two things
      // worth calling out are a pediatric-only line and a line children may
      // take only with advice.
      if (medicine.ageGroup == AgeGroup.child) {
        badges.add(
          const _Badge(
            icon: Icons.child_care,
            label: 'PEDIATRIC / CHILD',
            background: Color(0xFFFEF3C7),
            foreground: Color(0xFFB45309),
          ),
        );
      } else if (ageGuidance.kids == AgeSuitability.caution) {
        badges.add(
          const _Badge(
            icon: Icons.child_care,
            label: 'KIDS: ASK FIRST',
            background: Color(0xFFFEF3C7),
            foreground: Color(0xFFB45309),
          ),
        );
      }
    } else {
      switch (medicine.ageGroup) {
        case AgeGroup.child:
          badges.add(
            const _Badge(
              icon: Icons.child_care,
              label: 'PEDIATRIC / CHILD',
              background: Color(0xFFFEF3C7),
              foreground: Color(0xFFB45309),
            ),
          );
        case AgeGroup.adult:
          badges.add(
            const _Badge(
              icon: Icons.person_outline,
              label: 'ADULT FORMULA',
              background: AppColors.brandGreenSurface,
              foreground: AppColors.brandGreen,
            ),
          );
        case AgeGroup.both:
          break;
      }
    }

    if (medicine.requiresRx) {
      badges.add(
        const _Badge(
          icon: Icons.medical_information_outlined,
          label: 'Rx Required',
          background: Color(0xFFFDECEC),
          foreground: Color(0xFFB3261E),
        ),
      );
    }

    return badges;
  }
}

/// How to use a medicine, and what to watch for.
///
/// The pharmacist's own words. Passed in by the caller so the card does not
/// have to know where the text comes from.
@immutable
class ProductGuidance {
  const ProductGuidance({required this.howToUse, required this.cautions});

  /// Plain-language directions: how it is taken, and anything that changes how
  /// it works.
  final String howToUse;

  /// Warnings and red flags: who should not take it, and when to stop and ask
  /// the pharmacist.
  final String cautions;
}

/// A small tag: an icon and a word, on a tinted pill.
class _Badge extends StatelessWidget {
  const _Badge({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

/// The trailing control on a card: the tap hint, or the remove control once
/// the product is in the order.
///
/// There is deliberately no add button. The card itself opens the amount
/// panel, and this hint is what tells the counter so.
class _QuantityControl extends StatelessWidget {
  const _QuantityControl({
    required this.medicine,
    required this.quantity,
    required this.onRemove,
  });

  final MedicineModel medicine;
  final int quantity;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (quantity == 0) {
      // Nothing to say about a line that cannot be sold; its stock line and
      // muted card already carry that.
      if (medicine.isOutOfStock) return const SizedBox.shrink();

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.touch_app_outlined,
            size: 16,
            color: AppColors.brandGreen,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              'Tap To Add',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.brandGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }

    return Tooltip(
      message: 'Remove $quantity × ${medicine.name}',
      child: OutlinedButton(
        onPressed: onRemove,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.brandGreenSurface,
          foregroundColor: AppColors.brandGreen,
          side: const BorderSide(color: AppColors.brandGreenSurfaceBorder),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(0, 36),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.remove, size: 18),
            const SizedBox(width: 4),
            Text('×$quantity'),
          ],
        ),
      ),
    );
  }
}

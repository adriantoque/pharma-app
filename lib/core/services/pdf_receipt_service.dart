import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../features/orders/data/models/receipt_model.dart';

/// Builds a PDF receipt document from a [ReceiptModel].
///
/// The only file in the app that imports `package:pdf`. Everything else works
/// against the plain [ReceiptModel] and a [pw.Document] it hands back, so the
/// rendering logic can be tested without a widget tree or a printer.
///
/// Layout is a thermal-receipt strip: 80 mm wide, vertically flowing. Fonts
/// use the package's built-in Helvetica family so the PDF is self-contained
/// and prints identically on any device.
class PdfReceiptService {
  PdfReceiptService._();

  /// Shared instance. The service is stateless, so one instance serves the
  /// whole app.
  static final PdfReceiptService instance = PdfReceiptService._();

  /// The receipt's fixed width — 80 mm, the width of a standard thermal
  /// receipt roll. Height grows with the item list.
  static const double receiptWidthMm = 80;

  /// Brand teal, matching `AppColors.primary` in the Flutter theme.
  static const PdfColor brandTeal = PdfColor.fromInt(0xFF059669);

  /// Builds a [pw.Document] from [receipt]. The caller is responsible for
  /// saving, sharing, or printing the returned document.
  Future<pw.Document> build(ReceiptModel receipt) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          receiptWidthMm * PdfPageFormat.mm,
          240 * PdfPageFormat.mm,
        ),
        margin: const pw.EdgeInsets.all(8),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── Header: pharmacy branding ──────────────────────────────
            _header(receipt),
            pw.SizedBox(height: 6),
            _dashedDivider(),
            pw.SizedBox(height: 6),

            // ── Meta block ─────────────────────────────────────────────
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _metaCell('Receipt #', receipt.receiptId),
                _metaCell('Date', receipt.formattedDateTime),
              ],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _metaCell('Cashier', receipt.cashierName),
                _metaCell('Payment', receipt.paymentMethod),
              ],
            ),
            if (receipt.storeAddress.isNotEmpty)
              pw.Text(receipt.storeAddress,
                  style: _smallStyle(color: PdfColor.fromInt(0xFF374151))),
            if (receipt.storePhone.isNotEmpty)
              pw.Text(receipt.storePhone,
                  style: _smallStyle(color: PdfColor.fromInt(0xFF374151))),
            pw.SizedBox(height: 6),
            _dashedDivider(),
            pw.SizedBox(height: 8),

            // ── Itemized table header ──────────────────────────────────
            pw.Row(
              children: [
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    'Item',
                    style: _headerStyle(),
                  ),
                ),
                pw.SizedBox(
                  width: 30,
                  child: pw.Text(
                    'Qty',
                    textAlign: pw.TextAlign.center,
                    style: _headerStyle(),
                  ),
                ),
                pw.SizedBox(
                  width: 40,
                  child: pw.Text(
                    'Price',
                    textAlign: pw.TextAlign.right,
                    style: _headerStyle(),
                  ),
                ),
                pw.SizedBox(
                  width: 40,
                  child: pw.Text(
                    'Total',
                    textAlign: pw.TextAlign.right,
                    style: _headerStyle(),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            _dashedDivider(),
            pw.SizedBox(height: 4),

            // ── Item rows ──────────────────────────────────────────────
            for (final item in receipt.items)
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      item.name,
                      style: _bodyStyle(),
                    ),
                  ),
                  pw.SizedBox(
                    width: 30,
                    child: pw.Text(
                      '${item.quantity}',
                      textAlign: pw.TextAlign.center,
                      style: _bodyStyle(),
                    ),
                  ),
                  pw.SizedBox(
                    width: 40,
                    child: pw.Text(
                      item.formattedQuantity.split(' × ').first,
                      textAlign: pw.TextAlign.right,
                      style: _bodyStyle(),
                    ),
                  ),
                  pw.SizedBox(
                    width: 40,
                    child: pw.Text(
                      item.formattedTotal,
                      textAlign: pw.TextAlign.right,
                      style: _bodyStyle(),
                    ),
                  ),
                ],
              ),
            pw.SizedBox(height: 6),
            _dashedDivider(),
            pw.SizedBox(height: 6),

            // ── Totals ─────────────────────────────────────────────────
            _totalRow('Subtotal', receipt.subtotalCentavos),
            if (receipt.discountCentavos > 0)
              _totalRow('Discount', -receipt.discountCentavos),
            if (receipt.taxCentavos > 0)
              _totalRow('Tax (VAT)', receipt.taxCentavos),
            _totalRow('TOTAL', receipt.totalCentavos, bold: true, large: true),
            pw.SizedBox(height: 8),

            // ── Cash breakdown (when applicable) ───────────────────────
            if (receipt.cashTenderedCentavos != null &&
                receipt.changeCentavos != null) ...[
              _totalRow('Cash tendered', receipt.cashTenderedCentavos!),
              _totalRow('Change', receipt.changeCentavos!),
              pw.SizedBox(height: 8),
              _dashedDivider(),
              pw.SizedBox(height: 6),
            ],

            // ── Footer ─────────────────────────────────────────────────
            pw.Text(
              'Thank you for your patronage!',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                font: pw.Font.helveticaOblique(),
                fontSize: 9,
                color: PdfColor.fromInt(0xFF374151),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Computer-generated receipt.',
              textAlign: pw.TextAlign.center,
              style: _tinyStyle(),
            ),
          ],
        ),
      ),
    );

    return doc;
  }

  // ── Internal helpers ─────────────────────────────────────────────────

  pw.Widget _header(ReceiptModel receipt) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          receipt.storeName.isNotEmpty ? receipt.storeName : 'PharmaGuide Pharmacy',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            font: pw.Font.helveticaBold(),
            fontSize: 14,
            color: brandTeal,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'OFFICIAL RECEIPT',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            font: pw.Font.helveticaBold(),
            fontSize: 9,
            letterSpacing: 1.2,
            color: PdfColor.fromInt(0xFF000000),
          ),
        ),
      ],
    );
  }

  pw.Widget _metaCell(String label, String value) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            label,
            style: _tinyStyle(),
          ),
          pw.Text(
            value,
            style: _bodyStyle(),
          ),
        ],
      ),
    );
  }

  pw.Widget _dashedDivider() {
    return pw.Container(
      height: 1,
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(
            color: PdfColor.fromInt(0xFF9CA3AF),
            width: 0.5,
            style: pw.BorderStyle.dashed,
          ),
        ),
      ),
    );
  }

  pw.Widget _totalRow(String label, int centavos,
      {bool bold = false, bool large = false}) {
    final formatted =
        '₱${(centavos ~/ 100).abs()}.${(centavos.abs() % 100).toString().padLeft(2, '0')}';
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: _bodyStyle(
            bold: bold,
            fontSize: large ? 12 : null,
          ),
        ),
        pw.Text(
          formatted,
          textAlign: pw.TextAlign.right,
          style: _bodyStyle(
            bold: true,
            fontSize: large ? 13 : null,
          ),
        ),
      ],
    );
  }

  pw.TextStyle _bodyStyle({bool bold = false, double? fontSize}) {
    return pw.TextStyle(
      font: bold ? pw.Font.helveticaBold() : pw.Font.helvetica(),
      fontSize: fontSize ?? 9,
      color: PdfColor.fromInt(0xFF000000),
    );
  }

  pw.TextStyle _headerStyle() {
    return pw.TextStyle(
      font: pw.Font.helveticaBold(),
      fontSize: 8,
      color: PdfColor.fromInt(0xFF000000),
    );
  }

  pw.TextStyle _smallStyle({required PdfColor color}) {
    return pw.TextStyle(
      font: pw.Font.helvetica(),
      fontSize: 7.5,
      color: color,
    );
  }

  pw.TextStyle _tinyStyle() {
    return pw.TextStyle(
      font: pw.Font.helvetica(),
      fontSize: 7,
      color: PdfColor.fromInt(0xFF4B5563),
    );
  }
}

/// Re-exports `Uint8List` so callers can work with PDF bytes without importing
/// `dart:typed_data` themselves.
typedef PdfBytes = Uint8List;

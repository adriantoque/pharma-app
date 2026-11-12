import 'package:flutter/material.dart';

import '../../../search/data/models/age_guidance.dart';
import '../../../search/data/models/medicine_model.dart';

/// Modal form for adding a new medicine to the price list.
///
/// Captures every field supported by [MedicineModel] so a manually added line
/// is on par with an imported one.
class AddMedicineDialog extends StatefulWidget {
  const AddMedicineDialog({super.key});

  @override
  State<AddMedicineDialog> createState() => _AddMedicineDialogState();
}

class _AddMedicineDialogState extends State<AddMedicineDialog> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _productIdController = TextEditingController();
  final _packageTypeController = TextEditingController();
  final _categoryController = TextEditingController();
  final _genericKeyController = TextEditingController();
  final _usageController = TextEditingController();
  final _dosageController = TextEditingController();
  final _cautionsController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _aliasesController = TextEditingController();

  AgeGroup _ageGroup = AgeGroup.both;
  bool _requiresRx = false;
  DateTime? _expiryDate;

  @override
  void dispose() {
    _nameController.dispose();
    _productIdController.dispose();
    _packageTypeController.dispose();
    _categoryController.dispose();
    _genericKeyController.dispose();
    _usageController.dispose();
    _dosageController.dispose();
    _cautionsController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _aliasesController.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final priceText = _priceController.text.trim();
    final price = double.tryParse(priceText);
    if (price == null) return;
    final priceCentavos = (price * 100).round();

    final stockText = _stockController.text.trim();
    final stock = stockText.isEmpty ? null : int.tryParse(stockText);

    final aliases = _aliasesController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final medicine = MedicineModel(
      name: _nameController.text.trim(),
      productId: _productIdController.text.trim().isEmpty
          ? null
          : _productIdController.text.trim(),
      packageType: _packageTypeController.text.trim().isEmpty
          ? null
          : _packageTypeController.text.trim(),
      usageIndication: _usageController.text.trim().isEmpty
          ? null
          : _usageController.text.trim(),
      priceCentavos: priceCentavos,
      stock: stock,
      aliases: aliases,
      genericKey: _genericKeyController.text.trim().isEmpty
          ? null
          : _genericKeyController.text.trim(),
      expiryDate: _expiryDate,
      requiresRx: _requiresRx,
      dosageInfo: _dosageController.text.trim().isEmpty
          ? null
          : _dosageController.text.trim(),
      category: _categoryController.text.trim().isEmpty
          ? null
          : _categoryController.text.trim(),
      cautions: _cautionsController.text.trim().isEmpty
          ? null
          : _cautionsController.text.trim(),
      ageGroup: _ageGroup,
    );

    Navigator.of(context).pop(medicine);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Medicine'),
      scrollable: true,
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Basic Product Info',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Product Name *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _productIdController,
                decoration: const InputDecoration(labelText: 'Product ID'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _packageTypeController,
                decoration: const InputDecoration(labelText: 'Package Type'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _genericKeyController,
                decoration: const InputDecoration(labelText: 'Generic Name'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _aliasesController,
                decoration: const InputDecoration(
                    labelText: 'Aliases (comma separated)'),
              ),
              const SizedBox(height: 16),
              Text('Stock & Pricing',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              TextFormField(
                controller: _priceController,
                decoration:
                    const InputDecoration(labelText: 'Unit Price (pesos) *'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  final p = double.tryParse(v.trim());
                  if (p == null) return 'Enter a number';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _stockController,
                decoration:
                    const InputDecoration(labelText: 'Stock Quantity'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  if (int.tryParse(v.trim()) == null) return 'Enter a number';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _expiryDate == null
                          ? 'No expiry date'
                          : 'Expiry: ${_expiryDate!.year}-${_expiryDate!.month.toString().padLeft(2, '0')}-${_expiryDate!.day.toString().padLeft(2, '0')}',
                    ),
                  ),
                  TextButton(
                    onPressed: _pickExpiry,
                    child: const Text('Pick Expiry'),
                  ),
                  if (_expiryDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _expiryDate = null),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Medical Purpose & Eligibility',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              TextFormField(
                controller: _usageController,
                decoration:
                    const InputDecoration(labelText: 'Purpose / Indications'),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _dosageController,
                decoration: const InputDecoration(labelText: 'Dosage / Strength'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _cautionsController,
                decoration: const InputDecoration(labelText: 'Cautions'),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<AgeGroup>(
                initialValue: _ageGroup,
                decoration: const InputDecoration(labelText: 'Patient Group'),
                items: AgeGroup.values
                    .map((g) => DropdownMenuItem(
                          value: g,
                          child: Text(g.name),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _ageGroup = v);
                },
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _requiresRx,
                onChanged: (v) => setState(() => _requiresRx = v ?? false),
                title: const Text('Requires Prescription (Rx)'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Add Medicine'),
        ),
      ],
    );
  }
}
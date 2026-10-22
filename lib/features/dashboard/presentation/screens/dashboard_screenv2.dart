import 'package:flutter/material.dart';

void main() {
  runApp(const PharmacyPosApp());
}

class PharmacyPosApp extends StatelessWidget {
  const PharmacyPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PharmaStaff POS',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0284C7), // Medical Teal/Blue
          primary: const Color(0xFF0284C7),
          secondary: const Color(0xFF0D9488),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
      ),
      home: const MainStaffScreen(),
    );
  }
}

// -----------------------------------------------------------------------------
// MODELS
// -----------------------------------------------------------------------------
enum AgeGroup { child, adult, both }

class Product {
  final String id;
  final String name;
  final String genericName;
  final double price;
  final String category;
  final AgeGroup ageGroup;
  final int stock;
  final bool requiresRx;
  final String dosageInfo;
  final List<String> targetSymptoms;
  final List<String> warnings;

  Product({
    required this.id,
    required this.name,
    required this.genericName,
    required this.price,
    required this.category,
    required this.ageGroup,
    required this.stock,
    required this.requiresRx,
    required this.dosageInfo,
    required this.targetSymptoms,
    required this.warnings,
  });
}

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  double get total => product.price * quantity;
}

// -----------------------------------------------------------------------------
// MOCK DATA
// -----------------------------------------------------------------------------
final List<Product> mockProducts = [
  Product(
    id: 'MED-1001',
    name: 'Children\'s Paracetamol Syrup',
    genericName: 'Paracetamol 120mg/5ml',
    price: 6.50,
    category: 'Pain & Fever',
    ageGroup: AgeGroup.child,
    stock: 45,
    requiresRx: false,
    dosageInfo: '5ml - 10ml depending on weight, max 4 times/day.',
    targetSymptoms: ['Fever', 'Pain', 'Teething', 'Headache'],
    warnings: ['Do not exceed recommended dose'],
  ),
  Product(
    id: 'MED-1002',
    name: 'Adult Paracetamol Extra',
    genericName: 'Paracetamol 500mg + Caffeine',
    price: 8.00,
    category: 'Pain & Fever',
    ageGroup: AgeGroup.adult,
    stock: 120,
    requiresRx: false,
    dosageInfo: '1-2 tablets every 4-6 hours.',
    targetSymptoms: ['Fever', 'Headache', 'Body Pain', 'Toothache'],
    warnings: ['Avoid extra caffeine intake'],
  ),
  Product(
    id: 'MED-1003',
    name: 'Pediatric Cough Elixir',
    genericName: 'Guaifenesin Pediatric 50mg/5ml',
    price: 9.25,
    category: 'Cold & Cough',
    ageGroup: AgeGroup.child,
    stock: 18,
    requiresRx: false,
    dosageInfo: '2.5ml every 4 hours for ages 2-6.',
    targetSymptoms: ['Cough', 'Chest Congestion', 'Mucus'],
    warnings: ['Not suitable for infants under 2 years'],
  ),
  Product(
    id: 'MED-1004',
    name: 'Adult Cough & Mucus Relief',
    genericName: 'Guaifenesin 400mg Expectorant',
    price: 12.50,
    category: 'Cold & Cough',
    ageGroup: AgeGroup.adult,
    stock: 30,
    requiresRx: false,
    dosageInfo: '1 tablet every 12 hours with water.',
    targetSymptoms: ['Cough', 'Chest Congestion', 'Mucus'],
    warnings: ['Drink plenty of fluids'],
  ),
  Product(
    id: 'MED-1005',
    name: 'Pediatric Electrolyte Drops',
    genericName: 'Oral Rehydration Salts Child',
    price: 5.75,
    category: 'Digestive',
    ageGroup: AgeGroup.child,
    stock: 60,
    requiresRx: false,
    dosageInfo: 'Sip small amounts frequently.',
    targetSymptoms: ['Diarrhea', 'Dehydration', 'Vomiting'],
    warnings: ['Use within 24 hours of mixing'],
  ),
  Product(
    id: 'MED-1006',
    name: 'Adult Amoxicillin 500mg',
    genericName: 'Amoxicillin Trihydrate',
    price: 18.00,
    category: 'Antibiotics',
    ageGroup: AgeGroup.adult,
    stock: 25,
    requiresRx: true,
    dosageInfo: '1 capsule 3 times daily for 7 days.',
    targetSymptoms: ['Bacterial Infection', 'Sore Throat', 'Ear Pain'],
    warnings: ['Requires valid doctor prescription'],
  ),
];

// -----------------------------------------------------------------------------
// MAIN SCREEN CONTROLLER
// -----------------------------------------------------------------------------
class MainStaffScreen extends StatefulWidget {
  const MainStaffScreen({super.key});

  @override
  State<MainStaffScreen> createState() => _MainStaffScreenState();
}

class _MainStaffScreenState extends State<MainStaffScreen> {
  int _selectedIndex = 0;
  final List<CartItem> _cart = [];

  void _addToCart(Product product) {
    setState(() {
      final index = _cart.indexWhere((item) => item.product.id == product.id);
      if (index >= 0) {
        _cart[index].quantity++;
      } else {
        _cart.add(CartItem(product: product));
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} added to cart'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _updateQuantity(Product product, int change) {
    setState(() {
      final index = _cart.indexWhere((item) => item.product.id == product.id);
      if (index >= 0) {
        _cart[index].quantity += change;
        if (_cart[index].quantity <= 0) {
          _cart.removeAt(index);
        }
      }
    });
  }

  void _clearCart() {
    setState(() {
      _cart.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      SaleCatalogTab(onAddToCart: _addToCart),
      SymptomFinderTab(onAddToCart: _addToCart),
      ScannerTab(onAddToCart: _addToCart),
    ];

    int totalCartCount = _cart.fold(0, (sum, item) => sum + item.quantity);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.local_pharmacy, color: Color(0xFF0284C7)),
            SizedBox(width: 8),
            Text(
              'PharmaStaff POS',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: () {
                  _showCartSheet(context);
                },
              ),
              if (totalCartCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$totalCartCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'New Sale',
          ),
          NavigationDestination(
            icon: Icon(Icons.medical_services_outlined),
            selectedIcon: Icon(Icons.medical_services),
            label: 'Symptom Finder',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: Icon(Icons.qr_code_scanner),
            label: 'Scan SKU',
          ),
        ],
      ),
    );
  }

  void _showCartSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            double subtotal = _cart.fold(0, (sum, item) => sum + item.total);
            double tax = subtotal * 0.05;
            double grandTotal = subtotal + tax;

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Current Cart (${_cart.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  if (_cart.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Cart is empty',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: _cart.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          final item = _cart[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              item.product.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '\$${item.product.price.toStringAsFixed(2)} x ${item.quantity}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () {
                                    _updateQuantity(item.product, -1);
                                    setSheetState(() {});
                                  },
                                ),
                                Text(
                                  '${item.quantity}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () {
                                    _updateQuantity(item.product, 1);
                                    setSheetState(() {});
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  if (_cart.isNotEmpty) ...[
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal'),
                        Text('\$${subtotal.toStringAsFixed(2)}'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tax (5%)'),
                        Text('\$${tax.toStringAsFixed(2)}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '\$${grandTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _showCheckoutSuccessDialog(context, grandTotal);
                        },
                        child: const Text(
                          'Complete Sale',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCheckoutSuccessDialog(BuildContext context, double total) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Icon(Icons.check_circle, color: Colors.green, size: 48),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Transaction Successful!',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text('Amount Paid: \$${total.toStringAsFixed(2)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _clearCart();
              Navigator.pop(ctx);
            },
            child: const Text('New Sale'),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 1: NEW SALE CATALOG (CHILD & ADULT CATEGORIES)
// -----------------------------------------------------------------------------
class SaleCatalogTab extends StatefulWidget {
  final Function(Product) onAddToCart;

  const SaleCatalogTab({super.key, required this.onAddToCart});

  @override
  State<SaleCatalogTab> createState() => _SaleCatalogTabState();
}

class _SaleCatalogTabState extends State<SaleCatalogTab> {
  AgeGroup _selectedAgeGroup = AgeGroup.both;
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Pain & Fever',
    'Cold & Cough',
    'Digestive',
    'Antibiotics'
  ];

  @override
  Widget build(BuildContext context) {
    List<Product> filteredProducts = mockProducts.where((product) {
      if (_selectedAgeGroup != AgeGroup.both &&
          product.ageGroup != _selectedAgeGroup) {
        return false;
      }
      if (_selectedCategory != 'All' &&
          product.category != _selectedCategory) {
        return false;
      }
      if (_searchQuery.isNotEmpty &&
          !product.name.toLowerCase().contains(_searchQuery.toLowerCase()) &&
          !product.genericName
              .toLowerCase()
              .contains(_searchQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search medicine, generic name...',
                  prefixIcon: const Icon(Icons.search),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<AgeGroup>(
                      segments: const [
                        ButtonSegment(
                          value: AgeGroup.both,
                          label: Text('All'),
                          icon: Icon(Icons.people_outline, size: 16),
                        ),
                        ButtonSegment(
                          value: AgeGroup.child,
                          label: Text('Child'),
                          icon: Icon(Icons.child_care, size: 16),
                        ),
                        ButtonSegment(
                          value: AgeGroup.adult,
                          label: Text('Adult'),
                          icon: Icon(Icons.person_outline, size: 16),
                        ),
                      ],
                      selected: {_selectedAgeGroup},
                      onSelectionChanged: (Set<AgeGroup> newSelection) {
                        setState(() {
                          _selectedAgeGroup = newSelection.first;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 36,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: isSelected,
                        label: Text(cat),
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategory = cat;
                          });
                        },
                        selectedColor: const Color(0xFFE0F2FE),
                        checkmarkColor: const Color(0xFF0284C7),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filteredProducts.isEmpty
              ? const Center(
                  child: Text('No medicines found matching filters.'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    return ProductCard(
                      product: product,
                      onAdd: () => widget.onAddToCart(product),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 2: SYMPTOM FINDER TAB
// -----------------------------------------------------------------------------
class SymptomFinderTab extends StatefulWidget {
  final Function(Product) onAddToCart;

  const SymptomFinderTab({super.key, required this.onAddToCart});

  @override
  State<SymptomFinderTab> createState() => _SymptomFinderTabState();
}

class _SymptomFinderTabState extends State<SymptomFinderTab> {
  AgeGroup _targetAgeGroup = AgeGroup.child;
  final List<String> _selectedSymptoms = [];

  final List<String> _symptomOptions = [
    'Fever',
    'Headache',
    'Cough',
    'Mucus',
    'Chest Congestion',
    'Diarrhea',
    'Vomiting',
    'Sore Throat',
  ];

  @override
  Widget build(BuildContext context) {
    List<Product> matches = mockProducts.where((p) {
      bool matchesAge = p.ageGroup == _targetAgeGroup;
      bool matchesSymptom = _selectedSymptoms.isEmpty ||
          p.targetSymptoms.any((s) => _selectedSymptoms.contains(s));
      return matchesAge && matchesSymptom;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Patient Demographic & Symptoms',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ChoiceChip(
                avatar: const Icon(Icons.child_care, size: 16),
                label: const Text('Pediatric / Child'),
                selected: _targetAgeGroup == AgeGroup.child,
                onSelected: (selected) {
                  if (selected) setState(() => _targetAgeGroup = AgeGroup.child);
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                avatar: const Icon(Icons.person, size: 16),
                label: const Text('Adult'),
                selected: _targetAgeGroup == AgeGroup.adult,
                onSelected: (selected) {
                  if (selected) setState(() => _targetAgeGroup = AgeGroup.adult);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Select Symptoms:',
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: _symptomOptions.map((symptom) {
              final isSelected = _selectedSymptoms.contains(symptom);
              return FilterChip(
                label: Text(symptom, style: const TextStyle(fontSize: 12)),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedSymptoms.add(symptom);
                    } else {
                      _selectedSymptoms.remove(symptom);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text(
            'Recommended Medications (${matches.length})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: matches.isEmpty
                ? const Center(
                    child: Text('No matching medication found for selected criteria.'),
                  )
                : ListView.builder(
                    itemCount: matches.length,
                    itemBuilder: (context, index) {
                      final product = matches[index];
                      return ProductCard(
                        product: product,
                        onAdd: () => widget.onAddToCart(product),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 3: BARCODE SCANNER TAB
// -----------------------------------------------------------------------------
class ScannerTab extends StatefulWidget {
  final Function(Product) onAddToCart;

  const ScannerTab({super.key, required this.onAddToCart});

  @override
  State<ScannerTab> createState() => _ScannerTabState();
}

class _ScannerTabState extends State<ScannerTab> {
  final TextEditingController _skuController = TextEditingController();

  void _simulateScan(String sku) {
    final product = mockProducts.firstWhere(
      (p) => p.id.toLowerCase() == sku.toLowerCase(),
      orElse: () => mockProducts[0],
    );
    widget.onAddToCart(product);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_scanner, color: Colors.white54, size: 64),
                    SizedBox(height: 8),
                    Text(
                      'Position Barcode inside Frame',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
                Container(
                  height: 2,
                  width: 200,
                  color: Colors.redAccent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _skuController,
            decoration: InputDecoration(
              labelText: 'Manual SKU / Barcode Entry',
              hintText: 'e.g. MED-1001',
              suffixIcon: IconButton(
                icon: const Icon(Icons.add_shopping_cart),
                onPressed: () {
                  if (_skuController.text.isNotEmpty) {
                    _simulateScan(_skuController.text);
                    _skuController.clear();
                  }
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Quick Scan Samples (Tap to Scan)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: mockProducts.map((p) {
              return ActionChip(
                avatar: const Icon(Icons.qr_code, size: 16),
                label: Text('${p.name} (${p.id})'),
                onPressed: () => _simulateScan(p.id),
              );
            }).toList(),
          )
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// PRODUCT CARD WIDGET
// -----------------------------------------------------------------------------
class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onAdd;

  const ProductCard({
    super.key,
    required this.product,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    bool isChild = product.ageGroup == AgeGroup.child;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isChild
                        ? const Color(0xFFFEF3C7)
                        : const Color(0xFFE0E7FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isChild ? Icons.child_care : Icons.person_outline,
                        size: 14,
                        color: isChild
                            ? const Color(0xFFD97706)
                            : const Color(0xFF4338CA),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isChild ? 'PEDIATRIC / CHILD' : 'ADULT FORMULA',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isChild
                              ? const Color(0xFFD97706)
                              : const Color(0xFF4338CA),
                        ),
                      ),
                    ],
                  ),
                ),
                if (product.requiresRx)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Rx Required',
                      style: TextStyle(
                          color: Colors.red,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              product.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            Text(
              product.genericName,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Text(
              'Dosage: ${product.dosageInfo}',
              style: const TextStyle(fontSize: 11, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '\$${product.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0284C7),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_shopping_cart, size: 16),
                  label: const Text('Add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// main.dart — MVP «СканСклад»
// Flutter 3.x, однофайловый прототип для быстрого старта

import 'package:flutter/material.dart';

void main() {
  runApp(const ScanSkladApp());
}

class ScanSkladApp extends StatelessWidget {
  const ScanSkladApp({super.key});

  @override
  Widget build(BuildContext context) {
    final Color primary = const Color(0xFF7C3AED); // фиолетовый
    final Color accent = const Color(0xFFA855F7);  // светлее фиолетовый

    return MaterialApp(
      title: 'СканСклад',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          primary: primary,
          secondary: accent,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: RepositoryProvider(
        child: const HomeScreen(),
      ),
    );
  }
}

// ===== МОДЕЛИ =====
class Product {
  Product({
    required this.id,
    required this.name,
    required this.sku,
    this.barcode,
    required this.retailPrice,
    required this.costPrice,
    required this.unit,
    required this.qty,
  });

  final String id;
  String name;
  String sku;
  String? barcode;
  int retailPrice;
  int costPrice;
  String unit;
  int qty;
}

enum MovementType { in_, out, inventory }

class StockMovement {
  StockMovement({
    required this.id,
    required this.productId,
    required this.type,
    required this.qty,
    this.note,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String productId;
  final MovementType type;
  final int qty;
  final String? note;
  final DateTime createdAt;
}

// ===== ПРОСТОЕ РЕПОЗИТОРИЙ-ХРАНИЛИЩЕ =====
class RepositoryProvider extends InheritedWidget {
  RepositoryProvider({super.key, required Widget child})
      : repository = Repository(),
        super(child: child);

  final Repository repository;

  static Repository of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<RepositoryProvider>();
    assert(provider != null, 'RepositoryProvider not found');
    return provider!.repository;
  }

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) => false;
}

class Repository extends ChangeNotifier {
  final List<Product> _products = [];
  final List<StockMovement> _movements = [];

  List<Product> get products => List.unmodifiable(_products);
  List<StockMovement> get movements => List.unmodifiable(_movements);

  void upsertProduct(Product p) {
    final idx = _products.indexWhere((e) => e.id == p.id);
    if (idx == -1) {
      _products.add(p);
    } else {
      _products[idx] = p;
    }
    notifyListeners();
  }

  void deleteProduct(String id) {
    _products.removeWhere((e) => e.id == id);
    _movements.removeWhere((m) => m.productId == id);
    notifyListeners();
  }

  void addMovement(
      String productId, MovementType type, int qty,
      {String? note}) {
    final product = _products.firstWhere((e) => e.id == productId);
    if (type == MovementType.in_) {
      product.qty += qty;
    } else if (type == MovementType.out) {
      product.qty -= qty;
      if (product.qty < 0) product.qty = 0;
    }
    _movements.insert(
      0,
      StockMovement(
        id: UniqueKey().toString(),
        productId: productId,
        type: type,
        qty: qty,
        note: note,
      ),
    );
    notifyListeners();
  }
}

// ===== ГЛАВНЫЙ ЭКРАН С НИЖНЕЙ НАВИГАЦИЕЙ =====
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const CatalogScreen(),
      const ScannerScreen(),
      const HistoryScreen(),
    ];

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Scaffold(
        key: ValueKey(_index),
        appBar: AppBar(
          title: Text(['Каталог', 'Сканер', 'История'][_index]),
        ),
        body: pages[_index],
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2),
              label: 'Каталог',
            ),
            NavigationDestination(
              icon: Icon(Icons.qr_code_scanner),
              selectedIcon: Icon(Icons.qr_code_scanner),
              label: 'Сканер',
            ),
            NavigationDestination(
              icon: Icon(Icons.history),
              selectedIcon: Icon(Icons.history),
              label: 'История',
            ),
          ],
          onDestinationSelected: (i) => setState(() => _index = i),
        ),
        floatingActionButton: _index == 0
            ? FloatingActionButton(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ProductForm()),
                  );
                  setState(() {});
                },
                child: const Icon(Icons.add),
              )
            : null,
      ),
    );
  }
}

// ===== КАТАЛОГ =====
class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  String query = '';
  String unitFilter = 'Все';

  @override
  Widget build(BuildContext context) {
    final repo = RepositoryProvider.of(context);
    return AnimatedBuilder(
      animation: repo,
      builder: (context, _) {
        final items = repo.products.where((p) {
          final q = query.trim().toLowerCase();
          final matchesQuery =
              q.isEmpty ||
              p.name.toLowerCase().contains(q) ||
              p.sku.toLowerCase().contains(q) ||
              (p.barcode?.contains(q) ?? false);
          final matchesUnit = unitFilter == 'Все' || p.unit == unitFilter;
          return matchesQuery && matchesUnit;
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Название, артикул или штрих-код',
                ),
                onChanged: (v) => setState(() => query = v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('Все'),
                    selected: unitFilter == 'Все',
                    onSelected: (_) => setState(() => unitFilter = 'Все'),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('шт'),
                    selected: unitFilter == 'шт',
                    onSelected: (_) => setState(() => unitFilter = 'шт'),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('уп'),
                    selected: unitFilter == 'уп',
                    onSelected: (_) => setState(() => unitFilter = 'уп'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    'Здесь будет список товаров.\\nНажми + чтобы добавить первый товар.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final p = items[i];
                    return ListTile(
                      title: Text(p.name),
                      subtitle: Text('SKU: ${p.sku} • ${p.unit}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${p.retailPrice} ₸',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              )),
                          const SizedBox(height: 4),
                          Text('Ост: ${p.qty}',
                              style:
                                  const TextStyle(color: Colors.grey)),
                        ],
                      ),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ProductDetails(productId: p.id),
                          ),
                        );
                        setState(() {});
                      },
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

// ===== СТРАНИЦА ТОВАРА =====
class ProductDetails extends StatelessWidget {
  const ProductDetails({super.key, required this.productId});
  final String productId;

  @override
  Widget build(BuildContext context) {
    final repo = RepositoryProvider.of(context);
    final product =
        repo.products.firstWhere((e) => e.id == productId);

    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProductForm(editing: product),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await confirm(context, 'Удалить товар?');
              if (ok) {
                repo.deleteProduct(product.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Row(
              children: [
                Expanded(child: infoTile('Штрих-код', product.barcode ?? '—')),
                const SizedBox(width: 12),
                Expanded(child: infoTile('SKU', product.sku)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: infoTile('Единица', product.unit)),
                const SizedBox(width: 12),
                Expanded(
                    child: infoTile(
                        'Остаток', product.qty.toString())),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: infoTile('Розничная цена',
                        '${product.retailPrice} ₸')),
                const SizedBox(width: 12),
                Expanded(
                    child: infoTile('Закупочная цена',
                        '${product.costPrice} ₸')),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => openMovementDialog(
                        context, product.id, MovementType.in_),
                    icon: const Icon(Icons.call_received),
                    label: const Text('Приход'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => openMovementDialog(
                        context, product.id, MovementType.out),
                    icon: const Icon(Icons.call_made),
                    label: const Text('Расход'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('История движений',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...repo.movements
                .where((m) => m.productId == product.id)
                .map(
                  (m) => ListTile(
                    dense: true,
                    leading: Icon(m.type == MovementType.in_
                        ? Icons.north_east
                        : Icons.south_west),
                    title: Text(m.type == MovementType.in_
                        ? 'Приход +${m.qty}'
                        : 'Расход -${m.qty}'),
                    subtitle: Text(m.note ?? ''),
                    trailing: Text(formatTime(m.createdAt)),
                  ),
                )
                .toList(),
          ],
        ),
      ),
    );
  }
}

Widget infoTile(String title, String value) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.grey.shade200),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

// ===== ФОРМА ТОВАРА =====
class ProductForm extends StatefulWidget {
  ProductForm({super.key, Product? editing}) : editing = editing;
  final Product? editing;

  @override
  State<ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<ProductForm> {
  final formKey = GlobalKey<FormState>();
  final nameCtrl = TextEditingController();
  final skuCtrl = TextEditingController();
  final barcodeCtrl = TextEditingController();
  final retailCtrl = TextEditingController();
  final costCtrl = TextEditingController();
  final qtyCtrl = TextEditingController(text: '0');
  String unit = 'шт';

  @override
  void initState() {
    super.initState();
    final p = widget.editing;
    if (p != null) {
      nameCtrl.text = p.name;
      skuCtrl.text = p.sku;
      barcodeCtrl.text = p.barcode ?? '';
      retailCtrl.text = p.retailPrice.toString();
      costCtrl.text = p.costPrice.toString();
      unit = p.unit;
      qtyCtrl.text = p.qty.toString();
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    skuCtrl.dispose();
    barcodeCtrl.dispose();
    retailCtrl.dispose();
    costCtrl.dispose();
    qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = RepositoryProvider.of(context);

    return Scaffold(
      appBar: AppBar(
          title: Text(widget.editing == null
              ? 'Добавить товар'
              : 'Редактировать товар')),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Название *'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty)
                      ? 'Введите название'
                      : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: skuCtrl,
              decoration:
                  const InputDecoration(labelText: 'Артикул (SKU)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: barcodeCtrl,
              decoration:
                  const InputDecoration(labelText: 'Штрих-код'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: retailCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Розничная цена, ₸ *'),
                    keyboardType: TextInputType.number,
                    validator: (v) => _intValidator(v, allowZero: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: costCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Закупочная цена, ₸ *'),
                    keyboardType: TextInputType.number,
                    validator: (v) => _intValidator(v, allowZero: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: unit,
                    decoration:
                        const InputDecoration(labelText: 'Единица *'),
                    items: const [
                      DropdownMenuItem(value: 'шт', child: Text('шт')),
                      DropdownMenuItem(value: 'уп', child: Text('уп')),
                    ],
                    onChanged: (v) => setState(() => unit = v ?? 'шт'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: qtyCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Остаток *'),
                    keyboardType: TextInputType.number,
                    validator: (v) => _intValidator(v, allowZero: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final isEdit = widget.editing != null;
                final product =
                    widget.editing ??
                        Product(
                          id: UniqueKey().toString(),
                          name: nameCtrl.text.trim(),
                          sku: skuCtrl.text.trim(),
                          barcode: barcodeCtrl.text
                                  .trim()
                                  .isEmpty
                              ? null
                              : barcodeCtrl.text.trim(),
                          retailPrice:
                              int.parse(retailCtrl.text.trim()),
                          costPrice:
                              int.parse(costCtrl.text.trim()),
                          unit: unit,
                          qty: int.parse(qtyCtrl.text.trim()),
                        );

                if (isEdit) {
                  product
                    ..name = nameCtrl.text.trim()
                    ..sku = skuCtrl.text.trim()
                    ..barcode = barcodeCtrl.text.trim().isEmpty
                        ? null
                        : barcodeCtrl.text.trim()
                    ..retailPrice =
                        int.parse(retailCtrl.text.trim())
                    ..costPrice = int.parse(costCtrl.text.trim())
                    ..unit = unit
                    ..qty = int.parse(qtyCtrl.text.trim());
                }

                repo.upsertProduct(product);
                Navigator.pop(context);
              },
              child: Text(widget.editing == null
                  ? 'Сохранить'
                  : 'Обновить'),
            ),
          ],
        ),
      ),
    );
  }
}

String? _intValidator(String? v, {bool allowZero = false}) {
  if (v == null || v.trim().isEmpty) return 'Введите число';
  final n = int.tryParse(v.trim());
  if (n == null) return 'Только целые числа';
  if (!allowZero && n <= 0) return 'Должно быть > 0';
  if (allowZero && n < 0) return 'Не может быть отрицательным';
  return null;
}

// ===== ДИАЛОГ ПРИХОД/РАСХОД =====
Future<void> openMovementDialog(BuildContext context, String productId,
    MovementType type) async {
  final repo = RepositoryProvider.of(context);
  final qtyCtrl = TextEditingController(text: '1');
  final noteCtrl = TextEditingController();

  await showDialog(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(type == MovementType.in_ ? 'Приход' : 'Расход'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Количество'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                  labelText: 'Комментарий (необязательно)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(qtyCtrl.text.trim());
              if (n == null || n <= 0) return;
              repo.addMovement(
                productId,
                type,
                n,
                note: noteCtrl.text.trim().isEmpty
                    ? null
                    : noteCtrl.text.trim(),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Сохранить'),
          )
        ],
      );
    },
  );
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String formatTime(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

Future<bool> confirm(BuildContext context, String message) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Подтверждение'),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить')),
      ],
    ),
  );
  return res ?? false;
}

// ===== СКАНЕР (ПОКА ЗАГЛУШКА) =====
class ScannerScreen extends StatelessWidget {
  const ScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_scanner, size: 96),
            const SizedBox(height: 12),
            const Text(
              'Сканер появится в следующем шаге (mobile_scanner).\\nПока можно вводить штрих-код вручную в карточке товара.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Сканер скоро будет доступен')),
                );
              },
              child: const Text('Ок'),
            )
          ],
        ),
      ),
    );
  }
}

// ===== ИСТОРИЯ =====
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = RepositoryProvider.of(context);
    return AnimatedBuilder(
      animation: repo,
      builder: (context, _) {
        final items = repo.movements;
        if (items.isEmpty) {
          return const Center(child: Text('История пуста'));
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final m = items[i];
            final prod = repo.products.firstWhere(
              (p) => p.id == m.productId,
              orElse: () => Product(
                id: 'deleted',
                name: 'Удалённый товар',
                sku: '-',
                retailPrice: 0,
                costPrice: 0,
                unit: 'шт',
                qty: 0,
              ),
            );
            final sign = m.type == MovementType.in_ ? '+' : '-';
            final icon = m.type == MovementType.in_
                ? Icons.call_received
                : Icons.call_made;
            return ListTile(
              leading: Icon(icon),
              title: Text(
                  '${m.type == MovementType.in_ ? 'Приход' : 'Расход'} $sign${m.qty} — ${prod.name}'),
              subtitle: Text(m.note ?? ''),
              trailing: Text(formatTime(m.createdAt)),
            );
          },
        );
      },
    );
  }
}

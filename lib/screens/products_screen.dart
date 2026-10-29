import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../routes.dart';
import '../services/app_state.dart';
import '../widgets/common.dart';
/// Screen 4 - Product / Item Selection
class ProductsScreen extends StatefulWidget {
  /// true when shown as a tab inside HomeScreen (no back arrow).
  final bool embedded;
  const ProductsScreen({super.key, this.embedded = false});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String _query = '';
  String _category = 'All';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cats = [
      'All',
      ...{...state.products.map((p) => p.category)},
    ];
    final items = state.products
        .where((p) => _category == 'All' || p.category == _category)
        .where((p) => p.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: simpleAppBar('Products', back: !widget.embedded),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SearchField(
              hint: 'Search products...',
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 600 ? 4 : 2;
                return GridView.count(
                  crossAxisCount: columns,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: columns == 4 ? 2.25 : 1.8,
                  children: [
                    _SummaryCard(
                      icon: Icons.inventory_2_outlined,
                      label: 'Total Products',
                      value: '${state.products.length}',
                      color: const Color(0xFF1685F8),
                    ),
                    _SummaryCard(
                      icon: Icons.check_circle_outline,
                      label: 'In Stock',
                      value:
                          '${state.products.where((p) => p.stock > p.reorder).length}',
                      color: const Color(0xFF16B86A),
                    ),
                    _SummaryCard(
                      icon: Icons.warning_amber_rounded,
                      label: 'Low Stock',
                      value:
                          '${state.products.where((p) => p.isLow && p.stock > 0).length}',
                      color: const Color(0xFFF5A623),
                    ),
                    _SummaryCard(
                      icon: Icons.remove_shopping_cart_outlined,
                      label: 'Out of Stock',
                      value:
                          '${state.products.where((p) => p.stock == 0).length}',
                      color: const Color(0xFF8757E8),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: cats.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => PillChip(
                label: cats[i],
                selected: _category == cats[i],
                onTap: () => setState(() => _category = cats[i]),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('No products found'))
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 900
                          ? 4
                          : constraints.maxWidth >= 600
                          ? 2
                          : 1;
                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: items.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: columns == 1 ? 142 : 218,
                        ),
                        itemBuilder: (_, i) => _ProductCard(
                          product: items[i],
                          quantityInCart: state.cart[items[i].id] ?? 0,
                          onView: () => _showProduct(context, items[i]),
                          onAdd: () {
                            if (!state.addToCart(items[i])) {
                              toast(
                                context,
                                'Not enough stock for ${items[i].name}',
                              );
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
          if (state.cartCount > 0)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: PrimaryButton(
                  icon: Icons.shopping_cart_checkout,
                  label:
                      'View Cart (${state.cartCount})  -  ${ugx(state.total)}',
                  onPressed: () =>
                      Navigator.pushNamed(context, Routes.checkout),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showProduct(BuildContext context, Product product) {
    final color = product.stock == 0
        ? const Color(0xFFE94242)
        : product.isLow
        ? const Color(0xFFF0A020)
        : const Color(0xFF16B86A);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(product.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Category  ·  ${product.category}'),
            const SizedBox(height: 8),
            Text(
              ugx(product.price),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Stock: ${product.stock}',
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF18345A).withValues(alpha: .08),
          blurRadius: 16,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 21),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade600),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF14294B),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final int quantityInCart;
  final VoidCallback onView;
  final VoidCallback onAdd;

  const _ProductCard({
    required this.product,
    required this.quantityInCart,
    required this.onView,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final categoryColor = _categoryColor(product.category);
    final stockColor = product.stock == 0
        ? const Color(0xFFE94242)
        : product.isLow
        ? const Color(0xFFF0A020)
        : const Color(0xFF16B86A);
    final horizontal = MediaQuery.sizeOf(context).width < 600;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE7ECE9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF18345A).withValues(alpha: .14),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: horizontal
          ? Row(
              children: [
                _ProductIcon(product: product, color: categoryColor, size: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: _ProductDetails(
                    product: product,
                    categoryColor: categoryColor,
                    stockColor: stockColor,
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: onView,
                      tooltip: 'View product',
                      icon: const Icon(
                        Icons.visibility_outlined,
                        color: Color(0xFF1685F8),
                      ),
                    ),
                    IconButton.filled(
                      onPressed: onAdd,
                      tooltip: 'Add to cart',
                      icon: const Icon(Icons.add, size: 19),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF1685F8),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ProductIcon(
                        product: product,
                        color: categoryColor,
                        size: 66,
                      ),
                    ),
                    _CategoryTag(label: product.category, color: categoryColor),
                  ],
                ),
                const SizedBox(height: 10),
                _ProductDetails(
                  product: product,
                  categoryColor: categoryColor,
                  stockColor: stockColor,
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.visibility_outlined,
                        color: const Color(0xFF1685F8),
                        onTap: onView,
                        label: 'View',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.add,
                        color: const Color(0xFF16B86A),
                        onTap: onAdd,
                        label: quantityInCart > 0
                            ? 'Add ($quantityInCart)'
                            : 'Add',
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _ProductDetails extends StatelessWidget {
  final Product product;
  final Color categoryColor;
  final Color stockColor;
  const _ProductDetails({
    required this.product,
    required this.categoryColor,
    required this.stockColor,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (MediaQuery.sizeOf(context).width < 600)
        _CategoryTag(label: product.category, color: categoryColor),
      Text(
        product.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: Color(0xFF14294B),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        ugx(product.price),
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: Color(0xFF16B86A),
        ),
      ),
      const SizedBox(height: 4),
      Row(
        children: [
          Icon(Icons.inventory_2_outlined, size: 15, color: stockColor),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              product.stock == 0
                  ? 'Out of stock'
                  : product.isLow
                  ? 'Low stock · ${product.stock}'
                  : 'In stock · ${product.stock}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: stockColor),
            ),
          ),
        ],
      ),
    ],
  );
}

class _ProductIcon extends StatelessWidget {
  final Product product;
  final Color color;
  final double size;
  const _ProductIcon({
    required this.product,
    required this.color,
    required this.size,
  });
  @override
  Widget build(BuildContext context) {
    final asset = _productImage(product.name, product.category);
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        shape: BoxShape.circle,
      ),
      child: asset == null
          ? Icon(
              _categoryIcon(product.category),
              color: color,
              size: size * .48,
            )
          : ClipOval(
              child: Image.asset(
                asset,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Icon(
                  _categoryIcon(product.category),
                  color: color,
                  size: size * .48,
                ),
              ),
            ),
    );
  }
}

class _CategoryTag extends StatelessWidget {
  final String label;
  final Color color;
  const _CategoryTag({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
    ),
  );
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String label;
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.label,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 34,
    child: FilledButton.tonalIcon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
      style: FilledButton.styleFrom(
        foregroundColor: color,
        backgroundColor: color.withValues(alpha: .11),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
    ),
  );
}

Color _categoryColor(String category) {
  switch (category.toLowerCase()) {
    case 'beverages':
      return const Color(0xFF1685F8);
    case 'snacks':
      return const Color(0xFF8757E8);
    case 'household':
      return const Color(0xFF12A997);
    case 'electronics':
      return const Color(0xFF315FEA);
    case 'groceries':
    case 'baking':
      return const Color(0xFFF0A020);
    case 'personal care':
      return const Color(0xFFD34DB5);
    case 'stationery':
      return const Color(0xFF1685F8);
    default:
      return const Color(0xFF1685F8);
  }
}

IconData _categoryIcon(String category) {
  switch (category.toLowerCase()) {
    case 'beverages':
      return Icons.local_drink_outlined;
    case 'snacks':
      return Icons.cookie_outlined;
    case 'household':
      return Icons.cleaning_services_outlined;
    case 'electronics':
      return Icons.devices_outlined;
    case 'groceries':
    case 'baking':
      return Icons.grain;
    case 'personal care':
      return Icons.spa_outlined;
    case 'stationery':
      return Icons.menu_book_outlined;
    default:
      return Icons.inventory_2_outlined;
  }
}

String? _productImage(String name, String category) {
  final value = name.toLowerCase();
  if (value.contains('rice')) return 'assets/images/rice.jpg';
  if (value.contains('coca') || value.contains('cola')) {
    return 'assets/images/cola.jpg';
  }
  if (value.contains('chip')) return 'assets/images/chips.jpg';
  if (value.contains('ariel') || value.contains('detergent')) {
    return 'assets/images/detergent.jpg';
  }
  if (value.contains('samsung') || value.contains('phone')) {
    return 'assets/images/phone.jpg';
  }
  if (value.contains('notebook')) return 'assets/images/notebook.jpg';
  if (value.contains('dove') || value.contains('soap')) {
    return 'assets/images/soap.jpg';
  }
  if (value.contains('flour') || value.contains('unga')) {
    return 'assets/images/flour.jpg';
  }
  switch (category.toLowerCase()) {
    case 'beverages':
      return 'assets/images/cola.jpg';
    case 'snacks':
      return 'assets/images/chips.jpg';
    case 'household':
      return 'assets/images/detergent.jpg';
    case 'electronics':
      return 'assets/images/phone.jpg';
    case 'groceries':
      return 'assets/images/rice.jpg';
    case 'stationery':
      return 'assets/images/notebook.jpg';
    case 'personal care':
      return 'assets/images/soap.jpg';
    case 'baking':
      return 'assets/images/flour.jpg';
    default:
      return null;
  }
}

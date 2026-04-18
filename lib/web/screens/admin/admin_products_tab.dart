import 'package:flutter/material.dart';
import '../../../shared/services/admin/admin_service.dart';
import 'package:agridirect/shared/widgets/app_shimmer_loader.dart';
import 'admin_ui.dart';

class AdminProductsTab extends StatefulWidget {
  final AdminService adminService;
  const AdminProductsTab({super.key, required this.adminService});

  @override
  State<AdminProductsTab> createState() => _AdminProductsTabState();
}

class _AdminProductsTabState extends State<AdminProductsTab> {
  late Future<List<Map<String, dynamic>>> _productsFuture;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _productsFuture = widget.adminService.getAllProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      child: SingleChildScrollView(
        padding: AdminUi.pagePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminHeroCard(
              useGradient: true,
              eyebrow: 'Commerce System',
              title: 'Product Catalog',
              description: 'Oversee market inventory, review listings, and manage global supply.',
              metrics: [
                FutureBuilder<Map<String, dynamic>>(
                  future: widget.adminService.getProductMetrics(),
                  builder: (context, snapshot) {
                    final data = snapshot.data;
                    return Row(
                      children: [
                        AdminMiniMetric(
                          label: 'Total Listings', 
                          value: '${data?['total'] ?? "..."}', 
                          icon: Icons.inventory_2_rounded, 
                          light: true
                        ),
                        const SizedBox(width: 24),
                        AdminMiniMetric(
                          label: 'Active Items', 
                          value: '${data?['active'] ?? "..."}', 
                          icon: Icons.check_circle_rounded, 
                          light: true
                        ),
                        const SizedBox(width: 24),
                        AdminMiniMetric(
                          label: 'Out of Stock', 
                          value: '${data?['out_of_stock'] ?? "0"}', 
                          icon: Icons.warning_amber_rounded, 
                          light: true
                        ),
                      ],
                    );
                  }
                ),
              ],
              actions: [
                ElevatedButton.icon(
                  onPressed: _loadData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: AdminUi.radiusMd),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Sync Catalog'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AdminUi.radiusLg,
                border: Border.all(color: AdminUi.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _buildToolbar(),
                  const Divider(height: 1, color: AdminUi.border),
                  _buildTableHeader(),
                  const Divider(height: 1, color: AdminUi.border),
                  _buildTableBody(),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildBottomInsights(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomInsights() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            height: 200,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AdminUi.brandDark, AdminUi.brand],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: AdminUi.radiusLg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Market Demand Analysis', style: AdminUi.title(size: 20, color: Colors.white)),
                const SizedBox(height: 12),
                Text(
                  'Organic root vegetables are trending up 24% this week. Consider advising farmers to list more heirloom varieties.',
                  style: AdminUi.body(size: 14, color: Colors.white.withValues(alpha: 0.8)),
                ),
                const Spacer(),
                Text('VIEW TREND REPORT', style: AdminUi.label(size: 12, color: Colors.white, weight: FontWeight.w800)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Container(
            height: 200,
            padding: const EdgeInsets.all(32),
            decoration: AdminUi.cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Low Stock Alerts', style: AdminUi.title(size: 20)),
                const SizedBox(height: 16),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: widget.adminService.getAllProducts(),
                  builder: (context, snapshot) {
                    final lowStock = (snapshot.data ?? [])
                        .where((p) => (p['stock_quantity'] ?? 0) < 10)
                        .toList();
                    if (lowStock.isEmpty) {
                      return Text('All items well stocked', style: AdminUi.body(size: 13, color: AdminUi.textMuted));
                    }
                    return Column(
                      children: lowStock.take(2).map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _alertItem(
                          p['name'] ?? 'Unknown', 
                          '${p['stock_quantity'] ?? 0} units left', 
                          (p['stock_quantity'] ?? 0) == 0 ? AdminUi.danger : AdminUi.warning
                        ),
                      )).toList(),
                    );
                  }
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _alertItem(String name, String stock, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(name, style: AdminUi.label(size: 14, color: AdminUi.textPrimary))),
        Text(stock, style: AdminUi.body(size: 13, color: color, weight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AdminUi.background,
                borderRadius: AdminUi.radiusMd,
              ),
              child: TextField(
                decoration: AdminUi.inputDecoration(
                  hintText: 'Search products by name or farmer...',
                  prefixIcon: const Icon(Icons.search_rounded, color: AdminUi.textMuted, size: 20),
                ).copyWith(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: AdminUi.background,
              borderRadius: AdminUi.radiusMd,
            ),
            child: Row(
              children: [
                const Icon(Icons.filter_list_rounded, size: 18, color: AdminUi.textSecondary),
                const SizedBox(width: 8),
                Text('Filter', style: AdminUi.label(size: 13, color: AdminUi.textPrimary, weight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      color: AdminUi.sidebarBg.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          _headerCell('Product Detail', flex: 3),
          _headerCell('Price / Unit', flex: 1),
          _headerCell('Inventory', flex: 1),
          _headerCell('Status', flex: 1),
          _headerCell('Actions', flex: 1, align: TextAlign.right),
        ],
      ),
    );
  }

  Widget _headerCell(String text, {int flex = 1, TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Text(
        text.toUpperCase(),
        textAlign: align,
        style: AdminUi.label(size: 11, color: AdminUi.textMuted, weight: FontWeight.w700),
      ),
    );
  }

  Widget _buildTableBody() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _productsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: AppShimmerLoader(color: AdminUi.brand)),
          );
        }

        var products = snapshot.data ?? [];
        
        if (_searchQuery.isNotEmpty) {
          products = products.where((p) {
            final name = (p['name'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery);
          }).toList();
        }

        if (products.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Text('No products found.', style: AdminUi.body(color: AdminUi.textMuted)),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: products.length,
          separatorBuilder: (context, index) => const Divider(height: 1, color: AdminUi.border),
          itemBuilder: (context, index) => _buildRow(products[index]),
        );
      },
    );
  }

  Widget _buildRow(Map<String, dynamic> product) {
    final name = product['name'] ?? 'Unnamed Product';
    final price = product['price'] ?? 0;
    final stock = product['stock_quantity'] ?? 0;
    final isActive = product['is_active'] ?? true;

    Color statusColor = isActive ? AdminUi.success : AdminUi.danger;
    String status = isActive ? 'ACTIVE' : 'INACTIVE';

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () {},
        hoverColor: AdminUi.panelAlt,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AdminUi.brandSoft,
                        borderRadius: AdminUi.radiusMd,
                        border: Border.all(color: AdminUi.brand.withValues(alpha: 0.1)),
                        image: product['image_url'] != null 
                          ? DecorationImage(image: NetworkImage(product['image_url']), fit: BoxFit.cover)
                          : null,
                      ),
                      child: product['image_url'] == null 
                        ? const Icon(Icons.inventory_2_rounded, color: AdminUi.brand, size: 20)
                        : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: AdminUi.label(size: 14, color: AdminUi.textPrimary, weight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(product['category_name'] ?? 'Fresh Produce', style: AdminUi.body(size: 12, color: AdminUi.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 1,
                child: Text('₱${price.toStringAsFixed(2)}', style: AdminUi.label(size: 13, color: AdminUi.textPrimary)),
              ),
              Expanded(
                flex: 1,
                child: Text('$stock units', style: AdminUi.body(size: 13, color: AdminUi.textSecondary)),
              ),
              Expanded(
                flex: 1,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: AdminUi.radiusSm,
                      border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      status,
                      style: AdminUi.label(size: 10, color: statusColor, weight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded),
                      color: AdminUi.danger,
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

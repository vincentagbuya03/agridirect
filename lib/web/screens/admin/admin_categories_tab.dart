import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/admin/admin_service.dart';
import 'package:agridirect/shared/widgets/app_shimmer_loader.dart';
import 'admin_ui.dart';

class AdminCategoriesTab extends StatefulWidget {
  final AdminService adminService;
  const AdminCategoriesTab({super.key, required this.adminService});

  @override
  State<AdminCategoriesTab> createState() => _AdminCategoriesTabState();
}

class _AdminCategoriesTabState extends State<AdminCategoriesTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<Map<String, dynamic>>> _categoriesFuture;
  late Future<List<Map<String, dynamic>>> _unitsFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadData() {
    setState(() {
      _categoriesFuture = widget.adminService.getAllCategories();
      _unitsFuture = widget.adminService.getAllUnits();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: AdminUi.pagePadding(context),
            child: AdminHeroCard(
              useGradient: true,
              eyebrow: 'Market Taxonomy',
              title: 'Categories & Units',
              description: 'Configure standard marketplace classifications, measurement units, and global standards.',
              metrics: [
                AdminMiniMetric(label: 'Categories', value: '24', icon: Icons.category_rounded, light: true),
                AdminMiniMetric(label: 'Standard Units', value: '18', icon: Icons.straighten_rounded, light: true),
                AdminMiniMetric(label: 'Avg Products/Cat', value: '162', icon: Icons.analytics_rounded, light: true),
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
                  label: const Text('Refresh Data'),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: AdminUi.pagePadding(context).copyWith(top: 0),
              child: Container(
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
                    Container(
                      color: AdminUi.sidebarBg.withValues(alpha: 0.5),
                      child: TabBar(
                        controller: _tabController,
                        indicatorColor: AdminUi.brand,
                        indicatorWeight: 3,
                        indicatorSize: TabBarIndicatorSize.label,
                        labelColor: AdminUi.brand,
                        unselectedLabelColor: AdminUi.textSecondary,
                        labelStyle: AdminUi.label(size: 14, weight: FontWeight.w800),
                        unselectedLabelStyle: AdminUi.label(size: 14, weight: FontWeight.w600),
                        tabs: const [
                          Tab(text: 'Categories'),
                          Tab(text: 'Measurement Units'),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AdminUi.border),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildCategoriesView(),
                          _buildUnitsView(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesView() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _categoriesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: AppShimmerLoader(color: AdminUi.brand));
        final items = snapshot.data ?? [];
        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: items.length,
          separatorBuilder: (context, index) => const Divider(height: 1, color: AdminUi.border),
          itemBuilder: (context, index) {
            final cat = items[index];
            return Material(
              color: Colors.white,
              child: InkWell(
                onTap: () {},
                hoverColor: AdminUi.background,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AdminUi.brandSoft,
                        borderRadius: AdminUi.radiusMd,
                        border: Border.all(color: AdminUi.brand.withValues(alpha: 0.1)),
                      ),
                      child: const Icon(Icons.category_rounded, size: 20, color: AdminUi.brand),
                    ),
                    title: Text(cat['name'] ?? '', style: AdminUi.label(size: 15, color: AdminUi.textPrimary, weight: FontWeight.w700)),
                    subtitle: Text(cat['description'] ?? '', style: AdminUi.body(size: 13, color: AdminUi.textSecondary)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: AdminUi.danger, size: 20),
                      onPressed: () {},
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUnitsView() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _unitsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: AppShimmerLoader(color: AdminUi.brand));
        final items = snapshot.data ?? [];
        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: items.length,
          separatorBuilder: (context, index) => const Divider(height: 1, color: AdminUi.border),
          itemBuilder: (context, index) {
            final unit = items[index];
            return Material(
              color: Colors.white,
              child: InkWell(
                onTap: () {},
                hoverColor: AdminUi.background,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AdminUi.sidebarBg,
                        borderRadius: AdminUi.radiusMd,
                        border: Border.all(color: AdminUi.border),
                      ),
                      child: Center(
                        child: Text(
                          unit['abbreviation'] ?? '', 
                          style: GoogleFonts.plusJakartaSans(color: AdminUi.brand, fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                      ),
                    ),
                    title: Text(unit['name'] ?? '', style: AdminUi.label(size: 15, color: AdminUi.textPrimary, weight: FontWeight.w700)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: AdminUi.danger, size: 20),
                      onPressed: () {},
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

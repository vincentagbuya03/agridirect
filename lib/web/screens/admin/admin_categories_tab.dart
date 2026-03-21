import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/admin_service.dart';

/// Admin Categories Tab - Manage product categories and units
class AdminCategoriesTab extends StatefulWidget {
  final AdminService adminService;

  const AdminCategoriesTab({super.key, required this.adminService});

  @override
  State<AdminCategoriesTab> createState() => _AdminCategoriesTabState();
}

class _AdminCategoriesTabState extends State<AdminCategoriesTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const Color _primary = Color(0xFF10B981);
  static const Color _card = Color(0xFF1E293B);
  static const Color _border = Color(0xFF334155);
  static const Color _muted = Color(0xFF64748B);
  static const Color _dark = Color(0xFF0F172A);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      color: _dark,
      child: Column(
        children: [
          // Tab Bar
          Container(
            margin: EdgeInsets.fromLTRB(
              isMobile ? 16 : 24,
              24,
              isMobile ? 16 : 24,
              0,
            ),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: _primary,
              labelColor: _primary,
              unselectedLabelColor: _muted,
              labelStyle: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: _primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.category_rounded, size: 18),
                      const SizedBox(width: 8),
                      const Text('Categories'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.straighten_rounded, size: 18),
                      const SizedBox(width: 8),
                      const Text('Units'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _CategoriesList(adminService: widget.adminService),
                _UnitsList(adminService: widget.adminService),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Categories List
class _CategoriesList extends StatefulWidget {
  final AdminService adminService;

  const _CategoriesList({required this.adminService});

  @override
  State<_CategoriesList> createState() => _CategoriesListState();
}

class _CategoriesListState extends State<_CategoriesList> {
  late Future<List<Map<String, dynamic>>> _categoriesFuture;

  static const Color _primary = Color(0xFF10B981);
  static const Color _danger = Color(0xFFEF4444);
  static const Color _info = Color(0xFF3B82F6);
  static const Color _dark = Color(0xFF0F172A);
  static const Color _card = Color(0xFF1E293B);
  static const Color _border = Color(0xFF334155);
  static const Color _muted = Color(0xFF64748B);
  static const Color _text = Color(0xFFF1F5F9);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _categoriesFuture = widget.adminService.getAllCategories();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Add Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Product Categories',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _text,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddCategoryDialog(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Category'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Categories Grid
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _categoriesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: _primary),
                  ),
                );
              }

              final categories = snapshot.data ?? [];

              if (categories.isEmpty) {
                return _buildEmptyState();
              }

              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: categories
                    .map(
                      (cat) => _CategoryCard(
                        category: cat,
                        adminService: widget.adminService,
                        onAction: () => setState(() => _loadData()),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.category_outlined,
                color: _muted,
                size: 56,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No categories yet',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first product category',
              style: GoogleFonts.inter(fontSize: 13, color: _muted),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final iconController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.add_rounded, color: _primary, size: 24),
            ),
            const SizedBox(width: 16),
            Text(
              'Add Category',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: _text,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(
                nameController,
                'Category Name',
                Icons.label_rounded,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                descController,
                'Description (optional)',
                Icons.description_rounded,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                iconController,
                'Icon Name (optional)',
                Icons.emoji_emotions_rounded,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(color: _muted)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: _danger,
                    content: Text(
                      'Please enter a name',
                      style: GoogleFonts.inter(),
                    ),
                  ),
                );
                return;
              }
              final success = await widget.adminService.createCategory(
                name: nameController.text,
                description: descController.text.isEmpty
                    ? null
                    : descController.text,
                icon: iconController.text.isEmpty ? null : iconController.text,
              );
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: success ? _primary : _danger,
                    content: Text(
                      success
                          ? 'Category created'
                          : 'Failed to create category',
                      style: GoogleFonts.inter(color: Colors.white),
                    ),
                  ),
                );
                setState(() => _loadData());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Create',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon,
  ) {
    return TextField(
      controller: controller,
      style: GoogleFonts.inter(color: _text, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: _muted, fontSize: 13),
        prefixIcon: Icon(icon, color: _muted, size: 20),
        filled: true,
        fillColor: _dark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _primary),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final Map<String, dynamic> category;
  final AdminService adminService;
  final VoidCallback onAction;

  const _CategoryCard({
    required this.category,
    required this.adminService,
    required this.onAction,
  });

  static const Color _primary = Color(0xFF10B981);
  static const Color _danger = Color(0xFFEF4444);
  static const Color _card = Color(0xFF1E293B);
  static const Color _border = Color(0xFF334155);
  static const Color _muted = Color(0xFF64748B);
  static const Color _text = Color(0xFFF1F5F9);

  @override
  Widget build(BuildContext context) {
    final isActive = category['is_active'] ?? true;

    return Container(
      width: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? _border : _danger.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getIconData(category['icon']),
                  color: _primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category['name'] ?? 'Unnamed',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _text,
                      ),
                    ),
                    if (!isActive)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _danger.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Inactive',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _danger,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: _muted, size: 20),
                color: _card,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (value) => _handleAction(context, value),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(
                      children: [
                        Icon(
                          isActive
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          size: 18,
                          color: _muted,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isActive ? 'Deactivate' : 'Activate',
                          style: GoogleFonts.inter(color: _text, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_rounded, size: 18, color: _danger),
                        const SizedBox(width: 12),
                        Text(
                          'Delete',
                          style: GoogleFonts.inter(
                            color: _danger,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (category['description'] != null) ...[
            const SizedBox(height: 14),
            Text(
              category['description'],
              style: GoogleFonts.inter(fontSize: 13, color: _muted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  IconData _getIconData(String? iconName) {
    switch (iconName?.toLowerCase()) {
      case 'vegetables':
        return Icons.eco_rounded;
      case 'fruits':
        return Icons.apple_rounded;
      case 'grains':
        return Icons.grass_rounded;
      case 'dairy':
        return Icons.egg_rounded;
      case 'meat':
        return Icons.restaurant_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  void _handleAction(BuildContext context, String action) async {
    if (action == 'toggle') {
      final success = await adminService.updateCategory(
        categoryId: category['category_id'],
        isActive: !(category['is_active'] ?? true),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: success ? _primary : _danger,
            content: Text(
              success ? 'Category updated' : 'Failed to update',
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
        );
        onAction();
      }
    } else if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: _card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Delete Category?',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _text),
          ),
          content: Text(
            'This will permanently delete this category. Products using this category will need to be reassigned.',
            style: GoogleFonts.inter(color: _muted, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: GoogleFonts.inter(color: _muted)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _danger,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Delete',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );

      if (confirmed == true && context.mounted) {
        final success = await adminService.deleteCategory(
          category['category_id'],
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: success ? _primary : _danger,
            content: Text(
              success ? 'Category deleted' : 'Failed to delete',
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
        );
        onAction();
      }
    }
  }
}

// Units List
class _UnitsList extends StatefulWidget {
  final AdminService adminService;

  const _UnitsList({required this.adminService});

  @override
  State<_UnitsList> createState() => _UnitsListState();
}

class _UnitsListState extends State<_UnitsList> {
  late Future<List<Map<String, dynamic>>> _unitsFuture;

  static const Color _primary = Color(0xFF10B981);
  static const Color _danger = Color(0xFFEF4444);
  static const Color _dark = Color(0xFF0F172A);
  static const Color _card = Color(0xFF1E293B);
  static const Color _border = Color(0xFF334155);
  static const Color _muted = Color(0xFF64748B);
  static const Color _text = Color(0xFFF1F5F9);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _unitsFuture = widget.adminService.getAllUnits();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Measurement Units',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _text,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddUnitDialog(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Unit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Units Table
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _unitsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: _primary),
                  ),
                );
              }

              final units = snapshot.data ?? [];

              if (units.isEmpty) {
                return _buildEmptyState();
              }

              return Container(
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  children: [
                    // Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: _dark,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Unit Name',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _muted,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Abbreviation',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _muted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 80),
                        ],
                      ),
                    ),
                    // Table Body
                    ...units.map(
                      (unit) => _UnitRow(
                        unit: unit,
                        adminService: widget.adminService,
                        onAction: () => setState(() => _loadData()),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.straighten_rounded,
                color: _muted,
                size: 56,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No units yet',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add measurement units for products',
              style: GoogleFonts.inter(fontSize: 13, color: _muted),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddUnitDialog(BuildContext context) {
    final nameController = TextEditingController();
    final abbrController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.add_rounded, color: _primary, size: 24),
            ),
            const SizedBox(width: 16),
            Text(
              'Add Unit',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: _text,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(
                nameController,
                'Unit Name (e.g., Kilogram)',
                Icons.label_rounded,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                abbrController,
                'Abbreviation (e.g., kg)',
                Icons.short_text_rounded,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(color: _muted)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || abbrController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: _danger,
                    content: Text(
                      'Please fill all fields',
                      style: GoogleFonts.inter(),
                    ),
                  ),
                );
                return;
              }
              final success = await widget.adminService.createUnit(
                name: nameController.text,
                abbreviation: abbrController.text,
              );
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: success ? _primary : _danger,
                    content: Text(
                      success ? 'Unit created' : 'Failed to create unit',
                      style: GoogleFonts.inter(color: Colors.white),
                    ),
                  ),
                );
                setState(() => _loadData());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Create',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon,
  ) {
    return TextField(
      controller: controller,
      style: GoogleFonts.inter(color: _text, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: _muted, fontSize: 13),
        prefixIcon: Icon(icon, color: _muted, size: 20),
        filled: true,
        fillColor: _dark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _primary),
        ),
      ),
    );
  }
}

class _UnitRow extends StatelessWidget {
  final Map<String, dynamic> unit;
  final AdminService adminService;
  final VoidCallback onAction;

  const _UnitRow({
    required this.unit,
    required this.adminService,
    required this.onAction,
  });

  static const Color _primary = Color(0xFF10B981);
  static const Color _danger = Color(0xFFEF4444);
  static const Color _card = Color(0xFF1E293B);
  static const Color _border = Color(0xFF334155);
  static const Color _muted = Color(0xFF64748B);
  static const Color _text = Color(0xFFF1F5F9);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _border.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.straighten_rounded,
                    color: _primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  unit['name'] ?? 'Unknown',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _text,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _border.withOpacity(0.3),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                unit['abbreviation'] ?? '-',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _primary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Center(
              child: IconButton(
                onPressed: () => _confirmDelete(context),
                icon: Icon(Icons.delete_rounded, color: _danger, size: 20),
                tooltip: 'Delete',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Unit?',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _text),
        ),
        content: Text(
          'Products using this unit will need to be updated.',
          style: GoogleFonts.inter(color: _muted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: _muted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _danger,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await adminService.deleteUnit(unit['unit_id']);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: success ? _primary : _danger,
          content: Text(
            success ? 'Unit deleted' : 'Failed to delete',
            style: GoogleFonts.inter(color: Colors.white),
          ),
        ),
      );
      onAction();
    }
  }
}

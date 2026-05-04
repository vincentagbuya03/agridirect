import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/core/supabase_data_service.dart';
import '../../../shared/widgets/app_shimmer_loader.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../widgets/animated_components.dart';

class WebFarmerOrders extends StatefulWidget {
  final Function(int) onNavigate;
  final int currentIndex;

  const WebFarmerOrders({
    super.key,
    required this.onNavigate,
    required this.currentIndex,
  });

  @override
  State<WebFarmerOrders> createState() => _WebFarmerOrdersState();
}

class _WebFarmerOrdersState extends State<WebFarmerOrders> with TickerProviderStateMixin {
  late AnimationController _fadeInController;
  int _hoveredNav = -1;
  String _searchQuery = '';
  String _selectedStatus = 'ALL';
  final List<String> _statusFilters = ['ALL', 'PENDING', 'SHIPPED', 'DELIVERED', 'CANCELLED'];

  static const Color _primary = Color(0xFF16A34A);
  static const Color _dark = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _surface = Color(0xFFFAFAFA);

  @override
  void initState() {
    super.initState();
    _fadeInController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _fadeInController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: DotPatternPainter(opacity: 0.03, color: const Color(0xFF10B981)),
            ),
          ),
          Column(
            children: [
              _buildNavBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
                  child: FadeTransition(
                    opacity: _fadeInController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 32),
                        _buildOrderTable(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavBar() {
    final navItems = ['Dashboard', 'Products', 'Orders', 'Community'];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => widget.onNavigate(0),
              child: const BrandLogo(size: BrandLogoSize.medium),
            ),
          ),
          const SizedBox(width: 48),
          ...List.generate(navItems.length, (i) {
            final isActive = i == widget.currentIndex;
            final isHovered = _hoveredNav == i;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _hoveredNav = i),
                onExit: (_) => setState(() => _hoveredNav = -1),
                child: GestureDetector(
                  onTap: () => widget.onNavigate(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: isActive
                          ? _primary.withValues(alpha: 0.1)
                          : isHovered
                              ? _border.withValues(alpha: 0.5)
                              : Colors.transparent,
                    ),
                    child: Text(
                      navItems[i],
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                        color: isActive ? _primary : isHovered ? _dark : _muted,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => widget.onNavigate(4),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                  border: Border.all(color: _primary, width: 1.5),
                ),
                child: const Icon(Icons.person_rounded, color: _primary, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Order Management',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: _dark,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            // Status filters
            ...List.generate(_statusFilters.length, (index) {
              final status = _statusFilters[index];
              final isSelected = _selectedStatus == status;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(status),
                  selected: isSelected,
                  onSelected: (val) => setState(() => _selectedStatus = status),
                  selectedColor: _primary.withValues(alpha: 0.1),
                  labelStyle: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? _primary : _muted,
                  ),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: isSelected ? _primary : _border),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  showCheckmark: false,
                ),
              );
            }),
            const Spacer(),
            // Search
            Container(
              width: 300,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search order ID, customer...',
                  hintStyle: GoogleFonts.inter(color: _muted, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: _muted, size: 18),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOrderTable() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: SupabaseDataService().getFarmerOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: AppShimmerLoader()),
            );
          }

          final allOrders = snapshot.data ?? [];
          final orders = allOrders.where((o) {
            final id = o['orderId']?.toString().toLowerCase() ?? '';
            final customer = o['customerName']?.toString().toLowerCase() ?? '';
            final status = o['status']?.toString().toUpperCase() ?? '';
            
            final matchesSearch = id.contains(_searchQuery.toLowerCase()) || 
                                customer.contains(_searchQuery.toLowerCase());
            final matchesStatus = _selectedStatus == 'ALL' || status == _selectedStatus;
            
            return matchesSearch && matchesStatus;
          }).toList();

          if (orders.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(80),
              child: Center(
                child: Text('No orders match your criteria.', style: GoogleFonts.inter(color: _muted)),
              ),
            );
          }

          return Theme(
            data: Theme.of(context).copyWith(dividerColor: _border.withValues(alpha: 0.5)),
            child: DataTable(
              headingRowHeight: 64,
              dataRowMinHeight: 72,
              dataRowMaxHeight: 72,
              horizontalMargin: 24,
              columnSpacing: 24,
              columns: [
                _buildColumn('Order ID'),
                _buildColumn('Date'),
                _buildColumn('Customer'),
                _buildColumn('Items'),
                _buildColumn('Total'),
                _buildColumn('Status'),
                _buildColumn('Actions'),
              ],
              rows: orders.map((o) => _buildDataRow(o)).toList(),
            ),
          );
        },
      ),
    );
  }

  DataColumn _buildColumn(String label) {
    return DataColumn(
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: _dark,
        ),
      ),
    );
  }

  DataRow _buildDataRow(Map<String, dynamic> o) {
    final status = o['status']?.toString().toUpperCase() ?? 'PENDING';
    Color statusColor = Colors.orange;
    if (status == 'DELIVERED') statusColor = _primary;
    if (status == 'SHIPPED') statusColor = Colors.blue;
    if (status == 'CANCELLED') statusColor = Colors.red;

    return DataRow(
      cells: [
        DataCell(Text(o['orderId'] ?? '#0000', style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
        DataCell(Text(o['timeAgo'] ?? 'Recently', style: GoogleFonts.inter(fontSize: 13))),
        DataCell(
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: _primary.withValues(alpha: 0.1),
                child: Text(
                  (o['customerName'] ?? 'C')[0],
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _primary),
                ),
              ),
              const SizedBox(width: 10),
              Text(o['customerName'] ?? 'Customer', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        DataCell(
          SizedBox(
            width: 150,
            child: Text(
              o['items'] ?? 'Various items',
              style: GoogleFonts.inter(fontSize: 12, color: _muted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        DataCell(Text(o['total'] ?? '₱0.00', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: _dark))),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: statusColor),
            ),
          ),
        ),
        DataCell(
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.visibility_outlined, size: 20),
                onPressed: () {},
                tooltip: 'View Details',
              ),
              IconButton(
                icon: const Icon(Icons.check_circle_outline, size: 20, color: _primary),
                onPressed: () {},
                tooltip: 'Complete Order',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/admin_service.dart';

/// Admin Users Tab - Manage all users, verify, suspend, promote
class AdminUsersTab extends StatefulWidget {
  final AdminService adminService;

  const AdminUsersTab({
    super.key,
    required this.adminService,
  });

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  late Future<List<Map<String, dynamic>>> _usersFuture;
  final _searchController = TextEditingController();
  int _currentPage = 0;
  String _searchQuery = '';

  static const Color _primary = Color(0xFF16A34A);
  static const Color _danger = Color(0xFFEF4444);
  static const Color _darker = Color(0xFF111827);
  static const Color _cardBg = Color(0xFF1E293B);
  static const Color _surface = Color(0xFF334155);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _border = Color(0xFF334155);

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadUsers() {
    _usersFuture = widget.adminService.getAllUsers(
      page: _currentPage,
      searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
    );
  }

  void _onSearchChanged() {
    setState(() {
      _currentPage = 0;
      _searchQuery = _searchController.text;
      _loadUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      color: _darker,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'User Directory',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (!isMobile)
                  SizedBox(
                    width: 300,
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: _cardBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _border),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search users...',
                          hintStyle: GoogleFonts.plusJakartaSans(color: _muted, fontSize: 13),
                          prefixIcon: Icon(Icons.search, color: _muted, size: 20),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (isMobile) ...[
              const SizedBox(height: 16),
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search users...',
                    hintStyle: GoogleFonts.plusJakartaSans(color: _muted, fontSize: 13),
                    prefixIcon: Icon(Icons.search, color: _muted, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _usersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: _primary));
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Failed to load users',
                        style: GoogleFonts.plusJakartaSans(color: _danger)),
                  );
                }

                final users = snapshot.data ?? [];

                if (users.isEmpty) {
                  return Center(
                    child: Text('No users found',
                        style: GoogleFonts.plusJakartaSans(color: _muted)),
                  );
                }

                return Column(
                  children: [
                    if (!isMobile)
                      _UsersTable(users: users, adminService: widget.adminService)
                    else
                      Column(
                        children: [
                          for (final user in users)
                            _UserCard(
                              user: user,
                              adminService: widget.adminService,
                              onAction: _loadUsers,
                            ),
                        ],
                      ),
                    const SizedBox(height: 24),
                    // Pagination
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildPaginationBtn(
                          icon: Icons.arrow_back,
                          label: 'Previous',
                          onPressed: _currentPage > 0
                              ? () => setState(() {
                                    _currentPage--;
                                    _loadUsers();
                                  })
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: _cardBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _border),
                          ),
                          child: Text('Page ${_currentPage + 1}',
                              style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13)),
                        ),
                        const SizedBox(width: 16),
                        _buildPaginationBtn(
                          icon: Icons.arrow_forward,
                          label: 'Next',
                          onPressed: users.length >= 20
                              ? () => setState(() {
                                    _currentPage++;
                                    _loadUsers();
                                  })
                              : null,
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationBtn({
    required IconData icon,
    required String label,
    VoidCallback? onPressed,
  }) {
    final enabled = onPressed != null;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: enabled ? _cardBg : _surface.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: enabled ? _border : _surface),
        ),
        child: Row(
          children: [
            Icon(icon, color: enabled ? Colors.white : _muted, size: 16),
            const SizedBox(width: 8),
            Text(label,
                style: GoogleFonts.plusJakartaSans(
                    color: enabled ? Colors.white : _muted, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _UsersTable extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final AdminService adminService;

  static const Color _primary = Color(0xFF16A34A);
  static const Color _secondary = Color(0xFF06B6D4);
  static const Color _warning = Color(0xFFFFA500);
  static const Color _cardBg = Color(0xFF1E293B);
  static const Color _border = Color(0xFF334155);
  static const Color _muted = Color(0xFF6B7280);

  const _UsersTable({
    required this.users,
    required this.adminService,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFF111827)),
            dataRowColor: WidgetStateProperty.all(_cardBg),
            dividerThickness: 0.5,
            columns: [
              DataColumn(label: Text('Email', style: GoogleFonts.plusJakartaSans(color: _muted, fontSize: 12, fontWeight: FontWeight.w600))),
              DataColumn(label: Text('Name', style: GoogleFonts.plusJakartaSans(color: _muted, fontSize: 12, fontWeight: FontWeight.w600))),
              DataColumn(label: Text('Type', style: GoogleFonts.plusJakartaSans(color: _muted, fontSize: 12, fontWeight: FontWeight.w600))),
              DataColumn(label: Text('Status', style: GoogleFonts.plusJakartaSans(color: _muted, fontSize: 12, fontWeight: FontWeight.w600))),
              DataColumn(label: Text('Actions', style: GoogleFonts.plusJakartaSans(color: _muted, fontSize: 12, fontWeight: FontWeight.w600))),
            ],
            rows: [
              for (final user in users)
                DataRow(
                  cells: [
                    DataCell(Text(user['email'] ?? '-', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13))),
                    DataCell(Text(user['name'] ?? '-', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getUserTypeColor(user).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _getUserTypeColor(user).withOpacity(0.3)),
                        ),
                        child: Text(
                          _getUserTypeLabel(user),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _getUserTypeColor(user),
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('Active',
                            style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: _primary)),
                      ),
                    ),
                    DataCell(
                      Row(
                        children: [
                          _buildActionIcon(Icons.edit, _secondary, () => _showUserActions(context, user)),
                          const SizedBox(width: 4),
                          _buildActionIcon(Icons.block, const Color(0xFFEF4444), () {}),
                        ],
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

  Widget _buildActionIcon(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  String _getUserTypeLabel(Map<String, dynamic> user) {
    final roles = (user['roles'] as String?) ?? '';
    if (roles.contains('admin')) return 'Admin';
    if (roles.contains('seller')) return 'Farmer';
    return 'Customer';
  }

  Color _getUserTypeColor(Map<String, dynamic> user) {
    final roles = (user['roles'] as String?) ?? '';
    if (roles.contains('admin')) return _primary;
    if (roles.contains('seller')) return _warning;
    return _secondary;
  }

  void _showUserActions(BuildContext context, Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'User Actions: ${user['name']}',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogTile(Icons.verified, 'Verify User', _primary, () {
              Navigator.pop(context);
              adminService.verifyUser(user['user_id']);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: _primary,
                  content: Text('User verified', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF111827))),
                ),
              );
            }),
            _buildDialogTile(Icons.block, 'Suspend User', const Color(0xFFEF4444), () {
              Navigator.pop(context);
              _showSuspendDialog(context, user);
            }),
            if (!((user['roles'] as String?) ?? '').contains('admin'))
              _buildDialogTile(Icons.admin_panel_settings, 'Promote to Admin', _secondary, () {
                Navigator.pop(context);
                adminService.promoteToAdmin(user['user_id']);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: _primary,
                    content: Text('User promoted to admin', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF111827))),
                  ),
                );
              }),
            if (((user['roles'] as String?) ?? '').contains('admin'))
              _buildDialogTile(Icons.remove_moderator, 'Remove Admin Role', _warning, () {
                Navigator.pop(context);
                adminService.removeAdminRole(user['user_id']);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: _warning,
                    content: Text('Admin role removed', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF111827))),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogTile(IconData icon, String title, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      hoverColor: const Color(0xFF334155),
    );
  }

  void _showSuspendDialog(BuildContext context, Map<String, dynamic> user) {
    final reasonController = TextEditingController();
    final daysController = TextEditingController(text: '7');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Suspend User', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: reasonController,
              style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Reason for suspension',
                labelStyle: GoogleFonts.plusJakartaSans(color: _muted, fontSize: 13),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF16A34A)),
                ),
                filled: true,
                fillColor: const Color(0xFF111827),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: daysController,
              style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Days to suspend (0 for permanent)',
                labelStyle: GoogleFonts.plusJakartaSans(color: _muted, fontSize: 13),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF16A34A)),
                ),
                filled: true,
                fillColor: const Color(0xFF111827),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: _muted)),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = reasonController.text;
              final days = int.tryParse(daysController.text) ?? 7;
              adminService.suspendUser(
                userId: user['user_id'],
                reason: reason,
                adminId: '',
                isPermanent: days == 0,
                daysToExpire: days == 0 ? null : days,
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFFEF4444),
                  content: Text('User suspended', style: GoogleFonts.plusJakartaSans(color: Colors.white)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Suspend', style: GoogleFonts.plusJakartaSans()),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final AdminService adminService;
  final VoidCallback onAction;

  static const Color _primary = Color(0xFF16A34A);
  static const Color _secondary = Color(0xFF06B6D4);
  static const Color _warning = Color(0xFFFFA500);
  static const Color _cardBg = Color(0xFF1E293B);
  static const Color _border = Color(0xFF334155);
  static const Color _muted = Color(0xFF6B7280);

  const _UserCard({
    required this.user,
    required this.adminService,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user['name'] ?? '-',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(user['email'] ?? '-',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _muted)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getUserTypeColor().withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _getUserTypeColor().withOpacity(0.3)),
                ),
                child: Text(
                  _getUserTypeLabel(),
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: _getUserTypeColor()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => adminService.verifyUser(user['user_id']),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: const Color(0xFF111827),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Verify', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _muted,
                    side: const BorderSide(color: Color(0xFF334155)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Suspend', style: GoogleFonts.plusJakartaSans(fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getUserTypeLabel() {
    final roles = (user['roles'] as String?) ?? '';
    if (roles.contains('admin')) return 'Admin';
    if (roles.contains('seller')) return 'Farmer';
    return 'Customer';
  }

  Color _getUserTypeColor() {
    final roles = (user['roles'] as String?) ?? '';
    if (roles.contains('admin')) return _primary;
    if (roles.contains('seller')) return _warning;
    return _secondary;
  }
}

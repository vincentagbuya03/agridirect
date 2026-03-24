import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/admin_service.dart';

/// Admin Users Tab - Manage all platform users (Modern White)
class AdminUsersTab extends StatefulWidget {
  final AdminService adminService;

  const AdminUsersTab({super.key, required this.adminService});

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  late Future<List<Map<String, dynamic>>> _usersFuture;
  final _searchController = TextEditingController();
  int _currentPage = 0;
  String _searchQuery = '';

  // Modern light theme colors
  static const Color _primary = Color(0xFF10B981);
  static const Color _background = Color(0xFFFAFAFA);
  static const Color _card = Colors.white;
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _muted = Color(0xFF64748B);
  static const Color _text = Color(0xFF1E293B);

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
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
    if (_searchQuery != _searchController.text) {
      setState(() {
        _currentPage = 0;
        _searchQuery = _searchController.text;
        _loadUsers();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _background,
      child: Column(
        children: [
          // Standard modern header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User Management',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _text,
                      ),
                    ),
                    Text(
                      'Search and manage platform customers and accounts',
                      style: GoogleFonts.inter(fontSize: 13, color: _muted),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _loadUsers()),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _text,
                    elevation: 0,
                    side: const BorderSide(color: _border),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Search Card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.inter(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search by name or email...',
                hintStyle: GoogleFonts.inter(color: _muted),
                prefixIcon: const Icon(Icons.search_rounded, color: _primary),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () => _searchController.clear(),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF10B981)),
                ),
                fillColor: const Color(0xFFFAFAFA),
                filled: true,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _usersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _primary),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading users',
                      style: GoogleFonts.inter(color: Colors.red),
                    ),
                  );
                }

                final users = snapshot.data ?? [];

                if (users.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_search_rounded,
                          size: 64,
                          color: _muted.withOpacity(0.2),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No users found matching your search',
                          style: GoogleFonts.inter(
                            color: _muted,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  itemCount: users.length,
                  itemBuilder: (context, index) =>
                      _UserCard(user: users[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final role = user['role'] ?? 'CUSTOMER';
    final isAdmin = role?.toUpperCase() == 'ADMIN';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor:
                (isAdmin ? const Color(0xFF3B82F6) : const Color(0xFF10B981))
                    .withOpacity(0.1),
            child: Icon(
              isAdmin
                  ? Icons.admin_panel_settings_rounded
                  : Icons.person_rounded,
              color: isAdmin
                  ? const Color(0xFF3B82F6)
                  : const Color(0xFF10B981),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['name'] ?? 'Guest User',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  user['email'] ?? 'no@email.com',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color:
                  (isAdmin ? const Color(0xFF3B82F6) : const Color(0xFF10B981))
                      .withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              role.toUpperCase(),
              style: GoogleFonts.inter(
                color: isAdmin
                    ? const Color(0xFF3B82F6)
                    : const Color(0xFF10B981),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(
              Icons.more_horiz_rounded,
              color: Color(0xFF94A3B8),
            ),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

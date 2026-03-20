import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/services/admin/admin_service.dart';

/// Admin Farmer Registrations Tab — review, approve, or reject farmer applications
class AdminFarmerRegistrationsTab extends StatefulWidget {
  final AdminService adminService;

  const AdminFarmerRegistrationsTab({
    super.key,
    required this.adminService,
  });

  @override
  State<AdminFarmerRegistrationsTab> createState() =>
      _AdminFarmerRegistrationsTabState();
}

class _AdminFarmerRegistrationsTabState
    extends State<AdminFarmerRegistrationsTab> {
  // ── OLED-grade colour palette ────────────────────────────────────────────────
  static const Color _bg       = Color(0xFF090E1A); // near-black base
  static const Color _card     = Color(0xFF131A2B); // raised surface
  static const Color _elevated = Color(0xFF1A2438); // dialog / hover surface
  static const Color _border   = Color(0xFF1F2D40); // subtle border
  static const Color _surface  = Color(0xFF263245); // input/chip bg
  static const Color _muted    = Color(0xFF5A6980); // dimmed text
  static const Color _text     = Color(0xFFF0F4FF); // primary text
  static const Color _subtext  = Color(0xFF8B9AB3); // secondary text
  static const Color _green    = Color(0xFF22C55E); // CTA / approve
  static const Color _red      = Color(0xFFEF4444); // danger / reject
  static const Color _amber    = Color(0xFFF59E0B); // pending
  static const Color _greenDim = Color(0xFF14532D); // green tinted bg
  static const Color _redDim   = Color(0xFF450A0A); // red tinted bg
  static const Color _amberDim = Color(0xFF451A03); // amber tinted bg

  // ── state ────────────────────────────────────────────────────────────────────
  late Future<List<Map<String, dynamic>>> _future;
  String _filterStatus = 'all';
  String _searchQuery  = '';
  final _searchCtrl    = TextEditingController();
  final Set<String> _expanded  = {};
  final Set<String> _loadingIds = {}; // cards being processed

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(
      () => setState(() => _searchQuery = _searchCtrl.text.toLowerCase()),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _load() => setState(() {
        _future = widget.adminService.getFarmerRegistrations(
          status: _filterStatus == 'all' ? null : _filterStatus,
        );
      });

  // ── helpers ──────────────────────────────────────────────────────────────────

  String _name(Map<String, dynamic> r) {
    final u = r['users'];
    return u is Map ? ((u['name'] as String?) ?? 'Unknown') : 'Unknown';
  }

  String _email(Map<String, dynamic> r) {
    final u = r['users'];
    return u is Map ? ((u['email'] as String?) ?? '—') : '—';
  }

  String _initials(String name) {
    final p = name.trim().split(' ');
    if (p.length >= 2) return '${p[0][0]}${p[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String _fmt(String? iso) {
    if (iso == null) return '—';
    try {
      final d = DateTime.parse(iso);
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${m[d.month - 1]} ${d.day}, ${d.year}';
    } catch (_) {
      return iso;
    }
  }

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> all) {
    if (_searchQuery.isEmpty) return all;
    return all.where((r) {
      final n = _name(r).toLowerCase();
      final e = _email(r).toLowerCase();
      final a = ((r['residential_address'] ?? '') as String).toLowerCase();
      return n.contains(_searchQuery) || e.contains(_searchQuery) || a.contains(_searchQuery);
    }).toList();
  }

  // ── build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (ctx, snap) {
          final all = snap.data ?? [];
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PageHeader(all: all, onRefresh: _load, amber: _amber, amberDim: _amberDim, subtext: _subtext, text: _text, surface: _surface),
                      const SizedBox(height: 24),
                      _StatsRow(all: all, card: _card, border: _border, green: _green, red: _red, amber: _amber, muted: _muted, text: _text, subtext: _subtext, greenDim: _greenDim, redDim: _redDim, amberDim: _amberDim),
                      const SizedBox(height: 20),
                      _FilterBar(
                        controller: _searchCtrl,
                        activeFilter: _filterStatus,
                        card: _card, border: _border, surface: _surface, muted: _muted, text: _text, subtext: _subtext, green: _green,
                        onFilter: (f) { setState(() => _filterStatus = f); _load(); },
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              if (snap.connectionState == ConnectionState.waiting)
                _SkeletonSliver(card: _card, surface: _surface, border: _border)
              else if (snap.hasError)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  sliver: SliverToBoxAdapter(child: _ErrorBanner(error: snap.error.toString(), red: _red)),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                  sliver: _filtered(all).isEmpty
                      ? SliverToBoxAdapter(child: _EmptyState(muted: _muted, card: _card, text: _text, subtext: _subtext))
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (_, i) => _RegistrationCard(
                              key: ValueKey(_filtered(all)[i]['registration_id']),
                              reg: _filtered(all)[i],
                              isExpanded: _expanded.contains(_filtered(all)[i]['registration_id'] ?? ''),
                              isLoading: _loadingIds.contains(_filtered(all)[i]['registration_id'] ?? ''),
                              onToggleExpand: (id) => setState(() => _expanded.contains(id) ? _expanded.remove(id) : _expanded.add(id)),
                              onApprove: _onApprove,
                              onReject: _onReject,
                              name: _name(_filtered(all)[i]),
                              email: _email(_filtered(all)[i]),
                              initials: _initials(_name(_filtered(all)[i])),
                              formatDate: _fmt,
                              // colors
                              bg: _bg, card: _card, elevated: _elevated, border: _border,
                              surface: _surface, muted: _muted, text: _text, subtext: _subtext,
                              green: _green, red: _red, amber: _amber,
                              greenDim: _greenDim, redDim: _redDim, amberDim: _amberDim,
                            ),
                            childCount: _filtered(all).length,
                          ),
                        ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ── actions ──────────────────────────────────────────────────────────────────

  Future<void> _onApprove(Map<String, dynamic> reg) async {
    final regId = reg['registration_id'] as String?;
    final userId = reg['user_id'] as String?;
    if (regId == null || userId == null) return;

    final confirmed = await _approveDialog(context, _name(reg));
    if (!confirmed || !mounted) return;

    setState(() => _loadingIds.add(regId));
    final ok = await widget.adminService.approveFarmerRegistration(regId, userId);
    if (!mounted) return;
    setState(() => _loadingIds.remove(regId));

    _snack(
      ok ? '${_name(reg)} has been approved as a farmer.' : widget.adminService.errorMessage ?? 'Failed to approve.',
      ok ? _green : _red,
    );
    if (ok) _load();
  }

  Future<void> _onReject(Map<String, dynamic> reg) async {
    final regId = reg['registration_id'] as String?;
    final userId = reg['user_id'] as String?;
    if (regId == null || userId == null) return;

    final reason = await _rejectDialog(context, _name(reg));
    if (reason == null || !mounted) return;

    setState(() => _loadingIds.add(regId));
    final ok = await widget.adminService.rejectFarmerRegistration(regId, userId, reason: reason.isEmpty ? null : reason);
    if (!mounted) return;
    setState(() => _loadingIds.remove(regId));

    _snack(
      ok ? 'Application rejected.' : widget.adminService.errorMessage ?? 'Failed to reject.',
      ok ? _amber : _red,
    );
    if (ok) _load();
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Container(width: 4, height: 20, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 12),
        Expanded(child: Text(msg, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _text))),
      ]),
      backgroundColor: _elevated,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: color.withAlpha(80))),
      duration: const Duration(seconds: 3),
    ));
  }

  // ── dialogs ──────────────────────────────────────────────────────────────────

  static Future<bool> _approveDialog(BuildContext context, String name) async {
    const green = Color(0xFF22C55E);
    const card  = Color(0xFF131A2B);
    const elevated = Color(0xFF1A2438);
    const text  = Color(0xFFF0F4FF);
    const sub   = Color(0xFF8B9AB3);
    const muted = Color(0xFF5A6980);

    final res = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withAlpha(160),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: green.withAlpha(80)),
            boxShadow: [BoxShadow(color: green.withAlpha(30), blurRadius: 40, spreadRadius: 0)],
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: elevated, shape: BoxShape.circle,
                    border: Border.all(color: green.withAlpha(100))),
                  child: const Icon(Icons.check_circle_outline_rounded, color: green, size: 24),
                ),
                const SizedBox(width: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Approve Application', style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.bold, color: text)),
                  Text('Grant seller access', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: sub)),
                ]),
              ]),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: elevated, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF1F2D40))),
                child: Text(
                  '$name will be granted farmer/seller access and can start listing products on AgriDirect.',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, color: sub, height: 1.6),
                ),
              ),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('Cancel', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: muted)),
                ),
                const SizedBox(width: 8),
                _GlowButton(
                  label: 'Approve',
                  icon: Icons.check_rounded,
                  color: green,
                  onTap: () => Navigator.pop(ctx, true),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    return res ?? false;
  }

  static Future<String?> _rejectDialog(BuildContext context, String name) async {
    const red  = Color(0xFFEF4444);
    const card = Color(0xFF131A2B);
    const elevated = Color(0xFF1A2438);
    const text  = Color(0xFFF0F4FF);
    const sub   = Color(0xFF8B9AB3);
    const muted = Color(0xFF5A6980);
    const surface = Color(0xFF263245);
    const border  = Color(0xFF1F2D40);

    final ctrl = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withAlpha(160),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: red.withAlpha(80)),
            boxShadow: [BoxShadow(color: red.withAlpha(20), blurRadius: 40)],
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: elevated, shape: BoxShape.circle,
                    border: Border.all(color: red.withAlpha(100))),
                  child: const Icon(Icons.block_rounded, color: red, size: 24),
                ),
                const SizedBox(width: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Reject Application', style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.bold, color: text)),
                  Text('This action cannot be undone', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: sub)),
                ]),
              ]),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: elevated, borderRadius: BorderRadius.circular(10), border: Border.all(color: border)),
                child: Text(
                  "You are rejecting $name's farmer registration. They will not be granted seller access.",
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, color: sub, height: 1.6),
                ),
              ),
              const SizedBox(height: 16),
              Text('Reason for rejection', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: muted, letterSpacing: 0.4)),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                maxLines: 3,
                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: text),
                decoration: InputDecoration(
                  hintText: 'e.g. Incomplete documents, blurry face photo…',
                  hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted),
                  filled: true,
                  fillColor: surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: red.withAlpha(180), width: 1.5)),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: Text('Cancel', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: muted)),
                ),
                const SizedBox(width: 8),
                _GlowButton(
                  label: 'Reject Application',
                  icon: Icons.block_rounded,
                  color: red,
                  onTap: () => Navigator.pop(ctx, ctrl.text),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    ctrl.dispose();
    return res;
  }
}

// ── Sub-widgets ─────────────────────────────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  final List<Map<String, dynamic>> all;
  final VoidCallback onRefresh;
  final Color amber, amberDim, subtext, text, surface;

  const _PageHeader({
    required this.all, required this.onRefresh,
    required this.amber, required this.amberDim, required this.subtext, required this.text, required this.surface,
  });

  @override
  Widget build(BuildContext context) {
    final pending = all.where((r) => r['status'] == 'pending').length;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Farmer Applications',
            style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.bold, color: text, letterSpacing: -0.3)),
          const SizedBox(height: 5),
          Text('Review, approve, or reject incoming farmer registrations',
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: subtext)),
        ]),
        const Spacer(),
        if (pending > 0) ...[
          _PendingPill(count: pending, amber: amber, amberDim: amberDim),
          const SizedBox(width: 12),
        ],
        _IconBtn(icon: Icons.refresh_rounded, surface: surface, onTap: onRefresh),
      ],
    );
  }
}

class _PendingPill extends StatelessWidget {
  final int count;
  final Color amber, amberDim;
  const _PendingPill({required this.count, required this.amber, required this.amberDim});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: amberDim.withAlpha(180),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: amber.withAlpha(120)),
      ),
      child: Row(children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: amber, shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: amber.withAlpha(180), blurRadius: 6)])),
        const SizedBox(width: 8),
        Text('$count awaiting review',
          style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: amber)),
      ]),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color surface;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.surface, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(padding: const EdgeInsets.all(10), child: Icon(icon, color: Colors.white70, size: 18)),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final List<Map<String, dynamic>> all;
  final Color card, border, green, red, amber, muted, text, subtext, greenDim, redDim, amberDim;

  const _StatsRow({required this.all, required this.card, required this.border,
    required this.green, required this.red, required this.amber, required this.muted,
    required this.text, required this.subtext, required this.greenDim, required this.redDim, required this.amberDim});

  @override
  Widget build(BuildContext context) {
    final total    = all.length;
    final pending  = all.where((r) => r['status'] == 'pending').length;
    final approved = all.where((r) => r['status'] == 'approved').length;
    final rejected = all.where((r) => r['status'] == 'rejected').length;

    return Row(children: [
      _StatTile(label: 'Total', count: total, icon: Icons.assignment_outlined,
        accent: const Color(0xFF60A5FA), accentDim: const Color(0xFF1E3A5F),
        card: card, border: border, muted: muted, text: text),
      const SizedBox(width: 12),
      _StatTile(label: 'Pending', count: pending, icon: Icons.hourglass_top_rounded,
        accent: amber, accentDim: amberDim, card: card, border: border, muted: muted, text: text),
      const SizedBox(width: 12),
      _StatTile(label: 'Approved', count: approved, icon: Icons.verified_rounded,
        accent: green, accentDim: greenDim, card: card, border: border, muted: muted, text: text),
      const SizedBox(width: 12),
      _StatTile(label: 'Rejected', count: rejected, icon: Icons.block_rounded,
        accent: red, accentDim: redDim, card: card, border: border, muted: muted, text: text),
    ]);
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color accent, accentDim, card, border, muted, text;

  const _StatTile({
    required this.label, required this.count, required this.icon,
    required this.accent, required this.accentDim, required this.card,
    required this.border, required this.muted, required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(60), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentDim.withAlpha(200),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accent.withAlpha(60)),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(count.toString(),
              style: GoogleFonts.plusJakartaSans(fontSize: 26, fontWeight: FontWeight.bold, color: text, height: 1)),
            const SizedBox(height: 3),
            Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted)),
          ]),
        ]),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final TextEditingController controller;
  final String activeFilter;
  final void Function(String) onFilter;
  final Color card, border, surface, muted, text, subtext, green;

  const _FilterBar({
    required this.controller, required this.activeFilter, required this.onFilter,
    required this.card, required this.border, required this.surface,
    required this.muted, required this.text, required this.subtext, required this.green,
  });

  @override
  Widget build(BuildContext context) {
    const filters = [
      ('all', 'All'),
      ('pending', 'Pending'),
      ('approved', 'Approved'),
      ('rejected', 'Rejected'),
    ];

    return Row(children: [
      Expanded(
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border),
          ),
          child: TextField(
            controller: controller,
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: text),
            decoration: InputDecoration(
              hintText: 'Search by name, email, or location…',
              hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: muted),
              prefixIcon: Icon(Icons.search_rounded, color: muted, size: 18),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            ),
          ),
        ),
      ),
      const SizedBox(width: 14),
      ...filters.map((f) {
        final active = activeFilter == f.$1;
        return Padding(
          padding: const EdgeInsets.only(left: 6),
          child: GestureDetector(
            onTap: () => onFilter(f.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: active ? green : surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: active ? green : border),
                boxShadow: active ? [BoxShadow(color: green.withAlpha(60), blurRadius: 10)] : [],
              ),
              child: Text(f.$2,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                  color: active ? Colors.black : subtext,
                )),
            ),
          ),
        );
      }),
    ]);
  }
}

class _RegistrationCard extends StatelessWidget {
  final Map<String, dynamic> reg;
  final bool isExpanded, isLoading;
  final void Function(String id) onToggleExpand;
  final Future<void> Function(Map<String, dynamic>) onApprove, onReject;
  final String name, email, initials;
  final String Function(String?) formatDate;
  final Color bg, card, elevated, border, surface, muted, text, subtext;
  final Color green, red, amber, greenDim, redDim, amberDim;

  const _RegistrationCard({
    super.key,
    required this.reg, required this.isExpanded, required this.isLoading,
    required this.onToggleExpand, required this.onApprove, required this.onReject,
    required this.name, required this.email, required this.initials, required this.formatDate,
    required this.bg, required this.card, required this.elevated, required this.border,
    required this.surface, required this.muted, required this.text, required this.subtext,
    required this.green, required this.red, required this.amber,
    required this.greenDim, required this.redDim, required this.amberDim,
  });

  @override
  Widget build(BuildContext context) {
    final id       = (reg['registration_id'] as String?) ?? '';
    final status   = (reg['status'] as String?) ?? 'pending';
    final address  = (reg['residential_address'] as String?) ?? '—';
    final exp      = reg['years_of_experience'];
    final birth    = formatDate(reg['birth_date'] as String?);
    final applied  = formatDate(reg['created_at'] as String?);
    final history  = (reg['farming_history'] as String?) ?? '—';
    final cert     = reg['certification_accepted'] == true;
    final faceUrl  = reg['face_photo_path'] as String?;
    final idUrl    = reg['valid_id_path'] as String?;
    final isPending = status == 'pending';

    Color accent = status == 'approved' ? green : status == 'rejected' ? red : amber;
    Color accentDim = status == 'approved' ? greenDim : status == 'rejected' ? redDim : amberDim;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withAlpha(isPending ? 100 : 60)),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(50), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Stack(
        children: [
          // Left accent stripe
          Positioned(
            left: 0, top: 12, bottom: 12,
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [BoxShadow(color: accent.withAlpha(120), blurRadius: 8)],
              ),
            ),
          ),
          Column(
            children: [
              // ── card body ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    _Avatar(initials: initials, accent: accent, accentDim: accentDim),
                    const SizedBox(width: 16),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Text(name, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: text)),
                                  if (cert) ...[
                                    const SizedBox(width: 8),
                                    _Pill('Certified', green, greenDim),
                                  ],
                                ]),
                                const SizedBox(height: 3),
                                Text(email, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: muted)),
                              ]),
                            ),
                            const SizedBox(width: 12),
                            _StatusBadge(status: status, green: green, red: red, amber: amber),
                          ]),
                          const SizedBox(height: 12),
                          Wrap(spacing: 8, runSpacing: 6, children: [
                            _Chip(Icons.location_on_outlined, address, surface, muted, text),
                            if (exp != null) _Chip(Icons.work_history_outlined, '$exp yrs exp', surface, muted, text),
                            _Chip(Icons.cake_outlined, 'Born $birth', surface, muted, text),
                            _Chip(Icons.calendar_today_outlined, 'Applied $applied', surface, muted, text),
                          ]),
                        ],
                      ),
                    ),
                    // Approve / Reject buttons
                    if (isPending) ...[
                      const SizedBox(width: 16),
                      if (isLoading)
                        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: accent, strokeWidth: 2))
                      else
                        Column(
                          children: [
                            _GlowButton(label: 'Approve', icon: Icons.check_rounded, color: green, onTap: () => onApprove(reg)),
                            const SizedBox(height: 8),
                            _OutlineButton(label: 'Reject', icon: Icons.close_rounded, color: red, onTap: () => onReject(reg)),
                          ],
                        ),
                    ],
                  ],
                ),
              ),
              // ── expand toggle ──
              GestureDetector(
                onTap: () => onToggleExpand(id),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: border, width: 1)),
                    color: isExpanded ? elevated.withAlpha(120) : Colors.transparent,
                    borderRadius: isExpanded ? null : const BorderRadius.vertical(bottom: Radius.circular(16)),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(
                      isExpanded ? 'Collapse details' : 'View full details',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w500, color: muted),
                    ),
                    const SizedBox(width: 4),
                    Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: muted, size: 15),
                  ]),
                ),
              ),
              // ── expanded panel ──
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                child: isExpanded
                    ? _DetailsPanel(
                        history: history, faceUrl: faceUrl, idUrl: idUrl,
                        bg: bg, elevated: elevated, border: border, muted: muted, text: text, subtext: subtext, green: green)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String initials;
  final Color accent, accentDim;
  const _Avatar({required this.initials, required this.accent, required this.accentDim});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50, height: 50,
      decoration: BoxDecoration(
        color: accentDim.withAlpha(200),
        shape: BoxShape.circle,
        border: Border.all(color: accent.withAlpha(140), width: 1.5),
        boxShadow: [BoxShadow(color: accent.withAlpha(50), blurRadius: 10)],
      ),
      alignment: Alignment.center,
      child: Text(initials,
        style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: accent)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final Color green, red, amber;
  const _StatusBadge({required this.status, required this.green, required this.red, required this.amber});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    final IconData icon;
    switch (status) {
      case 'approved': color = green; label = 'Approved'; icon = Icons.verified_rounded; break;
      case 'rejected': color = red;   label = 'Rejected'; icon = Icons.block_rounded;   break;
      default:         color = amber; label = 'Pending';  icon = Icons.hourglass_top_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 11),
        const SizedBox(width: 5),
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color, dim;
  const _Pill(this.label, this.color, this.dim);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: dim.withAlpha(200), borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withAlpha(80))),
    child: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
  );
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color surface, muted, text;
  const _Chip(this.icon, this.label, this.surface, this.muted, this.text);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: surface.withAlpha(140), borderRadius: BorderRadius.circular(6)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: muted, size: 11),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: text.withAlpha(200))),
    ]),
  );
}

class _DetailsPanel extends StatelessWidget {
  final String history;
  final String? faceUrl, idUrl;
  final Color bg, elevated, border, muted, text, subtext, green;

  const _DetailsPanel({
    required this.history, required this.faceUrl, required this.idUrl,
    required this.bg, required this.elevated, required this.border,
    required this.muted, required this.text, required this.subtext, required this.green,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: BoxDecoration(
        color: bg.withAlpha(200),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(top: BorderSide(color: border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('FARMING HISTORY', muted: muted),
          const SizedBox(height: 8),
          Text(history, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: subtext, height: 1.65)),
          const SizedBox(height: 16),
          _SectionLabel('SUBMITTED DOCUMENTS', muted: muted),
          const SizedBox(height: 10),
          Row(children: [
            _DocChip('Face Photo', faceUrl, elevated: elevated, border: border, muted: muted, green: green),
            const SizedBox(width: 10),
            _DocChip('Valid ID', idUrl, elevated: elevated, border: border, muted: muted, green: green),
          ]),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color muted;
  const _SectionLabel(this.label, {required this.muted});

  @override
  Widget build(BuildContext context) => Text(label,
    style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: muted, letterSpacing: 0.8));
}

class _DocChip extends StatelessWidget {
  final String label;
  final String? path;
  final Color elevated, border, muted, green;
  const _DocChip(this.label, this.path, {required this.elevated, required this.border, required this.muted, required this.green});

  @override
  Widget build(BuildContext context) {
    final has = path != null && path!.isNotEmpty;
    final isUrl = has && path!.startsWith('http');
    final color = has ? green : muted;

    return GestureDetector(
      onTap: isUrl ? () => _showImagePreview(context, path!) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: has ? green.withAlpha(15) : elevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: has ? green.withAlpha(80) : border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(has ? Icons.task_alt_rounded : Icons.radio_button_unchecked_rounded, color: color, size: 13),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          const SizedBox(width: 4),
          if (isUrl)
            Row(children: [
              Text('· View', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: color.withAlpha(200), fontWeight: FontWeight.w500)),
              const SizedBox(width: 3),
              Icon(Icons.open_in_new, size: 10, color: color.withAlpha(200)),
            ])
          else
            Text(has ? '· Uploaded' : '· Not provided',
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: color.withAlpha(has ? 200 : 140))),
        ]),
      ),
    );
  }

  void _showImagePreview(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          decoration: BoxDecoration(
            color: const Color(0xFF131A2B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1F2D40)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFFF0F4FF))),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, color: Color(0xFF8B9AB3)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  color: const Color(0xFF090E1A),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (ctx, err, stack) => Center(
                      child: Text('Failed to load image',
                        style: GoogleFonts.plusJakartaSans(color: const Color(0xFF8B9AB3)),
                      ),
                    ),
                    loadingBuilder: (ctx, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / (loadingProgress.expectedTotalBytes ?? 1)
                              : null,
                          color: green,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlowButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _GlowButton({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: color.withAlpha(100), blurRadius: 12, offset: const Offset(0, 3))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.black, size: 14),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black)),
        ]),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _OutlineButton({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(120)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }
}

class _SkeletonSliver extends StatefulWidget {
  final Color card, surface, border;
  const _SkeletonSliver({required this.card, required this.surface, required this.border});

  @override
  State<_SkeletonSliver> createState() => _SkeletonSliverState();
}

class _SkeletonSliverState extends State<_SkeletonSliver> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _shimmer = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, i) => AnimatedBuilder(
            animation: _shimmer,
            builder: (_, _) => _SkeletonCard(
              shimmerValue: _shimmer.value,
              card: widget.card, surface: widget.surface, border: widget.border,
            ),
          ),
          childCount: 4,
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  final double shimmerValue;
  final Color card, surface, border;
  const _SkeletonCard({required this.shimmerValue, required this.card, required this.surface, required this.border});

  Widget _box(double w, double h) => Container(
    width: w, height: h,
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: Color.lerp(surface, const Color(0xFF334155), shimmerValue),
      borderRadius: BorderRadius.circular(6),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card, borderRadius: BorderRadius.circular(16), border: Border.all(color: border),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 50, height: 50,
          decoration: BoxDecoration(
            color: Color.lerp(surface, const Color(0xFF334155), shimmerValue),
            shape: BoxShape.circle,
          )),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _box(160, 14),
          _box(220, 11),
          const SizedBox(height: 6),
          Row(children: [_box(90, 22), const SizedBox(width: 8), _box(80, 22)]),
        ])),
      ]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Color muted, card, text, subtext;
  const _EmptyState({required this.muted, required this.card, required this.text, required this.subtext});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 70),
      alignment: Alignment.center,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(color: card, shape: BoxShape.circle,
            border: Border.all(color: muted.withAlpha(60))),
          child: Icon(Icons.assignment_outlined, color: muted, size: 36),
        ),
        const SizedBox(height: 18),
        Text('No applications found',
          style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.bold, color: text)),
        const SizedBox(height: 6),
        Text('No farmer registrations match your current filter.',
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: subtext)),
      ]),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String error;
  final Color red;
  const _ErrorBanner({required this.error, required this.red});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: red.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: red.withAlpha(80)),
      ),
      child: Row(children: [
        Icon(Icons.error_outline_rounded, color: red, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(error, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.white70))),
      ]),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/auth/user_address_model.dart';
import '../../../shared/services/user/user_service.dart';
import '../../../shared/services/auth/auth_service.dart';
import '../../../shared/router/app_routes.dart';
import '../../constants/web_design_tokens.dart';

/// Database-backed modal dialog for managing and selecting delivery addresses for Web
class WebLocationModal extends StatefulWidget {
  final UserAddress? currentAddress;
  final ValueChanged<UserAddress?>? onAddressUpdated;
  final String? currentLocation;
  final ValueChanged<String>? onLocationSelected;

  const WebLocationModal({
    super.key,
    this.currentAddress,
    this.onAddressUpdated,
    this.currentLocation,
    this.onLocationSelected,
  });

  static Future<void> show(
    BuildContext context, {
    UserAddress? currentAddress,
    ValueChanged<UserAddress?>? onAddressUpdated,
    String? currentLocation,
    ValueChanged<String>? onLocationSelected,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => WebLocationModal(
        currentAddress: currentAddress,
        onAddressUpdated: onAddressUpdated,
        currentLocation: currentLocation,
        onLocationSelected: onLocationSelected,
      ),
    );
  }

  @override
  State<WebLocationModal> createState() => _WebLocationModalState();
}

class _WebLocationModalState extends State<WebLocationModal> {
  final UserService _userService = UserService();
  final AuthService _authService = AuthService();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _showAddForm = false;
  List<UserAddress> _savedAddresses = [];
  UserAddress? _selectedAddress;

  // Add address form controllers
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _labelCtrl = TextEditingController(text: 'Home');
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _streetCtrl = TextEditingController();
  final TextEditingController _barangayCtrl = TextEditingController(text: 'Brgy. Roxas');
  final TextEditingController _cityCtrl = TextEditingController(text: 'San Carlos City');
  final TextEditingController _provinceCtrl = TextEditingController(text: 'Pangasinan');
  final TextEditingController _zipCtrl = TextEditingController(text: '2420');
  bool _setAsDefault = true;

  // Search in guest/quick picker
  final TextEditingController _searchCtrl = TextEditingController();
  List<String> _filteredBarangays = [];

  static const List<String> _sanCarlosBarangays = [
    'Brgy. Roxas',
    'Brgy. Baleyadaan',
    'Brgy. Tarece',
    'Brgy. Malabago',
    'Brgy. Talence',
    'Brgy. Tandoc',
    'Brgy. Pagal',
    'Brgy. Palaming',
    'Brgy. Ilang',
    'Brgy. Perez',
    'Brgy. Bogaoan',
    'Brgy. Caoayan-Kiling',
    'Brgy. Poblacion',
  ];

  @override
  void initState() {
    super.initState();
    _filteredBarangays = List.from(_sanCarlosBarangays);
    _searchCtrl.addListener(_onSearchChanged);

    _nameCtrl.text = _authService.userName;
    _loadDatabaseAddresses();
  }

  void _onSearchChanged() {
    final query = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredBarangays = List.from(_sanCarlosBarangays);
      } else {
        _filteredBarangays = _sanCarlosBarangays
            .where((b) => b.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _labelCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _streetCtrl.dispose();
    _barangayCtrl.dispose();
    _cityCtrl.dispose();
    _provinceCtrl.dispose();
    _zipCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDatabaseAddresses() async {
    if (!_authService.isLoggedIn) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final addresses = await _userService.getAllUserAddresses();
      if (mounted) {
        setState(() {
          _savedAddresses = addresses;
          if (widget.currentAddress != null) {
            _selectedAddress = addresses.firstWhere(
              (a) => a.addressId == widget.currentAddress!.addressId,
              orElse: () => addresses.isNotEmpty ? addresses.first : widget.currentAddress!,
            );
          } else if (addresses.isNotEmpty) {
            _selectedAddress = addresses.firstWhere(
              (a) => a.isDefault,
              orElse: () => addresses.first,
            );
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading database addresses: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectAndSaveDefault(UserAddress address) async {
    setState(() => _isSaving = true);
    try {
      await _userService.setDefaultAddress(address.addressId);
      final updated = address.copyWith(isDefault: true);
      widget.onAddressUpdated?.call(updated);
      widget.onLocationSelected?.call(updated.barangay);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Error setting default address: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update address: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _quickSaveBarangayAsAddress(String barangay) async {
    if (!_authService.isLoggedIn) {
      widget.onLocationSelected?.call(barangay);
      Navigator.of(context).pop();
      return;
    }

    setState(() => _isSaving = true);
    try {
      final newAddr = await _userService.upsertAddress(
        street: 'Purok Center',
        barangay: barangay,
        city: 'San Carlos City',
        province: 'Pangasinan',
        zipCode: '2420',
        label: 'Home',
        recipientName: _authService.userName.isNotEmpty ? _authService.userName : 'Customer',
        isDefault: true,
      );

      if (newAddr != null) {
        widget.onAddressUpdated?.call(newAddr);
        widget.onLocationSelected?.call(newAddr.barangay);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Error quick-saving address: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save to database: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _submitNewAddress() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final newAddr = await _userService.upsertAddress(
        street: _streetCtrl.text.trim(),
        barangay: _barangayCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        province: _provinceCtrl.text.trim(),
        zipCode: _zipCtrl.text.trim(),
        label: _labelCtrl.text.trim().isNotEmpty ? _labelCtrl.text.trim() : 'Home',
        recipientName: _nameCtrl.text.trim(),
        recipientPhone: _phoneCtrl.text.trim(),
        isDefault: _setAsDefault || _savedAddresses.isEmpty,
      );

      if (newAddr != null) {
        widget.onAddressUpdated?.call(newAddr);
        widget.onLocationSelected?.call(newAddr.barangay);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Error saving new address: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save address: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteAddress(String addressId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Address'),
        content: const Text('Are you sure you want to remove this delivery address?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _userService.deleteAddressById(addressId);
      await _loadDatabaseAddresses();
    } catch (e) {
      debugPrint('Error deleting address: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: WebDesignTokens.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: WebDesignTokens.primaryLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: WebDesignTokens.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _showAddForm ? 'Add Delivery Address' : 'Delivery Address',
                            style: GoogleFonts.rubik(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: WebDesignTokens.dark,
                            ),
                          ),
                          Text(
                            _authService.isLoggedIn
                                ? 'Saved in your AgriDirect database account'
                                : 'Select delivery location or sign in',
                            style: GoogleFonts.nunitoSans(
                              fontSize: 12.5,
                              color: WebDesignTokens.slate500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: WebDesignTokens.slate400),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: WebDesignTokens.border),
              const SizedBox(height: 16),

              // Content Body
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: WebDesignTokens.primary),
                      )
                    : _showAddForm
                        ? _buildAddAddressForm()
                        : _buildAddressListOrGuest(),
              ),

              // Footer Actions
              if (!_showAddForm && _authService.isLoggedIn) ...[
                const SizedBox(height: 14),
                const Divider(height: 1, color: WebDesignTokens.border),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () => setState(() => _showAddForm = true),
                      icon: const Icon(Icons.add_location_alt_outlined, size: 18, color: WebDesignTokens.primary),
                      label: Text(
                        'Add New Address',
                        style: GoogleFonts.nunitoSans(
                          fontWeight: FontWeight.w700,
                          color: WebDesignTokens.primary,
                        ),
                      ),
                    ),
                    if (_isSaving)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: WebDesignTokens.primary),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddressListOrGuest() {
    if (!_authService.isLoggedIn) {
      return _buildGuestView();
    }

    if (_savedAddresses.isEmpty) {
      return _buildEmptyAddressesView();
    }

    return ListView.separated(
      itemCount: _savedAddresses.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final addr = _savedAddresses[index];
        final isSelected = _selectedAddress?.addressId == addr.addressId;

        return InkWell(
          onTap: () => _selectAndSaveDefault(addr),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? WebDesignTokens.primaryLight.withValues(alpha: 0.3)
                  : WebDesignTokens.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? WebDesignTokens.primary : WebDesignTokens.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: isSelected ? WebDesignTokens.primary : WebDesignTokens.slate400,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: WebDesignTokens.bg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              addr.label.toUpperCase(),
                              style: GoogleFonts.rubik(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: WebDesignTokens.slate700,
                              ),
                            ),
                          ),
                          if (addr.isDefault) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'DEFAULT',
                                style: GoogleFonts.rubik(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF166534),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (addr.recipientName.isNotEmpty)
                        Text(
                          '${addr.recipientName}  •  ${addr.recipientPhone}',
                          style: GoogleFonts.nunitoSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: WebDesignTokens.dark,
                          ),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        '${addr.street}, ${addr.barangay}, ${addr.city}, ${addr.province}',
                        style: GoogleFonts.nunitoSans(
                          fontSize: 13,
                          color: WebDesignTokens.slate600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Delete address',
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: WebDesignTokens.slate400),
                  onPressed: () => _deleteAddress(addr.addressId),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyAddressesView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: WebDesignTokens.bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: WebDesignTokens.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: WebDesignTokens.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'You do not have a saved delivery address in the database yet.',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 13,
                    color: WebDesignTokens.dark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Quick Save Barangay to Database:',
              style: GoogleFonts.rubik(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: WebDesignTokens.dark,
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _showAddForm = true),
              child: const Text('+ Custom Form'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            itemCount: _sanCarlosBarangays.length,
            separatorBuilder: (_, index) => const Divider(height: 1, color: WebDesignTokens.border),
            itemBuilder: (context, index) {
              final b = _sanCarlosBarangays[index];
              return ListTile(
                dense: true,
                leading: const Icon(Icons.add_location_outlined, color: WebDesignTokens.primary, size: 20),
                title: Text(
                  '$b, San Carlos City',
                  style: GoogleFonts.nunitoSans(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: WebDesignTokens.slate400),
                onTap: () => _quickSaveBarangayAsAddress(b),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGuestView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: WebDesignTokens.primaryLight.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: WebDesignTokens.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_outline_rounded, color: WebDesignTokens.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sign in to save addresses to database',
                      style: GoogleFonts.rubik(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: WebDesignTokens.primaryDark,
                      ),
                    ),
                    Text(
                      'Log in to sync your verified shipping locations with your orders.',
                      style: GoogleFonts.nunitoSans(fontSize: 12, color: WebDesignTokens.slate600),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push(AppRoutes.login);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: WebDesignTokens.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                child: const Text('Sign In'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Search Box for guest location
        TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Select delivery barangay in San Carlos...',
            prefixIcon: const Icon(Icons.search_rounded, size: 20, color: WebDesignTokens.slate400),
            filled: true,
            fillColor: WebDesignTokens.bg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.separated(
            itemCount: _filteredBarangays.length,
            separatorBuilder: (_, index) => const Divider(height: 1, color: WebDesignTokens.border),
            itemBuilder: (context, index) {
              final b = _filteredBarangays[index];
              return ListTile(
                dense: true,
                leading: const Icon(Icons.location_city_rounded, color: WebDesignTokens.primary, size: 20),
                title: Text(
                  '$b, San Carlos City',
                  style: GoogleFonts.nunitoSans(fontSize: 13.5, fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  widget.onLocationSelected?.call(b);
                  Navigator.of(context).pop();
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAddAddressForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, size: 20),
                  onPressed: () => setState(() => _showAddForm = false),
                ),
                const SizedBox(width: 4),
                Text(
                  'Address Details',
                  style: GoogleFonts.rubik(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Label Choice
            Text('Address Label', style: GoogleFonts.nunitoSans(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: ['Home', 'Work', 'Farm', 'Other'].map((label) {
                final isSelected = _labelCtrl.text == label;
                return ChoiceChip(
                  label: Text(label),
                  selected: isSelected,
                  selectedColor: WebDesignTokens.primaryLight,
                  onSelected: (val) {
                    if (val) setState(() => _labelCtrl.text = label);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Recipient & Phone
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Recipient Name *',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _phoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Contact Phone',
                      hintText: '09xxxxxxxxx',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Street
            TextFormField(
              controller: _streetCtrl,
              decoration: const InputDecoration(
                labelText: 'Street Address / House No. / Building *',
                hintText: 'e.g. Purok 4, Main Highway',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            // Barangay (Dropdown or custom)
            DropdownButtonFormField<String>(
              initialValue: _sanCarlosBarangays.contains(_barangayCtrl.text)
                  ? _barangayCtrl.text
                  : _sanCarlosBarangays.first,
              decoration: const InputDecoration(
                labelText: 'Barangay *',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: _sanCarlosBarangays.map((b) {
                return DropdownMenuItem<String>(value: b, child: Text(b));
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _barangayCtrl.text = val);
              },
            ),
            const SizedBox(height: 12),

            // City & Province
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cityCtrl,
                    decoration: const InputDecoration(
                      labelText: 'City / Municipality',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _provinceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Province',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Default Checkbox
            CheckboxListTile(
              value: _setAsDefault,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Set as default delivery address'),
              onChanged: (val) => setState(() => _setAsDefault = val ?? false),
            ),
            const SizedBox(height: 14),

            // Submit Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => setState(() => _showAddForm = false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _submitNewAddress,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Save to Database'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WebDesignTokens.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

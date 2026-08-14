import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

import '../../../shared/styles/app_theme.dart';

import '../../../shared/services/user/user_service.dart';
import '../../../shared/models/auth/user_address_model.dart';

import '../../../shared/services/integration/reverse_geocoding_service.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Marketplace Screen - Professional Digital Marketplace
class AddressSelectorSheet extends StatefulWidget {
  final String? currentAddressId;
  const AddressSelectorSheet({super.key, this.currentAddressId});
  @override
  State<AddressSelectorSheet> createState() => _AddressSelectorSheetState();
}

class _AddressSelectorSheetState extends State<AddressSelectorSheet> {
  final UserService _userService = UserService();
  List<UserAddress> _addresses = [];
  bool _isLoading = true;
  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    try {
      final list = await _userService.getAllUserAddresses();
      if (mounted) setState(() => _addresses = list);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Text(
                  'Select Address',
                  style: AppTextStyles.headline1.copyWith(fontSize: 22),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    final nw = await showModalBottomSheet<UserAddress>(
                      context: context,
                      isScrollControlled: true,
                      useRootNavigator: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const AddressEditorSheet(),
                    );
                    if (nw != null && context.mounted) {
                      Navigator.pop(context, nw);
                    }
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add New'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : (_addresses.isEmpty
                      ? const Center(child: Text('No addresses found'))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: _addresses.length,
                          itemBuilder: (context, i) {
                            final addr = _addresses[i];
                            final sel =
                                addr.addressId == widget.currentAddressId;
                            return GestureDetector(
                              onTap: () => Navigator.pop(context, addr),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: sel
                                      ? AppColors.primary.withValues(alpha: 0.1)
                                      : AppColors.background,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: sel
                                        ? AppColors.primary
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: sel
                                            ? AppColors.primary
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        addr.label.toLowerCase() == 'home'
                                            ? Icons.home_rounded
                                            : (addr.label.toLowerCase() ==
                                                      'office'
                                                  ? Icons.work_rounded
                                                  : Icons.location_on_rounded),
                                        color: sel
                                            ? Colors.white
                                            : AppColors.primary,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                addr.label,
                                                style: AppTextStyles.headline3
                                                    .copyWith(fontSize: 16),
                                              ),
                                              if (addr.isDefault) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primary
                                                        .withValues(
                                                          alpha: 0.15,
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: const Text(
                                                    'DEFAULT',
                                                    style: TextStyle(
                                                      fontSize: 8,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: AppColors.primary,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          Text(
                                            addr.street,
                                            style: AppTextStyles.bodySmall,
                                          ),
                                          Text(
                                            '${addr.barangay}, ${addr.city}',
                                            style: AppTextStyles.bodySmall
                                                .copyWith(
                                                  color: AppColors.textSubtle,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (sel)
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: AppColors.primary,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        )),
          ),
        ],
      ),
    );
  }
}

class AddressEditorSheet extends StatefulWidget {
  final UserAddress? initialAddress;
  final bool? isDialog;
  const AddressEditorSheet({super.key, this.initialAddress, this.isDialog});

  @override
  State<AddressEditorSheet> createState() => _AddressEditorSheetState();
}

class _AddressEditorSheetState extends State<AddressEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _labels = ['Home', 'Office', 'Farm', 'Warehouse', 'Other'];
  String _selectedLabel = 'Home';

  final _recipientController = TextEditingController();
  final _phoneController = TextEditingController();
  final _streetController = TextEditingController();
  final _barangayController = TextEditingController();
  final _cityController = TextEditingController();
  final _provinceController = TextEditingController();

  bool _isDefault = false;
  bool _isSaving = false;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    if (widget.initialAddress != null) {
      _selectedLabel = _labels.contains(widget.initialAddress!.label)
          ? widget.initialAddress!.label
          : 'Other';
      _recipientController.text = widget.initialAddress!.recipientName;
      _phoneController.text = widget.initialAddress!.recipientPhone;
      _streetController.text = widget.initialAddress!.street;
      _barangayController.text = widget.initialAddress!.barangay;
      _cityController.text = widget.initialAddress!.city;
      _provinceController.text = widget.initialAddress!.province;
      _isDefault = widget.initialAddress!.isDefault;
      _latitude = widget.initialAddress!.latitude;
      _longitude = widget.initialAddress!.longitude;
    }
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _barangayController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select your exact delivery location on the map',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final res = await UserService().upsertAddress(
        addressId: widget.initialAddress?.addressId,
        label: _selectedLabel,
        recipientName: _recipientController.text.trim(),
        recipientPhone: _phoneController.text.trim(),
        street: _streetController.text.trim(),
        barangay: _barangayController.text.trim(),
        city: _cityController.text.trim(),
        province: _provinceController.text.trim(),
        zipCode: '0000',
        isDefault: _isDefault,
        latitude: _latitude,
        longitude: _longitude,
      );
      if (mounted && res != null) Navigator.pop(context, res);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _openLocationPicker() async {
    final isMobile = MediaQuery.of(context).size.width <= 800;
    Map<String, dynamic>? res;
    if (isMobile) {
      res = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const LocationPickerSheet(),
      );
    } else {
      res = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 750, maxHeight: 600),
            child: const LocationPickerSheet(isDialog: true),
          ),
        ),
      );
    }

    final actualRes = res;
    if (actualRes != null && mounted) {
      setState(() {
        _latitude = actualRes['lat'];
        _longitude = actualRes['lng'];
        if (actualRes['address'] != null) {
          final ResolvedFarmLocation a = actualRes['address'];
          _streetController.text = a.street;
          _barangayController.text = a.barangay;
          _cityController.text = a.city;
          _provinceController.text = a.province;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 800;
    final useDialog = widget.isDialog ?? isWeb;

    // â”€â”€â”€ Form content â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    Widget formContent = Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // â”€â”€ Title row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryDark, AppColors.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.initialAddress == null
                          ? 'Add New Address'
                          : 'Edit Address',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textHeadline,
                      ),
                    ),
                    Text(
                      'Fill in your delivery details below',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSubtle,
                      ),
                    ),
                  ],
                ),
              ),
              if (useDialog)
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: AppColors.textSubtle,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.all(8),
                    minimumSize: const Size(36, 36),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // â”€â”€ Location pin â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (_latitude != null)
                  ? AppColors.primary.withValues(alpha: 0.06)
                  : AppColors.error.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (_latitude != null)
                    ? AppColors.primary.withValues(alpha: 0.3)
                    : AppColors.error.withValues(alpha: 0.25),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: (_latitude != null)
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.location_on_rounded,
                    color: (_latitude != null)
                        ? AppColors.primary
                        : AppColors.error,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delivery Pin Location',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textHeadline,
                        ),
                      ),
                      Text(
                        (_latitude != null)
                            ? 'ðŸ“ ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}'
                            : 'Tap "Select" to pin your location on the map',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: (_latitude != null)
                              ? AppColors.primary
                              : AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _openLocationPicker,
                  icon: Icon(
                    (_latitude != null)
                        ? Icons.edit_location_alt_rounded
                        : Icons.map_rounded,
                    size: 15,
                  ),
                  label: Text((_latitude != null) ? 'Change' : 'Select'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    textStyle: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // â”€â”€ Address Tag â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          _buildSectionLabel('Address Tag'),
          const SizedBox(height: 8),
          _buildLabelSelector(),
          const SizedBox(height: 20),

          // â”€â”€ Recipient details â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          _buildSectionLabel('Recipient Details'),
          const SizedBox(height: 8),
          if (useDialog) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildField(
                    _recipientController,
                    'Recipient Name',
                    'Juan Dela Cruz',
                    icon: Icons.person_outline_rounded,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildField(
                    _phoneController,
                    'Phone Number',
                    '09123456789',
                    keyboard: TextInputType.phone,
                    icon: Icons.phone_outlined,
                  ),
                ),
              ],
            ),
          ] else ...[
            _buildField(
              _recipientController,
              'Recipient Name',
              'Juan Dela Cruz',
              icon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: 14),
            _buildField(
              _phoneController,
              'Phone Number',
              '09123456789',
              keyboard: TextInputType.phone,
              icon: Icons.phone_outlined,
            ),
          ],
          const SizedBox(height: 20),

          // â”€â”€ Address fields â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          _buildSectionLabel('Address Details'),
          const SizedBox(height: 8),
          if (useDialog) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildField(
                    _streetController,
                    'Street / House No.',
                    '123 Agri St.',
                    icon: Icons.home_outlined,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildField(
                    _barangayController,
                    'Barangay',
                    'Brgy. San Jose',
                    icon: Icons.location_city_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildField(
                    _cityController,
                    'City',
                    'Cabanatuan',
                    icon: Icons.apartment_outlined,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildField(
                    _provinceController,
                    'Province',
                    'Nueva Ecija',
                    icon: Icons.map_outlined,
                  ),
                ),
              ],
            ),
          ] else ...[
            _buildField(
              _streetController,
              'Street / House No.',
              '123 Agri St.',
              icon: Icons.home_outlined,
            ),
            const SizedBox(height: 14),
            _buildField(
              _barangayController,
              'Barangay',
              'Brgy. San Jose',
              icon: Icons.location_city_outlined,
            ),
            const SizedBox(height: 14),
            _buildField(
              _cityController,
              'City',
              'Cabanatuan',
              icon: Icons.apartment_outlined,
            ),
            const SizedBox(height: 14),
            _buildField(
              _provinceController,
              'Province',
              'Nueva Ecija',
              icon: Icons.map_outlined,
            ),
          ],
          const SizedBox(height: 16),

          // â”€â”€ Default toggle â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Set as default address',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textHeadline,
                ),
              ),
              subtitle: Text(
                'Used automatically at checkout',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSubtle,
                ),
              ),
              value: _isDefault,
              onChanged: (v) => setState(() => _isDefault = v),
              activeTrackColor: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),

          // â”€â”€ Save button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Row(
            children: [
              if (!useDialog) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSubtle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 2,
                child: _isSaving
                    ? Container(
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primaryDark, AppColors.primary],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          ),
                        ),
                      )
                    : GestureDetector(
                        onTap: _save,
                        child: Container(
                          height: 54,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.primaryDark,
                                AppColors.primary,
                                Color(0xFF10B981),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.save_alt_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Save Address',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
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

    if (useDialog) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: SingleChildScrollView(child: formContent),
      );
    }

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: formContent,
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primaryDark, AppColors.primary],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textHeadline,
          ),
        ),
      ],
    );
  }

  Widget _buildLabelSelector() {
    final icons = {
      'Home': Icons.home_rounded,
      'Office': Icons.business_rounded,
      'Farm': Icons.agriculture_rounded,
      'Warehouse': Icons.warehouse_rounded,
      'Other': Icons.location_on_rounded,
    };

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _labels.map((label) {
        final isSelected = _selectedLabel == label;
        return GestureDetector(
          onTap: () => setState(() => _selectedLabel = label),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [AppColors.primaryDark, AppColors.primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isSelected ? null : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icons[label] ?? Icons.location_on_rounded,
                  size: 15,
                  color: isSelected ? Colors.white : AppColors.textSubtle,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.textHeadline,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label,
    String hint, {
    TextInputType? keyboard,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSubtle,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboard,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textBody,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(icon, size: 18, color: AppColors.textSubtle),
                  )
                : null,
            prefixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
            hintStyle: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSubtle.withValues(alpha: 0.5),
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.error, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.error, width: 2),
            ),
          ),
          validator: (v) =>
              (v == null || v.isEmpty) ? '$label is required' : null,
        ),
      ],
    );
  }
}

class LocationPickerSheet extends StatefulWidget {
  final bool isDialog;
  const LocationPickerSheet({super.key, this.isDialog = false});

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  final MapController _mapController = MapController();
  LatLng _currentCenter = const LatLng(15.4828, 120.9714);
  bool _isLoading = true;
  bool _isResolving = false;
  ResolvedFarmLocation? _resolvedLocation;

  @override
  void initState() {
    super.initState();
    _moveToCurrentLocation();
  }

  Future<void> _moveToCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      final nw = LatLng(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() {
          _currentCenter = nw;
          _isLoading = false;
        });
        _mapController.move(nw, 16);
        _resolveAddress(nw);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resolveAddress(LatLng p) async {
    setState(() => _isResolving = true);
    try {
      final res = await ReverseGeocodingService.resolveFromCoordinates(
        latitude: p.latitude,
        longitude: p.longitude,
      );
      if (mounted) {
        setState(() {
          _resolvedLocation = res;
          _isResolving = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 800;
    final useDialog = widget.isDialog || isWeb;

    Widget body = Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(useDialog ? 24 : 32),
            bottom: Radius.circular(useDialog ? 24 : 0),
          ),
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: 16,
              onTap: (tp, p) {
                setState(() => _currentCenter = p);
                _mapController.move(p, _mapController.camera.zoom);
                _resolveAddress(p);
              },
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture) setState(() => _currentCenter = pos.center);
              },
              onMapEvent: (ev) {
                if (ev is MapEventMoveEnd) _resolveAddress(_currentCenter);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.agridirect.app',
              ),
            ],
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 35),
            child: Icon(
              Icons.location_on_rounded,
              color: AppColors.primary,
              size: 44,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 20,
          left: 20,
          right: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CircleAvatar(
                backgroundColor: Colors.white,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Text(
                  'Pin Delivery Location',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHeadline,
                  ),
                ),
              ),
              const SizedBox(width: 40),
            ],
          ),
        ),
        Positioned(
          bottom: 20,
          left: 20,
          right: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton(
                onPressed: _moveToCurrentLocation,
                backgroundColor: Colors.white,
                mini: true,
                child: const Icon(
                  Icons.my_location_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 24,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _isResolving
                                ? 'Resolving Address...'
                                : (_resolvedLocation?.fullAddress.isNotEmpty ==
                                          true
                                      ? _resolvedLocation!.fullAddress
                                      : 'Location: ${_currentCenter.latitude.toStringAsFixed(4)}, ${_currentCenter.longitude.toStringAsFixed(4)}'),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textHeadline,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isResolving
                            ? null
                            : () => Navigator.pop(context, {
                                'lat': _currentCenter.latitude,
                                'lng': _currentCenter.longitude,
                                'address': _resolvedLocation,
                              }),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Confirm Location',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
      ],
    );

    if (useDialog) {
      return Container(
        height: 600,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: body,
      );
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: body,
    );
  }
}

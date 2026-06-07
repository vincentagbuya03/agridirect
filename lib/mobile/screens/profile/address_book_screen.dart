import 'package:flutter/material.dart';
import '../consumer/marketplace_screen.dart';
import '../../../shared/models/auth/user_address_model.dart';
import '../../../shared/services/user/user_service.dart';
import '../../../shared/styles/app_theme.dart';

class AddressBookScreen extends StatefulWidget {
  const AddressBookScreen({super.key});

  @override
  State<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends State<AddressBookScreen> {
  final UserService _userService = UserService();
  List<UserAddress> _addresses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() => _isLoading = true);
    final addresses = await _userService.getAllUserAddresses();
    if (!mounted) return;
    setState(() {
      _addresses = addresses;
      _isLoading = false;
    });
  }

  Future<void> _openEditor([UserAddress? address]) async {
    final result = await showModalBottomSheet<UserAddress>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddressEditorSheet(initialAddress: address),
    );

    if (result != null) {
      await _loadAddresses();
    }
  }

  Future<void> _setDefault(UserAddress address) async {
    final success = await _userService.setDefaultAddress(address.addressId);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Default address updated.' : 'Unable to update address.',
        ),
        backgroundColor: success ? AppColors.success : AppColors.error,
      ),
    );

    if (success) {
      await _loadAddresses();
    }
  }

  Future<void> _deleteAddress(UserAddress address) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Address'),
        content: Text('Remove "${address.label}" from your address book?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    final success = await _userService.deleteAddressById(address.addressId);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Address deleted.' : 'Unable to delete address.',
        ),
        backgroundColor: success ? AppColors.success : AppColors.error,
      ),
    );

    if (success) {
      await _loadAddresses();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Address Book'),
        backgroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Add Address'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _addresses.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_off_rounded,
                      size: 56,
                      color: AppColors.textSubtle.withValues(alpha: 0.6),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No saved addresses yet',
                      style: AppTextStyles.headline3,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add your delivery address so checkout is faster next time.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSubtle,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadAddresses,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                itemCount: _addresses.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final address = _addresses[index];
                  return Container(
                    padding: const EdgeInsets.all(18),
                    decoration: AppDecorations.cardDecoration.copyWith(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.location_on_rounded,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          address.label,
                                          style: AppTextStyles.headline3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (address.isDefault) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.12,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            'DEFAULT',
                                            style: AppTextStyles.labelSmall
                                                .copyWith(
                                                  color: AppColors.primary,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    address.recipientName,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textSubtle,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(address.fullAddress, style: AppTextStyles.bodyMedium),
                        if (address.recipientPhone.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            address.recipientPhone,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSubtle,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _openEditor(address),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Edit'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: address.isDefault
                                    ? null
                                    : () => _setDefault(address),
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text('Set Default'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            IconButton.filledTonal(
                              onPressed: () => _deleteAddress(address),
                              style: IconButton.styleFrom(
                                foregroundColor: AppColors.error,
                              ),
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}

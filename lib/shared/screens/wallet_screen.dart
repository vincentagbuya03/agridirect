import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';
import '../services/wallet_service.dart';

/// Farmer wallet screen - displays earnings balance and transaction history.
/// Only accessible for farmers.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final WalletService _walletService = WalletService();

  bool _isLoading = true;
  Map<String, dynamic>? _wallet;
  List<Map<String, dynamic>> _transactions = [];
  bool _showAllTransactions = false;

  final TextEditingController _withdrawAmountController =
      TextEditingController();
  final TextEditingController _accountDetailsController =
      TextEditingController();
  String _selectedWithdrawMethod = 'GCash';

  @override
  void initState() {
    super.initState();
    _checkAccessAndLoad();
  }

  @override
  void dispose() {
    _withdrawAmountController.dispose();
    _accountDetailsController.dispose();
    super.dispose();
  }

  void _checkAccessAndLoad() {
    final auth = AuthService();
    if (!auth.isSeller) {
      // Not a farmer - redirect back
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Wallet is only available for farmers'),
              backgroundColor: Colors.orange,
            ),
          );
          context.pop();
        }
      });
      return;
    }
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final wallet = await _walletService.getMyFarmerWallet();
      final transactions = _showAllTransactions
          ? await _walletService.getAllFarmerWalletTransactions()
          : await _walletService.getMyFarmerWalletTransactions(limit: 10);

      if (mounted) {
        setState(() {
          _wallet = wallet;
          _transactions = transactions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading wallet: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatMoney(double value) {
    return '₱${value.toStringAsFixed(2)}';
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    final date = DateTime.tryParse(dateString);
    if (date == null) return '';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'My Wallet',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _wallet == null
          ? _buildNoWalletState()
          : _buildWalletContent(),
    );
  }

  Widget _buildNoWalletState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Wallet not found',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your wallet will be created when you receive your first payment.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletContent() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBalanceCard(),
            const SizedBox(height: 16),
            _buildStatsRow(),
            const SizedBox(height: 24),
            _buildWithdrawButton(),
            const SizedBox(height: 32),
            _buildTransactionsHeader(),
            const SizedBox(height: 12),
            _buildTransactionsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    final balance = (_wallet?['balance'] as num?)?.toDouble() ?? 0.0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF16A34A), Color(0xFF22C55E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16A34A).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Available Balance',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _formatMoney(balance),
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline, color: Colors.white, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Earnings from customer orders',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final totalCredited =
        (_wallet?['total_credited'] as num?)?.toDouble() ?? 0.0;
    final totalWithdrawn =
        (_wallet?['total_withdrawn'] as num?)?.toDouble() ?? 0.0;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Earned',
            _formatMoney(totalCredited),
            Icons.trending_up_rounded,
            const Color(0xFF16A34A),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Total Withdrawn',
            _formatMoney(totalWithdrawn),
            Icons.arrow_upward_rounded,
            const Color(0xFF3B82F6),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _showWithdrawDialog,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3B82F6),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: const Icon(Icons.arrow_upward_rounded),
        label: Text(
          'Withdraw Funds',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _showAllTransactions ? 'All Transactions' : 'Recent Transactions',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        TextButton(
          onPressed: () {
            setState(() {
              _showAllTransactions = !_showAllTransactions;
            });
            _loadData();
          },
          child: Text(_showAllTransactions ? 'Show Less' : 'See All'),
        ),
      ],
    );
  }

  Widget _buildTransactionsList() {
    if (_transactions.isEmpty) {
      return _buildEmptyTransactions();
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _transactions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final tx = _transactions[index];
        return _buildTransactionItem(tx);
      },
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> tx) {
    final type = tx['transaction_type'] as String? ?? 'credit';
    final isCredit = type == 'credit';
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final description = tx['description'] as String? ?? 'Transaction';
    final createdAt = tx['created_at'] as String?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isCredit
                  ? const Color(0xFFDCFCE7)
                  : const Color(0xFFDBEAFE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCredit ? Icons.add_rounded : Icons.arrow_upward_rounded,
              color: isCredit
                  ? const Color(0xFF16A34A)
                  : const Color(0xFF3B82F6),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(createdAt),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isCredit ? '+' : '-'}${_formatMoney(amount)}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isCredit
                  ? const Color(0xFF16A34A)
                  : const Color(0xFF3B82F6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTransactions() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.history_rounded, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'No transactions yet',
              style: GoogleFonts.plusJakartaSans(color: Colors.grey[500]),
            ),
            const SizedBox(height: 4),
            Text(
              'Your earnings will appear here when customers pay for orders.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }

  void _showWithdrawDialog() {
    final balance = (_wallet?['balance'] as num?)?.toDouble() ?? 0.0;

    if (balance < 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimum withdrawal amount is ₱100.00'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    _withdrawAmountController.clear();
    _accountDetailsController.clear();
    _selectedWithdrawMethod = 'GCash';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Withdraw Funds',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Available balance: ${_formatMoney(balance)}',
                  style: GoogleFonts.plusJakartaSans(color: Colors.grey[600]),
                ),
                const SizedBox(height: 20),

                // Amount field
                Text(
                  'Amount',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _withdrawAmountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    prefixText: '₱ ',
                    hintText: '0.00',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: Color(0xFF3B82F6),
                        width: 2,
                      ),
                    ),
                  ),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),

                // Withdrawal method
                Text(
                  'Withdrawal Method',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMethodOption(
                        'GCash',
                        Icons.account_balance_rounded,
                        Colors.blue,
                        setModalState,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMethodOption(
                        'Maya',
                        Icons.payment_rounded,
                        Colors.green,
                        setModalState,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMethodOption(
                        'Bank',
                        Icons.account_balance_outlined,
                        Colors.purple,
                        setModalState,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Account details
                Text(
                  _selectedWithdrawMethod == 'Bank'
                      ? 'Bank Account Details'
                      : '$_selectedWithdrawMethod Number',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _accountDetailsController,
                  keyboardType: _selectedWithdrawMethod == 'Bank'
                      ? TextInputType.text
                      : TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: _selectedWithdrawMethod == 'Bank'
                        ? 'Bank name - Account number'
                        : '09XX XXX XXXX',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: Color(0xFF3B82F6),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _processWithdrawal(balance),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Request Withdrawal',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'Withdrawals are processed within 1-3 business days.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMethodOption(
    String method,
    IconData icon,
    Color color,
    StateSetter setModalState,
  ) {
    final isSelected = _selectedWithdrawMethod == method;
    return GestureDetector(
      onTap: () {
        setModalState(() {
          _selectedWithdrawMethod = method;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey[400], size: 24),
            const SizedBox(height: 4),
            Text(
              method,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: isSelected ? color : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processWithdrawal(double availableBalance) async {
    final amountText = _withdrawAmountController.text.trim();
    final amount = double.tryParse(amountText);
    final accountDetails = _accountDetailsController.text.trim();

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    if (amount < 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimum withdrawal amount is ₱100.00')),
      );
      return;
    }

    if (amount > availableBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Insufficient balance. Available: ${_formatMoney(availableBalance)}',
          ),
        ),
      );
      return;
    }

    if (accountDetails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter account details')),
      );
      return;
    }

    Navigator.pop(context); // Close bottom sheet
    setState(() => _isLoading = true);

    try {
      await _walletService.requestWithdrawal(
        amount: amount,
        withdrawalMethod: _selectedWithdrawMethod,
        accountDetails: accountDetails,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Withdrawal request submitted for ${_formatMoney(amount)}',
            ),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Withdrawal failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }
}

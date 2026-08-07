import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../shared/services/core/supabase_config.dart';
import '../../../shared/widgets/app_shimmer_loader.dart';

enum _TwoFactorState { loading, intro, setup, verify, active }

class WebTwoFactorDialog extends StatefulWidget {
  final bool initialIsActive;
  
  const WebTwoFactorDialog({
    super.key,
    required this.initialIsActive,
  });

  @override
  State<WebTwoFactorDialog> createState() => _WebTwoFactorDialogState();
}

class _WebTwoFactorDialogState extends State<WebTwoFactorDialog> {
  _TwoFactorState _currentState = _TwoFactorState.loading;
  
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _qrCodeUri;
  String? _secret;
  String? _factorId;

  static const Color _primary = Color(0xFF16A34A);
  static const Color _dark = Color(0xFF111827);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    try {
      final res = await SupabaseConfig.client.auth.mfa.listFactors();
      final hasTotp = res.totp.isNotEmpty;
      
      if (mounted) {
        setState(() {
          _currentState = hasTotp ? _TwoFactorState.active : _TwoFactorState.intro;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _currentState = widget.initialIsActive ? _TwoFactorState.active : _TwoFactorState.intro);
      }
    }
  }

  Future<void> _startEnrollment() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final enrollResponse = await SupabaseConfig.client.auth.mfa.enroll();
      
      setState(() {
        _factorId = enrollResponse.id;
        _qrCodeUri = enrollResponse.totp?.uri;
        _secret = enrollResponse.totp?.secret;
        _currentState = _TwoFactorState.setup;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start 2FA setup: ${e.toString()}'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _verifyAndActivate() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 6-digit code.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // First create a challenge
      final challengeResponse = await SupabaseConfig.client.auth.mfa.challenge(factorId: _factorId!);
      
      // Then verify the code against the challenge
      await SupabaseConfig.client.auth.mfa.verify(
        factorId: _factorId!,
        challengeId: challengeResponse.id,
        code: code,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Two-Factor Authentication enabled successfully!'),
            backgroundColor: _primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(true); // true indicates status changed
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid code or setup failed.'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _disableMfa() async {
    setState(() => _isLoading = true);

    try {
      final res = await SupabaseConfig.client.auth.mfa.listFactors();
      if (res.totp.isNotEmpty) {
        final factorId = res.totp.first.id;
        await SupabaseConfig.client.auth.mfa.unenroll(factorId);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Two-Factor Authentication disabled.'),
              backgroundColor: _muted,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).pop(true); // true indicates status changed
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to disable 2FA: ${e.toString()}'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildBody(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Two-Factor Authentication',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _dark,
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded, color: _muted),
          splashRadius: 24,
        ),
      ],
    );
  }

  Widget _buildBody() {
    switch (_currentState) {
      case _TwoFactorState.loading:
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(32.0),
            child: AppShimmerLoader(strokeWidth: 3, valueColor: AlwaysStoppedAnimation(_primary)),
          ),
        );
      case _TwoFactorState.intro:
        return _buildIntroView();
      case _TwoFactorState.setup:
      case _TwoFactorState.verify:
        return _buildSetupView();
      case _TwoFactorState.active:
        return _buildActiveView();
    }
  }

  Widget _buildIntroView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.security_rounded, size: 48, color: _primary.withValues(alpha: 0.2)),
        const SizedBox(height: 16),
        Text(
          'Secure Your Account',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: _dark),
        ),
        const SizedBox(height: 8),
        Text(
          'Two-factor authentication adds an extra layer of security to your account. '
          'In addition to your password, you\'ll need to enter a code generated by an authenticator app (like Google Authenticator or Authy) on your phone.',
          style: GoogleFonts.inter(fontSize: 14, color: _muted, height: 1.5),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _startEnrollment,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('Set Up Authentication App', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildSetupView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '1. Scan this QR Code with your app',
          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: _dark),
        ),
        const SizedBox(height: 16),
        if (_qrCodeUri != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: QrImageView(
              data: _qrCodeUri!,
              version: QrVersions.auto,
              size: 200.0,
            ),
          ),
        const SizedBox(height: 16),
        if (_secret != null) ...[
          Text(
            'Or enter this code manually:',
            style: GoogleFonts.inter(fontSize: 13, color: _muted),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _secret!,
                    style: GoogleFonts.robotoMono(fontSize: 14, color: _dark, fontWeight: FontWeight.w500),
                  ),
                ),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _secret!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copied to clipboard'), duration: Duration(seconds: 2)),
                    );
                  },
                  child: const Icon(Icons.copy_rounded, size: 20, color: _primary),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 32),
        const Divider(color: _border),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '2. Verify the 6-digit code',
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: _dark),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold, color: _dark),
          decoration: InputDecoration(
            hintText: '000000',
            counterText: '',
            hintStyle: GoogleFonts.inter(color: const Color(0xFFCBD5E1), letterSpacing: 8),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primary, width: 2)),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _verifyAndActivate,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('Verify & Enable 2FA', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: _primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '2FA is Active',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: _dark),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Your account is secured with an authenticator app.',
                      style: GoogleFonts.inter(fontSize: 13, color: _primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Need to move to a new device or disable 2FA?',
          style: GoogleFonts.inter(fontSize: 14, color: _dark, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'Disabling two-factor authentication will remove the extra layer of security from your account.',
          style: GoogleFonts.inter(fontSize: 13, color: _muted, height: 1.5),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _isLoading ? null : _disableMfa,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade600,
              side: BorderSide(color: Colors.red.shade200),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                : Text('Disable 2FA', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}

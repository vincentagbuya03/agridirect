import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum MascotExpression {
  happy,
  celebrating,
  thinking,
  waving
}

enum MascotMode {
  dashboardTip,
  floatingHelp,
  celebration
}

class MascotWidget extends StatefulWidget {
  final MascotMode mode;
  final MascotExpression expression;
  final String text;
  final VoidCallback? onClose;
  final List<Widget>? actions;

  const MascotWidget({
    super.key,
    required this.mode,
    this.expression = MascotExpression.happy,
    this.text = '',
    this.onClose,
    this.actions,
  });

  @override
  State<MascotWidget> createState() => _MascotWidgetState();
}

class _MascotWidgetState extends State<MascotWidget> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  bool _isHelpMenuOpen = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _getAssetPath(MascotExpression expr) {
    switch (expr) {
      case MascotExpression.happy:
        return 'assets/images/kiko_happy.png';
      case MascotExpression.celebrating:
        return 'assets/images/kiko_happy.png'; // Fallback to happy
      case MascotExpression.thinking:
        return 'assets/images/kiko_cloudy.png'; // Using cloudy as thinking
      case MascotExpression.waving:
        return 'assets/images/kiko_happy.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.mode) {
      case MascotMode.dashboardTip:
        return _buildDashboardTip();
      case MascotMode.floatingHelp:
        return _buildFloatingHelp();
      case MascotMode.celebration:
        return _buildCelebration();
    }
  }

  Widget _buildDashboardTip() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFECFDF5), Color(0xFFF0FDF4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Kiko Avatar
            ScaleTransition(
              scale: _scaleAnimation,
              child: Image.asset(
                _getAssetPath(widget.expression),
                width: 76,
                height: 90,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 76,
                    height: 90,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.face, color: Colors.white, size: 36),
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            // Speech bubble message content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '🌱 Kiko the Carabao',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF047857),
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          letterSpacing: 0.2,
                        ),
                      ),
                      if (widget.onClose != null)
                        GestureDetector(
                          onTap: widget.onClose,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD1FAE5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: Color(0xFF047857),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      widget.text,
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF374151),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        height: 1.45,
                      ),
                    ),
                  ),
                  if (widget.actions != null && widget.actions!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: widget.actions!,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingHelp() {
    return Positioned(
      bottom: 16,
      left: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isHelpMenuOpen)
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: SizedBox(
                  width: 220,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.help_outline, color: Color(0xFF10B981)),
                        title: const Text('App Tour / Guide'),
                        dense: true,
                        onTap: () {
                          setState(() => _isHelpMenuOpen = false);
                          _showGuideDialog();
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.question_answer_outlined, color: Color(0xFF10B981)),
                        title: const Text('FAQs'),
                        dense: true,
                        onTap: () {
                          setState(() => _isHelpMenuOpen = false);
                          _showFaqDialog();
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.support_agent, color: Color(0xFF10B981)),
                        title: const Text('Contact Support'),
                        dense: true,
                        onTap: () {
                          setState(() => _isHelpMenuOpen = false);
                          _showSupportSnackbar();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'lando_helper_badge',
            backgroundColor: const Color(0xFF10B981),
            onPressed: () {
              setState(() {
                _isHelpMenuOpen = !_isHelpMenuOpen;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Image.asset(
                _getAssetPath(widget.expression),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.contact_support, color: Colors.white, size: 28);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCelebration() {
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 70, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Woohoo! 🎉',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF047857),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.text,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    if (widget.onClose != null) widget.onClose!();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Awesome!'),
                ),
              ],
            ),
          ),
          Positioned(
            top: -60,
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  )
                ]
              ),
              child: CircleAvatar(
                radius: 60,
                backgroundColor: const Color(0xFFECFDF5),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Image.asset(
                    _getAssetPath(MascotExpression.celebrating),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.celebration, color: Color(0xFF10B981), size: 48);
                    },
                  ),
                ),
              ),
            ),
          ),
          // Confetti simulation using CustomPainter
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ConfettiPainter(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showGuideDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Image.asset(
                'assets/images/kiko_happy.png',
                width: 40,
                height: 40,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.face, color: Color(0xFF10B981)),
              ),
              const SizedBox(width: 10),
              const Text('AgriDirect Quick Guide'),
            ],
          ),
          content: const Text(
            'Welcome to AgriDirect! Kiko is here to help you get the most out of your app.\n\n'
            '• As a farmer, you can register products, view sales stats, and manage pre-orders.\n'
            '• Use the community hub to connect with other farmers and share tips.\n'
            '• As a consumer, explore fresh organic produce directly from local farms!',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it!'),
            ),
          ],
        );
      },
    );
  }

  void _showFaqDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Frequently Asked Questions'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: const [
                Text('Q: How do I list a new product?', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('A: Go to your inventory/products screen and tap the "+" button.'),
                SizedBox(height: 12),
                Text('Q: How are order payments processed?', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('A: Payments are managed securely via our commerce integrations.'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showSupportSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Support requested! A helper agent will contact you shortly.'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles = List.generate(40, (index) {
    final random = Random();
    return _ConfettiParticle(
      color: [
        Colors.red,
        Colors.blue,
        Colors.green,
        Colors.yellow,
        Colors.orange,
        Colors.purple,
        Colors.pink
      ][random.nextInt(7)],
      position: Offset(random.nextDouble() * 280, random.nextDouble() * 200),
      radius: random.nextDouble() * 4 + 2,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var p in particles) {
      paint.color = p.color;
      canvas.drawCircle(p.position, p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ConfettiParticle {
  final Color color;
  final Offset position;
  final double radius;

  _ConfettiParticle({
    required this.color,
    required this.position,
    required this.radius,
  });
}

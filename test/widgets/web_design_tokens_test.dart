import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agridirect/web/constants/web_design_tokens.dart';

void main() {
  test('WebDesignTokens defines expected brand colors and text styles', () {
    expect(WebDesignTokens.primary, const Color(0xFF16A34A));
    expect(WebDesignTokens.dark, const Color(0xFF0F172A));
    expect(WebDesignTokens.bg, const Color(0xFFF8FAFC));
    expect(WebDesignTokens.dealAmber, const Color(0xFFEA580C));
    expect(WebDesignTokens.trustBlue, const Color(0xFF2563EB));
  });

  test('WebBreakpoints correctly evaluates screen widths', () {
    expect(WebBreakpoints.isDesktopWide(1440), isTrue);
    expect(WebBreakpoints.isDesktopWide(1200), isFalse);
    expect(WebBreakpoints.isDesktop(1200), isTrue);
    expect(WebBreakpoints.isTablet(900), isTrue);
    expect(WebBreakpoints.isMobile(600), isTrue);
  });
}

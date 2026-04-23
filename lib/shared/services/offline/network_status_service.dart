import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' as io;

class NetworkStatusService {
  NetworkStatusService._();

  static final NetworkStatusService _instance = NetworkStatusService._();

  factory NetworkStatusService() => _instance;

  Future<bool> isOnline() async {
    try {
      final result = await Connectivity().checkConnectivity().timeout(
        const Duration(seconds: 5),
        onTimeout: () => [ConnectivityResult.none],
      );
      
      final hasNetworkInterface =
          result.isNotEmpty && result.first != ConnectivityResult.none;

      if (!hasNetworkInterface) return false;

      // InternetAddress.lookup is NOT supported on web and will throw UnimplementedError
      if (kIsWeb) return true;

      try {
        final lookup = await io.InternetAddress.lookup(
          'google.com',
        ).timeout(const Duration(seconds: 3));
        return lookup.isNotEmpty && lookup.first.rawAddress.isNotEmpty;
      } catch (_) {
        return false;
      }
    } catch (_) {
      return false;
    }
  }
}

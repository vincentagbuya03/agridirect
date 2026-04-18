import 'dart:convert';

import 'package:http/http.dart' as http;

class ResolvedFarmLocation {
  final String street;
  final String sitio;
  final String barangay;
  final String city;
  final String province;
  final String fullAddress;

  const ResolvedFarmLocation({
    required this.street,
    required this.sitio,
    required this.barangay,
    required this.city,
    required this.province,
    required this.fullAddress,
  });

  bool get hasData => fullAddress.trim().isNotEmpty;
}

class ReverseGeocodingService {
  static String _firstNonEmpty(
    Map<String, dynamic> address,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = (address[key] as String?)?.trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  static Future<ResolvedFarmLocation> resolveFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$latitude&lon=$longitude&addressdetails=1',
      );

      final response = await http.get(
        uri,
        headers: const {
          'User-Agent': 'AgriDirect/1.0 (support: noreplyagridirect@gmail.com)',
          'Accept-Language': 'en',
        },
      );

      if (response.statusCode != 200) {
        return const ResolvedFarmLocation(
          street: '',
          sitio: '',
          barangay: '',
          city: '',
          province: '',
          fullAddress: '',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final address = (json['address'] as Map<String, dynamic>?) ?? {};

      final houseNumber = _firstNonEmpty(address, ['house_number']);
      final road = _firstNonEmpty(address, [
        'road',
        'pedestrian',
        'street',
        'footway',
        'path',
      ]);
      final street = [
        houseNumber,
        road,
      ].where((part) => part.isNotEmpty).join(' ').trim();

      final sitio = _firstNonEmpty(address, [
        'hamlet',
        'isolated_dwelling',
        'allotments',
        'quarter',
        'neighbourhood',
      ]);

      final barangay = _firstNonEmpty(address, ['suburb', 'village']);
      final city = _firstNonEmpty(address, [
        'city',
        'town',
        'municipality',
        'county',
      ]);
      final province = _firstNonEmpty(address, ['state', 'region']);

      final parts = [
        street,
        sitio,
        barangay,
        city,
        province,
      ].where((part) => part.isNotEmpty).toList();

      return ResolvedFarmLocation(
        street: street,
        sitio: sitio,
        barangay: barangay,
        city: city,
        province: province,
        fullAddress: parts.join(', '),
      );
    } catch (_) {
      return const ResolvedFarmLocation(
        street: '',
        sitio: '',
        barangay: '',
        city: '',
        province: '',
        fullAddress: '',
      );
    }
  }
}

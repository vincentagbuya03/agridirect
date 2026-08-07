import 'package:flutter/material.dart';

class ConsumerRadarView extends StatelessWidget {
  final double lat;
  final double lon;

  const ConsumerRadarView({super.key, required this.lat, required this.lon});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Live Weather Radar is only available on Web.'));
  }
}

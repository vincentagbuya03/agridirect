import 'package:flutter/material.dart';
import '../../../shared/models/weather_model.dart';

class WebWeatherRadarScreen extends StatefulWidget {
  final WeatherData? weatherData;
  final double? farmLatitude;
  final double? farmLongitude;
  final String? farmLocationName;
  final VoidCallback onBack;
  final bool isConsumerMode;

  const WebWeatherRadarScreen({
    super.key,
    required this.weatherData,
    this.farmLatitude,
    this.farmLongitude,
    this.farmLocationName,
    required this.onBack,
    this.isConsumerMode = false,
  });

  @override
  State<WebWeatherRadarScreen> createState() => _WebWeatherRadarScreenState();
}

class _WebWeatherRadarScreenState extends State<WebWeatherRadarScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weather Radar'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'Live Weather Radar is only available on Web.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}

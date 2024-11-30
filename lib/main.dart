import 'package:flutter/material.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;
import 'package:background_fetch/background_fetch.dart';
import 'dart:math';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: LocationScreen(),
    );
  }
}

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  _LocationScreenState createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  String _locationText = "Waiting for location updates...";
  final List<Map<String, dynamic>> _locationHistory = [];
  Map<String, double>? _lastLocation;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  void _initializeServices() {
    // Initialize Background Geolocation
    bg.BackgroundGeolocation.ready(bg.Config(
      desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
      distanceFilter: 5.0,
      stopOnTerminate: false,
      startOnBoot: true,
      enableHeadless: true,
      logLevel: bg.Config.LOG_LEVEL_VERBOSE,
      debug: true,
    )).then((bg.State state) {
      if (!state.enabled) {
        bg.BackgroundGeolocation.start();
      }
    });

    // Listen for location updates
    bg.BackgroundGeolocation.onLocation((bg.Location location) {
      _submitAndUpdateUI(location);
    });

    // Listen for motion changes
    bg.BackgroundGeolocation.onMotionChange((bg.Location location) {
      _submitAndUpdateUI(location);
    });

    // Initialize Background Fetch
    BackgroundFetch.configure(
      BackgroundFetchConfig(
        minimumFetchInterval: 15,
        stopOnTerminate: false,
        startOnBoot: true,
        enableHeadless: true,
      ),
      (String taskId) async {
        bg.BackgroundGeolocation.getCurrentPosition(
          samples: 1,
          persist: false,
        ).then((bg.Location location) {
          _submitAndUpdateUI(location);
        });
        print("***Background Fetch Concluded***");
        BackgroundFetch.finish(taskId);
      },
      (String taskId) async {
        print("***Background Fetch Timed Out***");
        BackgroundFetch.finish(taskId);
      },
    );
  }

  double _calculateDistance(lat1, lon1, lat2, lon2) {
    const earthRadius = 6371000; // in meters
    final dLat = (lat2 - lat1) * pi / 180.0;
    final dLon = (lon2 - lon1) * pi / 180.0;

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180.0) *
            cos(lat2 * pi / 180.0) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  Future<void> _submitAndUpdateUI(bg.Location location) async {
    final newLocation = {
      "latitude": location.coords.latitude,
      "longitude": location.coords.longitude,
    };

    double? distance;
    if (_lastLocation != null) {
      // Calculate the distance between the last and the new location
      distance = _calculateDistance(
        _lastLocation!["latitude"]!,
        _lastLocation!["longitude"]!,
        newLocation["latitude"]!,
        newLocation["longitude"]!,
      );

      if (distance < 25) {
        print("Location update skipped: Distance $distance meters.");
        return;
      }
      print("New location added: Distance $distance meters.");
    }

    // If distance from last is greater than X submit to API

    // Update UI with the new location
    setState(() {
      _locationText =
          "Latitude: ${location.coords.latitude}, Longitude: ${location.coords.longitude}";
      _locationHistory.add({
        "latitude": location.coords.latitude,
        "longitude": location.coords.longitude,
        "timestamp": location.timestamp,
        "distance": distance?.toStringAsFixed(2), // Add distance as a string
      });
      _lastLocation = newLocation; // Update the last known location
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Location Tracker')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _locationText,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Location History:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _locationHistory.length,
              itemBuilder: (context, index) {
                final location = _locationHistory[index];
                final distance = location["distance"];
                return ListTile(
                  title: Text(
                      "Lat: ${location['latitude']}, Lng: ${location['longitude']}"),
                  subtitle: Text(
                    "Timestamp: ${location['timestamp']}${distance != null ? ', Distance: $distance m' : ''}",
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

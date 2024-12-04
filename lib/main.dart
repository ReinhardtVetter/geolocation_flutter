import 'package:flutter/material.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;
import 'dart:math';
import 'dart:convert'; // For JSON encoding
import 'package:http/http.dart' as http; // For API requests
import 'package:background_fetch/background_fetch.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: UsernameScreen(),
    );
  }
}

class UsernameScreen extends StatefulWidget {
  const UsernameScreen({super.key});

  @override
  _UsernameScreenState createState() => _UsernameScreenState();
}

class _UsernameScreenState extends State<UsernameScreen> {
  final TextEditingController _usernameController = TextEditingController();

  void _submitUsername() {
    final username = _usernameController.text.trim();
    if (username.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LocationScreen(username: username),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a username')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter Username')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _submitUsername,
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}

class LocationScreen extends StatefulWidget {
  final String username;

  const LocationScreen({super.key, required this.username});

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

    // ** LOG INITIALIZE SERVICES **
    setState(() {
      _locationText = "Welcome User: ${widget.username}";
      _locationHistory.add({
        "latitude": "**",
        "longitude": "**",
        "timestamp": "**",
        "distance": "INITIALIZE SERVICES",
      });
    });

    // Distance interval set distanceFilter to value in meters AND add disableElasticity:true to ensure this value does not dynamically change
    // If using time interval use locationUpdateInterval: 1 * 60 * 1000,, set distanceFilter to 0 and remove disableElasticity:true
    // IMPORTANT: locationUpdateInterval only works on Android - we should stick to distanceFilter for both iOS and Android
    // IMPORTANT: define value of distanceFilter as a double by adding .0
    // IMPORTANT: Have to be on the same wifi for flutter and XCode to run app on phone, but can disconnect from WIFI once running
    // IMPORTANT: noticed the location is wonky on WIFI but on mobile network it works well
    // IMPORTANT: useSignificantChangesOnly seems like our best bet:
    // https://pub.dev/documentation/flutter_background_geolocation/latest/flt_background_geolocation/Config/useSignificantChangesOnly.html
    bg.BackgroundGeolocation.ready(bg.Config(
      desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
      useSignificantChangesOnly: true,
      distanceFilter: 1000,
      disableElasticity:true,
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

    // ** LOG INITIALIZE SERVICES **
    setState(() {
      _locationHistory.add({
        "latitude": "**",
        "longitude": "**",
        "timestamp": "**",
        "distance": "SUBSCRIBED TO LOCATION CHANGES",
      });
    });
    bg.BackgroundGeolocation.onLocation((bg.Location location) {
      _submitAndUpdateUI(location);
    });
  }

  Future<void> _submitAndUpdateUI(bg.Location location) async {
    final newLocation = {
      "latitude": location.coords.latitude,
      "longitude": location.coords.longitude,
    };

    double? distance;
    if (_lastLocation != null) {
      distance = _calculateDistance(
        _lastLocation!["latitude"]!,
        _lastLocation!["longitude"]!,
        newLocation["latitude"]!,
        newLocation["longitude"]!,
      );

      if (distance >= 999) {

        setState(() {
          _locationHistory.add({
            "latitude": location.coords.latitude,
            "longitude": location.coords.longitude,
            "timestamp": location.timestamp,
            "distance": distance,
          });
          _lastLocation = newLocation;
        });

        // Prepare the API payload
        final payload = {
          "username": widget.username, // Pass the username
          "latitude": location.coords.latitude.toString(),
          "longitude": location.coords.longitude.toString(),
          "distFromLast": distance?.toStringAsFixed(1) ??
              "0.0", // Default to 0.0 if distance is null
          "datetime": DateTime.now()
              .toIso8601String(), // Current timestamp in ISO format
        };

        // API URL
        const apiUrl =
            "https://apiuat-dfait.msappproxy.net/geo-technician/api/v1/locationDetail/register";

        // Basic Authentication credentials (use placeholder values for now)
        const username =
            "3d7fc068-3cd4-49c5-86ff-e162eba9ee78"; // Replace with your actual username
        const password =
            "xg~8Q~b~X6t.~EdxoBKfMrv8KNFRdXzBpLJf2bK3"; // Replace with your actual password
        final basicAuth =
            'Basic ' + base64Encode(utf8.encode('$username:$password'));

        try {
          // Make the API request
          final response = await http.post(
            Uri.parse(apiUrl),
            headers: {
              "Content-Type": "application/json",
              "Authorization": basicAuth,
            },
            body: jsonEncode(payload),
          );

          // Check the API response status
          if (response.statusCode == 200) {
            setState(() {
              _locationHistory.add({
                "latitude": "**",
                "longitude": "**",
                "timestamp": "API POST SUCCESS",
                "distance": "RESULT IS: ${response.statusCode}",
              });
            });
          } else {
            setState(() {
              _locationHistory.add({
                "latitude": "**",
                "longitude": "**",
                "timestamp": "API POST FAILED",
                "distance": "RESPONSE BODY: ${response.body}",
              });
            });
          }
        } catch (e) {
          setState(() {
            _locationHistory.add({
              "latitude": "**",
              "longitude": "**",
              "timestamp": "API POST",
              "distance": "ERROR OCCURRED: $e",
            });
          });
        }
      }
    } else {
      setState(() {
        _locationHistory.add({
          "latitude": location.coords.latitude,
          "longitude": location.coords.longitude,
          "timestamp": location.timestamp,
          "distance": "STARTING LOCATION",
        });
        _lastLocation = newLocation;
      });
    }
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
              'Location History V2:',
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

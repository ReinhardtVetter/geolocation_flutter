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
          "distFromLast": distance.toStringAsFixed(1),
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








/***************************** webview screen created ***********************/

import 'package:flutter/material.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;
import 'dart:math';
import 'dart:convert'; // For JSON encoding
import 'package:http/http.dart' as http; // For API requests
import 'package:background_fetch/background_fetch.dart';
import 'package:webview_flutter/webview_flutter.dart';

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

class webviewScreen extends StatefulWidget {
  const webviewScreen({super.key});

  @override
  _webviewScreenState createState() => _webviewScreenState();
}

class _webviewScreenState extends State<webviewScreen> {
  var controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setNavigationDelegate(
      NavigationDelegate(
        onProgress: (int progress) {
          // Update loading bar.
        },
        onPageStarted: (String url) {},
        onPageFinished: (String url) {},
        onHttpError: (HttpResponseError error) {},
        onWebResourceError: (WebResourceError error) {},
        onNavigationRequest: (NavigationRequest request) {
          if (request.url.startsWith('https://www.youtube.com/')) {
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ),
    )
    ..loadRequest(Uri.parse('https://flutter.dev'));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flutter Simple Example')),
      body: WebViewWidget(controller: controller),
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
      disableElasticity: true,
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
          "distFromLast": distance.toStringAsFixed(1),
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





***********************************
***********************************
***********************************
***********************************
***********************************
***********************************
***********************************
***********************************




import 'package:flutter/material.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;
import 'dart:math';
import 'dart:convert'; // For JSON encoding
import 'package:http/http.dart' as http; // For API requests
import 'package:background_fetch/background_fetch.dart';
import 'package:webview_flutter/webview_flutter.dart';

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

class webviewScreen extends StatefulWidget {
  final String username;

  const webviewScreen({super.key, required this.username});

  @override
  _webviewScreenState createState() => _webviewScreenState();
}

class _webviewScreenState extends State<webviewScreen> {
  late final WebViewController controller;
  bool _ssoReached = false;

  @override
  void initState() {
    super.initState();
    _showWebview();
  }

  void _showWebview() {
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {},
          onPageStarted: (String url) {},
          onPageFinished: (String url) {
            // Check if the WebView reached the target URL
            if (url.contains('https://d3w44ipqagcsvn.cloudfront.net') ||
                url.startsWith('https://d3w44ipqagcsvn.cloudfront.net')) {
              //Navigator.pop(context); // Close the WebView
              setState(() {
                _ssoReached = true;
              });
            }
          },
          onHttpError: (HttpResponseError error) {},
          onWebResourceError: (WebResourceError error) {},
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(
        'https://login.microsoftonline.com/60fcf832-af35-4960-9056-4d242cb86b7c/saml2?SAMLRequest=jZLfS8MwEMffBf%2BHkfe2add1W9gGZUMYqMj88eCLZOlVA2muy6VO%2F3u7DnGKFUNecrn7fu6by4xkZWqRN%2F7FbmDXAPnBW2Usie5izhpnBUrSJKysgIRX4ja%2FuhRJyEXt0KNCw87PBr%2Bs9WrOnuRWFVDGyTAdZePJlP8899Q%2BgCONds5aTp88UQNrS15a3%2BbxJA3iOODpXZwIztv92FO4ak1qK32n%2F%2BJ9TSKKDD5rG1ZaOSQsPVqjLYQKqyjjpSonwySQ5XAUpNOMB1M%2ByoK0SNJEbSfZdqyiw2slPbycCNyBtkRLTQXuFtyrVnC%2FufziF8N9mup6J58VvdpQGWyK0qH1oQXPFkfl2QEjOuPuZEx%2FT0l%2B4tniE0aewr22Be7pIP8%2Fi7PohH7aUC2uW%2Bh6dYNGq%2FfBBbpK%2Bv6e4jDuIroIyi5VQCW1yYvCAREb5MbgfulAepgz7xpgUUs70r%2F%2F1MUH&login_hint=${widget.username}',
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flutter Simple Example')),
      body: WebViewWidget(controller: controller),
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
          builder: (context) => webviewScreen(username: username),
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
                labelText: 'Azure AD Username for SSO',
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
      disableElasticity: true,
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
          "distFromLast": distance.toStringAsFixed(1),
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

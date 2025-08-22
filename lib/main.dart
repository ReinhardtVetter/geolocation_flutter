import 'package:flutter/material.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;
import 'dart:math';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:background_fetch/background_fetch.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:io';

void main() {
  runApp(const MainApp());
  BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);
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

// Background Fetch headless task handler
void backgroundFetchHeadlessTask(String taskId) async {
  await performBackgroundTask();
  BackgroundFetch.finish(taskId);
}

Future<void> performBackgroundTask() async {
  try {
    bg.Location location = await bg.BackgroundGeolocation.getCurrentPosition(
      persist: false,
    );
    await LocationScreen.updateUIWithLocation(location);
  } catch (e) {

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

  @override
  void initState() {
    super.initState();
    _showWebview();
  }

  void _showWebview() {
    final currentDate = DateTime.now();
    final timestamp = currentDate.toUtc().toIso8601String();
    final formattedTimestamp = timestamp.split('.')[0] + 'Z';

    String id = "_abcdef1234567890abcdef1234567890";
    String destination = "https://login.microsoftonline.com/60fcf832-af35-4960-9056-4d242cb86b7c/saml2";
    String assertionConsumerServiceURL = "https://d3w44ipqagcsvn.cloudfront.net";
    String issuer = "https://sts.windows.net/60fcf832-af35-4960-9056-4d242cb86b7c/";
    String nameIDPolicyFormat = "urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress";
    String ssoURLdecoded = '''
    <samlp:AuthnRequest xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol"
                    ID="$id"
                    Version="2.0"
                    IssueInstant="$formattedTimestamp"
                    Destination="$destination"
                    AssertionConsumerServiceURL="$assertionConsumerServiceURL">
        <saml:Issuer xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion">$issuer</saml:Issuer>
        <samlp:NameIDPolicy Format="$nameIDPolicyFormat" AllowCreate="true"/>
    </samlp:AuthnRequest>
    ''';
    // Convert the input string to bytes
    Uint8List inputBytes = utf8.encode(ssoURLdecoded);
    // Compress (deflate) the bytes using Zlib
    List<int> deflatedBytes = ZLibCodec(raw: true).encode(inputBytes);
    // Base64 encode the deflated bytes
    String base64Encoded = base64.encode(deflatedBytes);
    // URI Encode
    String ssoURIEncoded = Uri.encodeComponent(base64Encoded);
    
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (url == 'https://d3w44ipqagcsvn.cloudfront.net' ||
                url.contains('https://d3w44ipqagcsvn.cloudfront.net') ||
                url.startsWith('https://d3w44ipqagcsvn.cloudfront.net')) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      LocationScreen(username: widget.username),
                ),
              );
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(
        'https://login.microsoftonline.com/60fcf832-af35-4960-9056-4d242cb86b7c/saml2?SAMLRequest=$ssoURIEncoded&login_hint=${widget.username}',
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
      /*Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LocationScreen(username: username),
        ),
      );*/
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

  // Static method to update UI with location during background tasks
  static Future<void> updateUIWithLocation(bg.Location location) async {
    // Create a mock context for location update during background fetch
    final _LocationScreenState? state =
        _LocationScreenState.currentInstance; // Access the singleton instance
    if (state != null) {
      await state._submitAndUpdateUI(location);
    }
  }
}

class _LocationScreenState extends State<LocationScreen> {
  static _LocationScreenState? currentInstance;
  String _locationText = "Waiting for location updates...";
  final List<Map<String, dynamic>> _locationHistory = [];
  Map<String, double>? _lastLocation;

  @override
  void initState() {
    super.initState();
    currentInstance = this; // Assign singleton instance
    _initializeServices();
    BackgroundFetch.configure(
      BackgroundFetchConfig(
        minimumFetchInterval: 15,
        stopOnTerminate: false,
        startOnBoot: true,
        enableHeadless: true,
      ),
      (taskId) async {
        await performBackgroundTask();
        BackgroundFetch.finish(taskId);
      },
      (taskId) async {
        BackgroundFetch.finish(taskId);
      },
    ).then((status) {

    }).catchError((e) {

    });
  }

  @override
  void dispose() {
    currentInstance = null; // Clear singleton instance
    super.dispose();
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
      appBar: AppBar(title: const Text('Location Tracker'), automaticallyImplyLeading: false),
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
              'Location History V3:',
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

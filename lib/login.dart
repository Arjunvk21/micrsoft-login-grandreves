import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart'; // Ensure this package is in pubspec.yaml

class MicrosoftLoginPage extends StatefulWidget {
  @override
  _MicrosoftLoginPageState createState() => _MicrosoftLoginPageState();
}

class _MicrosoftLoginPageState extends State<MicrosoftLoginPage> {
  String? accessToken;
  String? authCode;
  String? codeVerifier;
  String? codeChallenge;
  final tenantid = 'b3561463-08b6-4c31-8ca6-eb063f60dd24';
  final String clientId = '326cd96d-45d2-4569-b22c-daad062af497';
  final String redirectUri =
      'http://localhost:53518/'; // Use HTTPS in production
  //     late final String authorizationEndpoint;
  // late final String tokenEndpoint;

  final String authorizationEndpoint =
      'https://login.microsoftonline.com/b3561463-08b6-4c31-8ca6-eb063f60dd24/v2.0/authorize';
  final tokenEndpoint =
      'https://login.microsoftonline.com/b3561463-08b6-4c31-8ca6-eb063f60dd24/oauth2/v2.0/token';

  // final String authorizationEndpoint =
  //     'https://login.microsoftonline.com\$tenantid/oauth2/v2.0/authorize';
  // final String tokenEndpoint =
  //     'https://login.microsoftonline.com/\$tenantid/oauth2/v2.0/token';

  final List<String> scopes = [
    'User.Read',
    'Calendars.Read',
    'Calendars.ReadWrite',
    'Calendars.ReadBasic',
  ];

  final _formKey = GlobalKey<FormState>();
  String emailOrPhone = '';
  String password = '';

  String generateCodeVerifier() {
    final Random random = Random.secure();
    final bytes = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url
        .encode(bytes)
        .replaceAll('=', '')
        .replaceAll('+', '-')
        .replaceAll('/', '_');
  }

  String generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final hashedBytes = sha256.convert(bytes).bytes;
    return base64Url
        .encode(hashedBytes)
        .replaceAll('=', '')
        .replaceAll('+', '-')
        .replaceAll('/', '_');
  }

  Future<void> loginWithMicrosoft() async {
    try {
      codeVerifier = generateCodeVerifier();
      codeChallenge = generateCodeChallenge(codeVerifier!);

      // Store codeVerifier in local storage
      html.window.localStorage['code_verifier'] = codeVerifier!;

      final authorizationUrl =
          '$authorizationEndpoint?client_id=$clientId&response_type=code&redirect_uri=$redirectUri&response_mode=query&scope=${Uri.encodeComponent(scopes.join(" "))}&code_challenge=$codeChallenge&code_challenge_method=S256';

      // final authorizationUrl =
      //     '$authorizationEndpoint?client_id=$clientId&response_type=code&redirect_uri=$redirectUri&response_mode=query&scope=${scopes.join(" ")}&code_challenge=$codeChallenge&code_challenge_method=S256';

      html.window.location.href = authorizationUrl;
    } catch (e) {
      print('Error during login: $e');
    }
  }

  Future<void> handleAuthorizationCode() async {
    final uri = Uri.base;
    if (uri.queryParameters.containsKey('code')) {
      authCode = uri.queryParameters['code'];
      print('Authorization code: $authCode');

      // Retrieve codeVerifier from local storage
      codeVerifier = html.window.localStorage['code_verifier'];

      // Call exchangeAuthorizationCodeForToken only if code and verifier are available
      if (authCode != null || codeVerifier != null) {
        await exchangeAuthorizationCodeForToken();
      } else {
        print('Authorization code or code verifier is missing');
      }
    } else if (uri.queryParameters.containsKey('error')) {
      print('Authorization error: ${uri.queryParameters['error_description']}');
    }
  }

  Future<void> exchangeAuthorizationCodeForToken() async {
    try {
      print('Exchanging authorization code for token...');
      print('Authorization Code: $authCode');
      print('Code Verifier: $codeVerifier');

      final response = await http.post(
        Uri.parse(tokenEndpoint),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'client_id': clientId,
          'scope': scopes.join(' '),
          'code': authCode!,
          'redirect_uri': redirectUri,
          'grant_type': 'authorization_code',
          'code_verifier': codeVerifier!,
        },
      );

      print('Token Response: ${response.body}');

      if (response.statusCode == 200) {
        final tokenResponse = jsonDecode(response.body);
        if (tokenResponse['access_token'] != null) {
          setState(() {
            accessToken = tokenResponse['access_token'];
            print('Access Token: $accessToken');
          });

          // Fetch user profile and calendar events after successful login
          final userProfile = await fetchUserProfile();
          final calendarEvents = await fetchEvents(); // Fetch events here

          // Navigate to HomePage with user profile and calendar events
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomePage(
                userProfile: userProfile,
                calendarEvents: calendarEvents,
              ),
            ),
          );
        } else {
          print('Access token is missing in the response.');
        }
      } else {
        print('Failed to exchange token. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('Error during token exchange: $e');
    }
  }

  Future<Map<String, dynamic>?> fetchUserProfile() async {
    if (accessToken == null) return null;

    final response = await http.get(
      Uri.parse('https://graph.microsoft.com/v1.0/me'),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final profile = jsonDecode(response.body);
      print('User Profile: ${profile.toString()}');
      return profile;
    } else {
      print(
          'Failed to fetch user profile. Status code: ${response.statusCode}');
      print('Response body: ${response.body}');
      return null;
    }
  }

  Future<List<dynamic>> fetchEvents() async {
    if (accessToken == null) return [];

    final response = await http.get(
      Uri.parse(
          'https://graph.microsoft.com/v1.0/me/events?\$select=subject,body,bodyPreview,organizer,attendees,start,end,location'), // Correct endpoint
      headers: {
        'Authorization':
            'Bearer EwCYA8l6BAAUbDba3x2OMJElkF7gJ4z/VbCPEz0AAQjcQeIEEq0M9RiPjCk8OVsG0+pit5hcMoqbqHsNLI1s8ODlfmKWzSq7kFMX/WJ6mD6287cSlkGLMDyHbwMx3Aosf6SVoSnklygzuYRxfL6MvKe73fAPy0u7Zre0C+8ytx+eX2gWY4lcyh9wwjcHBr+vWvwIhHzeD/mTqX64xojxjb6gOnbseHF+qkfDa0fEN/U57LNGyZV9wy8RJbgVDkmy316NV2iZLEeWJX7sxyh7DQeejsJehsf4i9CrY89rlWVnkSYBD4b9VPWnmL0oITdiwDrf7phFTLkgdAeHcxU2pe7ORg+TtVc7nCT7c/fZttfzUxzMJcFbCNRuGu8ESD8QZgAAEDbZt1SCymWe29+Y0SUbiV9gAnbqhgqBVsC9/w0HrOd2zpNQS6e6ioq4/mF68YFFeqKTi+8IiezVw2+5NlQOu6YoENH4bfsF4gz2X8BZ/n5Gm6Tm8nhEp9+CMY8YGEvfA8u97zce9D7rKk/N2LD83GTx7pv2ts4gpyfyNVFn3c89469wB/x5hjk68Ec53lQMSGcf4R0OWEEDT8iFfXNqSf7DhnUJGfLGIbZncFYnxF17DTcrfK7mcasRH5HVotLCwRQilmCwwzfytxv2FpxPlH4jUihPrWbaBncRX13uGsn8+rSQulBB/x/6qKVnWMeUrfwgomnNRguXCpYNbGut5D7c6ypDRs3zPFOnKkLrDrqgBzYOhB24AuUcWX45WG9XEeoilpWaWeH1Sc6Td32iIUPJkk3++Ww5pFB93DdySZtFiepAMOo9aqfVchhiYse4LUSpNyE4101fouVVPH6XLB5sEgYlWZ2T0rc+cUr2E/qLI+xsgUQnS8asj0pY56rA8COA8gBQJh2R9xspcwuMvnNVMJJ5NOBJwZED/bsvRUE7xrulpNHd/pDhw3ysEMpr+DXpV2C1f3grI/qdjqvp//1JeBpLvOZNVVBf4rEfy2nhA/zN72Jq53/P7zzZ5m/I+/ry+WrYUdrbvI0iekigtkqHZOtzwCoscpXHhB0nSiS5qGdAeaOOblVqZBpKJSS70cV0Ir9EoD9GvqeF9CfE5J4uQz1zpvmaMbGvsoCtHQ5Lrm1+UCG9PTPV8GVuk6VjPXIQwebB4z7JMgbEf+RAbo79uFRzo0VkjcvPV6C72BkRhFt26g+dJg91AUpSaoYELCQooAI=',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      print('${response.body}');
      print('Calendar Events: ${data['value']}');
      return data['value'] ?? [];
    } else {
      print('Failed to load calendar events: ${response.statusCode}');
      print('Response body: ${response.body}');
      return [];
    }
  }

  @override
  void initState() {
    super.initState();
    handleAuthorizationCode();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Microsoft Login'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Center(
          child: SingleChildScrollView(
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Sign In',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        onChanged: (value) {
                          emailOrPhone = value;
                        },
                        decoration: InputDecoration(
                          labelText: 'Email or Phone Number',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Colors.blueAccent),
                          ),
                          prefixIcon: const Icon(Icons.person),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email or phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        onChanged: (value) {
                          password = value;
                        },
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Colors.blueAccent),
                          ),
                          prefixIcon: const Icon(Icons.lock),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            // Trigger login logic here
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.blueAccent,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Sign In'),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: loginWithMicrosoft,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightBlueAccent,
                          padding: const EdgeInsets.symmetric(
                              vertical: 16.0, horizontal: 32.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.network(
                              'https://img.icons8.com/color/48/000000/microsoft.png',
                              width: 24,
                              height: 24,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Sign in with Microsoft',
                              style:
                                  TextStyle(fontSize: 16, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'By signing in, you agree to our Terms of Service and Privacy Policy.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  final Map<String, dynamic>? userProfile;
  final List<dynamic> calendarEvents;

  HomePage({required this.userProfile, required this.calendarEvents});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            userProfile != null
                ? Text(
                    'Welcome, ${userProfile!['displayName']}',
                    style: const TextStyle(fontSize: 24),
                  )
                : Container(),
            const SizedBox(height: 20),
            const Text('Calendar Events:', style: TextStyle(fontSize: 20)),
            Expanded(
              child: ListView.builder(
                itemCount: calendarEvents.length,
                itemBuilder: (context, index) {
                  final event = calendarEvents[index];
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      title: Text(
                        event['subject'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Starts at: ${event['start']['dateTime']}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) {
              return EventDialog(onSubmit: (
                String title,
                String bodyContent,
                String startDate,
                String endDate,
                String location,
              ) {
                postEvent(title, bodyContent, startDate, endDate, location);
              });
            },
          );
        },
        child: Icon(Icons.add),
      ),
    );
  }
}

Future<void> postEvent(
  String title,
  String bodyContent,
  String startDateTime,
  String endDateTime,
  String location,
) async {
  String accessToken =
      "EwCYA8l6BAAUbDba3x2OMJElkF7gJ4z/VbCPEz0AAQjcQeIEEq0M9RiPjCk8OVsG0+pit5hcMoqbqHsNLI1s8ODlfmKWzSq7kFMX/WJ6mD6287cSlkGLMDyHbwMx3Aosf6SVoSnklygzuYRxfL6MvKe73fAPy0u7Zre0C+8ytx+eX2gWY4lcyh9wwjcHBr+vWvwIhHzeD/mTqX64xojxjb6gOnbseHF+qkfDa0fEN/U57LNGyZV9wy8RJbgVDkmy316NV2iZLEeWJX7sxyh7DQeejsJehsf4i9CrY89rlWVnkSYBD4b9VPWnmL0oITdiwDrf7phFTLkgdAeHcxU2pe7ORg+TtVc7nCT7c/fZttfzUxzMJcFbCNRuGu8ESD8QZgAAEDbZt1SCymWe29+Y0SUbiV9gAnbqhgqBVsC9/w0HrOd2zpNQS6e6ioq4/mF68YFFeqKTi+8IiezVw2+5NlQOu6YoENH4bfsF4gz2X8BZ/n5Gm6Tm8nhEp9+CMY8YGEvfA8u97zce9D7rKk/N2LD83GTx7pv2ts4gpyfyNVFn3c89469wB/x5hjk68Ec53lQMSGcf4R0OWEEDT8iFfXNqSf7DhnUJGfLGIbZncFYnxF17DTcrfK7mcasRH5HVotLCwRQilmCwwzfytxv2FpxPlH4jUihPrWbaBncRX13uGsn8+rSQulBB/x/6qKVnWMeUrfwgomnNRguXCpYNbGut5D7c6ypDRs3zPFOnKkLrDrqgBzYOhB24AuUcWX45WG9XEeoilpWaWeH1Sc6Td32iIUPJkk3++Ww5pFB93DdySZtFiepAMOo9aqfVchhiYse4LUSpNyE4101fouVVPH6XLB5sEgYlWZ2T0rc+cUr2E/qLI+xsgUQnS8asj0pY56rA8COA8gBQJh2R9xspcwuMvnNVMJJ5NOBJwZED/bsvRUE7xrulpNHd/pDhw3ysEMpr+DXpV2C1f3grI/qdjqvp//1JeBpLvOZNVVBf4rEfy2nhA/zN72Jq53/P7zzZ5m/I+/ry+WrYUdrbvI0iekigtkqHZOtzwCoscpXHhB0nSiS5qGdAeaOOblVqZBpKJSS70cV0Ir9EoD9GvqeF9CfE5J4uQz1zpvmaMbGvsoCtHQ5Lrm1+UCG9PTPV8GVuk6VjPXIQwebB4z7JMgbEf+RAbo79uFRzo0VkjcvPV6C72BkRhFt26g+dJg91AUpSaoYELCQooAI="; // Replace with your actual token
  if (accessToken.isEmpty) return;

  final Map<String, dynamic> eventData = {
    "subject": title,
    "body": {"contentType": "HTML", "content": bodyContent},
    "start": {"dateTime": startDateTime, "timeZone": "Pacific Standard Time"},
    "end": {"dateTime": endDateTime, "timeZone": "Pacific Standard Time"},
    "location": {"displayName": location},
    "allowNewTimeProposals": true,
  };

  final response = await http.post(
    Uri.parse('https://graph.microsoft.com/v1.0/me/events'),
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
      'Prefer': 'outlook.timezone="Pacific Standard Time"',
    },
    body: jsonEncode(eventData),
  );

  if (response.statusCode == 201) {
    print('Event created successfully');
  } else {
    print('Failed to create event: ${response.statusCode}');
    print('Response body: ${response.body}');
  }
}

class EventDialog extends StatefulWidget {
  final Function(String title, String bodyContent, String startDate,
      String endDate, String location) onSubmit;

  EventDialog({required this.onSubmit});

  @override
  _EventDialogState createState() => _EventDialogState();
}

class _EventDialogState extends State<EventDialog> {
  final _formKey = GlobalKey<FormState>();
  String eventTitle = '';
  String eventBody = '';
  DateTime eventStartDate = DateTime.now();
  DateTime eventEndDate = DateTime.now();
  String eventLocation = '';

  String _formatDate(DateTime date) {
    return DateFormat("yyyy-MM-ddTHH:mm:ss").format(date);
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: eventStartDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != eventStartDate) {
      setState(() {
        eventStartDate = picked;
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: eventEndDate,
      firstDate: eventStartDate,
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != eventEndDate) {
      setState(() {
        eventEndDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Create Event"),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: InputDecoration(labelText: "Event Title"),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an event title';
                  }
                  return null;
                },
                onSaved: (value) {
                  eventTitle = value!;
                },
              ),
              TextFormField(
                decoration: InputDecoration(labelText: "Event Body"),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter event details';
                  }
                  return null;
                },
                onSaved: (value) {
                  eventBody = value!;
                },
              ),
              ListTile(
                title: Text(
                    "Start Date: ${DateFormat('yyyy-MM-dd').format(eventStartDate)}"),
                trailing: Icon(Icons.calendar_today),
                onTap: () => _selectStartDate(context),
              ),
              ListTile(
                title: Text(
                    "End Date: ${DateFormat('yyyy-MM-dd').format(eventEndDate)}"),
                trailing: Icon(Icons.calendar_today),
                onTap: () => _selectEndDate(context),
              ),
              TextFormField(
                decoration: InputDecoration(labelText: "Location"),
                onSaved: (value) {
                  eventLocation = value!;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          child: Text("Cancel"),
          onPressed: () => Navigator.of(context).pop(),
        ),
        ElevatedButton(
          child: Text("Create"),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();

              // Format the dates for the API
              final startDate = _formatDate(eventStartDate);
              final endDate = _formatDate(eventEndDate);

              widget.onSubmit(
                eventTitle,
                eventBody,
                startDate,
                endDate,
                eventLocation,
              );
              Navigator.of(context).pop();
            }
          },
        ),
      ],
    );
  }
}

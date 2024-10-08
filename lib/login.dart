import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart'; // Ensure this package is in pubspec.yaml

class MicrosoftLoginPage extends StatefulWidget {
  @override
  _MicrosoftLoginPageState createState() => _MicrosoftLoginPageState();
}

class _MicrosoftLoginPageState extends State<MicrosoftLoginPage> {
  String? accessToken;
  String? authCode;
  String? codeVerifier;
  String? codeChallenge;
  final tenantid = 'fb7834ec-ee45-4353-9655-0496df9120e0';
  final String clientId = '925af6e0-4cc9-4657-bc67-22c1401cd99e';
  final String redirectUri =
      'http://localhost:53518/'; // Use HTTPS in production
  final String authorizationEndpoint =
      'https://login.microsoftonline.com/fb7834ec-ee45-4353-9655-0496df9120e0/oauth2/v2.0/authorize';
  final String tokenEndpoint =
      'https://login.microsoftonline.com/fb7834ec-ee45-4353-9655-0496df9120e0/oauth2/v2.0/token';

  final List<String> scopes = [
    'User.Read',
    'Calendars.Read',
    'Calendars.ReadWrite'
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
          '$authorizationEndpoint?client_id=$clientId&response_type=code&redirect_uri=$redirectUri&response_mode=query&scope=${scopes.join(" ")}&code_challenge=$codeChallenge&code_challenge_method=S256';

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
  // Future<void> signInWithMicrosoft() async {
  //   try {
  //     // Initialize the MSAL client
  //     final msal = MsalFlutter(
  //       clientId: clientId,
  //       authority: 'https://login.microsoftonline.com/$tenantid',
  //       redirectUri: redirectUri,
  //     );

  //     // Sign in the user
  //     final result = await msal.acquireToken(
  //       scopes: ['User.Read', 'Calendars.Read'], // Request the necessary scopes
  //     );

  //     setState(() {
  //       accessToken = result.accessToken; // Get the access token
  //     });

  //     print('Access Token: $accessToken');

  //     // Fetch calendar events after signing in
  //     await fetchEvents(accessToken!);
  //   } catch (e) {
  //     print('Error signing in: $e');
  //   }
  // }

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
            'Bearer EwCIA8l6BAAUbDba3x2OMJElkF7gJ4z/VbCPEz0AAYS1f7iRUldP6q6Y8jaDNE7RIbBEAiv315k4ZH7rl2OlXhPpmU/OfcCzN0B44/kLuJJdRIsTpiPYlDkZphs3ehHXndZKpJqfBdTzXiHjBmP9+VN5KN6KS4gJASklwGtgB2PckRrHmpJ0FdQdAqY5f2WbGiFNRXSjz0eoN4f8APAOdHUJlZkiozJOCDjFYCoJmtxsEtwnlkwY2CB7C0ePpOKV8G+H6P52U+5YNiMCIuMZj44cVHiEdpL/m7ZZxTnFCMfoaQN0tEdnOVzMWNtp12Km6+lrbg+EGZF+LNR/nLCzgfwIW9LaJ13QUdJvvo9d3lAkt7jjvvTFOD4oZPwsnkcQZgAAEMbkEBFkyw8sSMELrIQtzndQArZ7Oo0/I6ugv5tG7I+Fmf2JngG8dk89ldtkY7RY1SBztuuoAiHOd/JfO/h0+ppV6dDcyP3tlR66ScNmFFjboDmuhV+yzTz1rZ2XbPS1j9ND7Yu/NKXuT/g9+HR1S/iTkfe5L5ZJXTDO3CF2juGVzNUzAfgzGTP9NOTcboSm21vfpdszZ349RMsmER5s1ob47t4RquL0TO0ujs6vhXIt403rIzmW6i5rC2qXJy6ZwVgFmUcCgD1yWu7iOYwGwn1i6eWZYd7wgUXUSovYcE5p+nimCpTTeNNGam9mEvI+priqKn/gztSz6CkN49nncMXfnqXEJsqAPp4AsUOqIJKhWTxhFWzDYJwvwK8xR8oWDyIHK6yWQGTTLgtGrBESxb6fR1XVlW0g2el+BpHvdy995taX7bJmp4mqphqtEPdXOy5e6ElouA/Zm7t+s9F2a2V2BpsWWsddgaE2/9JR5qXDQTSwP8zF0w/gPmRVQl5zU2Gx+iStloHBfQOZTJPAtEkS8BU5kyzQ4ExM9oS5flssFF44UFToPG8dRjYUgc21YMrrqCEWwbcS9RWq+ctA4H7iYy42ncuXRhQkl1B1JdHq3OZ1Gtc/imYisD7sEughWnRKAfdYHGh0vu4u/3Hz7eNGtcoROPJqQfXpuE+maNsCHN+O23+Z/IJFxqk+lI069y+0YNI8sqMNZgv98Mf0Cx5DpYqN7hzxO5/a71oicbMMd5D/eFDkK6SdrTA3Nf1H8/2dZEttNHuEwtW0n1B0jTA9lyqi4vBQHfCwRvs0zfNGMKeUAg==',
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
                        child: const Text('Sign In'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.blueAccent,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
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
                ? Text('Welcome, ${userProfile!['displayName']}',
                    style: const TextStyle(fontSize: 24))
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
                      title: Text(event['subject'],
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Starts at: ${event['start']['dateTime']}',
                          style: const TextStyle(color: Colors.grey)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

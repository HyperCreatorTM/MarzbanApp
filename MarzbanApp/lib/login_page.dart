import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:io';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final _storage = FlutterSecureStorage();

  bool _isLoading = false;
  String _errorMessage = '';

  // ----- BU, DOGRU FONKSIYON (/dashboard VE /alpha DESTEKLEYEN) -----
  String _validateAndCleanUrl(String url) {
    String newUrl = url.trim();
    if (newUrl.isEmpty) {
      _errorMessage = 'URL boş olamaz.';
      return '';
    }

    if (!newUrl.startsWith('http://') && !newUrl.startsWith('https://')) {
      newUrl = 'https://$newUrl';
    }

    try {
      // /#/login gibi kısımları temizle
      if (newUrl.contains('#')) {
        newUrl = newUrl.split('#')[0];
      }

      // Sondaki / işaretlerini temizle
      while (newUrl.endsWith('/')) {
        newUrl = newUrl.substring(0, newUrl.length - 1);
      }

      Uri.parse(newUrl);

      // Temizlenmiş URL'yi döndür (örn: https://orgtmshop.online/dashboard)
      return newUrl;
    } catch (e) {
      _errorMessage = 'Geçersiz URL formatı.';
      return '';
    }
  }
  // --------------------------------------------------

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    // DOGRU FONKSIYONU ÇAĞIR
    final String baseUrl = _validateAndCleanUrl(_urlController.text);
    if (baseUrl.isEmpty) {
      setState(() {
        _isLoading = false;
        if (_errorMessage.isEmpty) _errorMessage = 'URL formaty nädogry.';
      });
      return;
    }

    // DOGRU YOL: .../dashboard/api/admin/token (sonda / YOK)
    final uri = Uri.parse('$baseUrl/api/admin/token');
    final body = {
      'username': _usernameController.text.trim(),
      'password': _passwordController.text,
    };

    http.Response? lastResponse;
    Exception? lastError;

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'Accept': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      lastResponse = response;

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final String accessToken = responseData['access_token'];

        await _storage.write(key: 'panel_url', value: baseUrl);
        await _storage.write(key: 'access_token', value: accessToken);
        await _storage.write(
            key: 'username', value: _usernameController.text.trim());
        await _storage.write(key: 'password', value: _passwordController.text);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage(
              panelUrl: baseUrl, // DOGRU URL'Yİ GÖNDER (örn: .../alpha)
              accessToken: accessToken,
            ),
          ),
        );
        return;
      }
    } on SocketException catch (e) {
      lastError = e;
    } on HttpException catch (e) {
      lastError = e;
    } on FormatException catch (e) {
      lastError = e;
    } on Exception catch (e) {
      lastError = e;
    }

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (lastResponse != null) {
        String details = lastResponse!.body;
        try {
          final Map<String, dynamic> errorData =
              json.decode(lastResponse!.body);
          if (errorData.containsKey('detail')) {
            details = errorData['detail'].toString();
          }
        } catch (e) {/* ... */}
        _errorMessage = 'Ýalňyşlyk (Kod ${lastResponse!.statusCode}): $details';
      } else {
        _errorMessage =
            'Birikme ýalňyşlygy: ${lastError?.toString() ?? 'nämälim'}';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/marzban_logo.png',
                width: 100,
                height: 100,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.vpn_key_rounded,
                    size: 80,
                    color: Theme.of(context).primaryColorLight,
                  );
                },
              ),
              SizedBox(height: 24),
              Text(
                'Marzban Panel',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
              ),
              SizedBox(height: 32),
              Card(
                elevation: 8,
                color: Color(0xFF1F2937),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _urlController,
                        decoration: InputDecoration(
                          labelText: 'Panel URL',
                          hintText: 'https://panel.domain.com',
                          prefixIcon:
                              Icon(Icons.public, color: Colors.grey[400]),
                        ),
                        keyboardType: TextInputType.url,
                        style: TextStyle(color: Colors.white),
                      ),
                      SizedBox(height: 16.0),
                      TextField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: 'Ulanyjy ady',
                          prefixIcon:
                              Icon(Icons.person, color: Colors.grey[400]),
                        ),
                        style: TextStyle(color: Colors.white),
                      ),
                      SizedBox(height: 16.0),
                      TextField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Açar sözi',
                          prefixIcon: Icon(Icons.lock, color: Colors.grey[400]),
                        ),
                        obscureText: true,
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24.0),
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    _errorMessage,
                    style: TextStyle(color: Colors.red[300], fontSize: 14.0),
                    textAlign: TextAlign.center,
                  ),
                ),
              _isLoading
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _login,
                      child: Text('Giriş et'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 5,
                        textStyle: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

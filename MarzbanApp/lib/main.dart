import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'login_page.dart';
import 'home_page.dart';

// BU KODUN ÇALIŞMASI İÇİN "flutter_secure_storage" PAKETİ GEREKLİ
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = FlutterSecureStorage();
  String? token = await storage.read(key: 'access_token');
  String? url = await storage.read(key: 'panel_url');

  Widget homeWidget = (token != null && url != null)
      ? HomePage(panelUrl: url, accessToken: token)
      : LoginPage();

  runApp(MarzbanApp(homeWidget: homeWidget));
}

class MarzbanApp extends StatelessWidget {
  final Widget homeWidget;

  const MarzbanApp({super.key, required this.homeWidget});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Marzban Panel',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Color(0xFF111827),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF1F2937),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          labelStyle: TextStyle(color: Colors.grey[400]),
          hintStyle: TextStyle(color: Colors.grey[600]),
        ),
      ),
      home: homeWidget,
      debugShowCheckedModeBanner: false,
    );
  }
}

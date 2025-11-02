import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';

class EditUserPage extends StatefulWidget {
  final String panelUrl;
  final String accessToken;
  final Map<String, dynamic> user;

  const EditUserPage({
    super.key,
    required this.panelUrl,
    required this.accessToken,
    required this.user,
  });

  @override
  State<EditUserPage> createState() => _EditUserPageState();
}

class _EditUserPageState extends State<EditUserPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _dataLimitController;
  late TextEditingController _expireDaysController;
  late TextEditingController _noteController;

  bool _isLoading = false;
  String _errorMessage = '';

  Map<String, bool> _protocols = {
    'vless': false,
    'vmess': false,
    'trojan': false,
  };

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.user['username']);
    _noteController = TextEditingController(text: widget.user['note']);

    final int dataLimitBytes = widget.user['data_limit'] ?? 0;
    _dataLimitController = TextEditingController(
        text: dataLimitBytes == 0
            ? ''
            : (dataLimitBytes / 1024 / 1024 / 1024).toStringAsFixed(0));

    final int? expireTimestamp = widget.user['expire'];
    if (expireTimestamp != null && expireTimestamp != 0) {
      final days = DateTime.fromMillisecondsSinceEpoch(expireTimestamp * 1000)
          .difference(DateTime.now())
          .inDays;
      _expireDaysController =
          TextEditingController(text: days > 0 ? days.toString() : '');
    } else {
      _expireDaysController = TextEditingController();
    }

    final Map<String, dynamic> proxies = widget.user['proxies'] ?? {};
    if (proxies.containsKey('vless')) _protocols['vless'] = true;
    if (proxies.containsKey('vmess')) _protocols['vmess'] = true;
    if (proxies.containsKey('trojan')) _protocols['trojan'] = true;
  }

  Future<void> _updateUser() async {
    if (!_protocols.containsValue(true)) {
      setState(() {
        _errorMessage = 'Iň az bir protokol saýlaň.';
      });
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final String username = _usernameController.text.trim();
      final String note = _noteController.text.trim();

      final int dataLimitGB = int.tryParse(_dataLimitController.text) ?? 0;
      final int dataLimitBytes = dataLimitGB * 1024 * 1024 * 1024;

      final int expireDays = int.tryParse(_expireDaysController.text) ?? 0;
      int expireTimestamp = 0;
      if (expireDays > 0) {
        expireTimestamp = (DateTime.now()
                .add(Duration(days: expireDays))
                .millisecondsSinceEpoch ~/
            1000);
      }

      Map<String, dynamic> proxies = {};
      if (_protocols['vless'] == true)
        proxies['vless'] = {"flow": "xtls-rprx-vision"};
      if (_protocols['vmess'] == true) proxies['vmess'] = {};
      if (_protocols['trojan'] == true) proxies['trojan'] = {};

      final body = {
        "username": username,
        "note": note,
        "data_limit": dataLimitBytes,
        "expire": expireTimestamp,
        "proxies": proxies,
        "status": widget.user['status'],
      };

      final response = await http.put(
        Uri.parse('${widget.panelUrl}/api/user/$username'),
        headers: {
          'accept': 'application/json',
          'Authorization': 'Bearer ${widget.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Ulanyjy "$username" düzedildi'),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        throw Exception(errorData['detail'] ?? 'Nämälim ýalňyşlyk');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ulanyjy: ${_usernameController.text}'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Ulanyjy ady',
                prefixIcon: Icon(Icons.person),
              ),
              readOnly: true,
              style: TextStyle(color: Colors.grey[500]),
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _dataLimitController,
              decoration: InputDecoration(
                labelText: 'Traffic Limiti (GB)',
                hintText: '0 = Çäksiz',
                prefixIcon: Icon(Icons.data_usage),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _expireDaysController,
              decoration: InputDecoration(
                labelText: 'Möhleti (Gün)',
                hintText: '0 = Çäksiz',
                prefixIcon: Icon(Icons.calendar_today),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: 'Bellik (Note)',
                prefixIcon: Icon(Icons.note),
              ),
            ),
            SizedBox(height: 24),
            Text('Protokollar', style: TextStyle(color: Colors.grey[400])),
            CheckboxListTile(
              title: Text('VLESS',
                  style: TextStyle(
                      color:
                          _protocols['vless']! ? Colors.white : Colors.grey)),
              value: _protocols['vless'],
              onChanged: (val) {
                setState(() {
                  _protocols['vless'] = val!;
                });
              },
              activeColor: Theme.of(context).primaryColor,
            ),
            CheckboxListTile(
              title: Text('VMESS',
                  style: TextStyle(
                      color:
                          _protocols['vmess']! ? Colors.white : Colors.grey)),
              value: _protocols['vmess'],
              onChanged: (val) {
                setState(() {
                  _protocols['vmess'] = val!;
                });
              },
              activeColor: Theme.of(context).primaryColor,
            ),
            CheckboxListTile(
              title: Text('TROJAN',
                  style: TextStyle(
                      color:
                          _protocols['trojan']! ? Colors.white : Colors.grey)),
              value: _protocols['trojan'],
              onChanged: (val) {
                setState(() {
                  _protocols['trojan'] = val!;
                });
              },
              activeColor: Theme.of(context).primaryColor,
            ),
            SizedBox(height: 24),
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
                ? Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    onPressed: _updateUser,
                    icon: Icon(Icons.save),
                    label: Text('Ýatda sakla'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700]!,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

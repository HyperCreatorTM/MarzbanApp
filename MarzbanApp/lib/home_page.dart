import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'login_page.dart';
import 'create_user_page.dart';
import 'edit_user_page.dart';

class HomePage extends StatefulWidget {
  final String panelUrl;
  final String accessToken;

  const HomePage({
    super.key,
    required this.panelUrl,
    required this.accessToken,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _users = [];
  String _searchQuery = '';

  Map<String, dynamic> _systemStats = {};
  int _activeUsers = 0;
  double _totalDataUsage = 0.0;

  final _storage = FlutterSecureStorage();

  int _currentPage = 1;
  final int _usersPerPage = 5;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _fetchAllData();

    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final responses = await Future.wait([
        http.get(
          Uri.parse('${widget.panelUrl}/api/users'),
          headers: {
            'accept': 'application/json',
            'Authorization': 'Bearer ${widget.accessToken}',
          },
        ),
        http.get(
          Uri.parse('${widget.panelUrl}/api/system'),
          headers: {
            'accept': 'application/json',
            'Authorization': 'Bearer ${widget.accessToken}',
          },
        ),
      ]);
      if (!mounted) return;
      if (responses[0].statusCode == 200) {
        final Map<String, dynamic> data = json.decode(responses[0].body);
        _users = data['users'] ?? [];
        _calculateUserStats();
      } else {
        throw Exception(
            'Ulanyjy sanawy ýüklenmedi: ${responses[0].statusCode}');
      }
      if (responses[1].statusCode == 200) {
        _systemStats = json.decode(responses[1].body);
      } else {
        throw Exception(
            'Sistem maglumaty ýüklenmedi: ${responses[1].statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    }
    setState(() {
      _isLoading = false;
    });
  }

  void _calculateUserStats() {
    _activeUsers = _users.where((u) => u['status'] == 'active').length;
    double totalBytes = 0;
    for (var user in _users) {
      totalBytes += (user['used_traffic'] ?? 0);
    }
    _totalDataUsage = totalBytes;
  }

  void _logout() async {
    await _storage.deleteAll();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
      (Route<dynamic> route) => false,
    );
  }

  // ----- BU, 3 TB HATASINI DÜZELTEN YENİ FONKSİYON -----
  String _formatBytes(num bytes, {int decimals = 2}) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB", "PB"];

    int i = 0;
    double dBytes = bytes.toDouble();
    while (dBytes >= 1024 && i < suffixes.length - 1) {
      dBytes /= 1024;
      i++;
    }

    return '${dBytes.toStringAsFixed(decimals)} ${suffixes[i]}';
  }
  // ----------------------------------------------------

  String _getDaysRemaining(int? timestamp) {
    if (timestamp == null || timestamp == 0) return 'Çäksiz';
    try {
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
      final days = date.difference(DateTime.now()).inDays;
      if (days < 0) return 'Möhleti Doldy';
      return '$days gün galdy';
    } catch (e) {
      return 'N/A';
    }
  }

  bool _isUserOnline(String? onlineAt) {
    if (onlineAt == null) return false;
    try {
      final lastOnline = DateTime.parse(onlineAt).toLocal();
      return DateTime.now().difference(lastOnline) < Duration(minutes: 5);
    } catch (e) {
      return false;
    }
  }

  Future<void> _deleteUser(String username) async {
    final bool? confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ulanyjy Pozmak'),
        content: Text('"$username" atly ulanyjyny pozmak isleýärsiňizmi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Ýatyr'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Tassykla', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final response = await http.delete(
        Uri.parse('${widget.panelUrl}/api/user/$username'),
        headers: {
          'accept': 'application/json',
          'Authorization': 'Bearer ${widget.accessToken}',
        },
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Ulanyjy pozuldy'), backgroundColor: Colors.green),
        );
        _fetchAllData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Ulanyjy pozmak başartmady: ${response.body}'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _goToEditUserPage(Map<String, dynamic> user) async {
    final bool? userUpdated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditUserPage(
          panelUrl: widget.panelUrl,
          accessToken: widget.accessToken,
          user: user,
        ),
      ),
    );

    if (userUpdated == true) {
      _fetchAllData();
    }
  }

  void _goToCreateUserPage() async {
    final bool? userCreated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateUserPage(
          panelUrl: widget.panelUrl,
          accessToken: widget.accessToken,
        ),
      ),
    );
    if (userCreated == true) {
      _fetchAllData();
    }
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('$message göçürildi'), backgroundColor: Colors.green),
      );
    });
  }

  void _showConfigEditor() async {
    String currentConfig = '';
    String statusMessage = '';
    bool isLoading = true;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (isLoading && currentConfig.isEmpty) {
              http.get(
                Uri.parse('${widget.panelUrl}/api/config'),
                headers: {'Authorization': 'Bearer ${widget.accessToken}'},
              ).then((response) {
                if (!mounted) return;
                setDialogState(() {
                  isLoading = false;
                  if (response.statusCode == 200) {
                    var jsonObject = json.decode(response.body);
                    currentConfig =
                        JsonEncoder.withIndent('  ').convert(jsonObject);
                  } else if (response.statusCode == 403 ||
                      response.statusCode == 401) {
                    statusMessage =
                        'Ýalňyşlyk: Config faýlyny almaga rugsat ýok!';
                  } else {
                    statusMessage =
                        'Config alyp bolmady: ${response.statusCode}';
                  }
                });
              }).catchError((e) {
                if (!mounted) return;
                setDialogState(() {
                  isLoading = false;
                  statusMessage = 'Ýalňyşlyk: $e';
                });
              });
            }

            final configController = TextEditingController(text: currentConfig);

            Future<void> saveConfig() async {
              setDialogState(() {
                isLoading = true;
                statusMessage = '';
              });

              try {
                json.decode(configController.text);
              } catch (e) {
                setDialogState(() {
                  isLoading = false;
                  statusMessage = 'Nädogry JSON formaty!';
                });
                return;
              }

              final response = await http.put(
                Uri.parse('${widget.panelUrl}/api/config'),
                headers: {
                  'accept': 'application/json',
                  'Authorization': 'Bearer ${widget.accessToken}',
                  'Content-Type': 'application/json',
                },
                body: configController.text,
              );

              if (!mounted) return;
              setDialogState(() {
                isLoading = false;
                if (response.statusCode == 200) {
                  statusMessage = 'Üstünlikli ýatda saklandy!';
                } else if (response.statusCode == 403 ||
                    response.statusCode == 401) {
                  statusMessage =
                      'Ýalňyşlyk: Config faýlyny üýtgetmäge rugsat ýok!';
                } else {
                  statusMessage =
                      'Ýalňyşlyk (Kod ${response.statusCode}): ${response.body}';
                }
              });
            }

            return AlertDialog(
              title: Text('Sazlamalar (config.json)'),
              content: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.6,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLoading)
                      Expanded(
                          child: Center(child: CircularProgressIndicator()))
                    else
                      Expanded(
                        child: TextField(
                          controller: configController,
                          maxLines: null,
                          expands: true,
                          style:
                              TextStyle(fontFamily: 'monospace', fontSize: 12),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(),
                            fillColor: Colors.black.withOpacity(0.1),
                          ),
                        ),
                      ),
                    if (statusMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          statusMessage,
                          style: TextStyle(
                            color: statusMessage.startsWith('Üstünlikli')
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Ýatyr'),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : saveConfig,
                  child: Text('Ýatda sakla'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _users.where((user) {
      final username = user['username'].toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return username.contains(query);
    }).toList();

    final totalPages = (filteredUsers.length / _usersPerPage).ceil();
    if (totalPages > 0 && _currentPage > totalPages) {
      _currentPage = totalPages;
    }
    final startIndex = (_currentPage - 1) * _usersPerPage;
    final endIndex = math.min(startIndex + _usersPerPage, filteredUsers.length);
    final paginatedUsers = filteredUsers.isNotEmpty
        ? filteredUsers.sublist(startIndex, endIndex)
        : <dynamic>[];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            tooltip: 'Sazlamalar',
            onPressed: _showConfigEditor,
          ),
          IconButton(
            icon: Icon(Icons.logout),
            tooltip: 'Çykyş',
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _buildDashboard(paginatedUsers, filteredUsers.length, totalPages),
    );
  }

  Widget _buildDashboard(
      List<dynamic> paginatedUsers, int totalFilteredUsers, int totalPages) {
    final memUsed = _systemStats['mem']?['used'] ?? 0;
    final memTotal = _systemStats['mem']?['total'] ?? 0;
    final memPercent = (memTotal == 0) ? 0.0 : (memUsed / memTotal);
    String memValue;
    if (memTotal == 0) {
      memValue = 'Belli däl';
    } else {
      memValue =
          '${_formatBytes(memUsed, decimals: 1)} / ${_formatBytes(memTotal, decimals: 1)}';
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 16.0),
          child: Text(
            'Ulanyjylar',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        _buildStatsColumn(memValue, memPercent),
        SizedBox(height: 24),
        TextField(
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
              _currentPage = 1;
            });
          },
          decoration: InputDecoration(
            hintText: 'Gözleg...',
            prefixIcon: Icon(Icons.search, size: 20),
            contentPadding: EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Ulanyjy Sanawy ($totalFilteredUsers)',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _goToCreateUserPage,
                  icon: Icon(Icons.add, size: 18),
                  label: Text('Döret'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.refresh, color: Colors.grey[400]),
                  tooltip: 'Täzele',
                  onPressed: _fetchAllData,
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 12),
        _errorMessage.isNotEmpty
            ? _buildErrorArea()
            : (paginatedUsers.isEmpty
                ? _buildEmptyUserArea(_users.isNotEmpty)
                : _buildUserList(paginatedUsers)),
        if (totalPages > 1) _buildPaginationControls(totalPages),
      ],
    );
  }

  Widget _buildStatsColumn(String memValue, double memPercent) {
    return Column(
      children: [
        _StatCard(
          title: 'Aktiw Ulanyjylar',
          value: '$_activeUsers / ${_users.length}',
          icon: Icons.person_outline,
          color: Color(0xFF3B82F6),
        ),
        SizedBox(height: 12),
        _StatCard(
          title: 'Traffic Sarp ediş',
          value: _formatBytes(_totalDataUsage),
          icon: Icons.data_usage,
          color: Color(0xFF10B981),
        ),
        SizedBox(height: 12),
        _StatCard(
          title: 'RAM (Ýat) Sarp ediş',
          value: memValue,
          icon: Icons.memory,
          color: Color(0xFF8B5CF6),
          footer: memValue == 'Belli däl'
              ? null
              : LinearProgressIndicator(
                  value: memPercent,
                  backgroundColor: Colors.grey[700],
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                ),
        ),
      ],
    );
  }

  Widget _buildErrorArea() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 60),
            SizedBox(height: 16),
            Text(
              _errorMessage,
              style: TextStyle(color: Colors.red[300], fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
                onPressed: _fetchAllData, child: Text('Täzeden Synanş')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyUserArea(bool isSearchEmpty) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isSearchEmpty ? Icons.search_off : Icons.people_outline,
                size: 80, color: Colors.grey[600]),
            SizedBox(height: 16),
            Text(
              isSearchEmpty
                  ? '"$_searchQuery" üçin hiç zat tapylmady'
                  : 'Sistemde ulanyjy ýok',
              style: TextStyle(fontSize: 16, color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserList(List<dynamic> paginatedUsers) {
    return ListView.builder(
      itemCount: paginatedUsers.length,
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final user = paginatedUsers[index];
        final String username = user['username'] ?? 'N/A';
        final String status = user['status'] ?? 'nämälim';
        final num usedTraffic = user['used_traffic'] ?? 0;
        final num dataLimit = user['data_limit'] ?? 0;
        final int? expire = user['expire'];
        final String? onlineAt = user['online_at'];

        final bool isOnline = _isUserOnline(onlineAt);

        final Map<String, dynamic> proxies = user['proxies'] ?? {};
        final List<String> enabledProtocols = proxies.keys.toList();

        final String subLink = user['subscription_url'] ?? '';
        final String configLink = user['links']?.first ?? '';

        double progress = 0.0;
        if (dataLimit > 0) {
          progress = usedTraffic / dataLimit;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12.0),
          color: Color(0xFF1F2937),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            leading: Icon(Icons.wifi, color: Colors.grey[400]),
            title: Text(
              username,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            trailing: Icon(Icons.expand_more, color: Colors.grey[400]),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0).copyWith(top: 0),
                child: Column(
                  children: [
                    Divider(color: Colors.grey[700]),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            if (isOnline)
                              FadeTransition(
                                opacity: _pulseAnimation,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: Colors.greenAccent,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.greenAccent.withOpacity(0.5),
                                        blurRadius: 3.0,
                                        spreadRadius: 1.0,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (isOnline) SizedBox(width: 8),
                            if (enabledProtocols.isNotEmpty)
                              ...enabledProtocols
                                  .map((p) => _ProtocolBadge(protocol: p))
                                  .toList()
                            else
                              _StatusBadge(status: status),
                          ],
                        ),
                        Text(
                          _getDaysRemaining(expire),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Traffic Sarp ediş',
                          style:
                              TextStyle(color: Colors.grey[400], fontSize: 14),
                        ),
                        Text(
                          '${_formatBytes(usedTraffic)} / ${dataLimit == 0 ? "Çäksiz" : _formatBytes(dataLimit)}',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey[800],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        (progress > 0.9) ? Colors.red : Colors.green,
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            TextButton(
                              onPressed: () => _deleteUser(username),
                              child: Text('Poz',
                                  style: TextStyle(color: Colors.red[300])),
                            ),
                            SizedBox(width: 8),
                            TextButton(
                              onPressed: () => _goToEditUserPage(user),
                              child: Text('Düzet'),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            _CopyButton(
                              label: 'Abuna',
                              icon: Icons.link,
                              onTap: () =>
                                  _copyToClipboard(subLink, 'Abuna linki'),
                            ),
                            SizedBox(width: 16),
                            _CopyButton(
                              label: 'Kod',
                              icon: Icons.copy,
                              onTap: () =>
                                  _copyToClipboard(configLink, 'Config kody'),
                            ),
                          ],
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaginationControls(int totalPages) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 16),
          onPressed: (_currentPage == 1)
              ? null
              : () {
                  setState(() {
                    _currentPage--;
                  });
                },
        ),
        Text(
          'Sahypa $_currentPage / $totalPages',
          style: TextStyle(color: Colors.grey[400]),
        ),
        IconButton(
          icon: Icon(Icons.arrow_forward_ios, size: 16),
          onPressed: (_currentPage == totalPages)
              ? null
              : () {
                  setState(() {
                    _currentPage++;
                  });
                },
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Widget? footer;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Color(0xFF1F2937),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, color: color, size: 24),
              ],
            ),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            if (footer != null) ...[
              SizedBox(height: 8),
              footer!,
            ]
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    IconData statusIcon = Icons.help_outline;
    Color statusColor = Colors.grey;
    if (status == 'active') {
      statusIcon = Icons.check_circle;
      statusColor = Colors.green;
    } else if (status == 'disabled') {
      statusIcon = Icons.cancel;
      statusColor = Colors.red;
    } else if (status == 'limited') {
      statusIcon = Icons.warning_amber;
      statusColor = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 14),
          SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: TextStyle(
                color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ProtocolBadge extends StatelessWidget {
  final String protocol;
  const _ProtocolBadge({required this.protocol});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6.0),
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Color(0xFF3B82F6).withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color(0xFF3B82F6), width: 1),
      ),
      child: Text(
        protocol.toUpperCase(),
        style: TextStyle(
            color: Color(0xFF3B82F6),
            fontWeight: FontWeight.bold,
            fontSize: 10),
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _CopyButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Icon(icon, color: Colors.grey[400], size: 24),
            SizedBox(height: 4),
            Text(label,
                style: TextStyle(color: Colors.grey[400], fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

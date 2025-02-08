// lib/screens/home.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vds_flutter/VDS/VDS_API_Service.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final VdsApiService _vdsService = VdsApiService();
  ByteData? _clientCertBytes;
  ByteData? _caCertBytes;
  String? _token;
  bool _isLoading = false;
  String? _error;
  final String _password = "password"; // Fixed password

  @override
  void initState() {
    super.initState();
    _loadCertificates();
  }

  Future<void> _loadCertificates() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load certificates from assets
      _clientCertBytes = await rootBundle.load('assets/certs/client.p12');
      _caCertBytes = await rootBundle.load('assets/certs/root_cert.pem');

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error loading certificates: $e';
      });
      _showError('Failed to load certificates');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _authenticate() async {
    if (_clientCertBytes == null || _caCertBytes == null) {
      _showError('Certificates not loaded');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await _vdsService.authenticate(
        clientCertBytes: _clientCertBytes!,
        caCertBytes: _caCertBytes!,
        password: _password,
      );

      setState(() {
        _token = token;
      });

      // Store token in shared preferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token!);

      _showSuccess('Authentication successful');
    } catch (e) {
      setState(() {
        _error = 'Authentication error: $e';
      });
      _showError('Authentication failed: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchProfile() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('auth_token');

    if (token == null) {
      _showError('Not authenticated');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final profile = await _vdsService.getProfile(
        token: token,
        clientCertBytes: _clientCertBytes!,
        caCertBytes: _caCertBytes!,
        password: _password,
      );

      if (profile != null) {
        final userProfile = profile['userProfiles'][0];
        final userId = userProfile['digitalIdentityOwnerUUID'];
        final digitalUUID = userProfile['digitalIdentityUUID'];

        print('User ID: $userId');
        print('Digital UUID: $digitalUUID');

        _showSuccess('Profile fetched successfully');
      }
    } catch (e) {
      setState(() {
        _error = 'Profile fetch error: $e';
      });
      _showError('Failed to fetch profile: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VDS Integration'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    _StatusItem(
                      label: 'Client Certificate',
                      isLoaded: _clientCertBytes != null,
                    ),
                    _StatusItem(
                      label: 'CA Certificate',
                      isLoaded: _caCertBytes != null,
                    ),
                    _StatusItem(
                      label: 'Authentication Token',
                      isLoaded: _token != null,
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _authenticate,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Authenticate'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _fetchProfile,
              child: const Text('Get Profile'),
            ),
            const SizedBox(height: 8),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('Processing...'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusItem extends StatelessWidget {
  final String label;
  final bool isLoaded;

  const _StatusItem({
    required this.label,
    required this.isLoaded,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            isLoaded ? Icons.check_circle : Icons.error_outline,
            color: isLoaded ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text('$label: ${isLoaded ? "Loaded" : "Not Loaded"}'),
        ],
      ),
    );
  }
}

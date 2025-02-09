import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'SealPdfService.dart';
import 'auth_service.dart';
import 'profile_service.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  final SealPdfService _sealPdfService = SealPdfService();
  String? _profileData;
  String? _tokenSubject;
  String? _digitalIdentityUUID;
  bool _isLoading = false;
  String? _sealedPdfData;

  Future<void> _getProfile() async {
    setState(() => _isLoading = true);
    try {
      ByteData clientCert = await rootBundle.load('assets/certs/client.p12');
      ByteData caCert = await rootBundle.load('assets/certs/root_cert.pem');

      String? token = await _authService.authenticate(clientCert, caCert);
      if (token == null) throw Exception('Authentication failed');

      var profile = await _profileService.fetchProfile(clientCert, caCert);

      print("Profile Response: $profile");

      var userProfiles = profile?['userProfiles'] as List;
      if (userProfiles.isNotEmpty) {
        var tspClient = userProfiles[0]['tspClient'];
        var digitalIdentityUUID = userProfiles[0]['digitalIdentityUUID'];

        _tokenSubject = tspClient['tokenSubject'];
        _digitalIdentityUUID = digitalIdentityUUID;

        setState(() {
          _profileData =
              'Token Subject: $_tokenSubject\nDigital Identity UUID: $_digitalIdentityUUID';
        });
      }
    } catch (e) {
      setState(() => _profileData = 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sealPdf() async {
    setState(() => _isLoading = true);
    try {
      ByteData clientCert = await rootBundle.load('assets/certs/client.p12');
      ByteData caCert = await rootBundle.load('assets/certs/root_cert.pem');

      // Load demo PDF
      ByteData pdfData = await rootBundle.load('assets/demo.pdf');
      String pdfBase64 = base64Encode(pdfData.buffer.asUint8List());

      var sealedPdf = await _sealPdfService.sealPdf(
        clientCert: clientCert,
        caCert: caCert,
        fileName: 'demo.pdf',
        pdfBase64: pdfBase64,
      );

      setState(() {
        _sealedPdfData =
            'PDF Sealed Successfully\nSealed PDF Data: ${sealedPdf.toString()}';
      });
    } catch (e) {
      setState(() => _sealedPdfData = 'Error sealing PDF: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('VDS Flutter Demo')),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _isLoading ? null : _getProfile,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Get Profile'),
              ),
              const SizedBox(height: 20),
              if (_profileData != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(_profileData!, textAlign: TextAlign.center),
                ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _sealPdf,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Seal PDF'),
              ),
              const SizedBox(height: 20),
              if (_sealedPdfData != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(_sealedPdfData!, textAlign: TextAlign.center),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

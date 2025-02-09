import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;

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
  Uint8List? _pdfBytes;

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

      await _handleSealedPdf(sealedPdf);
    } catch (e) {
      setState(() => _sealedPdfData = 'Error sealing PDF: $e');
      print('Error sealing PDF: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSealedPdf(Map<String, dynamic>? sealedPdf) async {
    if (sealedPdf != null && sealedPdf['signedData'] != null) {
      List<dynamic> signedDataList = sealedPdf['signedData'];
      if (signedDataList.isNotEmpty) {
        String base64PdfContent = signedDataList[0];
        try {
          _pdfBytes = base64Decode(base64PdfContent);
          setState(() {
            _sealedPdfData = 'PDF Sealed Successfully';
          });
        } catch (e) {
          setState(() {
            _sealedPdfData = 'Error decoding PDF: $e';
          });
          print('Error decoding PDF: $e');
        }
      }
    }
  }

  Future<void> _downloadPdf() async {
    if (_pdfBytes == null) {
      setState(() => _sealedPdfData = 'No PDF data available');
      return;
    }

    if (kIsWeb) {
      _downloadPdfWeb();
    } else {
      await _downloadPdfMobile();
    }
  }

  void _downloadPdfWeb() {
    final blob = html.Blob([_pdfBytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", "sealed_document.pdf")
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _downloadPdfMobile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/sealed_document.pdf';
      File file = File(filePath);
      await file.writeAsBytes(_pdfBytes!);
      setState(() => _sealedPdfData = 'PDF saved to: $filePath');
    } catch (e) {
      setState(() => _sealedPdfData = 'Error saving PDF: $e');
      print('Error saving PDF: $e');
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
              if (_pdfBytes != null)
                ElevatedButton(
                  onPressed: _downloadPdf,
                  child: const Text('Download Sealed PDF'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

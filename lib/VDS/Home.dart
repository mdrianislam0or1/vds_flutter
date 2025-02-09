import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
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
  bool _isLoading = false;

  Future<void> _processAndDownloadPdf() async {
    setState(() => _isLoading = true);
    try {
      // Load certificates
      ByteData clientCert = await rootBundle.load('assets/certs/client.p12');
      ByteData caCert = await rootBundle.load('assets/certs/root_cert.pem');

      // Authenticate
      String? token = await _authService.authenticate(clientCert, caCert);
      if (token == null) throw Exception('Authentication failed');

      // Get profile
      var profile = await _profileService.fetchProfile(clientCert, caCert);
      if (profile == null || (profile['userProfiles'] as List).isEmpty) {
        throw Exception('Failed to get user profile');
      }

      // Load and seal PDF
      ByteData pdfData = await rootBundle.load('assets/demo.pdf');
      String pdfBase64 = base64Encode(pdfData.buffer.asUint8List());

      var sealedPdf = await _sealPdfService.sealPdf(
        clientCert: clientCert,
        caCert: caCert,
        fileName: 'demo.pdf',
        pdfBase64: pdfBase64,
      );

      if (sealedPdf == null || sealedPdf['signedData'] == null) {
        throw Exception('Failed to seal PDF');
      }

      // Process sealed PDF
      List<dynamic> signedDataList = sealedPdf['signedData'];
      if (signedDataList.isEmpty) {
        throw Exception('No signed data received');
      }

      Uint8List pdfBytes = base64Decode(signedDataList[0]);

      // Download based on platform
      if (kIsWeb) {
        await _downloadPdfWeb(pdfBytes);
      } else {
        await _downloadPdfMobile(pdfBytes);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF downloaded successfully'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      _showErrorDialog('Error', e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadPdfWeb(Uint8List pdfBytes) async {
    final blob = html.Blob([pdfBytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", "sealed_document.pdf")
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _downloadPdfMobile(Uint8List pdfBytes) async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final int androidVersion = androidInfo.version.sdkInt;

      if (androidVersion >= 30) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          throw Exception('Storage permission required');
        }
      } else {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          throw Exception('Storage permission required');
        }
      }

      Directory? directory;
      if (androidVersion >= 30) {
        directory = Directory('/storage/emulated/0/Download');
      } else {
        directory = await getExternalStorageDirectory();
      }

      if (directory == null) {
        throw Exception('Could not access download directory');
      }

      final fileName =
          'sealed_document_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = '${directory.path}/$fileName';
      await File(filePath).writeAsBytes(pdfBytes);
    } else {
      // iOS
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'sealed_document_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = '${directory.path}/$fileName';
      await File(filePath).writeAsBytes(pdfBytes);
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VDS Flutter Demo'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _processAndDownloadPdf,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Download Sealed PDF'),
          ),
        ),
      ),
    );
  }
}

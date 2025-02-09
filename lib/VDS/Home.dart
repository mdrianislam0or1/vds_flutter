import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
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
  String? _savedFilePath;

  Future<void> _getProfile() async {
    setState(() => _isLoading = true);
    try {
      ByteData clientCert = await rootBundle.load('assets/certs/client.p12');
      ByteData caCert = await rootBundle.load('assets/certs/root_cert.pem');

      String? token = await _authService.authenticate(clientCert, caCert);
      if (token == null) throw Exception('Authentication failed');

      var profile = await _profileService.fetchProfile(clientCert, caCert);

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
      _showErrorDialog('Profile Error', e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sealPdf() async {
    setState(() => _isLoading = true);
    try {
      ByteData clientCert = await rootBundle.load('assets/certs/client.p12');
      ByteData caCert = await rootBundle.load('assets/certs/root_cert.pem');

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
      _showErrorDialog('PDF Sealing Error', e.toString());
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
            _savedFilePath = null;
          });
        } catch (e) {
          setState(() => _sealedPdfData = 'Error decoding PDF: $e');
          _showErrorDialog('PDF Decoding Error', e.toString());
        }
      }
    }
  }

  Future<void> _downloadPdf() async {
    if (_pdfBytes == null) {
      _showErrorDialog('Download Error', 'No PDF data available');
      return;
    }

    try {
      if (kIsWeb) {
        await _downloadPdfWeb();
      } else {
        await _downloadPdfMobile();
      }
    } catch (e) {
      _showErrorDialog('Download Error', e.toString());
    }
  }

  Future<void> _downloadPdfWeb() async {
    final blob = html.Blob([_pdfBytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", "sealed_document.pdf")
      ..click();
    html.Url.revokeObjectUrl(url);
    setState(() => _sealedPdfData = 'PDF downloaded successfully');
  }

  Future<void> _downloadPdfMobile() async {
    try {
      if (Platform.isAndroid) {
        // Check Android version
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        final int androidVersion = androidInfo.version.sdkInt;

        if (androidVersion >= 30) {
          // Android 11 or higher
          final status = await Permission.storage.request();
          if (!status.isGranted) {
            throw Exception('Storage permission required');
          }
        } else {
          // For Android 10 and below
          final status = await Permission.storage.request();
          if (!status.isGranted) {
            throw Exception('Storage permission required');
          }
        }

        // Get the downloads directory
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

        // Save the file
        File file = File(filePath);
        await file.writeAsBytes(_pdfBytes!);

        setState(() {
          _savedFilePath = filePath;
          _sealedPdfData = 'PDF saved to Downloads folder';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF saved to Downloads folder'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        // For iOS, use the documents directory
        final directory = await getApplicationDocumentsDirectory();
        final fileName =
            'sealed_document_${DateTime.now().millisecondsSinceEpoch}.pdf';
        final filePath = '${directory.path}/$fileName';

        File file = File(filePath);
        await file.writeAsBytes(_pdfBytes!);

        setState(() {
          _savedFilePath = filePath;
          _sealedPdfData = 'PDF saved successfully';
        });
      }
    } catch (e) {
      _showErrorDialog('Download Error', e.toString());
    }
  }

  Future<void> _sharePdf() async {
    if (_pdfBytes == null) {
      _showErrorDialog('Share Error', 'No PDF data available');
      return;
    }

    try {
      final directory = await getTemporaryDirectory();
      final fileName =
          'sealed_document_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = '${directory.path}/$fileName';

      File file = File(filePath);
      await file.writeAsBytes(_pdfBytes!);

      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Sealed PDF Document',
      );
    } catch (e) {
      _showErrorDialog('Share Error', e.toString());
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _isLoading ? null : _getProfile,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Get Profile'),
              ),
              if (_profileData != null) ...[
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(_profileData!, textAlign: TextAlign.center),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _sealPdf,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Seal PDF'),
              ),
              if (_sealedPdfData != null) ...[
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(_sealedPdfData!, textAlign: TextAlign.center),
                        if (_savedFilePath != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'File saved to:\n$_savedFilePath',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              if (_pdfBytes != null) ...[
                const SizedBox(height: 20),
                if (kIsWeb)
                  ElevatedButton.icon(
                    onPressed: _downloadPdf,
                    icon: const Icon(Icons.download),
                    label: const Text('Download PDF'),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _downloadPdf,
                        icon: const Icon(Icons.download),
                        label: const Text('Save to Downloads'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: _sharePdf,
                        icon: const Icon(Icons.share),
                        label: const Text('Share PDF'),
                      ),
                    ],
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

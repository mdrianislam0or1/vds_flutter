import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:vds_flutter/VDS/VDS_API_Service.dart';

import 'auth_service.dart';

class SealPdfService {
  final VdsApiService _vdsService = VdsApiService();
  final String _password = "password";

  Future<Map<String, dynamic>?> sealPdf({
    required ByteData clientCert,
    required ByteData caCert,
    required String fileName,
    required String pdfBase64,
  }) async {
    try {
      AuthService authService = AuthService();
      String? token = await authService.getToken();

      if (token == null) {
        throw Exception('User is not authenticated');
      }

      // Fetch profile to get userId and digitalUUID
      final profile = await _vdsService.getProfile(
        token: token,
        clientCertBytes: clientCert,
        caCertBytes: caCert,
        password: _password,
      );

      if (profile == null ||
          profile['userProfiles'] == null ||
          (profile['userProfiles'] as List).isEmpty) {
        throw Exception('Failed to fetch user profile');
      }

      final userProfile = profile['userProfiles'][0];
      final userId = userProfile['tspClient']['tokenSubject'];
      final digitalUUID = userProfile['digitalIdentityUUID'];

      // Prepare VDS data
      final vdsData = {
        "documents": [
          {
            "fileName": fileName,
            "data": pdfBase64,
            "vSigEnabled": true,
            "vSigPage": 1,
            "vSigXPosition": 197,
            "vSigYPosition": 120,
            "vdsData": {
              "qrCodeData": {
                "k1": {"value": "default k1", "label": "Vrednost 1"},
                "k2": {"value": "default k2", "label": "Vrednost 2"},
                "k3": {"value": "2024-03-27", "label": "Vrednost datum"},
                "k4": {"value": null, "label": "Vrednost check"},
                "k5": {"value": null, "label": "Vrednost broj"}
              },
              "qrCodePage": 1,
              "qrCodeSize": 150,
              "qrCodeXPosition": 234,
              "qrCodeYPosition": 185
            }
          }
        ]
      };

      final sealedPdf = await _vdsService.sealPdf(
        token: token,
        clientCertBytes: clientCert,
        caCertBytes: caCert,
        password: _password,
        userId: userId,
        digitalUUID: digitalUUID,
        vdsData: json.encode(vdsData),
      );

      return sealedPdf;
    } catch (e) {
      print("Seal PDF Error: $e");
      rethrow;
    }
  }
}

import 'package:flutter/services.dart';
import 'package:vds_flutter/VDS/VDS_API_Service.dart';

import 'auth_service.dart';

class ProfileService {
  final VdsApiService _vdsService = VdsApiService();
  final String _password = "password";

  Future<Map<String, dynamic>?> fetchProfile(
      ByteData clientCert, ByteData caCert) async {
    try {
      AuthService authService = AuthService();
      String? token = await authService.getToken();

      if (token == null) {
        throw Exception('User is not authenticated');
      }

      final profile = await _vdsService.getProfile(
        token: token,
        clientCertBytes: clientCert,
        caCertBytes: caCert,
        password: _password,
      );

      return profile;
    } catch (e) {
      throw Exception('Profile fetch error: $e');
    }
  }
}

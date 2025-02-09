import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vds_flutter/VDS/VDS_API_Service.dart';

class AuthService {
  final VdsApiService _vdsService = VdsApiService();
  final String _password = "password";

  Future<String?> authenticate(ByteData clientCert, ByteData caCert) async {
    try {
      final token = await _vdsService.authenticate(
        clientCertBytes: clientCert,
        caCertBytes: caCert,
        password: _password,
      );

      if (token != null) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
      }

      return token;
    } catch (e) {
      throw Exception('Authentication error: $e');
    }
  }

  Future<String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }
}

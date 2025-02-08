// import 'dart:convert';

// import 'package:flutter/foundation.dart';
// import 'package:flutter/services.dart';
// import 'package:http/http.dart' as http;

// class VdsApiService {
//   final String baseUrl = "http://192.168.0.12:8082/api";

//   Future<String?> authenticate({
//     required ByteData clientCertBytes,
//     required ByteData caCertBytes,
//     required String password,
//   }) async {
//     try {
//       var request =
//           http.MultipartRequest('POST', Uri.parse('$baseUrl/authenticate'));

//       // Convert ByteData to List<int>
//       final clientCertList = clientCertBytes.buffer.asUint8List();
//       final caCertList = caCertBytes.buffer.asUint8List();

//       // Add files as bytes
//       request.files.add(http.MultipartFile.fromBytes(
//           'clientCert', clientCertList,
//           filename: 'client.p12'));
//       request.files.add(http.MultipartFile.fromBytes('caCert', caCertList,
//           filename: 'root_cert.pem'));
//       request.fields['password'] = password;

//       var response = await request.send();
//       final responseBody = await response.stream.bytesToString();
//       final responseData = json.decode(responseBody);
//       print("Token: ${responseData["data"]["token"]}");

//       if (response.statusCode == 200 && responseData["code"] == 0) {
//         return responseData["data"]["token"];
//       } else {
//         throw Exception("Authentication failed: ${responseData["message"]}");
//       }
//     } catch (e) {
//       print("VDS Authentication Error: $e");
//       rethrow;
//     }
//   }

//   Future<Map<String, dynamic>?> getProfile({
//     required String token,
//     required ByteData clientCertBytes,
//     required ByteData caCertBytes,
//     required String password,
//   }) async {
//     try {
//       // Convert certificates to base64 strings
//       final clientCertBase64 =
//           base64Encode(clientCertBytes.buffer.asUint8List());
//       final caCertBase64 = base64Encode(caCertBytes.buffer.asUint8List());

//       // Build URL with query parameters
//       final uri = Uri.parse('$baseUrl/profile').replace(queryParameters: {
//         'clientCert': clientCertBase64,
//         'caCert': caCertBase64,
//         'password': password,
//       });

//       // Make GET request with authorization header
//       final response = await http.get(
//         uri,
//         headers: {
//           'Authorization': token,
//           'Content-Type': 'application/json',
//         },
//       );

//       final responseData = json.decode(response.body);

//       if (response.statusCode == 200 && responseData["code"] == 0) {
//         return responseData["data"];
//       } else {
//         throw Exception("Profile fetch failed: ${responseData["message"]}");
//       }
//     } catch (e) {
//       print("VDS Profile Error: $e");
//       rethrow;
//     }
//   }
// }

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class VdsApiService {
  final String baseUrl = "http://192.168.0.12:8082/api";

  Future<String?> authenticate({
    required ByteData clientCertBytes,
    required ByteData caCertBytes,
    required String password,
  }) async {
    try {
      var request =
          http.MultipartRequest('POST', Uri.parse('$baseUrl/authenticate'));

      // Convert ByteData to List<int>
      final clientCertList = clientCertBytes.buffer.asUint8List();
      final caCertList = caCertBytes.buffer.asUint8List();

      // Add files as bytes
      request.files.add(http.MultipartFile.fromBytes(
          'clientCert', clientCertList,
          filename: 'client.p12'));
      request.files.add(http.MultipartFile.fromBytes('caCert', caCertList,
          filename: 'root_cert.pem'));
      request.fields['password'] = password;

      var response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final responseData = json.decode(responseBody);
      print("Token: ${responseData["data"]["token"]}");

      if (response.statusCode == 200 && responseData["code"] == 0) {
        return responseData["data"]["token"];
      } else {
        throw Exception("Authentication failed: ${responseData["message"]}");
      }
    } catch (e) {
      print("VDS Authentication Error: $e");
      rethrow;
    }
  }

  // Function to fetch the profile
  Future<Map<String, dynamic>?> getProfile({
    required String token,
    required ByteData clientCertBytes,
    required ByteData caCertBytes,
    required String password,
  }) async {
    try {
      // Create a GET request for the profile endpoint
      var request = http.Request('GET', Uri.parse('$baseUrl/profile'));

      // Convert ByteData to List<int>
      final clientCertList = clientCertBytes.buffer.asUint8List();
      final caCertList = caCertBytes.buffer.asUint8List();

      // Add the form data to the request
      request.headers['Authorization'] = token;

      // Add the necessary files to the request
      request.headers['clientCert'] =
          base64Encode(clientCertList); // Encoding the byte data
      request.headers['caCert'] =
          base64Encode(caCertList); // Encoding the byte data

      // Add the password as a query parameter or as part of the body
      request.body = jsonEncode({
        'password': password,
      });

      // Send the request
      var response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final responseData = json.decode(responseBody);

      // Check for successful response
      if (response.statusCode == 200 && responseData["code"] == 0) {
        return responseData["data"];
      } else {
        throw Exception("Profile fetch failed: ${responseData["message"]}");
      }
    } catch (e) {
      print("VDS Profile Error: $e");
      rethrow;
    }
  }
}

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
//         'clientCert',
//         clientCertList,
//         filename: 'client.p12',
//       ));
//       request.files.add(http.MultipartFile.fromBytes(
//         'caCert',
//         caCertList,
//         filename: 'root_cert.pem',
//       ));

//       request.fields['password'] = password;

//       var response = await request.send();
//       final responseBody = await response.stream.bytesToString();
//       final responseData = json.decode(responseBody);

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
//       // Convert ByteData to List<int>
//       final clientCertList = clientCertBytes.buffer.asUint8List();
//       final caCertList = caCertBytes.buffer.asUint8List();

//       // Create multipart request
//       var request =
//           http.MultipartRequest('POST', Uri.parse('$baseUrl/profile'));

//       // Add headers
//       request.headers.addAll({
//         'Authorization': token,
//       });

//       // Add files
//       request.files.add(http.MultipartFile.fromBytes(
//         'clientCert',
//         clientCertList,
//         filename: 'client.p12',
//       ));
//       request.files.add(http.MultipartFile.fromBytes(
//         'caCert',
//         caCertList,
//         filename: 'root_cert.pem',
//       ));

//       // Add password
//       request.fields['password'] = password;

//       // Send request
//       var streamedResponse = await request.send();
//       var response = await http.Response.fromStream(streamedResponse);

//       // Parse response
//       final responseData = json.decode(response.body);

//       // Check for successful response
//       if (response.statusCode == 200 && responseData["code"] == 0) {
//         return responseData["data"];
//       } else {
//         throw Exception("Profile fetch failed: ${responseData["message"]}");
//       }
//     } catch (e) {
//       print("Profile API Error: $e");
//       rethrow;
//     }
//   }

//   Future<String?> sealPdf({
//     required String token,
//     required ByteData clientCertBytes,
//     required ByteData caCertBytes,
//     required String password,
//     required String userId,
//     required String digitalUUID,
//     required String base64PdfData,
//   }) async {
//     try {
//       // Convert ByteData to List<int>
//       final clientCertList = clientCertBytes.buffer.asUint8List();
//       final caCertList = caCertBytes.buffer.asUint8List();

//       // Create the VDS data structure
//       final vdsData = {
//         "documents": [
//           {
//             "fileName": "VDSTest.pdf",
//             "data": base64PdfData,
//             "vSigEnabled": true,
//             "vSigPage": 1,
//             "vSigXPosition": 197,
//             "vSigYPosition": 120,
//             "vdsData": {
//               "qrCodeData": {
//                 "k1": {"value": "default k1", "label": "Vrednost 1"},
//                 "k2": {"value": "default k2", "label": "Vrednost 2"},
//                 "k3": {"value": "2024-03-27", "label": "Vrednost datum"},
//                 "k4": {"value": null, "label": "Vrednost check"},
//                 "k5": {"value": null, "label": "Vrednost broj"}
//               },
//               "qrCodePage": 1,
//               "qrCodeSize": 150,
//               "qrCodeXPosition": 234,
//               "qrCodeYPosition": 185
//             }
//           }
//         ]
//       };

//       // Create multipart request
//       var request =
//           http.MultipartRequest('POST', Uri.parse('$baseUrl/vdsSeal'));

//       // Add headers
//       request.headers.addAll({
//         'Authorization': 'Bearer $token',
//       });

//       // Add files
//       request.files.add(http.MultipartFile.fromBytes(
//         'clientCert',
//         clientCertList,
//         filename: 'client.p12',
//       ));
//       request.files.add(http.MultipartFile.fromBytes(
//         'caCert',
//         caCertList,
//         filename: 'root_cert.pem',
//       ));

//       // Add fields
//       request.fields['password'] = password;
//       request.fields['userId'] = userId;
//       request.fields['digitalUUID'] = digitalUUID;
//       request.fields['vds'] = json.encode(vdsData);

//       // Send request
//       var streamedResponse = await request.send();
//       var response = await http.Response.fromStream(streamedResponse);

//       // Parse response
//       final responseData = json.decode(response.body);

//       // Check for successful response
//       if (response.statusCode == 200 && responseData["code"] == 0) {
//         return responseData["data"]["signedData"][0];
//       } else {
//         throw Exception("PDF sealing failed: ${responseData["message"]}");
//       }
//     } catch (e) {
//       print("VDS Seal Error: $e");
//       rethrow;
//     }
//   }
// }

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class VdsApiService {
  final String baseUrl = "http://192.168.0.12:8082/api";

  // Authenticate method as before
  Future<String?> authenticate({
    required ByteData clientCertBytes,
    required ByteData caCertBytes,
    required String password,
  }) async {
    try {
      var request =
          http.MultipartRequest('POST', Uri.parse('$baseUrl/authenticate'));

      final clientCertList = clientCertBytes.buffer.asUint8List();
      final caCertList = caCertBytes.buffer.asUint8List();

      request.files.add(http.MultipartFile.fromBytes(
        'clientCert',
        clientCertList,
        filename: 'client.p12',
      ));
      request.files.add(http.MultipartFile.fromBytes(
        'caCert',
        caCertList,
        filename: 'root_cert.pem',
      ));

      request.fields['password'] = password;

      var response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final responseData = json.decode(responseBody);

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

  Future<Map<String, dynamic>?> getProfile({
    required String token,
    required ByteData clientCertBytes,
    required ByteData caCertBytes,
    required String password,
  }) async {
    try {
      final clientCertList = clientCertBytes.buffer.asUint8List();
      final caCertList = caCertBytes.buffer.asUint8List();

      var request =
          http.MultipartRequest('POST', Uri.parse('$baseUrl/profile'));

      request.headers.addAll({
        'Authorization': 'Bearer $token',
      });

      request.files.add(http.MultipartFile.fromBytes(
        'clientCert',
        clientCertList,
        filename: 'client.p12',
      ));
      request.files.add(http.MultipartFile.fromBytes(
        'caCert',
        caCertList,
        filename: 'root_cert.pem',
      ));

      request.fields['password'] = password;

      var response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final responseData = json.decode(responseBody);

      if (response.statusCode == 200 && responseData["code"] == 0) {
        return responseData["data"];
      } else {
        throw Exception("Profile fetch failed: ${responseData["message"]}");
      }
    } catch (e) {
      print("Get Profile Error: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> sealPdf({
    required String token,
    required ByteData clientCertBytes,
    required ByteData caCertBytes,
    required String password,
    required String userId,
    required String digitalUUID,
    required String vdsData,
  }) async {
    try {
      final clientCertList = clientCertBytes.buffer.asUint8List();
      final caCertList = caCertBytes.buffer.asUint8List();

      var request =
          http.MultipartRequest('POST', Uri.parse('$baseUrl/vdsSeal'));

      request.headers.addAll({
        'Authorization': 'Bearer $token',
      });

      request.files.add(http.MultipartFile.fromBytes(
        'clientCert',
        clientCertList,
        filename: 'client.p12',
      ));
      request.files.add(http.MultipartFile.fromBytes(
        'caCert',
        caCertList,
        filename: 'root_cert.pem',
      ));

      request.fields['password'] = password;
      request.fields['userId'] = userId;
      request.fields['digitalUUID'] = digitalUUID;
      request.fields['vds'] = vdsData;

      var response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final responseData = json.decode(responseBody);

      if (response.statusCode == 200 && responseData["code"] == 0) {
        return responseData["data"];
      } else {
        throw Exception("VDS Seal failed: ${responseData["message"]}");
      }
    } catch (e) {
      print("VDS Seal PDF Error: $e");
      rethrow;
    }
  }
}

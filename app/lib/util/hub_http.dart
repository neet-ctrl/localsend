import 'dart:io';

/// Creates an HttpClient that accepts self-signed certificates.
/// LocalSend uses self-signed TLS certs for LAN device communication;
/// strict verification always fails for devices you haven't pre-trusted.
HttpClient lanHttpClient() => HttpClient()
  ..badCertificateCallback = (X509Certificate cert, String host, int port) {
      return true;
    }
  ..connectionTimeout = const Duration(seconds: 10);

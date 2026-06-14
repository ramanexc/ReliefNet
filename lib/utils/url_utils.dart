import 'dart:io';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class UrlUtils {
  static const _channel = MethodChannel('app.reliefnet/intent');

  static Future<void> launchExternal(String url) async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('launchExternal', {'url': url});
        return;
      } catch (e) {
        // Fallback if method channel fails
      }
    }
    
    // Fallback for iOS or if MethodChannel isn't configured
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }
}

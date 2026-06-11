import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class IndiaPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;

    // Ensure it always starts with +91 
    if (text.length < 4) {
      return const TextEditingValue(
        text: '+91 ',
        selection: TextSelection.collapsed(offset: 4),
      );
    }

    if (!text.startsWith('+91 ')) {
      // Handle cases where +91 might be partially deleted or modified
      text = '+91 ${text.replaceFirst('+91', '').trim()}';
    }

    var digits = text.substring(4).replaceAll(' ', '');
    if (digits.length > 10) digits = digits.substring(0, 10);

    var formatted = '+91 ';
    for (var i = 0; i < digits.length; i++) {
      formatted += digits[i];
      if (i == 4 && digits.length > 5) {
        formatted += ' ';
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

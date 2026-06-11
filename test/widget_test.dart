import 'package:flutter_test/flutter_test.dart';
import 'package:reliefnet/components/phone_formatter.dart';

void main() {
  test('Test IndiaPhoneFormatter', () {
    final formatter = IndiaPhoneFormatter();
    
    // Test formatting behavior
    const oldValue = TextEditingValue.empty;
    const newValue = TextEditingValue(text: '7065558444');
    
    final result = formatter.formatEditUpdate(oldValue, newValue);
    
    expect(result.text, startsWith('+91 '));
  });
}

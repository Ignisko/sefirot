import 'dart:convert';
import 'dart:io';

void main() {
  final b64 = 'Cktwcm9qZWN0cy9zZWZpcm90LWZmOWFmL2RhdGFiYXNlcy8oZGVmYXVsdCkvY29sbGVjdGlvbnNHcm91cHMvbWVzc2FnZXMvaW5kZXhlcy9fEAEaDAoIY2hhdElkEAEaEQoNdGltZXN0YW1wEAIaDAoIX19uYW1lX18QAg';
  final padded = b64.padRight(b64.length + (4 - b64.length % 4) % 4, '=');
  // It's a protobuf payload, so we might just get binary dump, but let's try to extract readable parts
  final bytes = base64Url.decode(padded);
  
  // Quick hack to extract strings
  final buffer = StringBuffer();
  for (final byte in bytes) {
    if (byte >= 32 && byte <= 126) {
      buffer.writeCharCode(byte);
    } else {
      buffer.write('.');
    }
  }
  print(buffer.toString());
}

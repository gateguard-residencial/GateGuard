import 'package:encrypt/encrypt.dart';
import 'dart:convert';

class EncryptionService {
  // Clave de cifrado (en producción debería estar en variables de entorno)
  // AES requiere claves de 128, 192 o 256 bits (16, 24 o 32 bytes)
  static const String _encryptionKey = 'GateGuard2024SecretKey123456789012345678901234567890123456789012345678901234567890';
  
  static final _key = Key.fromUtf8(_encryptionKey.substring(0, 32));
  static final _encrypter = Encrypter(AES(_key));

  /// Cifra un texto usando AES
  static String encrypt(String text) {
    if (text.isEmpty) return text;
    
    try {
      final encrypted = _encrypter.encrypt(text, iv: IV.fromLength(16));
      return encrypted.base64;
    } catch (e) {
      print('Error al cifrar: $e');
      return text; // Retorna el texto original si hay error
    }
  }

  /// Descifra un texto usando AES
  static String decrypt(String encryptedText) {
    if (encryptedText.isEmpty) return encryptedText;
    
    try {
      final encrypted = Encrypted.fromBase64(encryptedText);
      final decrypted = _encrypter.decrypt(encrypted, iv: IV.fromLength(16));
      return decrypted;
    } catch (e) {
      print('Error al descifrar: $e');
      return encryptedText; // Retorna el texto cifrado si hay error
    }
  }

  /// Cifra un mapa de datos del usuario
  static Map<String, dynamic> encryptUserData(Map<String, dynamic> userData) {
    final encryptedData = Map<String, dynamic>.from(userData);
    
    // Campos sensibles que deben cifrarse
    final sensitiveFields = ['name', 'phone', 'address', 'email'];
    
    for (final field in sensitiveFields) {
      if (encryptedData.containsKey(field) && encryptedData[field] != null) {
        final value = encryptedData[field].toString();
        if (value.isNotEmpty) {
          final encryptedValue = encrypt(value);
          encryptedData[field] = encryptedValue;
        }
      }
    }
    return encryptedData;
  }

  /// Descifra un mapa de datos del usuario
  static Map<String, dynamic> decryptUserData(Map<String, dynamic> encryptedData) {
    final decryptedData = Map<String, dynamic>.from(encryptedData);
    
    // Campos sensibles que deben descifrarse
    final sensitiveFields = ['name', 'phone', 'address', 'email'];
    
    for (final field in sensitiveFields) {
      if (decryptedData.containsKey(field) && decryptedData[field] != null) {
        final value = decryptedData[field].toString();
        if (value.isNotEmpty) {
          decryptedData[field] = decrypt(value);
        }
      }
    }
    
    return decryptedData;
  }
}

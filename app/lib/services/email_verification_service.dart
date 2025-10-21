import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'email_sender_service.dart';

class EmailVerificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Genera un código de verificación de 6 dígitos
  static String _generateVerificationCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  /// Envía código de verificación por email
  static Future<bool> sendVerificationCode(String email, {String? userName}) async {
    try {
      // Generar código de 6 dígitos
      final verificationCode = _generateVerificationCode();
      
      // Guardar código en Firestore con expiración de 10 minutos
      await _firestore.collection('email_verifications').doc(email).set({
        'code': verificationCode,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 10))),
        'isUsed': false,
      });

      // Intentar enviar email real
      bool emailSent = false;
      try {
        emailSent = await EmailSenderService.sendVerificationEmail(
          toEmail: email,
          verificationCode: verificationCode,
          userName: userName ?? 'Usuario',
        );
      } catch (e) {
        print('Error al enviar email real: $e');
      }

      // Si falla el envío real, mostrar en consola como fallback
      if (!emailSent) {
        print('═══════════════════════════════════════════════════════════════');
        print('📧 CÓDIGO DE VERIFICACIÓN PARA: $email');
        print('🔐 CÓDIGO: $verificationCode');
        print('⏰ Expira en: 10 minutos');
        print('⚠️  Email no enviado - usando fallback de consola');
        print('═══════════════════════════════════════════════════════════════');
      }
      
      return true; // Siempre retorna true porque el código se guardó en Firebase
    } catch (e) {
      print('Error al enviar código de verificación: $e');
      return false;
    }
  }

  /// Verifica el código ingresado por el usuario
  static Future<bool> verifyCode(String email, String code) async {
    try {
      final doc = await _firestore.collection('email_verifications').doc(email).get();
      
      if (!doc.exists) {
        return false; // No hay código para este email
      }

      final data = doc.data()!;
      final storedCode = data['code'] as String;
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();
      final isUsed = data['isUsed'] as bool;

      // Verificar si el código ha expirado
      if (DateTime.now().isAfter(expiresAt)) {
        // Eliminar código expirado
        await _firestore.collection('email_verifications').doc(email).delete();
        return false;
      }

      // Verificar si ya fue usado
      if (isUsed) {
        return false;
      }

      // Verificar el código
      if (storedCode == code) {
        // Marcar como usado
        await _firestore.collection('email_verifications').doc(email).update({
          'isUsed': true,
          'verifiedAt': FieldValue.serverTimestamp(),
        });
        return true;
      }

      return false;
    } catch (e) {
      print('Error al verificar código: $e');
      return false;
    }
  }

  /// Verifica si un email ya está verificado
  static Future<bool> isEmailVerified(String email) async {
    try {
      final doc = await _firestore.collection('email_verifications').doc(email).get();
      
      if (!doc.exists) {
        return false;
      }

      final data = doc.data()!;
      return data['isUsed'] == true;
    } catch (e) {
      print('Error al verificar estado del email: $e');
      return false;
    }
  }

  /// Reenvía código de verificación
  static Future<bool> resendVerificationCode(String email) async {
    try {
      // Eliminar código anterior si existe
      await _firestore.collection('email_verifications').doc(email).delete();
      
      // Enviar nuevo código
      return await sendVerificationCode(email);
    } catch (e) {
      print('Error al reenviar código: $e');
      return false;
    }
  }
}

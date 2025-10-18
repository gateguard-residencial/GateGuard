import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class QRService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Genera un código QR único para el usuario basado en su UID
  static String generateQRData(String uid) {
    // Crear un string único que incluya el UID y timestamp para mayor seguridad
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'GATEGUARD:${uid}:${timestamp}';
  }

  /// Guarda la información del QR en Firestore
  static Future<void> saveQRData(String uid, String qrData) async {
    try {
      await _firestore.collection('user_qr_codes').doc(uid).set({
        'uid': uid,
        'qrData': qrData,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'userType': 'Residente',
      });
    } catch (e) {
      throw Exception('Error al guardar el código QR: $e');
    }
  }

  /// Obtiene la información del QR del usuario actual
  static Future<String?> getCurrentUserQRData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore.collection('user_qr_codes').doc(user.uid).get();
      
      if (doc.exists) {
        return doc.data()?['qrData'] as String?;
      }
      return null;
    } catch (e) {
      throw Exception('Error al obtener el código QR: $e');
    }
  }

  /// Genera y guarda un nuevo QR para el usuario actual
  static Future<String> generateAndSaveQR() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      final qrData = generateQRData(user.uid);
      await saveQRData(user.uid, qrData);
      
      return qrData;
    } catch (e) {
      throw Exception('Error al generar el código QR: $e');
    }
  }

  /// Verifica si un código QR es válido
  static Future<bool> validateQRCode(String qrData) async {
    try {
      // Parsear el QR data
      final parts = qrData.split(':');
      if (parts.length != 3 || parts[0] != 'GATEGUARD') {
        return false;
      }

      final uid = parts[1];
      
      // Verificar que el usuario existe y está activo
      final doc = await _firestore.collection('user_qr_codes').doc(uid).get();
      
      if (!doc.exists) return false;
      
      final data = doc.data()!;
      return data['isActive'] == true && data['qrData'] == qrData;
    } catch (e) {
      return false;
    }
  }

  /// Obtiene información del usuario por QR
  static Future<Map<String, dynamic>?> getUserInfoByQR(String qrData) async {
    try {
      final parts = qrData.split(':');
      if (parts.length != 3 || parts[0] != 'GATEGUARD') {
        return null;
      }

      final uid = parts[1];
      
      // Obtener información del usuario
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final qrDoc = await _firestore.collection('user_qr_codes').doc(uid).get();
      
      if (!userDoc.exists || !qrDoc.exists) return null;
      
      final userData = userDoc.data()!;
      final qrData_doc = qrDoc.data()!;
      
      return {
        'uid': uid,
        'name': userData['name'],
        'address': userData['address'],
        'userType': userData['userType'],
        'qrCreatedAt': qrData_doc['createdAt'],
        'isActive': qrData_doc['isActive'],
      };
    } catch (e) {
      return null;
    }
  }
}


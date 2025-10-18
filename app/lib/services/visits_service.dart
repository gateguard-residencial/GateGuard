import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VisitsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Obtiene el número de visitas pendientes para el usuario actual
  static Future<int> getPendingVisitsCount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0;

      final querySnapshot = await _firestore
          .collection('visits')
          .where('residentId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .where('visitDate', isGreaterThanOrEqualTo: _getTodayStart())
          .where('visitDate', isLessThan: _getTomorrowStart())
          .get();

      return querySnapshot.docs.length;
    } catch (e) {
      print('Error al obtener visitas pendientes: $e');
      return 0;
    }
  }

  /// Obtiene todas las visitas pendientes del usuario actual
  static Future<List<Map<String, dynamic>>> getPendingVisits() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final querySnapshot = await _firestore
          .collection('visits')
          .where('residentId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .where('visitDate', isGreaterThanOrEqualTo: _getTodayStart())
          .where('visitDate', isLessThan: _getTomorrowStart())
          .orderBy('visitDate')
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print('Error al obtener visitas: $e');
      return [];
    }
  }

  /// Crea una nueva visita para un invitado (modelo simplificado)
  /// Campos guardados:
  /// - residentId (UID del residente)
  /// - guestName
  /// - guestPhone (opcional)
  /// - visitDate (DateTime)
  /// - status (por defecto: 'pending')
  /// - createdAt (serverTimestamp)
  /// - qrCode, approvedAt, approvedBy (para el flujo posterior)
  static Future<String> createVisit({
    required String guestName,
    String? guestPhone,
    required DateTime visitDate,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      // Crear la visita con campos mínimos requeridos
      final visitData = {
        'residentId': user.uid,
        'guestName': guestName,
        'guestPhone': guestPhone ?? '',
        'visitDate': visitDate,
        'status': 'pending', // pending, approved, denied, completed
        'createdAt': FieldValue.serverTimestamp(),
        'qrCode': '', // Se generará cuando se apruebe
        'approvedAt': null,
        'approvedBy': null,
      };

      final docRef = await _firestore.collection('visits').add(visitData);
      
      return docRef.id;
    } catch (e) {
      throw Exception('Error al crear la visita: $e');
    }
  }

  /// Aprueba una visita pendiente
  static Future<void> approveVisit(String visitId) async {
    try {
      await _firestore.collection('visits').doc(visitId).update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': _auth.currentUser?.uid,
      });
    } catch (e) {
      throw Exception('Error al aprobar la visita: $e');
    }
  }

  /// Deniega una visita pendiente
  static Future<void> denyVisit(String visitId, {String? reason}) async {
    try {
      await _firestore.collection('visits').doc(visitId).update({
        'status': 'denied',
        'deniedAt': FieldValue.serverTimestamp(),
        'deniedBy': _auth.currentUser?.uid,
        'denialReason': reason ?? '',
      });
    } catch (e) {
      throw Exception('Error al denegar la visita: $e');
    }
  }

  /// Obtiene el historial de visitas del usuario
  static Future<List<Map<String, dynamic>>> getVisitsHistory({
    int limit = 50,
    String? status,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      Query query = _firestore
          .collection('visits')
          .where('residentId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      final querySnapshot = await query.get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print('Error al obtener historial de visitas: $e');
      return [];
    }
  }

  /// Obtiene estadísticas de visitas del usuario
  static Future<Map<String, int>> getVisitsStats() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {};

      final querySnapshot = await _firestore
          .collection('visits')
          .where('residentId', isEqualTo: user.uid)
          .get();

      int pending = 0;
      int approved = 0;
      int denied = 0;
      int completed = 0;

      for (var doc in querySnapshot.docs) {
        final status = doc.data()['status'] as String?;
        switch (status) {
          case 'pending':
            pending++;
            break;
          case 'approved':
            approved++;
            break;
          case 'denied':
            denied++;
            break;
          case 'completed':
            completed++;
            break;
        }
      }

      return {
        'pending': pending,
        'approved': approved,
        'denied': denied,
        'completed': completed,
        'total': querySnapshot.docs.length,
      };
    } catch (e) {
      print('Error al obtener estadísticas: $e');
      return {};
    }
  }

  /// Helper para obtener el inicio del día actual
  static DateTime _getTodayStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Helper para obtener el inicio del día siguiente
  static DateTime _getTomorrowStart() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
  }

  /// Genera un QR temporal para una visita aprobada
  static Future<String> generateVisitQR(String visitId) async {
    try {
      final visitDoc = await _firestore.collection('visits').doc(visitId).get();
      
      if (!visitDoc.exists) {
        throw Exception('Visita no encontrada');
      }

      final visitData = visitDoc.data()!;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Crear QR específico para la visita
      final qrData = 'VISIT:${visitId}:${timestamp}';
      
      // Actualizar la visita con el QR
      await _firestore.collection('visits').doc(visitId).update({
        'qrCode': qrData,
        'qrGeneratedAt': FieldValue.serverTimestamp(),
      });

      return qrData;
    } catch (e) {
      throw Exception('Error al generar QR de visita: $e');
    }
  }
}


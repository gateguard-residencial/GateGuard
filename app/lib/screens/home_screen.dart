import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/qr_service.dart';
import '../services/visits_service.dart';
import '../services/encryption_service.dart';
import 'visits_history_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? userName;
  String? userAddress;
  String? userQRData;
  bool isLoading = true;
  int pendingVisitors = 0;
  List<Map<String, dynamic>> pendingVisitsList = [];

  @override
  void initState() {
    super.initState();
    _getUserData();
  }

  Future<void> _getUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Obtener datos del usuario
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        // Obtener datos del QR
        final qrData = await QRService.getCurrentUserQRData();
        
        // Obtener visitas pendientes
        final pendingCount = await VisitsService.getPendingVisitsCount();
        final pendingVisits = await VisitsService.getPendingVisits();
        
        if (userDoc.exists) {
          final encryptedData = userDoc.data()!;
          
          // Descifrar datos sensibles
          final decryptedData = EncryptionService.decryptUserData(encryptedData);
          
          setState(() {
            userName = decryptedData['name'] ?? 'Usuario';
            userAddress = decryptedData['address'] ?? 'Fraccionamiento';
            userQRData = qrData;
            pendingVisitors = pendingCount;
            pendingVisitsList = pendingVisits;
            isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        userName = 'Usuario';
        userAddress = 'Fraccionamiento';
        userQRData = null;
        pendingVisitors = 0;
        pendingVisitsList = [];
        isLoading = false;
      });
    }
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _goToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProfileScreen(),
      ),
    );
  }

  void _viewVisitorsList() {
    // TODO: Implementar lista de visitantes
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Próximamente: Lista de visitantes'),
        backgroundColor: Color(0xFF4CAF50),
      ),
    );
  }

  void _viewAccessHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const VisitsHistoryScreen(),
      ),
    ).then((_) {
      // Al volver del historial, refrescar estado de visitas
      _refreshPendingVisits();
    });
  }

  void _regenerateQR() async {
    try {
      // Mostrar indicador de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      // Regenerar QR
      final newQRData = await QRService.generateAndSaveQR();
      
      setState(() {
        userQRData = newQRData;
      });

      Navigator.pop(context); // cerrar loader
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Código QR regenerado exitosamente!'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
    } catch (e) {
      Navigator.pop(context); // cerrar loader
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al regenerar QR: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _refreshPendingVisits() async {
    try {
      final pendingCount = await VisitsService.getPendingVisitsCount();
      final pendingVisits = await VisitsService.getPendingVisits();
      if (!mounted) return;
      setState(() {
        pendingVisitors = pendingCount;
        pendingVisitsList = pendingVisits;
      });
    } catch (e) {
      // Silently ignore refresh errors for now
    }
  }

  void _debugInsertTestVisitForResident() async {
    try {
      final visitDate = DateTime.now().add(const Duration(minutes: 30));
      
      await FirebaseFirestore.instance.collection('visits').add({
        'residentId': '0oP3xgBd2dPVUrL46VLQBcuiHZz1',
        'guestName': 'Invitado demo',
        'guestPhone': '5550001111',
        'visitDate': visitDate,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'qrCode': '',
        'approvedAt': null,
        'approvedBy': null,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Visita de prueba insertada')),
        );
      }
      
      // Esperar un poco para que la inserción se complete
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Refrescar contador y lista de visitas pendientes
      await _refreshPendingVisits();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al insertar visita: $e')),
        );
      }
    }
  }

  String _formatVisitTime(dynamic visitDate) {
    try {
      if (visitDate is Timestamp) {
        final date = visitDate.toDate();
        return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      } else if (visitDate is DateTime) {
        return '${visitDate.hour.toString().padLeft(2, '0')}:${visitDate.minute.toString().padLeft(2, '0')}';
      }
      return '--:--';
    } catch (e) {
      return '--:--';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1976D2),
                Color(0xFF1565C0),
              ],
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'GateGuard',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w300,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            Text(
              userAddress ?? 'Fraccionamiento',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          // TEMP: Acción de depuración para insertar una visita de prueba
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white.withOpacity(0.2),
              child: IconButton(
                icon: const Icon(
                  Icons.bug_report_outlined,
                  size: 20,
                ),
                onPressed: _debugInsertTestVisitForResident,
                tooltip: 'Insertar visita demo',
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white.withOpacity(0.2),
              child: IconButton(
                icon: const Icon(
                  Icons.person_outline,
                  size: 20,
                ),
                onPressed: _goToProfile,
                tooltip: 'Perfil',
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white.withOpacity(0.2),
              child: IconButton(
                icon: const Icon(
                  Icons.logout,
                  size: 20,
                ),
            onPressed: _logout,
                tooltip: 'Cerrar Sesión',
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: Text(
                    userName?.substring(0, 1).toUpperCase() ?? 'U',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Hola, ${userName ?? 'Usuario'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Residente',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.home,
                        size: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'En línea',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE3F2FD),
              Color(0xFFF1F8E9),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                _buildNotificationsSection(),
                const SizedBox(height: 30),
                _buildQRResidentSection(),
                const SizedBox(height: 30),
                _buildActionButtonsSection(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildQRResidentSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4CAF50),
            Color(0xFF388E3C),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withOpacity(0.4),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Icon(
                  Icons.qr_code,
                  size: 32,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tu QR de Acceso',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Código personal para el fraccionamiento',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.security,
                          size: 16,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          userQRData != null ? 'Activo' : 'Generando...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _regenerateQR,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.refresh,
                        size: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                Center(
                  child: userQRData != null
                    ? QrImageView(
                        data: userQRData!,
                        version: QrVersions.auto,
                        size: 200.0,
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF4CAF50),
                        errorStateBuilder: (cxt, err) {
                          return const Icon(
                            Icons.error,
                            size: 200,
                            color: Colors.red,
                          );
                        },
                      )
                    : const Icon(
                        Icons.qr_code_2,
                        size: 200,
                        color: Color(0xFF4CAF50),
                      ),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: userQRData != null 
                        ? const Color(0xFF4CAF50)
                        : Colors.orange,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      userQRData != null ? Icons.check : Icons.sync,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtonsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
        children: [
          Container(
                width: 50,
                height: 50,
            decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1976D2),
                      Color(0xFF1565C0),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(25),
            ),
            child: const Icon(
                  Icons.receipt_long,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
          Text(
                      'Historial de visitas',
            style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1F36),
                      ),
                    ),
          Text(
                      'Consulta tus registros de entradas y salidas',
            style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildActionButton(
            icon: Icons.receipt_long,
            title: 'Ver historial',
            subtitle: 'Entradas y salidas',
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1976D2),
                Color(0xFF1565C0),
              ],
            ),
            onTap: _viewAccessHistory,
            isFullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required LinearGradient gradient,
    required VoidCallback onTap,
    bool isFullWidth = false,
  }) {
    return Container(
      width: isFullWidth ? double.infinity : null,
      height: isFullWidth ? 65 : 90,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: isFullWidth 
              ? Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 1),
          Text(
                            subtitle,
            style: TextStyle(
                              fontSize: 11,
              color: Colors.white.withOpacity(0.9),
            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white.withOpacity(0.8),
                      size: 12,
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
          Text(
                      title,
            style: const TextStyle(
                        fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.white.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
          ),
        ],
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: pendingVisitors > 0 
            ? [
                const Color(0xFFFF9800).withOpacity(0.1),
                const Color(0xFFFF9800).withOpacity(0.05),
              ]
            : [
                const Color(0xFF4CAF50).withOpacity(0.1),
                const Color(0xFF4CAF50).withOpacity(0.05),
              ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: pendingVisitors > 0 
            ? const Color(0xFFFF9800).withOpacity(0.3)
            : const Color(0xFF4CAF50).withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: pendingVisitors > 0 
              ? const Color(0xFFFF9800).withOpacity(0.2)
              : const Color(0xFF4CAF50).withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: pendingVisitors > 0 
                    ? const Color(0xFFFF9800).withOpacity(0.2)
                    : const Color(0xFF4CAF50).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Icon(
                  pendingVisitors > 0 ? Icons.notifications_active : Icons.notifications_none,
                  color: pendingVisitors > 0 ? const Color(0xFFFF9800) : const Color(0xFF4CAF50),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estado de Visitas',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: pendingVisitors > 0 
                          ? const Color(0xFFFF9800)
                          : const Color(0xFF4CAF50),
                      ),
                    ),
                    Text(
                      'Información actualizada',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (pendingVisitors > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800),
            borderRadius: BorderRadius.circular(12),
          ),
                  child: Text(
                    '$pendingVisitors',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      pendingVisitors > 0 ? Icons.person_add : Icons.check_circle,
                      color: pendingVisitors > 0 ? const Color(0xFFFF9800) : const Color(0xFF4CAF50),
                      size: 28,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pendingVisitors > 0 
                              ? 'Tienes visitantes pendientes'
                              : 'Todo en orden',
                            style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
                              color: Color(0xFF333333),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            pendingVisitors > 0 
                              ? 'Hoy tienes $pendingVisitors visitantes esperando tu autorización'
                              : 'No hay visitas programadas para hoy',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (pendingVisitors > 0) ...[
                  const SizedBox(height: 16),
                  ...pendingVisitsList.take(3).map((visit) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9800).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFFF9800).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.person,
                          color: const Color(0xFFFF9800),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                visit['guestName'] ?? 'Invitado',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF333333),
                                ),
                              ),
                              Text(
                                visit['reason'] ?? 'Visita',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _formatVisitTime(visit['visitDate']),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                  if (pendingVisitsList.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Y ${pendingVisitsList.length - 3} visitas más...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}


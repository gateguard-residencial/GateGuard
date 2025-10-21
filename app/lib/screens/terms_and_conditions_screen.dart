import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

class TermsAndConditionsScreen extends StatefulWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  State<TermsAndConditionsScreen> createState() => _TermsAndConditionsScreenState();
}

class _TermsAndConditionsScreenState extends State<TermsAndConditionsScreen> {
  String _termsContent = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTerms();
  }

  // Función asíncrona para cargar el texto desde el archivo de assets
  Future<void> _loadTerms() async {

    debugPrint('Iniciando la carga de términos y condiciones...');

    try {
      final content = await rootBundle.loadString('assets/terms_and_conditions.txt');

      debugPrint('Archivo de términos cargado exitosamente.');

      if (mounted) {
        setState(() {
          _termsContent = content;
          _isLoading = false;
        });
      }
    } catch (e, stacktrace) {

      debugPrint('Error al cargar los términos y condiciones: $e');
      debugPrint('Stacktrace: $stacktrace');

      if (mounted) {
        setState(() {
          _termsContent = 'No se pudieron cargar los términos y condiciones. Por favor, inténtelo de nuevo más tarde.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Términos y Condiciones'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          // Muestra un indicador de carga mientras se lee el archivo
          ? const Center(child: CircularProgressIndicator())
          // Muestra el contenido una vez cargado
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Text(
                _termsContent,
                textAlign: TextAlign.justify,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: Color(0xFF333333),
                ),
              ),
            ),
    );
  }
}

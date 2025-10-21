import 'dart:convert';
import 'package:http/http.dart' as http;

class EmailSenderService {
  // Configuración de SendGrid (gratis hasta 100 emails/día)
  static const String _apiKey = 'SG.REEMPLAZA_CON_TU_API_KEY_AQUI'; // Reemplaza con tu API key
  static const String _fromEmail = 'tu-email@gmail.com'; // Tu email verificado en SendGrid
  static const String _fromName = 'GateGuard Residencial';

  /// Envía código de verificación por email usando SendGrid
  static Future<bool> sendVerificationEmail({
    required String toEmail,
    required String verificationCode,
    required String userName,
  }) async {
    try {
      final url = Uri.parse('https://api.sendgrid.com/v3/mail/send');
      
      final headers = {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      };

      final body = {
        'personalizations': [
          {
            'to': [
              {'email': toEmail, 'name': userName}
            ],
            'subject': 'Código de Verificación - GateGuard'
          }
        ],
        'from': {
          'email': _fromEmail,
          'name': _fromName
        },
        'content': [
          {
            'type': 'text/html',
            'value': _buildEmailTemplate(userName, verificationCode)
          }
        ]
      };

      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode == 202) {
        print('✅ Email enviado exitosamente a: $toEmail');
        return true;
      } else {
        print('❌ Error al enviar email: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error en EmailSenderService: $e');
      return false;
    }
  }

  /// Template HTML para el email
  static String _buildEmailTemplate(String userName, String verificationCode) {
    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Verificación de Email - GateGuard</title>
    </head>
    <body style="margin: 0; padding: 0; font-family: Arial, sans-serif; background-color: #f5f5f5;">
        <div style="max-width: 600px; margin: 0 auto; background-color: white; padding: 20px;">
            <!-- Header -->
            <div style="text-align: center; padding: 20px 0; border-bottom: 2px solid #1976D2;">
                <h1 style="color: #1976D2; margin: 0;">GateGuard Residencial</h1>
                <p style="color: #666; margin: 5px 0 0 0;">Sistema de Control de Acceso</p>
            </div>
            
            <!-- Content -->
            <div style="padding: 30px 20px;">
                <h2 style="color: #333; margin-bottom: 20px;">¡Hola $userName!</h2>
                
                <p style="color: #666; line-height: 1.6; margin-bottom: 20px;">
                    Gracias por registrarte en GateGuard Residencial. Para completar tu registro, 
                    necesitamos verificar tu dirección de email.
                </p>
                
                <div style="background-color: #f8f9fa; border: 2px solid #1976D2; border-radius: 10px; padding: 20px; text-align: center; margin: 30px 0;">
                    <p style="margin: 0 0 10px 0; color: #333; font-weight: bold;">Tu código de verificación es:</p>
                    <div style="font-size: 32px; font-weight: bold; color: #1976D2; letter-spacing: 5px; font-family: monospace;">
                        $verificationCode
                    </div>
                </div>
                
                <p style="color: #666; line-height: 1.6; margin-bottom: 20px;">
                    <strong>Importante:</strong>
                </p>
                <ul style="color: #666; line-height: 1.6; margin-bottom: 20px;">
                    <li>Este código expira en <strong>10 minutos</strong></li>
                    <li>Ingresa el código en la aplicación para completar tu registro</li>
                    <li>Si no solicitaste este código, ignora este email</li>
                </ul>
                
                <div style="text-align: center; margin-top: 30px;">
                    <p style="color: #999; font-size: 12px;">
                        Este es un email automático, por favor no respondas.
                    </p>
                </div>
            </div>
            
            <!-- Footer -->
            <div style="text-align: center; padding: 20px; background-color: #f8f9fa; border-top: 1px solid #eee;">
                <p style="color: #666; margin: 0; font-size: 12px;">
                    © 2024 GateGuard Residencial. Todos los derechos reservados.
                </p>
            </div>
        </div>
    </body>
    </html>
    ''';
  }
}

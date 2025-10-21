const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

admin.initializeApp();

// Configuración de email (reemplaza con tus credenciales)
const transporter = nodemailer.createTransporter({
  service: 'gmail', // o tu proveedor de email
  auth: {
    user: 'tu-email@gmail.com', // Reemplaza con tu email
    pass: 'tu-app-password' // Reemplaza con tu contraseña de aplicación
  }
});

// Función para enviar código de verificación
exports.sendVerificationCode = functions.https.onCall(async (data, context) => {
  try {
    const { email, userName, verificationCode } = data;

    // Validar datos
    if (!email || !userName || !verificationCode) {
      throw new functions.https.HttpsError('invalid-argument', 'Faltan parámetros requeridos');
    }

    // Template del email
    const htmlContent = `
      <!DOCTYPE html>
      <html>
      <head>
          <meta charset="utf-8">
          <title>Verificación de Email - GateGuard</title>
      </head>
      <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
          <div style="text-align: center; background-color: #1976D2; color: white; padding: 20px; border-radius: 10px 10px 0 0;">
              <h1>GateGuard Residencial</h1>
              <p>Sistema de Control de Acceso</p>
          </div>
          
          <div style="background-color: #f8f9fa; padding: 30px; border-radius: 0 0 10px 10px;">
              <h2>¡Hola ${userName}!</h2>
              <p>Gracias por registrarte en GateGuard Residencial. Para completar tu registro, necesitamos verificar tu dirección de email.</p>
              
              <div style="background-color: white; border: 2px solid #1976D2; border-radius: 10px; padding: 20px; text-align: center; margin: 20px 0;">
                  <p style="margin: 0 0 10px 0; font-weight: bold;">Tu código de verificación es:</p>
                  <div style="font-size: 32px; font-weight: bold; color: #1976D2; letter-spacing: 5px; font-family: monospace;">
                      ${verificationCode}
                  </div>
              </div>
              
              <p><strong>Importante:</strong></p>
              <ul>
                  <li>Este código expira en <strong>10 minutos</strong></li>
                  <li>Ingresa el código en la aplicación para completar tu registro</li>
                  <li>Si no solicitaste este código, ignora este email</li>
              </ul>
              
              <p style="text-align: center; color: #666; font-size: 12px; margin-top: 30px;">
                  Este es un email automático, por favor no respondas.
              </p>
          </div>
      </body>
      </html>
    `;

    // Configuración del email
    const mailOptions = {
      from: 'GateGuard Residencial <tu-email@gmail.com>',
      to: email,
      subject: 'Código de Verificación - GateGuard',
      html: htmlContent
    };

    // Enviar email
    await transporter.sendMail(mailOptions);

    console.log(`Email de verificación enviado a: ${email}`);
    return { success: true, message: 'Email enviado exitosamente' };

  } catch (error) {
    console.error('Error al enviar email:', error);
    throw new functions.https.HttpsError('internal', 'Error al enviar email: ' + error.message);
  }
});


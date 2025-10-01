// Test para GateGuard Residencial - Pantalla de Login
//
// Este test verifica que la pantalla de login se renderice correctamente
// y que los elementos principales estén presentes.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gateguard/main.dart';

void main() {
  testWidgets('Login screen renders correctly', (WidgetTester tester) async {
    // Construir la aplicación y activar un frame
    await tester.pumpWidget(const GateGuardApp());

    // Verificar que el logo y texto principal estén presentes
    // Nota: "GateGuard" está dividido en dos TextSpan, así que buscamos por partes
    expect(find.text('Gate'), findsOneWidget);
    expect(find.text('Guard'), findsOneWidget);
    expect(find.text('Residencial'), findsOneWidget);
    
    // Verificar que el formulario de login esté presente
    expect(find.text('Iniciar Sesión'), findsOneWidget);
    expect(find.text('Usuario'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    
    // Verificar que los botones estén presentes
    expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
    expect(find.text('¿No tienes una cuenta?'), findsOneWidget);
    expect(find.text('Regístrate'), findsOneWidget);
    
    // Verificar que los íconos estén presentes
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off), findsOneWidget);
  });

  testWidgets('Login form validation works', (WidgetTester tester) async {
    // Construir la aplicación
    await tester.pumpWidget(const GateGuardApp());

    // Intentar enviar el formulario vacío
    await tester.tap(find.text('Iniciar Sesión'));
    await tester.pump();

    // Verificar que aparezcan los mensajes de error
    expect(find.text('Por favor ingresa tu usuario'), findsOneWidget);
    expect(find.text('Por favor ingresa tu contraseña'), findsOneWidget);
  });

  testWidgets('Password visibility toggle works', (WidgetTester tester) async {
    // Construir la aplicación
    await tester.pumpWidget(const GateGuardApp());

    // Verificar que inicialmente el ícono sea de ojo cerrado
    expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    expect(find.byIcon(Icons.visibility), findsNothing);

    // Hacer tap en el botón de mostrar/ocultar contraseña
    await tester.tap(find.byIcon(Icons.visibility_off));
    await tester.pump();

    // Verificar que el ícono cambie a ojo abierto
    expect(find.byIcon(Icons.visibility), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off), findsNothing);
  });

  testWidgets('Forgot password dialog appears', (WidgetTester tester) async {
    // Construir la aplicación
    await tester.pumpWidget(const GateGuardApp());

    // Hacer tap en "¿Olvidaste tu contraseña?"
    await tester.tap(find.text('¿Olvidaste tu contraseña?'));
    await tester.pump();

    // Verificar que aparezca el diálogo
    expect(find.text('Recuperar Contraseña'), findsOneWidget);
    expect(find.text('¿Necesitas ayuda para recuperar tu contraseña?'), findsOneWidget);
    expect(find.text('Cerrar'), findsOneWidget);
    expect(find.text('Enviar'), findsOneWidget);
  });
}

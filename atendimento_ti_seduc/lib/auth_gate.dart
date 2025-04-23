// lib/auth_gate.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'home_page.dart'; // Ou sua tela principal
import 'lista_chamados_screen.dart'; // Importe a ListaChamadosScreen

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return const ListaChamadosScreen(); // Ou HomePage()
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
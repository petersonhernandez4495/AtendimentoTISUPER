import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'login_screen.dart';
// import 'home_page.dart'; // Removido se não usar HomePage aqui
// import 'lista_chamados_screen.dart'; // Removido se não usar ListaChamadosScreen aqui
import 'main_navigation_screen.dart'; // <<< IMPORTAR MainNavigationScreen >>>

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Usuário está logado
        if (snapshot.hasData) {
          // <<< ALTERAÇÃO AQUI >>>
          return const MainNavigationScreen(); // Mostra a tela de navegação principal
        }
        // Usuário NÃO está logado
        else {
          return const LoginScreen(); // Mostra a tela de login
        }
        // Opcional: Adicionar um indicador de carregamento enquanto verifica
        // if (snapshot.connectionState == ConnectionState.waiting) {
        //   return const Center(child: CircularProgressIndicator());
        // }
      },
    );
  }
}
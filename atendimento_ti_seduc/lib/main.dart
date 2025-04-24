// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/audio_notification_service.dart';
// Seus imports de tela
import 'login_screen.dart';
import 'cadastro_screen.dart';
import 'lista_chamados_screen.dart';
// import 'home_page.dart'; // Comentado no seu código original
// import 'auth_gate.dart'; // Comentado no seu código original
// import 'novo_chamado_screen.dart'; // Comentado no seu código original

// --- Importe a nova tela de navegação principal ---
// (Certifique-se de criar este arquivo depois, como discutimos)
import 'main_navigation_screen.dart'; // <--- ADICIONAR IMPORT

// Importe o arquivo de opções do Firebase
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
    );
    await initializeDateFormatting('pt_BR', null);
    runApp(const MyApp());
  } catch (e) {
    print('Erro ao inicializar o app: $e');
  }

  AudioNotificationService.startListening();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cadastro de Atendimento',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [
         Locale('pt', 'BR'),
         Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // --- PONTO DE ENTRADA PRINCIPAL ALTERADO ---
      // Define a tela com a BottomNavigationBar como inicial.
      // OBS: Isso vai pular a tela de login. O ideal é manter
      // LoginScreen como home e navegar para MainNavigationScreen APÓS o login.
      home: const MainNavigationScreen(), // <--- ALTERADO DE LoginScreen
      // ---------------------------------------------

      // Rotas nomeadas podem ainda ser úteis para navegação específica,
      // mas a navegação principal será controlada pela BottomNavBar.
      routes: {
        '/login': (context) => const LoginScreen(),
        '/cadastro': (context) => const CadastroScreen(),
        // A rota '/lista_chamados' pode não ser mais necessária se
        // ListaChamadosScreen for apenas uma das abas da MainNavigationScreen.
        '/lista_chamados': (context) => const ListaChamadosScreen(),
        // '/home': (context) => const HomePage(),
      },
    );
  }
}

// Pode remover MyHomePage e _MyHomePageState se não estiverem sendo usados.
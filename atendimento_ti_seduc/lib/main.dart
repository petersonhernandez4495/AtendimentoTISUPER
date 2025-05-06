import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// --- Importe a classe AppTheme ---
import 'config/theme/app_theme.dart';

// Imports das telas e serviços
import 'services/audio_notification_service.dart';
import 'login_screen.dart';
import 'cadastro_screen.dart';
import 'lista_chamados_screen.dart';
import 'main_navigation_screen.dart';
import 'firebase_options.dart';
import 'user_management_screen.dart';
import 'auth_gate.dart'; // <<< IMPORTAR O AUTH GATE >>>

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
    // Considere um erro visual mais claro para o usuário em produção
  }
  // Removido AudioNotificationService daqui, idealmente inicializado onde for usado.
  // AudioNotificationService.startListening();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Atendimento TI', // Título ajustado
      theme: AppTheme.darkTheme, // Usando seu tema
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,

      // --- PONTO DE ENTRADA ALTERADO ---
      // Agora aponta para o AuthGate, que decide entre Login e MainNavigation
      home: const AuthGate(),
      // ---------------------------------

      // Rotas nomeadas podem ser mantidas se você ainda as usa para navegação interna
      routes: {
        '/login': (context) => const LoginScreen(),
        '/cadastro': (context) => const CadastroScreen(),
        '/main_nav': (context) => const MainNavigationScreen(),
        '/lista_chamados': (context) => const ListaChamadosScreen(),
        '/user_management': (context) => const UserManagementScreen(),
      },
    );
  }
}
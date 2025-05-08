import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'config/theme/app_theme.dart';

import 'login_screen.dart';
import 'cadastro_screen.dart';
import 'lista_chamados_screen.dart';
import 'main_navigation_screen.dart';
import 'firebase_options.dart';
import 'user_management_screen.dart';
import 'auth_gate.dart';
import 'screens/tutorial_screen.dart';
import 'profile_screen.dart';
import 'agenda_screen.dart';
import 'novo_chamado_screen.dart';
import 'chamados_arquivados_screen.dart';


class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('Tela: $title\n(Implementar esta tela)')),
    );
  }
}

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
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Atendimento TI',
      theme: AppTheme.darkTheme,
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
      home: const AuthGate(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/cadastro': (context) => const CadastroScreen(),
        '/main_nav': (context) => const MainNavigationScreen(),
        TutorialScreen.routeName: (context) => const TutorialScreen(),
        '/chamados': (context) => const ListaChamadosScreen(),
        '/novo_chamado': (context) => const NovoChamadoScreen(),
        '/agenda': (context) => const AgendaScreen(),
        '/perfil': (context) => const ProfileScreen(),
        '/gerenciar_usuarios': (context) => const UserManagementScreen(),
        '/chamados_arquivados': (context) => const ListaChamadosArquivadosScreen(),
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Página Não Encontrada')),
            body: Center(
              child: Text('A rota "${settings.name}" não foi encontrada.'),
            ),
          ),
        );
      },
    );
  }
}

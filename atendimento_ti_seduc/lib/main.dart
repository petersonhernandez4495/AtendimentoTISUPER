import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart'; // Para formatação de datas
import 'package:flutter_localizations/flutter_localizations.dart';

// Importações do seu projeto
import 'config/theme/app_theme.dart'; // Seu tema
import 'login_screen.dart';
import 'cadastro_screen.dart';
import 'lista_chamados_screen.dart';
import 'main_navigation_screen.dart';
import 'firebase_options.dart'; // Configurações do Firebase
import 'user_management_screen.dart';
import 'auth_gate.dart'; // Seu widget de controle de autenticação
import 'screens/tutorial_screen.dart'; // Sua tela de tutorial
import 'profile_screen.dart';
import 'agenda_screen.dart';
import 'novo_chamado_screen.dart';
import 'chamados_arquivados_screen.dart';

// Classe PlaceholderScreen (se você ainda a utiliza em algum lugar)
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
  // 1. Garante que os bindings do Flutter sejam inicializados
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Inicialização do Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform, // Usa o firebase_options.dart gerado
    );
  } catch (e) {
    print('Erro ao inicializar o Firebase: $e');
    // Considere tratar este erro de forma mais robusta se o Firebase for crítico
    // Exemplo: runApp(ErrorApp(errorMessage: "Falha ao conectar ao Firebase: $e"));
  }

  // 3. Inicialização da formatação de data para pt_BR
  try {
    await initializeDateFormatting('pt_BR', null);
  } catch (e) {
    print('Erro ao inicializar formatação de data: $e');
  }

  // 4. Executa o aplicativo
  // O plugin webview_windows geralmente não requer inicialização explícita aqui.
  // Ele tentará usar o WebView2 Runtime existente ou baixá-lo, se necessário.
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Atendimento TI SUPER', // Título do seu aplicativo
      theme: AppTheme.darkTheme, // Seu tema escuro padrão
      // Se você tiver um tema claro, pode configurá-lo também:
      // theme: AppTheme.lightTheme,
      // darkTheme: AppTheme.darkTheme,
      // themeMode: ThemeMode.system, // Ou ThemeMode.light, ThemeMode.dark
      locale: const Locale('pt', 'BR'), // Define o local padrão para Português do Brasil
      supportedLocales: const [
        Locale('pt', 'BR'),
        // Adicione outros locales suportados se necessário
        // Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate, // Localização para widgets Material
        GlobalWidgetsLocalizations.delegate, // Localização para widgets básicos
        GlobalCupertinoLocalizations.delegate, // Localização para widgets Cupertino
      ],
      debugShowCheckedModeBanner: false, // Remove o banner de debug
      home: const AuthGate(), // Ponto de entrada da UI após inicializações (controla login)
      routes: {
        // Define as rotas nomeadas do seu aplicativo
        '/login': (context) => const LoginScreen(),
        '/cadastro': (context) => const CadastroScreen(),
        '/main_nav': (context) => const MainNavigationScreen(),
        TutorialScreen.routeName: (context) => const TutorialScreen(), // Rota para a tela de tutoriais
        '/chamados': (context) => const ListaChamadosScreen(),
        '/novo_chamado': (context) => const NovoChamadoScreen(),
        '/agenda': (context) => const AgendaScreen(),
        '/perfil': (context) => const ProfileScreen(),
        '/gerenciar_usuarios': (context) => const UserManagementScreen(),
        '/chamados_arquivados': (context) => const ListaChamadosArquivadosScreen(),
      },
      onUnknownRoute: (settings) {
        // Fallback para rotas desconhecidas
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

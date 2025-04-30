// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// --- Importe a classe AppTheme ---
// Certifique-se que o caminho está correto para o seu projeto
import 'config/theme/app_theme.dart'; // <--- USA A CLASSE AppTheme

// Imports das telas e serviços (verifique os caminhos se necessário)
import 'services/audio_notification_service.dart';
import 'login_screen.dart';
import 'cadastro_screen.dart';
import 'lista_chamados_screen.dart'; // Importa a tela (embora seja usada dentro da navegação)
import 'main_navigation_screen.dart'; // Tela principal com a navegação
import 'firebase_options.dart';     // Arquivo gerado pelo FlutterFire CLI

Future<void> main() async {
  // Garante inicialização do Flutter
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Inicializa Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Inicializa formatação de datas para Português (Brasil)
    await initializeDateFormatting('pt_BR', null);
    // Roda o aplicativo
    runApp(const MyApp());
  } catch (e) {
    // Tratamento básico de erro durante inicialização
    print('Erro ao inicializar o app: $e');
    // Em um app de produção, considere mostrar uma mensagem mais amigável
    // ou ter um mecanismo de fallback.
  }

  // Inicia serviço de notificação de áudio (se aplicável ao seu projeto)
  AudioNotificationService.startListening();
}

class MyApp extends StatelessWidget {
  // Construtor padrão para StatelessWidget
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Título que aparece na gestão de apps do sistema operacional
      title: 'Cadastro de Atendimento',

      // --- TEMA APLICADO VIA CLASSE ESTÁTICA ---
      theme: AppTheme.darkTheme, // Aplica o tema escuro definido na classe AppTheme
      // -----------------------------------------

      // --- CONFIGURAÇÕES DE LOCALIZAÇÃO ---
      locale: const Locale('pt', 'BR'), // Define Português (Brasil) como padrão
      supportedLocales: const [
        Locale('pt', 'BR'), // Único idioma suportado explicitamente aqui
        // Locale('en', 'US'), // Adicione se precisar de suporte a Inglês
      ],
      localizationsDelegates: const [
        // Delegates necessários para usar localizações do Material e Widgets
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate, // Para widgets estilo iOS
      ],
      // ------------------------------------

      // Remove a faixa "Debug" no canto superior direito
      debugShowCheckedModeBanner: false,

      // --- PONTO DE ENTRADA PRINCIPAL ---
      // Define a tela inicial que será exibida quando o app abrir.
      // OBSERVAÇÃO: Conforme seu código anterior, está indo direto para a tela
      // de navegação principal. Lembre-se que para produção, o fluxo ideal
      // seria começar com LoginScreen ou um verificador de autenticação.
      home: const MainNavigationScreen(),
      // -----------------------------------

      // --- ROTAS NOMEADAS ---
      // Permitem navegar para telas específicas usando um nome.
      // Avalie se todas ainda são necessárias ou se a navegação principal
      // via MainNavigationScreen cobre a maioria dos casos.
      routes: {
        '/login': (context) => const LoginScreen(),
        '/cadastro': (context) => const CadastroScreen(),
        '/main_nav': (context) => const MainNavigationScreen(),
        // só é acessada como uma aba dentro de MainNavigationScreen.
        '/lista_chamados': (context) => const ListaChamadosScreen(),
      },
      // ---------------------
    );
  }
}
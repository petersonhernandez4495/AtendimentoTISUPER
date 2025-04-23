// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart'; 
import 'package:flutter_localizations/flutter_localizations.dart';

// Seus imports de tela
import 'login_screen.dart';
import 'cadastro_screen.dart';
import 'lista_chamados_screen.dart';
import 'home_page.dart'; 
import 'auth_gate.dart'; 
import 'novo_chamado_screen.dart';

// Importe o arquivo de opções do Firebase
import 'firebase_options.dart';

Future<void> main() async { // Precisa ser async
  WidgetsFlutterBinding.ensureInitialized(); // Garante inicialização do Flutter
  try {
    await Firebase.initializeApp( // Inicializa Firebase
        options: DefaultFirebaseOptions.currentPlatform,
    );

    // --- ADICIONE ESTA LINHA AQUI ---
    // Inicializa os dados de formatação para Português do Brasil
    await initializeDateFormatting('pt_BR', null);
    // ---------------------------------

    runApp(const MyApp()); // Chama o app DEPOIS de inicializar tudo

  } catch (e) {
    // É uma boa prática ter um tratamento de erro aqui
    print('Erro ao inicializar o app: $e');
    // Poderia exibir uma tela de erro simples aqui se a inicialização falhar
    // runApp(ErrorScreen(errorMessage: e.toString()));
  }
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
      // Definir o locale padrão da aplicação (opcional, mas recomendado)
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [
         Locale('pt', 'BR'),
         Locale('en', 'US'), // Adicione outros se suportar mais línguas
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // ------------------------------------------------------------
      home: const LoginScreen(), // Sua tela inicial
      routes: {
        // Suas rotas nomeadas
        '/login': (context) => const LoginScreen(),
        '/cadastro': (context) => const CadastroScreen(),
        '/lista_chamados': (context) => const ListaChamadosScreen(),
        // '/home': (context) => const HomePage(),
      },
    );
  }
}

// A classe MyHomePage e _MyHomePageState parecem ser código padrão não utilizado,
// já que sua 'home' está definida como LoginScreen.
// Você pode remover MyHomePage e _MyHomePageState se não estiverem sendo usados.
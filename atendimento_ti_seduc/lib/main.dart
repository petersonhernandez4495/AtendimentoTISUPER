import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

// Importe o arquivo de opções do Firebase, se gerado
// import 'firebase_options.dart';

void main() async {
  // Garante que os widgets do Flutter estejam inicializados
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o Firebase
  await Firebase.initializeApp(
    // Se você tiver o arquivo firebase_options.dart, use esta linha:
    // options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
} catch (e) {
    print('Exceção ao rodar o app: $e');
  }

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cadastro de Atendimento', // Atualizei o título
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue), // Mudei a cor de exemplo
        useMaterial3: true, // Opcional: para usar a versão mais recente do Material Design
      ),
      home: const MyHomePage(title: 'Página Inicial'), // Atualizei o título da página inicial
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('Você apertou o botão tantas vezes:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Incrementar',
        child: const Icon(Icons.add),
      ),
    );
  }
}
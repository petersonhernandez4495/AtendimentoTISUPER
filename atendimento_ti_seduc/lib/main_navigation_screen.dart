// lib/main_navigation_screen.dart
import 'package:flutter/material.dart';

// Importe os WIDGETS DE CONTEÚDO (sem Scaffold/AppBar)
import 'lista_chamados_screen.dart'; // <<< Certifique-se que este é SÓ o conteúdo
import 'novo_chamado_screen.dart';          // <<< Verifique se esta precisa ou não de Scaffold próprio
import 'profile_screen.dart';             // <<< Certifique-se que esta é SÓ o conteúdo

// Imports para Logout
import 'login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0; // Índice do item selecionado no Rail

  // Lista das telas (Widgets de CONTEÚDO)
  static const List<Widget> _widgetOptions = <Widget>[
    ListaChamadosScreen(), // Índice 0
    NovoChamadoScreen(),          // Índice 1
    ProfileScreen(),              // Índice 2
  ];

  // Títulos para a AppBar (opcional)
  static const List<String> _titles = <String>[
    'Chamados', // Título mais curto para AppBar
    'Novo Chamado',
    'Meu Perfil',
  ];

  // Função chamada quando um destino no Rail é selecionado
  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Função de Logout (agora parte desta tela novamente)
  Future<void> _fazerLogout(BuildContext context) async {
     bool confirmar = await showDialog<bool>( context: context, builder: (BuildContext context) { return AlertDialog( title: const Text('Confirmar Logout'), content: const Text('Tem certeza que deseja sair?'), actions: <Widget>[ TextButton( onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar'), ), TextButton( onPressed: () => Navigator.of(context).pop(true), child: const Text('Sair', style: TextStyle(color: Colors.red)), ), ], ); }, ) ?? false;
     if (!confirmar || !mounted) return;
    try {
      await FirebaseAuth.instance.signOut();
      // Navega para Login e remove tudo
      Navigator.of(context).pushAndRemoveUntil( MaterialPageRoute(builder: (context) => const LoginScreen()), (Route<dynamic> route) => false, );
    } catch (e) { print("Erro logout: $e"); if(mounted) ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Erro ao fazer logout: ${e.toString()}')),); }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar opcional (pode remover se não quiser AppBar geral)
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]), // Título muda com a seleção
        automaticallyImplyLeading: false, // Remove botão voltar
      ),
      // Corpo agora é uma Row: NavigationRail | Divisor | Conteúdo
      body: Row(
        children: <Widget>[
          // --- O Menu Lateral Estático ---
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onDestinationSelected, // Atualiza o estado
            labelType: NavigationRailLabelType.selected, // Mostrar label só do selecionado
            // labelType: NavigationRailLabelType.all, // Ou mostrar todos os labels
            backgroundColor: Theme.of(context).colorScheme.surface, // Fundo do Rail
             indicatorColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3), // Cor de fundo do item selecionado

            // --- Itens do Menu ---
            destinations: const <NavigationRailDestination>[
              // Item 0: Chamados
              NavigationRailDestination(
                icon: Icon(Icons.list_alt_outlined),
                selectedIcon: Icon(Icons.list_alt),
                label: Text('Chamados'),
              ),
              // Item 1: Novo
              NavigationRailDestination(
                icon: Icon(Icons.add_circle_outline),
                selectedIcon: Icon(Icons.add_circle),
                label: Text('Novo'),
              ),
              // Item 2: Perfil
              NavigationRailDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: Text('Perfil'),
              ),
            ],

            // --- Item de Logout no final do Rail ---
            trailing: Expanded( // Empurra para baixo
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: IconButton(
                    icon: const Icon(Icons.logout),
                    color: Colors.red[400], // Cor do ícone logout
                    tooltip: 'Logout',
                    onPressed: () => _fazerLogout(context), // Chama logout
                  ),
                ),
              ),
            ),
            // ---------------------------------------
          ),
          // --- Divisor Vertical ---
          const VerticalDivider(thickness: 1, width: 1),
          // ----------------------

          // --- Conteúdo Principal (Tela Selecionada) ---
          Expanded( // Ocupa o resto do espaço horizontal
            child: IndexedStack( // Mantém o estado das telas
               index: _selectedIndex,
               children: _widgetOptions,
            ),
          ),
          // -----------------------------------------
        ],
      ),
      // REMOVIDO: bottomNavigationBar: BottomNavigationBar(...),
    );
  }
}
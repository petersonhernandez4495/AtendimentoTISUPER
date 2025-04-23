// lib/main_navigation_screen.dart

import 'package:flutter/material.dart';

// Importe as telas que serão exibidas pela BottomNavBar
import 'lista_chamados_screen.dart';
import 'novo_chamado_screen.dart';

// Importe a tela de login para a função de logout no perfil
import 'login_screen.dart';

// Importe o Firebase Auth se estiver usando para logout (exemplo)
// import 'package:firebase_auth/firebase_auth.dart';

// --- Tela Placeholder para o Perfil ---
// (Você pode mover isso para um arquivo separado 'profile_screen.dart' depois)
class ProfileScreenPlaceholder extends StatelessWidget {
  const ProfileScreenPlaceholder({super.key});

  // Função de Logout (movida para cá)
  Future<void> _fazerLogout(BuildContext context) async {
    try {
      // Exemplo: Descomente e use se estiver usando Firebase Auth
      // await FirebaseAuth.instance.signOut();

      // Navega para a tela de login e remove todas as telas anteriores
      // Garante que o context está válido antes de usar
      if (Navigator.of(context).mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      print("Erro ao fazer logout: $e");
      // Garante que o context está válido antes de usar
      if (Navigator.of(context).mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao fazer logout: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Exemplo de dados do usuário (substitua pela lógica real de auth)
    const userName = "Nome do Usuário";
    const userEmail = "usuario@email.com";

    return Scaffold(
      // Cada tela dentro da BottomNav pode ter seu próprio AppBar se necessário
      // Ou pode haver um AppBar genérico na MainNavigationScreen
      appBar: AppBar(
         // O Título pode mudar baseado na aba selecionada, ou ser fixo.
         // Exemplo: Define o título baseado na aba atual se o AppBar estiver aqui.
        title: const Text('Perfil'),
         // Removendo o botão de voltar automático se esta tela não deve ter um
         automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Exibir informações do usuário (exemplo)
              CircleAvatar(
                radius: 50,
                // backgroundImage: NetworkImage(user?.photoURL ?? ''), // Se tiver foto
                child: const Icon(Icons.person, size: 50), // Ícone padrão
              ),
              const SizedBox(height: 16),
              Text(userName, style: Theme.of(context).textTheme.headlineSmall),
              Text(userEmail, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 30),
              const Text('Mais conteúdo do perfil aqui...'),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                onPressed: () => _fazerLogout(context), // Chama a função de logout
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent, // Cor para logout
                  foregroundColor: Colors.white, // Cor do texto/ícone
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
// -----------------------------------------


// --- Widget Principal da Navegação ---
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0; // Índice da tela/aba ativa

  // Lista estática das telas que serão gerenciadas pela BottomNavBar
  // A ordem aqui DEVE corresponder à ordem dos itens na BottomNavigationBar
  static const List<Widget> _widgetOptions = <Widget>[
    ListaChamadosScreen(),        // Índice 0
    NovoChamadoScreen(),          // Índice 1
    ProfileScreenPlaceholder(),   // Índice 2
  ];

  // Função chamada quando um item da barra inferior é tocado
  void _onItemTapped(int index) {
    setState(() { // Atualiza o estado para reconstruir com a nova tela selecionada
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // O body agora exibe o widget da lista '_widgetOptions'
      // que corresponde ao índice selecionado (_selectedIndex)
      body: IndexedStack( // Usar IndexedStack preserva o estado de cada tela/aba
        index: _selectedIndex,
        children: _widgetOptions,
      ),

      // A Barra de Navegação Inferior
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // Garante que todos os itens apareçam
        items: const <BottomNavigationBarItem>[
          // Item 0: Lista de Chamados
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Chamados',
          ),
          // Item 1: Novo Chamado
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'Novo',
          ),
          // Item 2: Perfil
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Perfil',
          ),
        ],
        currentIndex: _selectedIndex, // Define qual item está ativo
        // Cores (opcional, pode usar o tema padrão)
        // selectedItemColor: Theme.of(context).colorScheme.primary,
        // unselectedItemColor: Colors.grey,
        onTap: _onItemTapped, // Função a ser chamada ao tocar
      ),
    );
  }
}
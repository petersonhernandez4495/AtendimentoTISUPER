// lib/main_navigation_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Para autenticação e logout

// Importa classes de configuração e widgets reutilizáveis
import 'config/theme/app_theme.dart'; // Para usar cores do tema (ex: kErrorColor)
import 'widgets/gradient_background_container.dart'; // Widget para o fundo com gradiente
import 'widgets/side_menu.dart'; // Widget para o menu lateral (NavigationRail)

// Importa as telas que serão exibidas como conteúdo principal
import 'lista_chamados_screen.dart';
import 'novo_chamado_screen.dart';
import 'agenda_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart'; // Importa a tela de login para redirecionar após logout

// Widget principal da tela de navegação
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

// Estado do widget MainNavigationScreen
class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0; // Mantém o índice do item selecionado no menu

  // Lista estática dos widgets que representam o conteúdo de cada aba/seção
  // Estes widgets devem ser apenas o CONTEÚDO da tela (sem Scaffold/AppBar próprios)
  static const List<Widget> _widgetOptions = <Widget>[
    ListaChamadosScreen(), // Conteúdo da tela de Chamados (Índice 0)
    NovoChamadoScreen(),   // Conteúdo da tela de Novo Chamado (Índice 1)
    AgendaScreen(),        // Conteúdo da tela de Agenda (Índice 2)
    ProfileScreen(),       // Conteúdo da tela de Perfil (Índice 3)
  ];

  // Lista estática dos títulos correspondentes para a AppBar de cada seção
  static const List<String> _titles = <String>[
    'Chamados',
    'Novo Chamado',
    'Agenda',
    'Meu Perfil',
  ];

  // Callback chamado quando um item no SideMenu (NavigationRail) é selecionado
  // Atualiza o estado para reconstruir a tela com o novo índice selecionado
  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Função assíncrona para realizar o logout do usuário
  Future<void> _fazerLogout(BuildContext context) async {
    // Exibe um diálogo de confirmação antes de prosseguir
    bool confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        // Usa o AlertDialog padrão, que pegará estilos do tema
        return AlertDialog(
          title: const Text('Confirmar Logout'),
          content: const Text('Tem certeza que deseja sair?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), // Fecha o diálogo retornando false
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true), // Fecha o diálogo retornando true
              // Aplica a cor de erro definida no tema ao texto "Sair"
              child: Text('Sair', style: TextStyle(color: AppTheme.kErrorColor)),
            ),
          ],
        );
      },
    ) ?? false; // Garante que, se o diálogo for dispensado, retorne false

    // Interrompe se o usuário não confirmou ou se o widget foi desmontado
    if (!confirmar || !mounted) return;

    // Bloco try-catch para lidar com possíveis erros durante o logout
    try {
      // Efetua o logout no Firebase Authentication
      await FirebaseAuth.instance.signOut();
      // Se o logout for bem-sucedido e o widget ainda estiver montado,
      // navega para a tela de Login e remove todas as telas anteriores da pilha
      if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false, // Remove todas as rotas anteriores
        );
      }
    } catch (e) {
      // Imprime o erro no console (para debug)
      print("Erro ao fazer logout: $e");
      // Se o widget ainda estiver montado, mostra uma SnackBar com o erro
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao fazer logout: ${e.toString()}')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    // O Scaffold é a estrutura base da tela (AppBar, Body)
    return Scaffold(
      // A AppBar é configurada aqui, mas seu estilo visual (cor, elevação, etc.)
      // é definido globalmente no appBarTheme dentro de AppTheme.darkTheme
      appBar: AppBar(
        // O título muda dinamicamente com base no índice selecionado
        title: Text(_titles[_selectedIndex]),
        // Impede que um botão "voltar" seja adicionado automaticamente
        automaticallyImplyLeading: false,
      ),

      // O body do Scaffold usa o widget GradientBackgroundContainer
      // para aplicar o fundo com gradiente definido no tema.
      body: GradientBackgroundContainer(
        // O child do GradientBackgroundContainer é a Row principal do layout
        child: Row(
          children: <Widget>[
            // --- WIDGET DO MENU LATERAL ---
            // Instancia o widget SideMenu que criamos, passando o estado
            // e os callbacks necessários. Toda a lógica de aparência
            // do menu lateral está encapsulada dentro de SideMenu.
            SideMenu(
              selectedIndex: _selectedIndex,        // Informa qual item está ativo
              onDestinationSelected: _onDestinationSelected, // Função a ser chamada ao clicar num item
              onLogout: () => _fazerLogout(context), // Função a ser chamada ao clicar no botão de logout
            ),
            // -----------------------------

            // Linha vertical fina para separar o menu do conteúdo
            const VerticalDivider(thickness: 1, width: 1),

            // --- ÁREA DE CONTEÚDO PRINCIPAL ---
            // Expanded faz com que esta parte ocupe todo o espaço restante na Row
            Expanded(
              // IndexedStack é usado para manter o estado das diferentes telas
              // de conteúdo (_widgetOptions) mesmo quando não estão visíveis.
              // Ele só exibe o widget no índice correspondente a _selectedIndex.
              child: IndexedStack(
                index: _selectedIndex, // Mostra o widget da lista correspondente ao índice
                children: _widgetOptions, // A lista de widgets das telas de conteúdo
              ),
            ),
          ],
        ),
      ), // Fim do GradientBackgroundContainer
    ); // Fim do Scaffold
  } // Fim do método build
} // Fim da classe _MainNavigationScreenState
// lib/main_navigation_screen.dart

import 'package:flutter/material.dart';

// Importe as telas que serão exibidas pela BottomNavBar
// !!! GARANTA QUE OS NOMES E CAMINHOS DOS ARQUIVOS ESTÃO CORRETOS !!!
import 'lista_chamados_screen.dart'; 
import 'novo_chamado_screen.dart';           
import 'profile_screen.dart';            

// O import do login_screen não é mais necessário aqui, pois a lógica de logout
// foi movida para dentro da ProfileScreen.
// O import do firebase_auth não é necessário aqui diretamente.

// --- Widget Principal da Navegação ---
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0; // Índice da tela/aba ativa que começa em 'Chamados'

  // Lista estática das telas (widgets) que serão exibidas no corpo (body)
  // A ordem aqui DEVE corresponder à ordem dos itens na BottomNavigationBar abaixo.
  // Estes widgets NÃO devem ter Scaffold/AppBar próprios se você quiser um AppBar único aqui.
  static const List<Widget> _widgetOptions = <Widget>[
    // Use o nome correto do widget que contém o StreamBuilder/GridView da lista
    ListaChamadosScreen(),   // Índice 0
    NovoChamadoScreen(),            // Índice 1 (Verificar se precisa de Scaffold próprio)
    ProfileScreen(),                // Índice 2 (Tela de Perfil REAL)
  ];

  // Títulos correspondentes para um AppBar dinâmico (opcional)
  // static const List<String> _titles = <String>['Chamados', 'Novo Chamado', 'Meu Perfil'];

  // Função chamada quando um item da barra inferior é tocado
  void _onItemTapped(int index) {
    setState(() { // Atualiza o estado para reconstruir com a nova tela selecionada
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // --- AppBar (Opcional) ---
      // Se você descomentar este AppBar, as telas em _widgetOptions NÃO devem ter AppBar.
      // Se preferir que cada tela tenha seu AppBar, comente/remova este.
      // appBar: AppBar(
      //   title: Text(_titles[_selectedIndex]), // Título muda conforme a aba
      //   automaticallyImplyLeading: false, // Remove botão 'voltar' automático
      // ),
      // ------------------------

      // O body exibe o widget da lista '_widgetOptions'
      // que corresponde ao índice selecionado (_selectedIndex).
      // IndexedStack preserva o estado de cada tela ao trocar de aba.
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),

      // --- Barra de Navegação Inferior ---
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // Para que todos os itens apareçam sempre
        backgroundColor: Theme.of(context).colorScheme.surface, // Cor de fundo da barra
        items: const <BottomNavigationBarItem>[
          // Item 0: Lista de Chamados
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_outlined),      // Ícone padrão
            activeIcon: Icon(Icons.list_alt),        // Ícone quando selecionado
            label: 'Chamados',
          ),
          // Item 1: Novo Chamado
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),    // Ícone padrão
            activeIcon: Icon(Icons.add_circle),      // Ícone quando selecionado
            label: 'Novo',
          ),
          // Item 2: Perfil
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),       // Ícone padrão
            activeIcon: Icon(Icons.person),         // Ícone quando selecionado
            label: 'Perfil',
          ),
        ],
        currentIndex: _selectedIndex, // Índice do item ativo
        selectedItemColor: Theme.of(context).colorScheme.primary, // Cor do ícone/label ativo
        unselectedItemColor: Colors.grey[600], // Cor do ícone/label inativo
        showUnselectedLabels: true, // Mostrar labels mesmo quando inativos
        onTap: _onItemTapped, // Função chamada ao tocar em um item
      ),
      // ---------------------------------
    );
  }
}
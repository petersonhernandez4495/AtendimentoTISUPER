// lib/widgets/side_menu.dart

import 'package:flutter/material.dart';
import '../config/theme/app_theme.dart'; // Importa para usar cores do tema

class SideMenu extends StatelessWidget {
  final int selectedIndex; // Qual item está selecionado
  final ValueChanged<int> onDestinationSelected; // Função chamada ao selecionar
  final VoidCallback onLogout; // Função chamada ao clicar em Logout

  const SideMenu({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    // Obtém dados do tema
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color? unselectedItemColor = theme.iconTheme.color?.withOpacity(0.8);
    final TextStyle? unselectedLabelStyle = theme.textTheme.bodyMedium?.copyWith(color: unselectedItemColor);
    final Color surfaceColorBase = colorScheme.surface;

    // --- WIDGET DO MENU LATERAL (NavigationRail encapsulado) ---
    return ClipRRect( // Mantém o arredondamento da borda direita
      borderRadius: const BorderRadius.horizontal(right: Radius.circular(20.0)),
      child: NavigationRail(
        selectedIndex: selectedIndex, // Usa o índice passado
        onDestinationSelected: onDestinationSelected, // Usa o callback passado

        // --- Configurações de Aparência (Refinadas) ---
        labelType: NavigationRailLabelType.none, // Apenas ícones
        useIndicator: false, // Sem fundo no item selecionado
        minWidth: 64, // Largura mínima
        backgroundColor: surfaceColorBase.withOpacity(0.9), // Fundo semi-transparente

        // --- Estilos dos Ícones/Labels (baseados no tema) ---
        selectedIconTheme: IconThemeData(color: colorScheme.primary, size: 26),
        unselectedIconTheme: IconThemeData(color: unselectedItemColor, size: 24),
        selectedLabelTextStyle: theme.textTheme.bodyMedium?.copyWith( fontWeight: FontWeight.bold, color: colorScheme.primary,),
        unselectedLabelTextStyle: unselectedLabelStyle,

        // --- Destinos da Navegação (Definidos aqui) ---
        // Adicionamos Tooltips para acessibilidade, já que os labels estão ocultos
        destinations: const <NavigationRailDestination>[
          NavigationRailDestination(
            icon: Tooltip(message: 'Chamados', child: Icon(Icons.list_alt_outlined)),
            selectedIcon: Tooltip(message: 'Chamados', child: Icon(Icons.list_alt)),
            label: Text('Chamados'), // Label ainda necessário internamente
          ),
          NavigationRailDestination(
            icon: Tooltip(message: 'Novo Chamado', child: Icon(Icons.add_circle_outline)),
            selectedIcon: Tooltip(message: 'Novo Chamado', child: Icon(Icons.add_circle)),
            label: Text('Novo'),
          ),
          NavigationRailDestination(
            icon: Tooltip(message: 'Agenda', child: Icon(Icons.calendar_month_outlined)),
            selectedIcon: Tooltip(message: 'Agenda', child: Icon(Icons.calendar_month)),
            label: Text('Agenda'),
          ),
          NavigationRailDestination(
            icon: Tooltip(message: 'Meu Perfil', child: Icon(Icons.person_outline)),
            selectedIcon: Tooltip(message: 'Meu Perfil', child: Icon(Icons.person)),
            label: Text('Perfil'),
          ),
        ],

        // --- Botão de Logout ---
        trailing: Expanded( // Garante que o botão fique na parte inferior
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Tooltip(
                message: 'Logout',
                child: IconButton(
                  icon: Icon(Icons.logout, color: AppTheme.kErrorColor), // Usa cor de erro do tema
                  onPressed: onLogout, // Chama o callback passado
                ),
              ),
            ),
          ),
        ), // Fim do Trailing (Logout)
      ), // Fim do NavigationRail
    ); // Fim do ClipRRect
  }
}
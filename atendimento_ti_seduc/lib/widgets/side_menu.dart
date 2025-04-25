// lib/widgets/side_menu.dart

import 'package:flutter/material.dart';
import '../config/theme/app_theme.dart'; // Importa para usar cores e constantes do tema

class SideMenu extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onLogout;

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
    // final Color surfaceColorBase = colorScheme.surface; // Não usamos mais a cor de superfície base aqui

    // Padding externo para efeito flutuante (mantido)
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 20.0, 0.0, 20.0), // Ajuste se necessário
      child: ClipRRect( // ClipRRect para aplicar o arredondamento
        // --- ARREDONDAMENTO TOTAL ---
        borderRadius: BorderRadius.circular(24.0), // <<< Aplicado a todos os cantos (ajuste o raio)
        // ---------------------------
        child: Container( // <<< CONTAINER PARA O FUNDO COM GRADIENTE
          decoration: BoxDecoration(
            gradient: LinearGradient(
              // --- GRADIENTE E TRANSPARÊNCIA ---
              colors: [
                // Use cores do tema com a opacidade desejada (ex: 50% e 30%)
                AppTheme.kPrimaryColor.withOpacity(0.5),   // <<< Ajuste a opacidade (ex: 0.5, 0.4)
                AppTheme.kSecondaryColor.withOpacity(0.3), // <<< Ajuste a opacidade (ex: 0.3, 0.2)
              ],
              // Direção do gradiente (pode mudar para Alignment.topLeft, etc.)
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              // ---------------------------------
            ),
          ),
          child: NavigationRail( // NavigationRail agora é filho do Container
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,

            // --- FUNDO DO NAVIGATION RAIL TRANSPARENTE ---
            // Para que o gradiente do Container pai seja visível
            backgroundColor: Colors.transparent, // <<< IMPORTANTE
            // ------------------------------------------

            // Configurações de aparência (mantidas)
            labelType: NavigationRailLabelType.none,
            useIndicator: false, // Sem indicador de fundo na seleção
            minWidth: 64, // Largura mínima

            // Estilos dos Ícones/Labels (mantidos - verifique contraste com novo fundo)
            selectedIconTheme: IconThemeData(color: AppTheme.kTextColor, size: 26), // Selecionado usa cor de texto principal
            unselectedIconTheme: IconThemeData(color: AppTheme.kSecondaryTextColor, size: 24), // Não selecionado usa cor secundária
            // Ajuste as cores acima se necessário para melhor contraste com o gradiente

            // Estilos de Label (não visíveis, mas definidos)
            selectedLabelTextStyle: theme.textTheme.bodyMedium?.copyWith( fontWeight: FontWeight.bold, color: AppTheme.kTextColor,), // Usa cor de texto principal
            unselectedLabelTextStyle: unselectedLabelStyle?.copyWith(color: AppTheme.kSecondaryTextColor), // Usa cor secundária

            // Destinos (mantidos com Tooltips)
            destinations: const <NavigationRailDestination>[
               NavigationRailDestination( icon: Tooltip(message: 'Chamados', child: Icon(Icons.list_alt_outlined)), selectedIcon: Tooltip(message: 'Chamados', child: Icon(Icons.list_alt)), label: Text('Chamados'), ),
               NavigationRailDestination( icon: Tooltip(message: 'Novo Chamado', child: Icon(Icons.add_circle_outline)), selectedIcon: Tooltip(message: 'Novo Chamado', child: Icon(Icons.add_circle)), label: Text('Novo'), ),
               NavigationRailDestination( icon: Tooltip(message: 'Agenda', child: Icon(Icons.calendar_month_outlined)), selectedIcon: Tooltip(message: 'Agenda', child: Icon(Icons.calendar_month)), label: Text('Agenda'), ),
               NavigationRailDestination( icon: Tooltip(message: 'Meu Perfil', child: Icon(Icons.person_outline)), selectedIcon: Tooltip(message: 'Meu Perfil', child: Icon(Icons.person)), label: Text('Perfil'), ),
            ],

            // Botão de Logout (mantido)
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: Tooltip(
                    message: 'Logout',
                    child: IconButton(
                      // Ajuste a cor se necessário para contraste com o gradiente
                      icon: Icon(Icons.logout, color: AppTheme.kErrorColor.withOpacity(0.8)),
                      onPressed: onLogout,
                    ),
                  ),
                ),
              ),
            ), // Fim do Trailing (Logout)
          ), // Fim do NavigationRail
        ), // Fim do Container do Gradiente
      ), // Fim do ClipRRect
    ); // Fim do Padding externo
  }
}
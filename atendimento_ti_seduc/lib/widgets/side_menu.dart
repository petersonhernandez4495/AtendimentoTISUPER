// lib/widgets/side_menu.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/theme/app_theme.dart'; // Ajuste o caminho se necessário
import 'package:flutter/foundation.dart'; // Para kReleaseMode
import '../screens/tutorial_screen.dart'; // Importa a tela de tutorial

// Definição do modelo de dados para os itens de menu
class MenuItemData {
  final IconData icon;
  final String title;
  final int index;
  final bool isAdminOnly;
  final VoidCallback? customNavigation; // Para navegação especial (ex: Tutoriais)

  MenuItemData({
    required this.icon,
    required this.title,
    required this.index,
    this.isAdminOnly = false,
    this.customNavigation,
  });
}

// Widget SideMenu principal
class SideMenu extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected; // Callback para seleção de tela principal
  final VoidCallback onLogout; // Callback para logout
  final bool isAdminUser; // Indica se o usuário é administrador
  final User? currentUser; // Objeto do usuário atual do Firebase
  final VoidCallback? onCheckForUpdates; // Callback para verificar atualizações
  final ValueChanged<String>? onSearchQueryChanged; // Callback para mudança na busca
  final String initialSearchQuery; // Query de busca inicial

  const SideMenu({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onLogout,
    required this.isAdminUser,
    this.currentUser,
    this.onCheckForUpdates,
    this.onSearchQueryChanged,
    this.initialSearchQuery = "",
  });

  @override
  State<SideMenu> createState() => _SideMenuState();
}

class _SideMenuState extends State<SideMenu> {
  bool _isExpanded = true; // Controla se o menu está expandido ou recolhido
  final double _collapsedWidth = 70.0; // Largura quando recolhido
  final double _expandedWidth = 256.0; // Largura quando expandido
  late TextEditingController _searchController; // Controller para o campo de busca

  late List<MenuItemData> _navigationRailItems; // Itens principais do NavigationRail
  late List<MenuItemData> _footerItems; // Itens secundários/rodapé (ex: Tutoriais)

  // Índices constantes para telas específicas
  static const int perfilScreenIndex = 3;
  static const int tutorialScreenIndex = 6; // Índice único para tutoriais

  // Constantes de layout
  static const double _maxLogoContainerHeight = 120.0;
  static const double _logoVerticalPadding = 8.0;

  @override
  void initState() {
    super.initState();
    _updateMenuItems(); // Atualiza as listas de itens de menu
    _searchController = TextEditingController(text: widget.initialSearchQuery);
    // Adiciona listener para notificar sobre mudanças na busca
    _searchController.addListener(() {
      widget.onSearchQueryChanged?.call(_searchController.text);
    });
  }

  @override
  void didUpdateWidget(covariant SideMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Atualiza itens se o status de admin mudar
    if (oldWidget.isAdminUser != widget.isAdminUser) {
      _updateMenuItems();
    }
    // Atualiza o texto do campo de busca se a query inicial mudar externamente
    if (widget.initialSearchQuery != oldWidget.initialSearchQuery &&
        widget.initialSearchQuery != _searchController.text) {
      // Usa addPostFrameCallback para garantir que o build não esteja em andamento
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _searchController.text = widget.initialSearchQuery;
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose(); // Libera o controller
    super.dispose();
  }

  // Método para definir os itens de menu com base no status de admin
  void _updateMenuItems() {
    // Itens principais que mudam a tela via onDestinationSelected
    _navigationRailItems = [
      MenuItemData(icon: Icons.list_alt_rounded, title: 'Chamados', index: 0),
      MenuItemData(icon: Icons.add_comment_outlined, title: 'Novo Chamado', index: 1),
      MenuItemData(icon: Icons.calendar_month_outlined, title: 'Agenda', index: 2),
      MenuItemData(icon: Icons.archive_outlined, title: 'Chamados Arquivados', index: 5),
    ];
    // Adiciona item de Gerenciar Usuários apenas para admins
    if (widget.isAdminUser) {
      _navigationRailItems.add(MenuItemData(icon: Icons.manage_accounts_outlined, title: 'Gerenciar Usuários', index: 4, isAdminOnly: true));
    }

    // Itens que ficam no rodapé ou têm navegação customizada
    _footerItems = [
      MenuItemData(
        icon: Icons.video_library_rounded, // Ícone para tutoriais
        title: 'Tutoriais',
        index: tutorialScreenIndex, // Índice definido
        customNavigation: () { // Lógica de navegação própria
           // Fecha o menu se for um Drawer antes de navegar
           // (Pode ser necessário ajustar se não for um Drawer)
           // if (Navigator.of(context).canPop()) {
           //   Navigator.of(context).pop();
           // }
           // Empurra a tela de Tutorial
           Navigator.of(context).push(
             MaterialPageRoute(builder: (context) => const TutorialScreen()),
           );
        }
      ),
      // Poderia adicionar 'Verificar Atualizações' e 'Sair' aqui também
      // se quisesse separá-los visualmente ou funcionalmente.
    ];
  }

  // Constrói o campo de busca (ou botão de busca se recolhido)
  Widget _buildSearchField(BuildContext context) {
    if (!_isExpanded) {
      return IconButton(
        icon: const Icon(Icons.search_outlined),
        tooltip: 'Pesquisar Chamados',
        color: AppTheme.kWinSecondaryText,
        iconSize: 26,
        onPressed: () {
          setState(() {
            _isExpanded = true; // Expande ao clicar no ícone
          });
        },
      );
    }

    // Campo de texto quando expandido
    return Padding(
      padding: const EdgeInsets.fromLTRB(12.0, 8.0, 12.0, 12.0),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: AppTheme.kWinPrimaryText, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Pesquisar chamado...',
          hintStyle: TextStyle(color: AppTheme.kWinSecondaryText.withOpacity(0.7), fontSize: 13),
          prefixIcon: Icon(Icons.search_outlined, color: AppTheme.kWinSecondaryText.withOpacity(0.8), size: 20),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 10.0),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20.0),
            borderSide: BorderSide(color: AppTheme.kWinDivider.withOpacity(0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20.0),
            borderSide: BorderSide(color: AppTheme.kWinDivider.withOpacity(0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20.0),
            borderSide: BorderSide(color: AppTheme.kWinAccent, width: 1.5),
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded, color: AppTheme.kWinSecondaryText, size: 18),
                  onPressed: () {
                    _searchController.clear(); // O listener notificará a mudança
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              : null,
        ),
      ),
    );
  }

  // Constrói a seção do logo (visível apenas quando expandido)
  Widget _buildLogoSection(BuildContext context) {
    if (!_isExpanded) return const SizedBox.shrink(); // Não mostra se recolhido
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: _logoVerticalPadding, horizontal: 60.0),
      child: SizedBox(
        height: _maxLogoContainerHeight,
        width: double.infinity,
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
          child: Image.asset(
            'assets/images/seu_logo.png', // SUBSTITUA PELO CAMINHO CORRETO DO SEU LOGO
            errorBuilder: (c, e, s) => Container( // Fallback se o logo não carregar
              height: _maxLogoContainerHeight,
              alignment: Alignment.center,
              child: Text(
                "LOGO",
                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppTheme.kWinPrimaryText),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Constrói a seção do perfil do usuário
  Widget _buildUserProfileSection(BuildContext context) {
    final User? user = widget.currentUser;
    final ThemeData theme = Theme.of(context);
    if (user == null) return const SizedBox.shrink(); // Não mostra se não houver usuário

    // Verifica se a URL da foto é válida
    final bool hasValidPhotoUrl = user.photoURL != null &&
        user.photoURL!.isNotEmpty &&
        (user.photoURL!.startsWith('http') || user.photoURL!.startsWith('https'));

    return InkWell(
      onTap: () {
        // Navega para a tela de perfil usando o callback principal
        widget.onDestinationSelected(perfilScreenIndex);
      },
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: _isExpanded ? 16.0 : (_collapsedWidth - 40) / 2, // Ajusta padding horizontal
          vertical: 10.0,
        ),
        child: _isExpanded
            ? Row( // Layout expandido
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.kWinAccent.withOpacity(0.2),
                    backgroundImage: hasValidPhotoUrl ? NetworkImage(user.photoURL!) : null,
                    child: !hasValidPhotoUrl ? Icon(Icons.person_rounded, size: 22, color: AppTheme.kWinAccent) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (user.displayName != null && user.displayName!.isNotEmpty)
                          Text(
                            user.displayName!,
                            style: theme.textTheme.titleSmall?.copyWith(
                                color: AppTheme.kWinPrimaryText, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        if (user.email != null && user.email!.isNotEmpty)
                          Text(
                            user.email!,
                            style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.kWinSecondaryText),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                      ],
                    ),
                  ),
                ],
              )
            : Tooltip( // Layout recolhido (mostra apenas avatar com tooltip)
                message: user.displayName ?? user.email ?? 'Perfil',
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.kWinAccent.withOpacity(0.2),
                  backgroundImage: hasValidPhotoUrl ? NetworkImage(user.photoURL!) : null,
                  child: !hasValidPhotoUrl ? Icon(Icons.person_rounded, size: 22, color: AppTheme.kWinAccent) : null,
                ),
              ),
      ),
    );
  }

  // Constrói a seção de ações (ex: Verificar Atualizações)
  Widget _buildMenuActions(BuildContext context) {
    List<Widget> actions = [];
    // Adiciona botão de verificar atualizações apenas em modo Release
    if (widget.onCheckForUpdates != null && kReleaseMode) {
      actions.add(_buildActionItem(context, icon: Icons.update_outlined, label: 'Verificar Atualizações', onPressed: widget.onCheckForUpdates));
    }
    if (actions.isEmpty) return const SizedBox.shrink();
    return Column(mainAxisSize: MainAxisSize.min, children: actions);
  }

  // Helper para construir um item de ação genérico (botão de texto ou ícone)
  Widget _buildActionItem(BuildContext context, {required IconData icon, required String label, VoidCallback? onPressed}) {
    if (_isExpanded) {
      return TextButton.icon(
        icon: Icon(icon, color: AppTheme.kWinSecondaryText, size: 20),
        label: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.kWinPrimaryText),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          alignment: Alignment.centerLeft,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))
        ),
      );
    } else {
      return IconButton(
        icon: Icon(icon, color: AppTheme.kWinSecondaryText, size: 24),
        tooltip: label,
        onPressed: onPressed,
        padding: const EdgeInsets.all(12),
      );
    }
  }

  // Helper para construir itens customizáveis do menu (usado para _footerItems)
  Widget _buildCustomMenuItem(BuildContext context, MenuItemData item) {
    // Verifica se este item está selecionado (geralmente não aplicável para itens com customNavigation)
    final bool isSelected = widget.selectedIndex == item.index && item.customNavigation == null;
    final Color iconColor = isSelected ? AppTheme.kWinAccent : AppTheme.kWinSecondaryText;
    final Color textColor = isSelected ? AppTheme.kWinAccent : AppTheme.kWinPrimaryText;
    final FontWeight fontWeight = isSelected ? FontWeight.bold : FontWeight.normal;

    if (_isExpanded) {
      return TextButton.icon(
        icon: Icon(item.icon, color: iconColor, size: 22),
        label: Text(
          item.title,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textColor, fontWeight: fontWeight),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        onPressed: () {
          // Chama a navegação customizada se existir, senão usa o callback principal
          if (item.customNavigation != null) {
            item.customNavigation!();
          } else {
            widget.onDestinationSelected(item.index);
          }
        },
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          alignment: Alignment.centerLeft,
          backgroundColor: isSelected ? AppTheme.kWinAccent.withOpacity(0.12) : Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))
        ),
      );
    } else {
      // Layout recolhido para itens customizados
      return Tooltip(
        message: item.title,
        preferBelow: false,
        child: IconButton(
          icon: Icon(item.icon, color: iconColor),
          iconSize: 24,
          isSelected: isSelected,
          selectedIcon: Icon(item.icon, color: AppTheme.kWinAccent), // Ícone quando selecionado
          onPressed: () {
            if (item.customNavigation != null) {
              item.customNavigation!();
            } else {
              widget.onDestinationSelected(item.index);
            }
          },
          padding: const EdgeInsets.all(12),
          style: IconButton.styleFrom(
             backgroundColor: isSelected ? AppTheme.kWinAccent.withOpacity(0.12) : Colors.transparent,
             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
          ),
        ),
      );
    }
  }

  // Constrói o botão de Logout
  Widget _buildLogoutButton(BuildContext context) {
    final Color logoutIconColor = AppTheme.kErrorColor.withOpacity(0.9);
    final Color logoutTextColor = AppTheme.kErrorColor;

    if (_isExpanded) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        child: TextButton.icon(
          icon: Icon(Icons.logout_rounded, color: logoutIconColor, size: 22),
          label: Text(
            'Sair',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: logoutTextColor, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          onPressed: widget.onLogout, // Chama o callback de logout
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            alignment: Alignment.centerLeft,
          ),
        ),
      );
    } else {
      return Tooltip(
        message: 'Sair',
        preferBelow: true,
        child: IconButton(
          icon: Icon(Icons.logout_rounded, color: logoutIconColor),
          iconSize: 24,
          onPressed: widget.onLogout,
          padding: const EdgeInsets.all(12),
        ),
      );
    }
  }

  // ------------ MÉTODO build() CORRIGIDO ------------
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    int railSelectedIndex = -1; // Índice para o NavigationRail principal

    // Determina qual item do NavigationRail principal está selecionado
    // Ignora o perfil e o tutorial, pois eles não estão no NavigationRail principal
    if (widget.selectedIndex != perfilScreenIndex && widget.selectedIndex != tutorialScreenIndex) {
        railSelectedIndex = _navigationRailItems.indexWhere((item) => item.index == widget.selectedIndex);
    }

    return Container(
      width: _isExpanded ? _expandedWidth : _collapsedWidth,
      decoration: BoxDecoration(
        color: AppTheme.kWinSurface, // Cor de fundo do menu
        border: Border(
          right: BorderSide(color: AppTheme.kWinDivider, width: 1.0), // Borda direita
        ),
      ),
      child: Column( // Coluna Principal organiza todo o conteúdo do menu
        children: [
          // ---- Parte Superior (Fixa) ----
          Container( // Botão de expandir/recolher
            height: 56,
            alignment: _isExpanded ? Alignment.centerRight : Alignment.center,
            padding: _isExpanded ? const EdgeInsets.only(right: 8) : EdgeInsets.zero,
            child: IconButton(
              icon: Icon(_isExpanded ? Icons.menu_open_rounded : Icons.menu_rounded),
              tooltip: _isExpanded ? 'Recolher Menu' : 'Expandir Menu',
              color: AppTheme.kWinSecondaryText,
              iconSize: 26,
              onPressed: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
            ),
          ),
          _buildLogoSection(context), // Seção do Logo
          _buildSearchField(context), // Campo ou botão de busca
          _buildUserProfileSection(context), // Seção do perfil
          const Divider(height: 1, thickness: 1, color: AppTheme.kWinDivider),

          // ---- Parte Central Expansível (NavigationRail) ----
          Expanded( // Garante que o NavigationRail receba altura FINITA
            child: NavigationRail(
              selectedIndex: railSelectedIndex >= 0 ? railSelectedIndex : null, // Marca o item selecionado
              onDestinationSelected: (selectedIndexInRail) {
                // Callback para os itens do NavigationRail principal
                if (selectedIndexInRail >= 0 && selectedIndexInRail < _navigationRailItems.length) {
                  final selectedItem = _navigationRailItems[selectedIndexInRail];
                  widget.onDestinationSelected(selectedItem.index);
                }
              },
              extended: _isExpanded, // Controla se mostra labels ou não
              backgroundColor: Colors.transparent, // Fundo transparente
              minWidth: _collapsedWidth,
              minExtendedWidth: _expandedWidth,
              labelType: NavigationRailLabelType.none, // Não mostrar labels textuais (usamos Tooltips)
              selectedIconTheme: const IconThemeData(color: AppTheme.kWinAccent, size: 24), // Estilo do ícone selecionado
              unselectedIconTheme: const IconThemeData(color: AppTheme.kWinSecondaryText, size: 22), // Estilo do ícone não selecionado
              useIndicator: true, // Mostra um indicador visual para o item selecionado
              indicatorColor: AppTheme.kWinAccent.withOpacity(0.12),
              indicatorShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6.0)
              ),
              // Mapeia os dados dos itens principais para os destinos do NavigationRail
              destinations: _navigationRailItems.map((item) {
                return NavigationRailDestination(
                  icon: Tooltip(message: item.title, child: Icon(item.icon)), // Ícone com tooltip
                  selectedIcon: Tooltip(message: item.title, child: Icon(item.icon)), // Ícone selecionado com tooltip
                  label: Text(item.title, overflow: TextOverflow.ellipsis, maxLines: 1), // Label (não visível com labelType: none)
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                );
              }).toList(),
            ),
          ), // Fim do Expanded que contém NavigationRail

          // ---- Parte Inferior (Fixa) ----
          // Renderiza os itens do rodapé (ex: Tutoriais)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: _isExpanded ? 8.0 : 0, vertical: 8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min, // Importante
              children: _footerItems.map((item) => _buildCustomMenuItem(context, item)).toList(),
            ),
          ),

          // Renderiza as ações do menu (ex: Verificar Atualizações)
          if (widget.onCheckForUpdates != null && kReleaseMode)
             Padding(
                padding: EdgeInsets.symmetric(horizontal: _isExpanded ? 8.0 : 0, vertical: 0),
                child: _buildMenuActions(context)
              )
          else if (!_isExpanded && (widget.onCheckForUpdates != null && kReleaseMode))
             _buildMenuActions(context),

          // Linha divisória e botão de Logout
          const Divider(height: 0, thickness: 1, color: AppTheme.kWinDivider),
          _buildLogoutButton(context),
          const SizedBox(height: 4), // Pequeno espaço no final
        ],
      ),
    );
  }
  // ------------ FIM DO MÉTODO build() CORRIGIDO ------------
}
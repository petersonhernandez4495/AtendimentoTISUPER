// lib/widgets/side_menu.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart'; // Não é mais necessário aqui se isAdminUser é passado
import '../config/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
class MenuItemData {
  final IconData icon;
  final String title;
  final int index;
  final bool isAdminOnly;

  MenuItemData({
    required this.icon,
    required this.title,
    required this.index,
    this.isAdminOnly = false,
  });
}

class SideMenu extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onLogout;
  final bool isAdminUser;
  final User? currentUser; // Para exibir informações do usuário
  final VoidCallback? onCheckForUpdates; // Callback para verificar atualizações
  final VoidCallback? onSearchPressed; // Callback para ação de busca

  const SideMenu({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onLogout,
    required this.isAdminUser,
    this.currentUser,
    this.onCheckForUpdates,
    this.onSearchPressed,
  });

  @override
  State<SideMenu> createState() => _SideMenuState();
}

class _SideMenuState extends State<SideMenu> {
  bool _isExpanded = false;
  final double _collapsedWidth = 70.0;
  final double _expandedWidth = 240.0; // Um pouco mais largo para acomodar mais informações

  late List<MenuItemData> _displayedMenuItems;

  @override
  void initState() {
    super.initState();
    _updateMenuItems();
  }

  @override
  void didUpdateWidget(covariant SideMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isAdminUser != widget.isAdminUser) {
      _updateMenuItems();
    }
  }

  void _updateMenuItems() {
    final allPossibleItems = [
      MenuItemData(icon: Icons.list_alt_rounded, title: 'Chamados', index: 0),
      MenuItemData(icon: Icons.add_comment_outlined, title: 'Novo Chamado', index: 1),
      MenuItemData(icon: Icons.calendar_month_outlined, title: 'Agenda', index: 2),
      // O item de Perfil agora pode ser acessado clicando no avatar/nome do usuário
      // MenuItemData(icon: Icons.person_outline_rounded, title: 'Meu Perfil', index: 3), 
      MenuItemData(icon: Icons.manage_accounts_outlined, title: 'Gerenciar Usuários', index: 4, isAdminOnly: true),
    ];

    // Ajuste: O item de perfil é geralmente o penúltimo item visível antes do admin
    // Se o item de perfil for removido daqui, o índice 3 pode ficar vago ou ser reatribuído.
    // Vamos manter o perfil como um item de navegação por enquanto para consistência de índices.
    // Se for removido, a lógica de `onDestinationSelected` e `selectedIndex` precisa ser ajustada.
    _displayedMenuItems = [
       MenuItemData(icon: Icons.list_alt_rounded, title: 'Chamados', index: 0),
       MenuItemData(icon: Icons.add_comment_outlined, title: 'Novo Chamado', index: 1),
       MenuItemData(icon: Icons.calendar_month_outlined, title: 'Agenda', index: 2),
       MenuItemData(icon: Icons.person_outline_rounded, title: 'Meu Perfil', index: 3),
    ];
    if (widget.isAdminUser) {
      _displayedMenuItems.add(MenuItemData(icon: Icons.manage_accounts_outlined, title: 'Gerenciar Usuários', index: 4, isAdminOnly: true));
    }
  }

  Widget _buildMenuHeader(BuildContext context) {
    final User? user = widget.currentUser;
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: _isExpanded ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        if (_isExpanded) // Logo visível apenas quando expandido
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
            child: Image.asset(
              'assets/images/seu_logo.png', // Certifique-se que o caminho está correto
              height: 28,
              errorBuilder: (c, e, s) => Text(
                "APP LOGO",
                style: theme.textTheme.titleMedium?.copyWith(color: AppTheme.kWinPrimaryText),
              ),
            ),
          ),
        if (user != null)
          InkWell(
            onTap: () {
              // Navegar para a tela de perfil (índice 3, conforme _displayedMenuItems)
              // Encontrar o índice correto do perfil na lista atual
              final profileItem = _displayedMenuItems.firstWhere((item) => item.title == 'Meu Perfil', orElse: () => _displayedMenuItems[3]);
              widget.onDestinationSelected(profileItem.index);
            },
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: _isExpanded ? 16.0 : (_collapsedWidth - 40) / 2, // 40 é o tamanho do avatar
                vertical: 12.0,
              ),
              child: _isExpanded
                  ? Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppTheme.kWinAccent.withOpacity(0.2),
                          backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                          child: user.photoURL == null
                              ? Icon(Icons.person_rounded, size: 22, color: AppTheme.kWinAccent)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if(user.displayName != null && user.displayName!.isNotEmpty)
                                Text(
                                  user.displayName!,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                      color: AppTheme.kWinPrimaryText, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (user.email != null && user.email!.isNotEmpty)
                                Text(
                                  user.email!,
                                  style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.kWinSecondaryText),
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : CircleAvatar( // Apenas Avatar quando colapsado
                      radius: 20,
                      backgroundColor: AppTheme.kWinAccent.withOpacity(0.2),
                      backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                      child: user.photoURL == null
                          ? Icon(Icons.person_rounded, size: 22, color: AppTheme.kWinAccent)
                          : null,
                    ),
            ),
          ),
        const Divider(height: 1, thickness: 1, color: AppTheme.kWinDivider),
      ],
    );
  }
  
  Widget _buildMenuActions(BuildContext context) {
    Widget buildActionItem({required IconData icon, required String label, VoidCallback? onPressed}) {
      if (_isExpanded) {
        return TextButton.icon(
          icon: Icon(icon, color: AppTheme.kWinSecondaryText, size: 20),
          label: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.kWinPrimaryText)),
          onPressed: onPressed,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            alignment: Alignment.centerLeft,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))
          ),
        );
      } else {
        return IconButton(
          icon: Icon(icon, color: AppTheme.kWinSecondaryText, size: 24),
          tooltip: label,
          onPressed: onPressed,
        );
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
         if (widget.onSearchPressed != null) buildActionItem(icon: Icons.search_outlined, label: 'Buscar', onPressed: widget.onSearchPressed),
         if (widget.onCheckForUpdates != null && kReleaseMode) // Mostrar apenas em Release Mode
            buildActionItem(icon: Icons.update_outlined, label: 'Verificar Atualizações', onPressed: widget.onCheckForUpdates),
      ],
    );
  }


  Widget _buildLogoutButton(BuildContext context) {
    final Color logoutIconColor = AppTheme.kErrorColor.withOpacity(0.9);
    final Color logoutTextColor = AppTheme.kErrorColor;

    if (_isExpanded) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: TextButton.icon(
          icon: Icon(Icons.logout_rounded, color: logoutIconColor, size: 22),
          label: Text(
            'Sair',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: logoutTextColor, fontWeight: FontWeight.w600)
          ),
          onPressed: widget.onLogout,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: _isExpanded ? _expandedWidth : _collapsedWidth,
      decoration: BoxDecoration(
        color: AppTheme.kWinSurface, 
        border: Border(
          right: BorderSide(color: AppTheme.kWinDivider, width: 1.0),
        ),
      ),
      child: Column( // Estrutura principal do SideMenu
        children: [
          // 1. Botão de Expandir/Recolher
          Container(
            height: 56, // Altura para o botão de toggle
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
          // 2. Cabeçalho com Logo e Informações do Usuário
          _buildMenuHeader(context), // Não é mais parte do `leading` do NavigationRail

          // 3. Itens de Navegação Principais
          Expanded(
            child: NavigationRail(
              selectedIndex: widget.selectedIndex < _displayedMenuItems.length ? widget.selectedIndex : 0,
              onDestinationSelected: (index) {
                 if (index < _displayedMenuItems.length) {
                   widget.onDestinationSelected(_displayedMenuItems[index].index);
                 }
              },
              extended: _isExpanded,
              backgroundColor: Colors.transparent,
              minWidth: _collapsedWidth, // Usa a largura colapsada para o rail
              minExtendedWidth: _expandedWidth, // Usa a largura expandida para o rail
              labelType: NavigationRailLabelType.none, 
              selectedIconTheme: const IconThemeData(color: AppTheme.kWinAccent, size: 26),
              unselectedIconTheme: const IconThemeData(color: AppTheme.kWinSecondaryText, size: 24),
              selectedLabelTextStyle: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.kWinAccent,
              ),
              unselectedLabelTextStyle: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.kWinPrimaryText,
              ),
              useIndicator: true,
              indicatorColor: AppTheme.kWinAccent.withOpacity(0.12),
              indicatorShape: RoundedRectangleBorder(
                 borderRadius: BorderRadius.circular(8.0)
              ),
              // O leading do NavigationRail pode ser usado para o toggle, mas como já temos um acima, pode ser nulo.
              // Ou, se preferir o toggle DENTRO do scroll do NavigationRail:
              // leading: IconButton(icon: Icon(_isExpanded ? Icons.menu_open_rounded : Icons.menu_rounded), onPressed: () => setState(() => _isExpanded = !_isExpanded)),
              destinations: _displayedMenuItems.map((item) {
                return NavigationRailDestination(
                  icon: Tooltip(message: item.title, child: Icon(item.icon)),
                  selectedIcon: Tooltip(message: item.title, child: Icon(item.icon)),
                  label: Text(item.title),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0), // Ajuste padding do destino
                );
              }).toList(),
            ),
          ),
          // 4. Ações (Busca, Atualização) e Logout
          _buildMenuActions(context),
          const Divider(height: 0, thickness: 1, color: AppTheme.kWinDivider),
          Padding(
             padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: _buildLogoutButton(context),
          ),
        ],
      ),
    );
  }
}
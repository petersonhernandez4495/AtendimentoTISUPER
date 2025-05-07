// lib/widgets/side_menu.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/theme/app_theme.dart';
import 'package:flutter/foundation.dart'; // Para kReleaseMode

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
  final User? currentUser;
  final VoidCallback? onCheckForUpdates;
  final VoidCallback? onSearchPressed;

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
  final double _expandedWidth = 240.0;

  late List<MenuItemData> _navigationRailItems;
  static const int perfilScreenIndex = 3;

  @override
  void initState() {
    super.initState();
    _updateNavigationRailItems();
  }

  @override
  void didUpdateWidget(covariant SideMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isAdminUser != widget.isAdminUser) {
      _updateNavigationRailItems();
    }
  }

  void _updateNavigationRailItems() {
    _navigationRailItems = [
      MenuItemData(icon: Icons.list_alt_rounded, title: 'Chamados', index: 0),
      MenuItemData(icon: Icons.add_comment_outlined, title: 'Novo Chamado', index: 1),
      MenuItemData(icon: Icons.calendar_month_outlined, title: 'Agenda', index: 2),
      MenuItemData(icon: Icons.archive_outlined, title: 'Chamados Arquivados', index: 5),
    ];

    if (widget.isAdminUser) {
      _navigationRailItems.add(MenuItemData(icon: Icons.manage_accounts_outlined, title: 'Gerenciar Usuários', index: 4, isAdminOnly: true));
    }
  }

  Widget _buildMenuHeader(BuildContext context) {
    final User? user = widget.currentUser;
    final ThemeData theme = Theme.of(context);

    // SOLUÇÃO PARA O ERRO "No host specified in URI":
    // Validar user.photoURL antes de usá-lo com NetworkImage.
    ImageProvider? userImageProvider;
    if (user?.photoURL != null &&
        user!.photoURL!.isNotEmpty &&
        (user.photoURL!.startsWith('http://') || user.photoURL!.startsWith('https://'))) {
      try {
        userImageProvider = NetworkImage(user.photoURL!);
      } catch (e) {
        print('Erro ao criar NetworkImage para ${user.photoURL}: $e');
        // userImageProvider permanece null, o ícone de fallback será usado
      }
    }

    return Column(
      crossAxisAlignment: _isExpanded ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        if (_isExpanded)
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
              widget.onDestinationSelected(perfilScreenIndex);
            },
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: _isExpanded ? 16.0 : (_collapsedWidth - 40) / 2,
                vertical: 12.0,
              ),
              child: _isExpanded
                  ? Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppTheme.kWinAccent.withOpacity(0.2),
                          backgroundImage: userImageProvider, // Usar a variável validada
                          child: userImageProvider == null // Mostrar ícone se a imagem não puder ser carregada
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
                  : CircleAvatar(
                      radius: 20,
                      backgroundColor: AppTheme.kWinAccent.withOpacity(0.2),
                      backgroundImage: userImageProvider, // Usar a variável validada
                      child: userImageProvider == null // Mostrar ícone se a imagem não puder ser carregada
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
          if (widget.onCheckForUpdates != null && kReleaseMode)
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
    int railSelectedIndex = -1;
    if (widget.selectedIndex != perfilScreenIndex) {
        railSelectedIndex = _navigationRailItems.indexWhere((item) => item.index == widget.selectedIndex);
    }

    return Container(
      width: _isExpanded ? _expandedWidth : _collapsedWidth,
      decoration: BoxDecoration(
        color: AppTheme.kWinSurface,
        border: Border(
          right: BorderSide(color: AppTheme.kWinDivider, width: 1.0),
        ),
      ),
      child: Column(
        children: [
          Container(
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
          _buildMenuHeader(context),
          Expanded(
            child: NavigationRail(
              selectedIndex: railSelectedIndex >= 0 ? railSelectedIndex : null,
              onDestinationSelected: (selectedIndexInRail) {
                  if (selectedIndexInRail < _navigationRailItems.length) {
                    widget.onDestinationSelected(_navigationRailItems[selectedIndexInRail].index);
                  }
              },
              extended: _isExpanded,
              backgroundColor: Colors.transparent,
              minWidth: _collapsedWidth,
              minExtendedWidth: _expandedWidth,
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
              destinations: _navigationRailItems.map((item) {
                return NavigationRailDestination(
                  icon: Tooltip(message: item.title, child: Icon(item.icon)),
                  selectedIcon: Tooltip(message: item.title, child: Icon(item.icon)),
                  label: Text(item.title),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
                );
              }).toList(),
            ),
          ),
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
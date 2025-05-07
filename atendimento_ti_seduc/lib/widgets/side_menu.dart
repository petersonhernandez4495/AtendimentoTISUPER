import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/theme/app_theme.dart'; // Ajuste o caminho se necessário
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
  bool _isExpanded = true;
  final double _collapsedWidth = 70.0;
  final double _expandedWidth = 256.0;

  late List<MenuItemData> _navigationRailItems;
  static const int perfilScreenIndex = 3;

  // Defina uma altura máxima razoável para a logo
  static const double _maxLogoContainerHeight = 260.0; // Reduzido para teste, ajuste conforme necessário
  // Defina um padding vertical para a logo
  static const double _logoVerticalPadding = 8.0;

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

  Widget _buildLogoSection(BuildContext context) {
    if (!_isExpanded) return const SizedBox.shrink(); // Não mostra logo se colapsado

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: _logoVerticalPadding, horizontal: 12.0),
      child: SizedBox(
        height: _maxLogoContainerHeight,
        width: double.infinity,
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
          child: Image.asset(
            'assets/images/seu_logo.png', // SUBSTITUA PELO CAMINHO CORRETO
            errorBuilder: (c, e, s) => Container(
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

  Widget _buildUserProfileSection(BuildContext context) {
    final User? user = widget.currentUser;
    final ThemeData theme = Theme.of(context);
    if (user == null) return const SizedBox.shrink();

    return InkWell(
      onTap: () {
        widget.onDestinationSelected(perfilScreenIndex);
      },
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: _isExpanded ? 16.0 : (_collapsedWidth - 40) / 2, // 40 = diâmetro do avatar
          vertical: 10.0,
        ),
        child: _isExpanded
            ? Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.kWinAccent.withOpacity(0.2),
                    backgroundImage: user.photoURL != null && user.photoURL!.isNotEmpty && (user.photoURL!.startsWith('http') || user.photoURL!.startsWith('https'))
                        ? NetworkImage(user.photoURL!)
                        : null,
                    child: user.photoURL == null || user.photoURL!.isEmpty || !(user.photoURL!.startsWith('http') || user.photoURL!.startsWith('https'))
                        ? Icon(Icons.person_rounded, size: 22, color: AppTheme.kWinAccent)
                        : null,
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
            : CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.kWinAccent.withOpacity(0.2),
                backgroundImage: user.photoURL != null && user.photoURL!.isNotEmpty && (user.photoURL!.startsWith('http') || user.photoURL!.startsWith('https'))
                    ? NetworkImage(user.photoURL!)
                    : null,
                child: user.photoURL == null || user.photoURL!.isEmpty || !(user.photoURL!.startsWith('http') || user.photoURL!.startsWith('https'))
                    ? Icon(Icons.person_rounded, size: 22, color: AppTheme.kWinAccent)
                    : null,
              ),
      ),
    );
  }

  Widget _buildMenuActions(BuildContext context) {
    // Esta função pode ser simplificada ou ter seus itens com altura controlada
    List<Widget> actions = [];
    if (widget.onSearchPressed != null) {
      actions.add(_buildActionItem(context, icon: Icons.search_outlined, label: 'Buscar', onPressed: widget.onSearchPressed));
    }
    if (widget.onCheckForUpdates != null && kReleaseMode) {
      actions.add(_buildActionItem(context, icon: Icons.update_outlined, label: 'Verificar Atualizações', onPressed: widget.onCheckForUpdates));
    }
    if (actions.isEmpty) return const SizedBox.shrink();
    return Column(mainAxisSize: MainAxisSize.min, children: actions);
  }

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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Padding vertical reduzido
          alignment: Alignment.centerLeft,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))
        ),
      );
    } else {
      return IconButton(
        icon: Icon(icon, color: AppTheme.kWinSecondaryText, size: 24),
        tooltip: label,
        onPressed: onPressed,
        padding: const EdgeInsets.all(12), // Padding para IconButton
      );
    }
  }

  Widget _buildLogoutButton(BuildContext context) {
    final Color logoutIconColor = AppTheme.kErrorColor.withOpacity(0.9);
    final Color logoutTextColor = AppTheme.kErrorColor;

    if (_isExpanded) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0), // Padding vertical
        child: TextButton.icon(
          icon: Icon(Icons.logout_rounded, color: logoutIconColor, size: 22),
          label: Text(
            'Sair',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: logoutTextColor, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          onPressed: widget.onLogout,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), // Padding vertical reduzido
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
          padding: const EdgeInsets.all(12), // Padding para IconButton
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
          // 1. Botão de Expandir/Recolher
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

          // 2. Seção do Logo (somente se expandido)
          _buildLogoSection(context),

          // 3. Seção do Perfil do Usuário
          _buildUserProfileSection(context),
          
          const Divider(height: 1, thickness: 1, color: AppTheme.kWinDivider),

          // 4. Itens de Navegação Principais
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
              selectedIconTheme: const IconThemeData(color: AppTheme.kWinAccent, size: 24), // Tamanho do ícone ajustado
              unselectedIconTheme: const IconThemeData(color: AppTheme.kWinSecondaryText, size: 22), // Tamanho do ícone ajustado
              selectedLabelTextStyle: theme.textTheme.bodySmall?.copyWith( // Usando bodySmall para labels
                fontWeight: FontWeight.bold,
                color: AppTheme.kWinAccent,
              ),
              unselectedLabelTextStyle: theme.textTheme.bodySmall?.copyWith( // Usando bodySmall
                color: AppTheme.kWinPrimaryText,
              ),
              useIndicator: true,
              indicatorColor: AppTheme.kWinAccent.withOpacity(0.12),
              indicatorShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6.0) // Raio menor
              ),
              destinations: _navigationRailItems.map((item) {
                return NavigationRailDestination(
                  icon: Tooltip(message: item.title, child: Icon(item.icon)),
                  selectedIcon: Tooltip(message: item.title, child: Icon(item.icon)),
                  label: Text(
                    item.title,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0), // Padding vertical reduzido
                );
              }).toList(),
            ),
          ),
          
          // 5. Ações (Busca, Atualização)
          if (_isExpanded) // Mostrar ações apenas se expandido e se houver ações
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: _buildMenuActions(context),
            )
          else if (!_isExpanded && (widget.onSearchPressed != null || (widget.onCheckForUpdates != null && kReleaseMode)) ) // Mostrar ícones de ação se colapsado e houver ações
             _buildMenuActions(context),


          // 6. Logout
          const Divider(height: 0, thickness: 1, color: AppTheme.kWinDivider),
          _buildLogoutButton(context),
          const SizedBox(height: 4), // Pequeno espaço no final
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../config/theme/app_theme.dart';

class MenuItemData {
  final IconData icon;
  final String title;
  final int index;
  final bool isAdminOnly;
  final VoidCallback? customNavigation;

  MenuItemData({
    required this.icon,
    required this.title,
    required this.index,
    this.isAdminOnly = false,
    this.customNavigation,
  });
}

class SideMenu extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onLogout;
  final bool isAdminUser;
  final String userRole;
  final User? currentUser;
  final VoidCallback? onCheckForUpdates;
  final ValueChanged<String>? onSearchQueryChanged;
  final String initialSearchQuery;

  static const int perfilScreenIndex = 3;
  static const int tutorialScreenIndex =
      6; // Corresponde ao índice da tela de Tutoriais

  const SideMenu({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onLogout,
    required this.isAdminUser,
    required this.userRole,
    this.currentUser,
    this.onCheckForUpdates,
    this.onSearchQueryChanged,
    this.initialSearchQuery = "",
  });

  @override
  State<SideMenu> createState() => _SideMenuState();
}

class _SideMenuState extends State<SideMenu> {
  bool _isExpanded = true;
  final double _collapsedWidth = 70.0;
  final double _expandedWidth = 256.0;
  late TextEditingController _searchController;

  late List<MenuItemData> _navigationRailItems;
  late List<MenuItemData> _footerItems;

  static const double _maxLogoContainerHeight = 120.0;
  static const double _logoVerticalPadding = 8.0;

  @override
  void initState() {
    super.initState();
    _updateMenuItems();
    _searchController = TextEditingController(text: widget.initialSearchQuery);
    _searchController.addListener(() {
      widget.onSearchQueryChanged?.call(_searchController.text);
    });
  }

  @override
  void didUpdateWidget(covariant SideMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isAdminUser != widget.isAdminUser ||
        oldWidget.userRole != widget.userRole) {
      _updateMenuItems(); // Atualiza os itens se a role ou status de admin mudar
    }
    if (widget.initialSearchQuery != oldWidget.initialSearchQuery &&
        widget.initialSearchQuery != _searchController.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _searchController.text = widget.initialSearchQuery;
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _updateMenuItems() {
    _navigationRailItems = [
      MenuItemData(icon: Icons.list_alt_rounded, title: 'Chamados', index: 0),
      // MODIFICADO: "Novo Chamado" (index 1) sempre visível.
      // O controle de acesso é feito na MainNavigationScreen ao tentar navegar.
      MenuItemData(
          icon: Icons.add_comment_outlined, title: 'Novo Chamado', index: 1),
      MenuItemData(
          icon: Icons.calendar_month_outlined, title: 'Agenda', index: 2),
      MenuItemData(
          icon: Icons.archive_outlined, title: 'Chamados Arquivados', index: 5),
    ];

    if (widget.isAdminUser) {
      _navigationRailItems.add(MenuItemData(
          icon: Icons.manage_accounts_outlined,
          title: 'Gerenciar Usuários',
          index: 4, // Índice da UserManagementScreen
          isAdminOnly: true));
    }

    // Opcional: Reordenar para garantir a ordem visual caso a adição seja complexa.
    // _navigationRailItems.sort((a, b) => a.index.compareTo(b.index));

    _footerItems = [
      MenuItemData(
        icon: Icons.video_library_rounded,
        title: 'Tutoriais',
        index: SideMenu.tutorialScreenIndex, // Índice 6
        customNavigation: null,
      ),
    ];
  }

  Widget _buildSearchField(BuildContext context) {
    if (!_isExpanded) {
      return IconButton(
        icon: const Icon(Icons.search_outlined),
        tooltip: 'Pesquisar Chamados',
        color: AppTheme.kWinSecondaryText,
        iconSize: 26,
        onPressed: () {
          setState(() {
            _isExpanded = true;
          });
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12.0, 8.0, 12.0, 12.0),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: AppTheme.kWinPrimaryText, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Pesquisar chamado...',
          hintStyle: TextStyle(
              color: AppTheme.kWinSecondaryText.withOpacity(0.7), fontSize: 13),
          prefixIcon: Icon(Icons.search_outlined,
              color: AppTheme.kWinSecondaryText.withOpacity(0.8), size: 20),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 10.0, horizontal: 10.0),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20.0),
            borderSide:
                BorderSide(color: AppTheme.kWinDivider.withOpacity(0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20.0),
            borderSide:
                BorderSide(color: AppTheme.kWinDivider.withOpacity(0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20.0),
            borderSide:
                const BorderSide(color: AppTheme.kWinAccent, width: 1.5),
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded,
                      color: AppTheme.kWinSecondaryText, size: 18),
                  onPressed: () {
                    _searchController.clear();
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildLogoSection(BuildContext context) {
    if (!_isExpanded) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(
          vertical: _logoVerticalPadding, horizontal: 60.0),
      child: SizedBox(
        height: _maxLogoContainerHeight,
        width: double.infinity,
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
          child: Image.asset(
            'assets/images/seu_logo.png',
            errorBuilder: (c, e, s) => Container(
              height: _maxLogoContainerHeight,
              alignment: Alignment.center,
              child: Text(
                "LOGO",
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: AppTheme.kWinPrimaryText),
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

    final bool hasValidPhotoUrl = user.photoURL != null &&
        user.photoURL!.isNotEmpty &&
        (user.photoURL!.startsWith('http') ||
            user.photoURL!.startsWith('https'));

    return InkWell(
      onTap: () {
        widget.onDestinationSelected(SideMenu.perfilScreenIndex);
      },
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: _isExpanded ? 16.0 : (_collapsedWidth - 40) / 2,
          vertical: 10.0,
        ),
        child: _isExpanded
            ? Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.kWinAccent.withOpacity(0.2),
                    backgroundImage:
                        hasValidPhotoUrl ? NetworkImage(user.photoURL!) : null,
                    child: !hasValidPhotoUrl
                        ? const Icon(Icons.person_rounded,
                            size: 22, color: AppTheme.kWinAccent)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (user.displayName != null &&
                            user.displayName!.isNotEmpty)
                          Text(
                            user.displayName!,
                            style: theme.textTheme.titleSmall?.copyWith(
                                color: AppTheme.kWinPrimaryText,
                                fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        if (user.email != null && user.email!.isNotEmpty)
                          Text(
                            user.email!,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: AppTheme.kWinSecondaryText),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                      ],
                    ),
                  ),
                ],
              )
            : Tooltip(
                message: user.displayName ?? user.email ?? 'Perfil',
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.kWinAccent.withOpacity(0.2),
                  backgroundImage:
                      hasValidPhotoUrl ? NetworkImage(user.photoURL!) : null,
                  child: !hasValidPhotoUrl
                      ? const Icon(Icons.person_rounded,
                          size: 22, color: AppTheme.kWinAccent)
                      : null,
                ),
              ),
      ),
    );
  }

  Widget _buildMenuActions(BuildContext context) {
    List<Widget> actions = [];
    if (widget.onCheckForUpdates != null && kReleaseMode) {
      actions.add(_buildActionItem(context,
          icon: Icons.update_outlined,
          label: 'Verificar Atualizações',
          onPressed: widget.onCheckForUpdates));
    }
    if (actions.isEmpty) return const SizedBox.shrink();
    return Column(mainAxisSize: MainAxisSize.min, children: actions);
  }

  Widget _buildActionItem(BuildContext context,
      {required IconData icon,
      required String label,
      VoidCallback? onPressed}) {
    if (_isExpanded) {
      return TextButton.icon(
        icon: Icon(icon, color: AppTheme.kWinSecondaryText, size: 20),
        label: Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppTheme.kWinPrimaryText),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        onPressed: onPressed,
        style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            alignment: Alignment.centerLeft,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
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

  Widget _buildCustomMenuItem(BuildContext context, MenuItemData item) {
    final bool isSelected =
        widget.selectedIndex == item.index && item.customNavigation == null;
    final Color iconColor =
        isSelected ? AppTheme.kWinAccent : AppTheme.kWinSecondaryText;
    final Color textColor =
        isSelected ? AppTheme.kWinAccent : AppTheme.kWinPrimaryText;
    final FontWeight fontWeight =
        isSelected ? FontWeight.bold : FontWeight.normal;

    if (_isExpanded) {
      return TextButton.icon(
        icon: Icon(item.icon, color: iconColor, size: 22),
        label: Text(
          item.title,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: textColor, fontWeight: fontWeight),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        onPressed: () {
          if (item.customNavigation != null) {
            item.customNavigation!();
          } else {
            widget.onDestinationSelected(item.index);
          }
        },
        style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            alignment: Alignment.centerLeft,
            backgroundColor: isSelected
                ? AppTheme.kWinAccent.withOpacity(0.12)
                : Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
      );
    } else {
      return Tooltip(
        message: item.title,
        preferBelow: false,
        child: IconButton(
          icon: Icon(item.icon, color: iconColor),
          iconSize: 24,
          isSelected: isSelected,
          selectedIcon: Icon(item.icon, color: AppTheme.kWinAccent),
          onPressed: () {
            if (item.customNavigation != null) {
              item.customNavigation!();
            } else {
              widget.onDestinationSelected(item.index);
            }
          },
          padding: const EdgeInsets.all(12),
          style: IconButton.styleFrom(
            backgroundColor: isSelected
                ? AppTheme.kWinAccent.withOpacity(0.12)
                : Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6.0)),
          ),
        ),
      );
    }
  }

  Widget _buildLogoutButton(BuildContext context) {
    final Color logoutIconColor = AppTheme.kErrorColor.withOpacity(0.9);
    const Color logoutTextColor = AppTheme.kErrorColor;

    if (_isExpanded) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        child: TextButton.icon(
          icon: Icon(Icons.logout_rounded, color: logoutIconColor, size: 22),
          label: Text(
            'Sair',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: logoutTextColor, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          onPressed: widget.onLogout,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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

  @override
  Widget build(BuildContext context) {
    int railSelectedIndex = -1;

    if (widget.selectedIndex != SideMenu.perfilScreenIndex &&
        widget.selectedIndex != SideMenu.tutorialScreenIndex) {
      railSelectedIndex = _navigationRailItems
          .indexWhere((item) => item.index == widget.selectedIndex);
    }

    return Container(
      width: _isExpanded ? _expandedWidth : _collapsedWidth,
      decoration: const BoxDecoration(
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
            padding:
                _isExpanded ? const EdgeInsets.only(right: 8) : EdgeInsets.zero,
            child: IconButton(
              icon: Icon(
                  _isExpanded ? Icons.menu_open_rounded : Icons.menu_rounded),
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
          _buildLogoSection(context),
          _buildSearchField(context),
          _buildUserProfileSection(context),
          const Divider(height: 1, thickness: 1, color: AppTheme.kWinDivider),
          Expanded(
            child: NavigationRail(
              selectedIndex: railSelectedIndex >= 0 ? railSelectedIndex : null,
              onDestinationSelected: (selectedIndexInRail) {
                if (selectedIndexInRail >= 0 &&
                    selectedIndexInRail < _navigationRailItems.length) {
                  final selectedItem =
                      _navigationRailItems[selectedIndexInRail];
                  widget.onDestinationSelected(selectedItem.index);
                }
              },
              extended: _isExpanded,
              backgroundColor: Colors.transparent,
              minWidth: _collapsedWidth,
              minExtendedWidth: _expandedWidth,
              labelType: NavigationRailLabelType.none,
              selectedIconTheme:
                  const IconThemeData(color: AppTheme.kWinAccent, size: 24),
              unselectedIconTheme: const IconThemeData(
                  color: AppTheme.kWinSecondaryText, size: 22),
              useIndicator: true,
              indicatorColor: AppTheme.kWinAccent.withOpacity(0.12),
              indicatorShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6.0)),
              destinations: _navigationRailItems.map((item) {
                return NavigationRailDestination(
                  icon: Tooltip(message: item.title, child: Icon(item.icon)),
                  selectedIcon:
                      Tooltip(message: item.title, child: Icon(item.icon)),
                  label: Text(item.title,
                      overflow: TextOverflow.ellipsis, maxLines: 1),
                  padding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: _isExpanded ? 8.0 : 0, vertical: 8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _footerItems
                  .map((item) => _buildCustomMenuItem(context, item))
                  .toList(),
            ),
          ),
          if (widget.onCheckForUpdates != null && kReleaseMode)
            Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: _isExpanded ? 8.0 : 0, vertical: 0),
                child: _buildMenuActions(context))
          else if (!_isExpanded &&
              (widget.onCheckForUpdates != null && kReleaseMode))
            _buildMenuActions(context),
          const Divider(height: 0, thickness: 1, color: AppTheme.kWinDivider),
          _buildLogoutButton(context),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

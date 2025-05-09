import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config/theme/app_theme.dart';
import 'widgets/gradient_background_container.dart';
import 'widgets/side_menu.dart';
import 'lista_chamados_screen.dart';
import 'novo_chamado_screen.dart';
import 'agenda_screen.dart';
import 'profile_screen.dart';
import 'user_management_screen.dart';
import 'login_screen.dart';
import 'chamados_arquivados_screen.dart';
import 'screens/tutorial_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});
  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  bool _isAdmin = false;
  String _userRole = 'inativo';
  bool _isLoadingRole = true;
  User? _firebaseUserInstance;
  String _globalSearchQuery = "";

  // Índices canônicos (baseados na lista de admin)
  static const int listaChamadosIndex = 0;
  static const int novoChamadoIndex = 1;
  static const int agendaIndex = 2;
  static const int perfilIndex = 3;
  static const int gerenciarUsuariosIndex = 4;
  static const int arquivadosIndex = 5;
  static const int tutoriaisIndex = 6;

  List<Widget> get _adminScreens => [
        ListaChamadosScreen(
            key: ValueKey('admin_chamados_$_globalSearchQuery'), // 0
            searchQuery: _globalSearchQuery),
        const NovoChamadoScreen(key: ValueKey('admin_novo_chamado')), // 1
        const AgendaScreen(key: ValueKey('admin_agenda')), // 2
        const ProfileScreen(key: ValueKey('admin_perfil')), // 3
        const UserManagementScreen(key: ValueKey('admin_user_management')), // 4
        ListaChamadosArquivadosScreen(
            key: ValueKey('admin_arquivados_$_globalSearchQuery'), // 5
            searchQuery: _globalSearchQuery),
        const TutorialScreen(key: ValueKey('admin_tutoriais')), // 6
      ];

  List<Widget> get _userScreens {
    return [
      ListaChamadosScreen(
          key: ValueKey('user_chamados_$_globalSearchQuery'), // 0
          searchQuery: _globalSearchQuery),
      const NovoChamadoScreen(key: ValueKey('user_novo_chamado')), // 1
      const ProfileScreen(
          key: ValueKey(
              'user_perfil')), // 2 (corresponde ao admin perfilIndex 3)
      ListaChamadosArquivadosScreen(
          key: ValueKey(
              'user_arquivados_$_globalSearchQuery'), // 3 (corresponde ao admin arquivadosIndex 5)
          searchQuery: _globalSearchQuery),
      const TutorialScreen(
          key: ValueKey(
              'user_tutoriais')), // 4 (corresponde ao admin tutoriaisIndex 6)
    ];
  }

  List<Widget> get _currentScreenOptions =>
      _isAdmin ? _adminScreens : _userScreens;

  @override
  void initState() {
    super.initState();
    _firebaseUserInstance = FirebaseAuth.instance.currentUser;
    _checkUserRole();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (kReleaseMode) {
        _verificarAtualizacoesApp();
      }
    });
  }

  Future<void> _checkUserRole() async {
    // ... (lógica de _checkUserRole como antes)
    final User? currentUserFromAuth = FirebaseAuth.instance.currentUser;
    if (mounted) {
      setState(() {
        _firebaseUserInstance = currentUserFromAuth;
      });
    }
    bool isAdminResult = false;
    String roleResult = 'inativo';
    if (currentUserFromAuth != null) {
      try {
        final DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserFromAuth.uid)
            .get();
        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data() as Map<String, dynamic>;
          if (userData.containsKey('role_temp') &&
              userData['role_temp'] != null &&
              (userData['role_temp'] as String).isNotEmpty) {
            roleResult = userData['role_temp'] as String;
          } else if (userData.containsKey('role') &&
              userData['role'] != null &&
              (userData['role'] as String).isNotEmpty) {
            roleResult = userData['role'] as String;
          }
          if (roleResult.isEmpty) {
            roleResult = 'inativo';
          }
          if (roleResult == 'admin') {
            isAdminResult = true;
          }
        } else {
          roleResult = 'inativo';
        }
      } catch (e) {
        isAdminResult = false;
        roleResult = 'inativo';
      }
    } else {
      roleResult = 'inativo';
      isAdminResult = false;
    }
    if (mounted) {
      setState(() {
        _isAdmin = isAdminResult;
        _userRole = roleResult;
        _isLoadingRole = false;
        final optionsLength = _currentScreenOptions.length;
        if (_selectedIndex >= optionsLength || _selectedIndex < 0) {
          _selectedIndex = 0;
        }
      });
    }
  }

  Future<void> _verificarAtualizacoesApp() async {/* ... (como antes) ... */}
  Future<void> _mostrarDialogoAtualizacao(
      String newVersion, String notes, String url) async {
    /* ... (como antes) ... */
  }
  Future<void> _abrirUrlDownload(String url) async {/* ... (como antes) ... */}

  void _onDestinationSelected(int newScreenIndexFromSideMenu) {
    print(
        "DEBUG: _onDestinationSelected - newScreenIndexFromSideMenu: $newScreenIndexFromSideMenu, _isAdmin: $_isAdmin, _userRole: $_userRole");

    int targetListIndex =
        newScreenIndexFromSideMenu; // O índice para _adminScreens ou o índice mapeado para _userScreens

    if (!_isAdmin) {
      // Bloqueios específicos para não-admins
      if (_userRole == 'inativo' &&
          newScreenIndexFromSideMenu == novoChamadoIndex) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Permissão negada. Espere a ativação da conta.'),
            backgroundColor: Colors.orangeAccent,
            duration: Duration(seconds: 3),
          ));
        }
        return;
      }
      if (newScreenIndexFromSideMenu == agendaIndex) {
        // Tentativa de acessar Agenda
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Acesso à Agenda restrito a administradores.')),
          );
        }
        return;
      }
      if (newScreenIndexFromSideMenu == gerenciarUsuariosIndex) {
        // Tentativa de acessar Gerenciar Usuários
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Acesso restrito a administradores.')),
          );
        }
        return;
      }

      // Mapeamento de índices para _userScreens
      if (newScreenIndexFromSideMenu == perfilIndex) {
        // Admin index 3
        targetListIndex = 2; // User index 2
      } else if (newScreenIndexFromSideMenu == arquivadosIndex) {
        // Admin index 5
        targetListIndex = 3; // User index 3
      } else if (newScreenIndexFromSideMenu == tutoriaisIndex) {
        // Admin index 6
        targetListIndex = 4; // User index 4
      }
      // Índices 0 (Lista) e 1 (Novo) são os mesmos para _userScreens
    }

    final optionsLength = _currentScreenOptions.length;
    if (targetListIndex >= 0 && targetListIndex < optionsLength) {
      if (mounted) {
        setState(() {
          _selectedIndex = targetListIndex;
          // Limpa a busca global se sair das telas de listagem de chamados
          int arquivadosListIndex =
              _isAdmin ? arquivadosIndex : 3; // Mapeado para _userScreens
          if (_globalSearchQuery.isNotEmpty &&
              _selectedIndex != listaChamadosIndex &&
              _selectedIndex != arquivadosListIndex) {
            _globalSearchQuery = "";
          }
        });
      }
    } else {
      print(
          "DEBUG: _onDestinationSelected - targetListIndex $targetListIndex fora dos limites para optionsLength $optionsLength");
      if (mounted && _selectedIndex != 0) {
        setState(() {
          _selectedIndex = 0;
        });
      }
    }
  }

  Future<void> _fazerLogout(BuildContext context) async {
    /* ... (como antes) ... */
  }

  void _handleSearchQueryChanged(String query) {
    if (mounted) {
      setState(() {
        _globalSearchQuery = query;
        int arquivadosListIndex =
            _isAdmin ? arquivadosIndex : 3; // Mapeado para _userScreens
        if (_selectedIndex != listaChamadosIndex &&
            _selectedIndex != arquivadosListIndex &&
            query.isNotEmpty) {
          _selectedIndex =
              listaChamadosIndex; // Volta para a lista de chamados principal
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (lógica de build como antes, usando _selectedIndex que agora está corretamente mapeado) ...
    final BorderRadius contentBorderRadius = BorderRadius.circular(12.0);
    int effectiveIndex = _selectedIndex;

    if (_isLoadingRole) {
      effectiveIndex = 0;
    } else {
      final optionsLength = _currentScreenOptions.length;
      if (_selectedIndex < 0 || _selectedIndex >= optionsLength) {
        print(
            "DEBUG: Build - _selectedIndex $_selectedIndex fora dos limites, resetando para 0");
        effectiveIndex = 0;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedIndex != effectiveIndex) {
            setState(() {
              _selectedIndex = effectiveIndex;
            });
          }
        });
      } else {
        effectiveIndex = _selectedIndex;
      }
    }

    if (_isLoadingRole) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: GradientBackgroundContainer(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SideMenu(
              selectedIndex:
                  _selectedIndex, // Passa o _selectedIndex já mapeado
              onDestinationSelected: _onDestinationSelected,
              onLogout: () => _fazerLogout(context),
              isAdminUser: _isAdmin,
              userRole: _userRole,
              currentUser: _firebaseUserInstance,
              onCheckForUpdates:
                  kReleaseMode ? _verificarAtualizacoesApp : null,
              onSearchQueryChanged: _handleSearchQueryChanged,
              initialSearchQuery: _globalSearchQuery,
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(
                    top: 8.0, right: 8.0, bottom: 8.0, left: 0.0),
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).cardTheme.color ?? AppTheme.kWinSurface,
                  borderRadius: contentBorderRadius,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: contentBorderRadius,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    child: IndexedStack(
                      key: ValueKey<String>(
                          'indexed_stack_${_isAdmin}_${_userRole}_$effectiveIndex'),
                      index: effectiveIndex,
                      children: _currentScreenOptions,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

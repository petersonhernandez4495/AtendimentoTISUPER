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
import 'widgets/side_menu.dart'; // Import do SideMenu
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
  String _userRole = 'inativo'; // Armazena a role do usuário, padrão 'inativo'
  bool _isLoadingRole = true;
  User? _firebaseUserInstance;
  String _globalSearchQuery = "";

  // Telas disponíveis para administradores
  List<Widget> get _adminScreens => [
        ListaChamadosScreen(
            key: ValueKey('admin_chamados_$_globalSearchQuery'),
            searchQuery: _globalSearchQuery),
        const NovoChamadoScreen(key: ValueKey('admin_novo_chamado')),
        const AgendaScreen(key: ValueKey('admin_agenda')),
        const ProfileScreen(key: ValueKey('admin_perfil')),
        const UserManagementScreen(key: ValueKey('admin_user_management')),
        ListaChamadosArquivadosScreen(
            key: ValueKey('admin_arquivados_$_globalSearchQuery'),
            searchQuery: _globalSearchQuery),
        const TutorialScreen(key: ValueKey('admin_tutoriais')),
      ];

  // Telas disponíveis para usuários não-administradores
  List<Widget> get _userScreens {
    // MODIFICADO: NovoChamadoScreen sempre presente. O controle de acesso
    // será feito em _onDestinationSelected.
    return [
      ListaChamadosScreen(
          key: ValueKey('user_chamados_$_globalSearchQuery'),
          searchQuery: _globalSearchQuery),
      const NovoChamadoScreen(
          key: ValueKey('user_novo_chamado')), // Sempre incluído
      const AgendaScreen(key: ValueKey('user_agenda')),
      const ProfileScreen(key: ValueKey('user_perfil')),
      Container(
          key: const ValueKey(
              'user_placeholder_admin_only')), // Placeholder para User Management
      ListaChamadosArquivadosScreen(
          key: ValueKey('user_arquivados_$_globalSearchQuery'),
          searchQuery: _globalSearchQuery),
      const TutorialScreen(key: ValueKey('user_tutoriais')),
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
          print(
              "MainNavigationScreen: Documento do usuário não encontrado, tratando como 'inativo'. UID: ${currentUserFromAuth.uid}");
          roleResult = 'inativo';
        }
      } catch (e) {
        print("MainNavigationScreen: Erro ao verificar papel do usuário: $e");
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

        // MODIFICADO: Removida a lógica que força _selectedIndex = 0 para usuário inativo
        // tentando acessar o índice 1, pois o _onDestinationSelected cuidará disso com um alerta.
        final optionsLength = _currentScreenOptions.length;
        if (_selectedIndex >= optionsLength ||
            _selectedIndex < 0 ||
            (!_isAdmin && _selectedIndex == 4)) {
          // Apenas verifica UserManagement para não-admin
          _selectedIndex = 0;
        }
      });
    }
  }

  Future<void> _verificarAtualizacoesApp() async {
    const String versionUrl =
        'https://raw.githubusercontent.com/petersonhernandez4495/AtendimentoTISUPER/refs/heads/main/atendimento_ti_seduc/updates/versao.json';
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String buildNumber =
          packageInfo.buildNumber.isNotEmpty ? packageInfo.buildNumber : "0";
      final Version currentVersion =
          Version.parse("${packageInfo.version}+$buildNumber");

      final response = await http.get(Uri.parse(versionUrl));
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final String? latestVersionStr =
            jsonResponse['latestSemanticVersion'] as String?;
        final String? releaseNotes = jsonResponse['releaseNotes'] as String?;
        final String? downloadUrl = jsonResponse['downloadUrl'] as String?;

        if (latestVersionStr == null || downloadUrl == null) {
          return;
        }

        final Version latestVersion = Version.parse(latestVersionStr);
        if (latestVersion > currentVersion) {
          if (mounted) {
            _mostrarDialogoAtualizacao(latestVersionStr,
                releaseNotes ?? "Sem notas de versão.", downloadUrl);
          }
        }
      }
    } catch (e) {
      // print("MainNavigationScreen: Erro ao verificar atualizações: $e");
    }
  }

  Future<void> _mostrarDialogoAtualizacao(
      String newVersion, String notes, String url) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Atualização Disponível! (v$newVersion)'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'Uma nova versão do aplicativo está disponível. Notas da versão:'),
                const SizedBox(height: 15),
                Text(notes, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('MAIS TARDE'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('ATUALIZAR AGORA'),
              onPressed: () {
                Navigator.of(context).pop();
                _abrirUrlDownload(url);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _abrirUrlDownload(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await canLaunchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Não foi possível abrir o link de download: $url'),
            backgroundColor: Colors.red));
      }
      return;
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erro ao tentar abrir o link: $e'),
            backgroundColor: Colors.red));
      }
    }
  }

  void _onDestinationSelected(int newScreenIndex) {
    final optionsLength = _currentScreenOptions.length;

    // MODIFICADO: Mensagem da SnackBar atualizada.
    if (!_isAdmin && _userRole == 'inativo' && newScreenIndex == 1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Permissão negada. Espere a ativação da conta.'), // Mensagem atualizada
          backgroundColor: Colors.orangeAccent, // Cor ajustada para alerta
          duration: Duration(seconds: 3),
        ));
      }
      return;
    }

    if (newScreenIndex == 4 && !_isAdmin) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Acesso restrito a administradores.')),
        );
      }
      return;
    }

    if (newScreenIndex >= 0 && newScreenIndex < optionsLength) {
      if (mounted) {
        setState(() {
          _selectedIndex = newScreenIndex;
          if (_globalSearchQuery.isNotEmpty &&
              newScreenIndex != 0 &&
              newScreenIndex != 5) {
            _globalSearchQuery = "";
          }
        });
      }
    } else {
      if (mounted && _selectedIndex != 0) {
        setState(() {
          _selectedIndex = 0;
        });
      }
    }
  }

  Future<void> _fazerLogout(BuildContext context) async {
    bool confirmar = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirmar Logout'),
            content: const Text('Deseja realmente sair da sua conta?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancelar')),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Sair',
                    style: TextStyle(color: AppTheme.kErrorColor)),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmar || !mounted) return;
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao fazer logout: $e')),
        );
      }
    }
  }

  void _handleSearchQueryChanged(String query) {
    if (mounted) {
      setState(() {
        _globalSearchQuery = query;
        if (_selectedIndex != 0 && _selectedIndex != 5 && query.isNotEmpty) {
          _selectedIndex = 0;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final BorderRadius contentBorderRadius = BorderRadius.circular(12.0);
    int effectiveIndex = _selectedIndex;

    if (_isLoadingRole) {
      effectiveIndex = 0;
    } else {
      final optionsLength = _currentScreenOptions.length;
      // MODIFICADO: Removida a lógica que força effectiveIndex = 0 para usuário inativo
      // tentando acessar o índice 1, pois o _onDestinationSelected cuidará disso com um alerta.
      if (_selectedIndex < 0 ||
          _selectedIndex >= optionsLength ||
          (!_isAdmin && _selectedIndex == 4)) {
        // Apenas verifica UserManagement para não-admin
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
              selectedIndex: effectiveIndex,
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

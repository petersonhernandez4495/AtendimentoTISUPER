// lib/main_navigation_screen.dart
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
import 'chamados_arquivados_screen.dart'; // Importe a tela de arquivados

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});
  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  bool _isAdmin = false;
  bool _isLoadingRole = true;
  User? _firebaseUserInstance;

  String _globalSearchQuery = "";

  // CORRIGIDO: Passa searchQuery para ListaChamadosArquivadosScreen também
  List<Widget> get _adminScreens => [
        ListaChamadosScreen(key: ValueKey('admin_chamados_$_globalSearchQuery'), searchQuery: _globalSearchQuery),
        const NovoChamadoScreen(key: ValueKey('admin_novo_chamado')),
        const AgendaScreen(key: ValueKey('admin_agenda')),
        const ProfileScreen(key: ValueKey('admin_perfil')),
        const UserManagementScreen(key: ValueKey('admin_user_management')),
        ListaChamadosArquivadosScreen(key: ValueKey('admin_arquivados_$_globalSearchQuery'), searchQuery: _globalSearchQuery), // Passa a query
      ];

  List<Widget> get _userScreens => [
        ListaChamadosScreen(key: ValueKey('user_chamados_$_globalSearchQuery'), searchQuery: _globalSearchQuery),
        const NovoChamadoScreen(key: ValueKey('user_novo_chamado')),
        const AgendaScreen(key: ValueKey('user_agenda')),
        const ProfileScreen(key: ValueKey('user_perfil')),
        Container(key: const ValueKey('user_placeholder_admin_only')),
        ListaChamadosArquivadosScreen(key: ValueKey('user_arquivados_$_globalSearchQuery'), searchQuery: _globalSearchQuery), // Passa a query
      ];

  List<Widget> get _currentScreenOptions =>
      _isAdmin ? _adminScreens : _userScreens;

  @override
  void initState() {
    // ... (seu initState existente) ...
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
    // ... (seu código _checkUserRole existente) ...
        final User? currentUserFromAuth = FirebaseAuth.instance.currentUser;
    if (mounted) { // Verifica se o widget ainda está montado
      setState(() {
        _firebaseUserInstance = currentUserFromAuth;
      });
    }

    bool isAdminResult = false;
    if (currentUserFromAuth != null) {
      try {
        // Use suas constantes aqui após centralizar
        final DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users') // Use kCollectionUsers
            .doc(currentUserFromAuth.uid)
            .get();
        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data() as Map<String, dynamic>;
          // Use kFieldUserRole
          if (userData.containsKey('role_temp') && userData['role_temp'] == 'admin') {
            isAdminResult = true;
          }
        }
      } catch (e) {
        print("MainNavigationScreen: Erro ao verificar papel do usuário: $e");
        isAdminResult = false;
      }
    }
    if (mounted) { // Verifica novamente antes de chamar setState
      setState(() {
        _isAdmin = isAdminResult;
        _isLoadingRole = false;
        if (_selectedIndex >= _currentScreenOptions.length || _selectedIndex < 0) {
          _selectedIndex = 0; // Garante que o índice seja válido
        }
      });
    }
  }

  Future<void> _verificarAtualizacoesApp() async {
    // ... (seu código _verificarAtualizacoesApp existente) ...
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
            _mostrarDialogoAtualizacao(
                latestVersionStr, releaseNotes ?? "Sem notas de versão.", downloadUrl);
          }
        }
      }
    } catch (e) {
      // print("MainNavigationScreen: Erro ao verificar atualizações: $e");
    }
  }

  Future<void> _mostrarDialogoAtualizacao(
      String newVersion, String notes, String url) async {
    // ... (seu código _mostrarDialogoAtualizacao existente) ...
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
    // ... (seu código _abrirUrlDownload existente) ...
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
    // ... (seu código _onDestinationSelected existente, com a limpeza de _globalSearchQuery) ...
        final optionsLength = _currentScreenOptions.length;
    if (newScreenIndex >= 0 && newScreenIndex < optionsLength) {
      if (mounted) {
        setState(() {
          _selectedIndex = newScreenIndex;
          // Limpa a pesquisa se o usuário navegar para uma tela que não seja
          // a de chamados (índice 0) ou arquivados (índice 5) E havia uma pesquisa.
          if (_globalSearchQuery.isNotEmpty && newScreenIndex != 0 && newScreenIndex != 5) {
            _globalSearchQuery = "";
          }
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _selectedIndex = 0; // Fallback seguro
        });
      }
    }
  }

  Future<void> _fazerLogout(BuildContext context) async {
    // ... (seu código _fazerLogout existente) ...
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
                child: Text('Sair', style: TextStyle(color: AppTheme.kErrorColor)),
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
    // ... (seu código _handleSearchQueryChanged existente) ...
        if (mounted) {
      setState(() {
        _globalSearchQuery = query;
        // Se o usuário está digitando e não está na tela de chamados (índice 0),
        // ou arquivados (índice 5), navega para a tela de chamados ativos.
        if (_selectedIndex != 0 && _selectedIndex != 5 && query.isNotEmpty) {
          _onDestinationSelected(0); // Chama o método que já tem setState e lógica de limpeza
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (seu código build existente, passando os callbacks e a query para SideMenu e usando _currentScreenOptions) ...
        final BorderRadius contentBorderRadius = BorderRadius.circular(12.0);

    int effectiveSelectedIndex = _selectedIndex;
    if (_selectedIndex >= _currentScreenOptions.length || _selectedIndex < 0) {
      effectiveSelectedIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedIndex != effectiveSelectedIndex) {
          setState(() {
            _selectedIndex = effectiveSelectedIndex;
          });
        }
      });
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
              selectedIndex: effectiveSelectedIndex,
              onDestinationSelected: _onDestinationSelected,
              onLogout: () => _fazerLogout(context),
              isAdminUser: _isAdmin,
              currentUser: _firebaseUserInstance,
              onCheckForUpdates: kReleaseMode ? _verificarAtualizacoesApp : null,
              onSearchQueryChanged: _handleSearchQueryChanged,
              initialSearchQuery: _globalSearchQuery,
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(
                    top: 8.0, right: 8.0, bottom: 8.0, left: 0.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color ?? AppTheme.kWinSurface,
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
                      key: ValueKey<int>(effectiveSelectedIndex),
                      index: effectiveSelectedIndex,
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

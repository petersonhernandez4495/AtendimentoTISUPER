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

  final List<Widget> _adminScreens = [
    const ListaChamadosScreen(),
    const NovoChamadoScreen(),
    const AgendaScreen(),
    const ProfileScreen(),
    const UserManagementScreen(),
  ];

  final List<Widget> _userScreens = [
    const ListaChamadosScreen(),
    const NovoChamadoScreen(),
    const AgendaScreen(),
    const ProfileScreen(),
  ];

  List<Widget> get _currentScreenOptions => _isAdmin ? _adminScreens : _userScreens;

  @override
  void initState() {
    super.initState();
    _firebaseUserInstance = FirebaseAuth.instance.currentUser;
    _checkUserRole();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (kReleaseMode) {
        _verificarAtualizacoesApp();
      } else {
        print("[UpdateCheck] Verificação de atualizações pulada (Modo Debug).");
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
    if (currentUserFromAuth != null) {
      try {
        final DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserFromAuth.uid).get();
        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data() as Map<String, dynamic>;
          if (userData.containsKey('role_temp') && userData['role_temp'] == 'admin') {
            isAdminResult = true;
          }
        }
      } catch (e) {
        print("MainNavigationScreen: Erro ao buscar role do usuário: $e");
      }
    }
    if (mounted) {
      setState(() {
        _isAdmin = isAdminResult;
        _isLoadingRole = false;
        if (_selectedIndex >= _currentScreenOptions.length) {
          _selectedIndex = 0;
        }
      });
    }
  }

  Future<void> _verificarAtualizacoesApp() async {
    // ... (código da função _verificarAtualizacoesApp da resposta anterior, sem alterações aqui) ...
     print('[UpdateCheck] Verificando atualizações...');
    const String versionUrl = 'https://raw.githubusercontent.com/petersonhernandez4495/AtendimentoTISUPER/refs/heads/main/atendimento_ti_seduc/updates/versao.json';

    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String buildNumber = packageInfo.buildNumber.isNotEmpty ? packageInfo.buildNumber : "0";
      final Version currentVersion = Version.parse("${packageInfo.version}+${buildNumber}");
      print('[UpdateCheck] Versão Instalada: $currentVersion');

      final response = await http.get(Uri.parse(versionUrl));
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final String? latestVersionStr = jsonResponse['latestSemanticVersion'] as String?;
        final String? releaseNotes = jsonResponse['releaseNotes'] as String?;
        final String? downloadUrl = jsonResponse['downloadUrl'] as String?;

        if (latestVersionStr == null || downloadUrl == null) {
          print('[UpdateCheck] Erro: JSON de versão inválido ou incompleto.');
          return;
        }

        final Version latestVersion = Version.parse(latestVersionStr);
        print('[UpdateCheck] Versão Online: $latestVersion');

        if (latestVersion > currentVersion) {
          print('[UpdateCheck] Nova versão encontrada!');
          if (mounted) {
            _mostrarDialogoAtualizacao(latestVersionStr, releaseNotes ?? "Sem notas de versão.", downloadUrl);
          }
        } else {
          print('[UpdateCheck] Nenhuma atualização encontrada.');
        }
      } else {
        print('[UpdateCheck] Erro ao buscar JSON de versão: Status ${response.statusCode}');
      }
    } catch (e, s) {
      print('[UpdateCheck] Erro excepcional ao verificar atualizações: $e\n$s');
    }
  }

  Future<void> _mostrarDialogoAtualizacao(String newVersion, String notes, String url) async {
    // ... (código da função _mostrarDialogoAtualizacao da resposta anterior, sem alterações aqui) ...
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
                const Text('Uma nova versão do aplicativo está disponível. Notas da versão:'),
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
    // ... (código da função _abrirUrlDownload da resposta anterior, sem alterações aqui) ...
    final Uri uri = Uri.parse(url);
    if (!await canLaunchUrl(uri)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível abrir o link de download: $url'), backgroundColor: Colors.red));
      return;
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao tentar abrir o link: $e'), backgroundColor: Colors.red));
    }
  }


  void _onDestinationSelected(int newScreenIndex) {
    // O SideMenu envia o 'index' original do MenuItemData, que já foi mapeado
    // para corresponder aos índices das telas principais.
    if (newScreenIndex >= 0 && newScreenIndex < _currentScreenOptions.length) {
      if (mounted) {
        setState(() {
          _selectedIndex = newScreenIndex;
        });
      }
    } else {
      print("MainNavigationScreen: Índice de destino inválido $newScreenIndex recebido do SideMenu. Resetando para 0.");
      if (mounted) {
        setState(() {
          _selectedIndex = 0;
        });
      }
    }
  }

  Future<void> _fazerLogout(BuildContext context) async {
    // ... (código da função _fazerLogout da resposta anterior, sem alterações aqui) ...
    bool confirmar = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirmar Logout'),
            content: const Text('Deseja realmente sair da sua conta?'),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text('Sair', style: TextStyle(color: AppTheme.kErrorColor)),
              ),
            ],
          ),
        ) ?? false;
    if (!confirmar || !mounted) return;
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        setState(() {
          _firebaseUserInstance = null;
        });
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
      print("Erro no logout: $e");
    }
  }

  // Ação de busca (placeholder, pode ser expandida)
  void _handleSearch() {
    // TODO: Implementar lógica de busca. Pode abrir um Dialog, uma nova tela, ou um campo de busca.
    print("Ação de busca pressionada!");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funcionalidade de busca a ser implementada.')),
    );
  }


  @override
  Widget build(BuildContext context) {
    // final ThemeData theme = Theme.of(context); // Não usado diretamente aqui, mas pode ser útil
    final BorderRadius contentBorderRadius = BorderRadius.circular(12.0); 

    int effectiveSelectedIndex = _selectedIndex;
    if (_selectedIndex >= _currentScreenOptions.length) {
        effectiveSelectedIndex = 0;
        if (_selectedIndex != effectiveSelectedIndex) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _selectedIndex = effectiveSelectedIndex;
              });
            }
          });
        }
    }

    return Scaffold(
      // AppBar REMOVIDA
      body: GradientBackgroundContainer(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch, // Para o SideMenu ocupar toda a altura
          children: <Widget>[
            SideMenu(
              selectedIndex: effectiveSelectedIndex,
              onDestinationSelected: _onDestinationSelected,
              onLogout: () => _fazerLogout(context),
              isAdminUser: _isAdmin,
              currentUser: _firebaseUserInstance, // Passando o usuário para o SideMenu
              onCheckForUpdates: kReleaseMode ? _verificarAtualizacoesApp : null, // Passando callback
              onSearchPressed: _handleSearch, // Passando callback de busca
            ),
            Expanded(
              child: Container( 
                 margin: const EdgeInsets.only(top:8.0, right: 8.0, bottom: 8.0, left: 0.0), // Removido margin-left
                 decoration: BoxDecoration(
                   color: Theme.of(context).cardTheme.color ?? AppTheme.kWinSurface, 
                   borderRadius: contentBorderRadius,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0,2)
                      )
                    ]
                 ),
                child: ClipRRect(
                  borderRadius: contentBorderRadius,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (Widget child, Animation<double> animation) {
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
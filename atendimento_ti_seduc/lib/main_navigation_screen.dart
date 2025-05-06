import 'dart:convert'; // Para jsonDecode
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // Para kReleaseMode
import 'package:http/http.dart' as http; // Para buscar JSON
import 'package:package_info_plus/package_info_plus.dart'; // Para versão atual
import 'package:pub_semver/pub_semver.dart'; // Para comparar versões
import 'package:url_launcher/url_launcher.dart'; // Para abrir link

import 'config/theme/app_theme.dart';
import 'widgets/gradient_background_container.dart';
import 'widgets/side_menu.dart';
import 'lista_chamados_screen.dart';
import 'novo_chamado_screen.dart';
import 'agenda_screen.dart';
import 'profile_screen.dart';
import 'user_management_screen.dart';
import 'login_screen.dart';
import 'services/chamado_service.dart'; // Para constantes (se necessário)

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});
  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  bool _isAdmin = false;
  bool _isLoadingRole = true;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (kReleaseMode) { _verificarAtualizacoesApp(); }
      else { print("[UpdateCheck] Verificação pulada (Modo Debug)."); }
    });
  }

  Future<void> _checkUserRole() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    bool isAdminResult = false;
    if (currentUser != null) {
      try {
        final DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data() as Map<String, dynamic>;
          if (userData.containsKey('role_temp') && userData['role_temp'] == 'admin') { isAdminResult = true; }
        }
      } catch (e) { print("MainNavigation: Erro role: $e"); }
    }
    if (mounted) { setState(() { _isAdmin = isAdminResult; _isLoadingRole = false; }); }
  }

  Future<void> _verificarAtualizacoesApp() async {
    print('[UpdateCheck] Verificando atualizações...');
    // !!! SUBSTITUA PELA URL RAW DO SEU versao.json NO GITHUB !!!
    final String versionUrl = 'https://raw.githubusercontent.com/petersonhernandez4495/AtendimentoTISUPER/refs/heads/main/atendimento_ti_seduc/updates/appcast.xml';

    if (versionUrl == 'https://raw.githubusercontent.com/petersonhernandez4495/AtendimentoTISUPER/refs/heads/main/atendimento_ti_seduc/updates/appcast.xml' || versionUrl.isEmpty) {
      print('[UpdateCheck] ERRO: URL de versão não configurada!');
      return;
    }

    try {
      // 1. Obter informações do pacote atual
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final Version currentVersion = Version.parse("${packageInfo.version}+${packageInfo.buildNumber}");
      print('[UpdateCheck] Versão Instalada: $currentVersion');

      // 2. Buscar informações da versão online
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

        // 3. Comparar versões
        if (latestVersion > currentVersion) {
          print('[UpdateCheck] Nova versão encontrada!');
          if (mounted) {
             _mostrarDialogoAtualizacao(latestVersionStr, releaseNotes ?? "Sem notas.", downloadUrl);
          }
        } else {
          print('[UpdateCheck] Nenhuma atualização encontrada.');
        }
      } else {
        print('[UpdateCheck] Erro ao buscar JSON: Status ${response.statusCode}');
      }
    } catch (e, s) {
      print('[UpdateCheck] Erro ao verificar atualizações: $e\n$s');
    }
  }

  Future<void> _mostrarDialogoAtualizacao(String newVersion, String notes, String url) async {
    await showDialog(
      context: context,
      barrierDismissible: false, // Não fechar clicando fora
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Atualização Disponível! (v$newVersion)'),
          content: SingleChildScrollView( // Para caso as notas sejam longas
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
              onPressed: () { Navigator.of(context).pop(); },
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('ATUALIZAR AGORA'),
              onPressed: () {
                 Navigator.of(context).pop(); // Fecha dialog
                 _abrirUrlDownload(url); // Abre link no navegador
              },
            ),
          ],
        );
      },
    );
  }

   Future<void> _abrirUrlDownload(String url) async {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
         try {
            await launchUrl(uri, mode: LaunchMode.externalApplication); // Tenta abrir fora do app
         } catch(e) {
            if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível abrir o link: $e'), backgroundColor: Colors.red));
         }
      } else {
         if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível abrir o link: $url'), backgroundColor: Colors.red));
      }
   }


  void _onDestinationSelected(int index) { int maxValidIndex = 3; if (!_isLoadingRole && _isAdmin) { maxValidIndex = 4; } if (index >= 0 && index <= maxValidIndex) { setState(() { _selectedIndex = index; }); } else { print("Índice inválido: $index (max: $maxValidIndex)"); } }
  Future<void> _fazerLogout(BuildContext context) async { bool confirmar = await showDialog<bool>( context: context, builder: (ctx) => AlertDialog( title: const Text('Confirmar Logout'), content: const Text('Deseja sair?'), actions: [ TextButton( onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar'), ), TextButton( onPressed: () => Navigator.of(ctx).pop(true), child: Text('Sair', style: TextStyle(color: AppTheme.kErrorColor)), ), ], ), ) ?? false; if (!confirmar || !mounted) return; try { await FirebaseAuth.instance.signOut(); if (mounted) { Navigator.of(context).pushAndRemoveUntil( MaterialPageRoute(builder: (context) => const LoginScreen()), (Route<dynamic> route) => false, ); } } catch (e) { if (mounted) { ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Erro logout: $e')), ); } } }
  ImageProvider? _getValidNetworkImage(String? url) { if (url != null && url.isNotEmpty) { final Uri? uri = Uri.tryParse(url); if (uri != null && uri.hasScheme && uri.hasAuthority && (uri.scheme == 'http' || uri.scheme == 'https')) { return NetworkImage(url); } } return null; }

  @override
  Widget build(BuildContext context) {
    final List<Widget> currentOptions = [ const ListaChamadosScreen(), const NovoChamadoScreen(), const AgendaScreen(), const ProfileScreen(), if (!_isLoadingRole && _isAdmin) const UserManagementScreen(), ]; int correctedIndex = _selectedIndex; if (_selectedIndex >= currentOptions.length) { correctedIndex = 0; } final User? user = FirebaseAuth.instance.currentUser; final ThemeData theme = Theme.of(context); final Color? appBarTextColor = theme.appBarTheme.titleTextStyle?.color ?? AppTheme.kTextColor; final BorderRadius borderRadius = BorderRadius.circular(24.0);

    return Scaffold(
      appBar: AppBar( flexibleSpace: Container( decoration: BoxDecoration( gradient: LinearGradient( colors: [ AppTheme.kPrimaryColor.withOpacity(0.5), AppTheme.kSecondaryColor.withOpacity(0.3), ], begin: Alignment.topCenter, end: Alignment.bottomCenter, ), ), ), title: Padding( padding: const EdgeInsets.only(top: 4.0), child: Image.asset( 'assets/images/seu_logo.png', height: 30, errorBuilder: (c, e, s) => Text("LOGO", style: theme.textTheme.titleLarge?.copyWith(color: appBarTextColor)), ), ), automaticallyImplyLeading: false, toolbarHeight: 65.0, actions: <Widget>[ IconButton( icon: const Icon(Icons.search), tooltip: 'Buscar', onPressed: () {}, ), IconButton( icon: const Icon(Icons.update), tooltip: "Verificar Atualizações", onPressed: kReleaseMode ? _verificarAtualizacoesApp : null, ), const SizedBox(width: 8), if (user != null) Padding( padding: const EdgeInsets.only(right: 16.0), child: Row( children: [ if (user.email != null) Padding( padding: const EdgeInsets.only(right: 8.0), child: Text( user.email!, style: theme.textTheme.bodyMedium?.copyWith(color: appBarTextColor), overflow: TextOverflow.ellipsis,), ), CircleAvatar( radius: 16, backgroundColor: theme.colorScheme.primary.withOpacity(0.2), backgroundImage: _getValidNetworkImage(user.photoURL), child: _getValidNetworkImage(user.photoURL) == null ? Icon( Icons.person_outline, size: 18, color: theme.colorScheme.primary,) : null, ), ], ), ), if (user == null) const SizedBox(width: 16) ], ),
      body: GradientBackgroundContainer( child: Row( crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[ Padding( padding: const EdgeInsets.fromLTRB(16.0, 20.0, 0.0, 20.0), child: SideMenu( selectedIndex: _selectedIndex, onDestinationSelected: _onDestinationSelected, onLogout: () => _fazerLogout(context), ), ), Expanded( child: Padding( padding: const EdgeInsets.fromLTRB(8.0, 20.0, 16.0, 20.0), child: ClipRRect( borderRadius: borderRadius, child: AnimatedSwitcher( duration: const Duration(milliseconds: 250), transitionBuilder: (Widget child, Animation<double> animation) { return FadeTransition(opacity: animation, child: child); }, child: IndexedStack( key: ValueKey<int>(correctedIndex), index: correctedIndex, children: currentOptions, ), ) ), ), ), ], ), ),
    );
  }
}
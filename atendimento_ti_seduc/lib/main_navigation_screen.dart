import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:auto_updater/auto_updater.dart';
import 'package:flutter/foundation.dart'; // Para kReleaseMode

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

  @override
  void initState() {
    super.initState();
    _checkUserRole();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (kReleaseMode) {
         _initializeAutoUpdater();
      } else {
         print("[AutoUpdater] Verificação de updates pulada (Modo Debug).");
      }
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
          if (userData.containsKey('role_temp') && userData['role_temp'] == 'admin') {
            isAdminResult = true;
          }
        }
      } catch (e) { print("MainNavigation: Erro role: $e"); }
    }
    if (mounted) { setState(() { _isAdmin = isAdminResult; _isLoadingRole = false; }); }
  }

  Future<void> _initializeAutoUpdater() async {
    String feedURL = 'https://raw.githubusercontent.com/petersonhernandez4495/AtendimentoTISUPER/refs/heads/main/atendimento_ti_seduc/updates/appcast.xml?token=GHSAT0AAAAAADCHBSWUHBWHDFXPOHTIOKS22A2EB5A'; // <<< SUBSTITUA!

    if (feedURL == 'https://raw.githubusercontent.com/petersonhernandez4495/AtendimentoTISUPER/refs/heads/main/atendimento_ti_seduc/updates/appcast.xml?token=GHSAT0AAAAAADCHBSWUHBWHDFXPOHTIOKS22A2EB5A' || feedURL.isEmpty) {
       print("[AutoUpdater] ERRO: Feed URL não configurada!");
       return;
    }

    print('[AutoUpdater] Configurando Feed URL: $feedURL');
    try {
      await autoUpdater.setFeedURL(feedURL);

      // --- Listener REMOVIDO ---
      // autoUpdater.setCheckForUpdatesListener((event) { /* ... código removido ... */ });
      // ---------------------------

      print('[AutoUpdater] Verificando atualizações ao iniciar...');
      await autoUpdater.checkForUpdates(); // << Chama sem argumentos >>
      print('[AutoUpdater] Verificação inicial concluída (UI nativa pode ter sido mostrada).');
    } catch (e) {
       print('[AutoUpdater] Erro na inicialização/verificação: $e');
    }
  }

  Future<void> _checkForUpdatesManually() async {
     print('[AutoUpdater] Verificação manual iniciada...');
     final scaffoldMessenger = ScaffoldMessenger.of(context);
     try {
         await autoUpdater.checkForUpdates(); // << Chama sem argumentos >>
         // A UI nativa deve aparecer se houver update ou erro.
         // Você pode adicionar um SnackBar genérico se quiser feedback sempre.
         // scaffoldMessenger.showSnackBar(SnackBar(content: Text("Verificação concluída.")));
     } catch (e) {
         print('[AutoUpdater] Erro na verificação manual: $e');
         if(mounted) {
            scaffoldMessenger.showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
         }
     }
  }


  void _onDestinationSelected(int index) {
    int maxValidIndex = 3; if (!_isLoadingRole && _isAdmin) { maxValidIndex = 4; }
    if (index >= 0 && index <= maxValidIndex) { setState(() { _selectedIndex = index; }); }
    else { print("Índice inválido: $index (max: $maxValidIndex)"); }
  }

  Future<void> _fazerLogout(BuildContext context) async {
    bool confirmar = await showDialog<bool>( context: context, builder: (ctx) => AlertDialog( title: const Text('Confirmar Logout'), content: const Text('Deseja sair?'), actions: [ TextButton( onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar'), ), TextButton( onPressed: () => Navigator.of(ctx).pop(true), child: Text('Sair', style: TextStyle(color: AppTheme.kErrorColor)), ), ], ), ) ?? false; if (!confirmar || !mounted) return; try { await FirebaseAuth.instance.signOut(); if (mounted) { Navigator.of(context).pushAndRemoveUntil( MaterialPageRoute(builder: (context) => const LoginScreen()), (Route<dynamic> route) => false, ); } } catch (e) { if (mounted) { ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Erro logout: $e')), ); } }
  }

  ImageProvider? _getValidNetworkImage(String? url) { if (url != null && url.isNotEmpty) { final Uri? uri = Uri.tryParse(url); if (uri != null && uri.hasScheme && uri.hasAuthority && (uri.scheme == 'http' || uri.scheme == 'https')) { return NetworkImage(url); } } return null; }

  @override
  Widget build(BuildContext context) {
    final List<Widget> currentOptions = [ const ListaChamadosScreen(), const NovoChamadoScreen(), const AgendaScreen(), const ProfileScreen(), if (!_isLoadingRole && _isAdmin) const UserManagementScreen(), ];
    int correctedIndex = _selectedIndex; if (_selectedIndex >= currentOptions.length) { correctedIndex = 0; }
    final User? user = FirebaseAuth.instance.currentUser; final ThemeData theme = Theme.of(context); final Color? appBarTextColor = theme.appBarTheme.titleTextStyle?.color ?? AppTheme.kTextColor; final BorderRadius borderRadius = BorderRadius.circular(24.0);

    return Scaffold(
      appBar: AppBar(
          flexibleSpace: Container( decoration: BoxDecoration( gradient: LinearGradient( colors: [ AppTheme.kPrimaryColor.withOpacity(0.5), AppTheme.kSecondaryColor.withOpacity(0.3), ], begin: Alignment.topCenter, end: Alignment.bottomCenter, ), ), ),
          title: Padding( padding: const EdgeInsets.only(top: 4.0), child: Image.asset( 'assets/images/seu_logo.png', height: 30, errorBuilder: (c, e, s) => Text("LOGO", style: theme.textTheme.titleLarge?.copyWith(color: appBarTextColor)), ), ),
          automaticallyImplyLeading: false, toolbarHeight: 65.0,
          actions: <Widget>[
            IconButton( icon: const Icon(Icons.search), tooltip: 'Buscar', onPressed: () {}, ),
            IconButton( icon: const Icon(Icons.update), tooltip: "Verificar Atualizações", onPressed: kReleaseMode ? _checkForUpdatesManually : null, ),
            const SizedBox(width: 8),
            if (user != null) Padding( padding: const EdgeInsets.only(right: 16.0), child: Row( children: [ if (user.email != null) Padding( padding: const EdgeInsets.only(right: 8.0), child: Text( user.email!, style: theme.textTheme.bodyMedium?.copyWith(color: appBarTextColor), overflow: TextOverflow.ellipsis,), ), CircleAvatar( radius: 16, backgroundColor: theme.colorScheme.primary.withOpacity(0.2), backgroundImage: _getValidNetworkImage(user.photoURL), child: _getValidNetworkImage(user.photoURL) == null ? Icon( Icons.person_outline, size: 18, color: theme.colorScheme.primary,) : null, ), ], ), ),
            if (user == null) const SizedBox(width: 16)
          ],
      ),
      body: GradientBackgroundContainer( child: Row( crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[ Padding( padding: const EdgeInsets.fromLTRB(16.0, 20.0, 0.0, 20.0), child: SideMenu( selectedIndex: _selectedIndex, onDestinationSelected: _onDestinationSelected, onLogout: () => _fazerLogout(context), ), ), Expanded( child: Padding( padding: const EdgeInsets.fromLTRB(8.0, 20.0, 16.0, 20.0), child: ClipRRect( borderRadius: borderRadius, child: AnimatedSwitcher( duration: const Duration(milliseconds: 250), transitionBuilder: (Widget child, Animation<double> animation) { return FadeTransition(opacity: animation, child: child); }, child: IndexedStack( key: ValueKey<int>(correctedIndex), index: correctedIndex, children: currentOptions, ), ) ), ), ), ], ), ),
    );
  }
}
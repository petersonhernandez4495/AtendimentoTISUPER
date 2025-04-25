// lib/main_navigation_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'config/theme/app_theme.dart';
import 'widgets/gradient_background_container.dart';
import 'widgets/side_menu.dart';
// import 'widgets/horizontal_date_selector.dart'; // Não usado aqui
import 'lista_chamados_screen.dart';
import 'novo_chamado_screen.dart';
import 'agenda_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  // Estado de data removido

  // Funções e Callbacks (mantidos)
  void _onDestinationSelected(int index) { setState(() { _selectedIndex = index; }); }
  Future<void> _fazerLogout(BuildContext context) async { bool confirmar = await showDialog<bool>( context: context, builder: (BuildContext context) { return AlertDialog( title: const Text('Confirmar Logout'), content: const Text('Tem certeza que deseja sair?'), actions: <Widget>[ TextButton( onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar'), ), TextButton( onPressed: () => Navigator.of(context).pop(true), child: Text('Sair', style: TextStyle(color: AppTheme.kErrorColor)), ), ], ); }, ) ?? false; if (!confirmar || !mounted) return; try { await FirebaseAuth.instance.signOut(); if (mounted) { Navigator.of(context).pushAndRemoveUntil( MaterialPageRoute(builder: (context) => const LoginScreen()), (Route<dynamic> route) => false, ); } } catch (e) { print("Erro ao fazer logout: $e"); if (mounted) { ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Erro ao fazer logout: ${e.toString()}')), ); } } }
  List<Widget> _buildWidgetOptions() { return const <Widget>[ ListaChamadosScreen(), NovoChamadoScreen(), AgendaScreen(), ProfileScreen(), ]; }
  ImageProvider? _getValidNetworkImage(String? url) { if (url != null && url.isNotEmpty) { final Uri? uri = Uri.tryParse(url); if (uri != null && uri.hasScheme && uri.hasAuthority && (uri.scheme == 'http' || uri.scheme == 'https')) { return NetworkImage(url); } else { print('Formato de photoURL inválido: "$url"'); return null; } } return null; }


  @override
  Widget build(BuildContext context) {
    final List<Widget> widgetOptions = _buildWidgetOptions();
    final User? user = FirebaseAuth.instance.currentUser;
    final ThemeData theme = Theme.of(context);
    final Color? appBarTextColor = theme.appBarTheme.titleTextStyle?.color ?? AppTheme.kTextColor;
    final BorderRadius borderRadius = BorderRadius.circular(24.0); // Raio para cantos arredondados

    return Scaffold(
      appBar: AppBar(
        // AppBar com fundo gradiente via flexibleSpace (mantido)
        flexibleSpace: Container( decoration: BoxDecoration( gradient: LinearGradient( colors: [ AppTheme.kPrimaryColor.withOpacity(0.5), AppTheme.kSecondaryColor.withOpacity(0.3), ], begin: Alignment.topCenter, end: Alignment.bottomCenter, ), ), ),
        title: Padding( padding: const EdgeInsets.only(top: 4.0), child: Image.asset( 'assets/images/seu_logo.png', height: 30, errorBuilder: (context, error, stackTrace) { print("Erro ao carregar logo: $error"); return Text("LOGO", style: theme.textTheme.titleLarge?.copyWith(color: appBarTextColor)); }, ), ),
        automaticallyImplyLeading: false,
        toolbarHeight: 65.0,
        // Sem bottom (carrossel)
        actions: <Widget>[ // Actions mantidas
          IconButton( icon: const Icon(Icons.search), tooltip: 'Buscar Chamado', onPressed: () { /* TODO */ }, ),
          const SizedBox(width: 8),
          if (user != null) Padding( padding: const EdgeInsets.only(right: 16.0), child: Row( children: [ if (user.email != null) Padding( padding: const EdgeInsets.only(right: 8.0), child: Text( user.email!, style: theme.textTheme.bodyMedium?.copyWith(color: appBarTextColor), overflow: TextOverflow.ellipsis,), ), CircleAvatar( radius: 16, backgroundColor: theme.colorScheme.primary.withOpacity(0.2), backgroundImage: _getValidNetworkImage(user.photoURL), child: _getValidNetworkImage(user.photoURL) == null ? Icon( Icons.person_outline, size: 18, color: theme.colorScheme.primary,) : null, ), ], ), ),
          if (user == null) const SizedBox(width: 16)
        ],
      ),

      body: GradientBackgroundContainer( // Fundo gradiente geral
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // SideMenu com Padding externo (mantido)
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 20.0, 0.0, 20.0),
              child: SideMenu(
                selectedIndex: _selectedIndex,
                onDestinationSelected: _onDestinationSelected,
                onLogout: () => _fazerLogout(context),
              ),
            ),

            // SEM VerticalDivider

            // --- ÁREA DE CONTEÚDO PRINCIPAL (FUNDO TRANSPARENTE) ---
            Expanded(
              child: Padding( // Padding externo mantido
                padding: const EdgeInsets.fromLTRB(8.0, 20.0, 16.0, 20.0),
                child: ClipRRect( // Cantos arredondados mantidos
                  borderRadius: borderRadius,
                  // --- Container com cor REMOVIDO ---
                  // Agora o IndexedStack é filho direto do ClipRRect
                  // e mostrará o GradientBackgroundContainer por baixo
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: widgetOptions,
                  ),
                  // ---------------------------------
                ),
              ),
            ),
            // ----------------------------------------------------
          ],
        ),
      ),
    );
  }
}
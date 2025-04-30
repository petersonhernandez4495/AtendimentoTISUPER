import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <<< ADICIONADO: Para verificar role
import 'config/theme/app_theme.dart';
import 'widgets/gradient_background_container.dart';
import 'widgets/side_menu.dart';
import 'lista_chamados_screen.dart';
import 'novo_chamado_screen.dart';
import 'agenda_screen.dart';
import 'profile_screen.dart';
import 'user_management_screen.dart'; // <<< ADICIONADO: Importar a tela de admin
import 'login_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  // --- ADICIONADO: Estado para controle de Role Admin ---
  bool _isAdmin = false;
  bool _isLoadingRole = true;
  // --- FIM ADIÇÃO ---

  @override
  void initState() {
    super.initState();
    _checkUserRole(); // Chama a verificação ao iniciar
  }

  // --- ADICIONADO: Função para verificar Role Admin ---
  // (Similar à do SideMenu, adaptada para este contexto)
  Future<void> _checkUserRole() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    bool isAdminResult = false;

    if (currentUser != null) {
      try {
        final DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data() as Map<String, dynamic>;
          if (userData.containsKey('role_temp') && userData['role_temp'] == 'admin') {
            isAdminResult = true;
          }
        } else {
           print("MainNavigation: Documento do usuário ${currentUser.uid} não encontrado.");
        }
      } catch (e) {
        print("MainNavigation: Erro ao buscar role: $e");
      }
    } else {
      print("MainNavigation: Nenhum usuário logado.");
    }

    if (mounted) {
      setState(() {
        _isAdmin = isAdminResult;
        _isLoadingRole = false;
      });
    }
  }
  // --- FIM ADIÇÃO ---


  // --- MODIFICADO: Lógica de seleção com validação de índice ---
  void _onDestinationSelected(int index) {
    // Determina o número máximo de índices válidos AGORA
    int maxValidIndex = 3; // Índices 0, 1, 2, 3 são sempre válidos
    if (!_isLoadingRole && _isAdmin) {
       maxValidIndex = 4; // Se não está carregando E é admin, o índice 4 é válido
    }

    // Só atualiza se o índice estiver dentro dos limites válidos atuais
    if (index >= 0 && index <= maxValidIndex) {
      setState(() {
        _selectedIndex = index;
      });
    } else {
      print(" tentativa de selecionar indice invalido MainNavigation: $index (maximo atual: $maxValidIndex, isAdmin: $_isAdmin, isLoading: $_isLoadingRole)");
      // Opcional: Redefinir para um índice seguro, como 0
      // setState(() { _selectedIndex = 0; });
    }
  }
  // --- FIM MODIFICAÇÃO ---

  // Função de Logout (sem alterações)
  Future<void> _fazerLogout(BuildContext context) async {
     bool confirmar = await showDialog<bool>( context: context, builder: (BuildContext context) { return AlertDialog( title: const Text('Confirmar Logout'), content: const Text('Tem certeza que deseja sair?'), actions: <Widget>[ TextButton( onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar'), ), TextButton( onPressed: () => Navigator.of(context).pop(true), child: Text('Sair', style: TextStyle(color: AppTheme.kErrorColor)), ), ], ); }, ) ?? false; if (!confirmar || !mounted) return; try { await FirebaseAuth.instance.signOut(); if (mounted) { Navigator.of(context).pushAndRemoveUntil( MaterialPageRoute(builder: (context) => const LoginScreen()), (Route<dynamic> route) => false, ); } } catch (e) { print("Erro ao fazer logout: $e"); if (mounted) { ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Erro ao fazer logout: ${e.toString()}')), ); } }
  }

  // Obter imagem (sem alterações)
  ImageProvider? _getValidNetworkImage(String? url) { if (url != null && url.isNotEmpty) { final Uri? uri = Uri.tryParse(url); if (uri != null && uri.hasScheme && uri.hasAuthority && (uri.scheme == 'http' || uri.scheme == 'https')) { return NetworkImage(url); } else { print('Formato de photoURL inválido: "$url"'); return null; } } return null; }

  // --- REMOVIDO: _buildWidgetOptions() não é mais necessário ---
  // A lista será construída diretamente no build

  @override
  Widget build(BuildContext context) {
    // --- MODIFICADO: Construção dinâmica da lista de widgets ---
    final List<Widget> currentOptions = [
      const ListaChamadosScreen(), // Índice 0
      const NovoChamadoScreen(),   // Índice 1
      const AgendaScreen(),      // Índice 2
      const ProfileScreen(),     // Índice 3
      // Adiciona a tela de admin APENAS se a verificação terminou E o user é admin
      if (!_isLoadingRole && _isAdmin)
        const UserManagementScreen(), // Índice 4 (se adicionado)
    ];
    // --- FIM MODIFICAÇÃO ---

    final User? user = FirebaseAuth.instance.currentUser;
    final ThemeData theme = Theme.of(context);
    final Color? appBarTextColor = theme.appBarTheme.titleTextStyle?.color ?? AppTheme.kTextColor;
    final BorderRadius borderRadius = BorderRadius.circular(24.0);

    // --- Adicionado: Lógica para ajustar _selectedIndex se ele ficar inválido ---
    // Isso pode acontecer se o usuário era admin, selecionou a tela admin (index 4),
    // e então sua role mudou (ou ele deslogou/relogou como não-admin)
    // fazendo com que currentOptions tenha apenas 4 itens.
    int correctedIndex = _selectedIndex;
    if (_selectedIndex >= currentOptions.length) {
       print("Index corrigido: $_selectedIndex -> 0 (porque options.length é ${currentOptions.length})");
       correctedIndex = 0; // Volta para a primeira tela segura
       // Poderia chamar setState aqui, mas é mais seguro usar correctedIndex direto no IndexedStack
       // e deixar a próxima interação do usuário ou rebuild ajustar _selectedIndex via _onDestinationSelected.
       // WidgetsBinding.instance.addPostFrameCallback((_) {
       //   if(mounted) setState(() => _selectedIndex = 0);
       // });
    }
    // --- FIM ADIÇÃO ---


    return Scaffold(
      appBar: AppBar(
        // ... (AppBar sem alterações) ...
         flexibleSpace: Container( decoration: BoxDecoration( gradient: LinearGradient( colors: [ AppTheme.kPrimaryColor.withOpacity(0.5), AppTheme.kSecondaryColor.withOpacity(0.3), ], begin: Alignment.topCenter, end: Alignment.bottomCenter, ), ), ),
         title: Padding( padding: const EdgeInsets.only(top: 4.0), child: Image.asset( 'assets/images/seu_logo.png', height: 30, errorBuilder: (context, error, stackTrace) { print("Erro ao carregar logo: $error"); return Text("LOGO", style: theme.textTheme.titleLarge?.copyWith(color: appBarTextColor)); }, ), ),
         automaticallyImplyLeading: false,
         toolbarHeight: 65.0,
         actions: <Widget>[ IconButton( icon: const Icon(Icons.search), tooltip: 'Buscar Chamado', onPressed: () { /* TODO */ }, ), const SizedBox(width: 8), if (user != null) Padding( padding: const EdgeInsets.only(right: 16.0), child: Row( children: [ if (user.email != null) Padding( padding: const EdgeInsets.only(right: 8.0), child: Text( user.email!, style: theme.textTheme.bodyMedium?.copyWith(color: appBarTextColor), overflow: TextOverflow.ellipsis,), ), CircleAvatar( radius: 16, backgroundColor: theme.colorScheme.primary.withOpacity(0.2), backgroundImage: _getValidNetworkImage(user.photoURL), child: _getValidNetworkImage(user.photoURL) == null ? Icon( Icons.person_outline, size: 18, color: theme.colorScheme.primary,) : null, ), ], ), ), if (user == null) const SizedBox(width: 16) ],
      ),

      body: GradientBackgroundContainer(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // SideMenu (sem alterações na chamada)
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 20.0, 0.0, 20.0),
              child: SideMenu(
                selectedIndex: _selectedIndex, // Continua usando o estado
                onDestinationSelected: _onDestinationSelected,
                onLogout: () => _fazerLogout(context),
              ),
            ),

            // Conteúdo Principal
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8.0, 20.0, 16.0, 20.0),
                child: ClipRRect(
                  borderRadius: borderRadius,
                  child: AnimatedSwitcher( // <<< OPCIONAL: Adiciona animação suave na troca de tela
                     duration: const Duration(milliseconds: 250),
                     transitionBuilder: (Widget child, Animation<double> animation) {
                        return FadeTransition(opacity: animation, child: child);
                        // Ou use SlideTransition, etc.
                     },
                     // --- MODIFICADO: Usa a lista dinâmica e o índice corrigido ---
                     child: IndexedStack(
                       key: ValueKey<int>(correctedIndex), // Chave ajuda o AnimatedSwitcher
                       index: correctedIndex, // Usa o índice corrigido
                       children: currentOptions, // Usa a lista dinâmica
                     ),
                    // --- FIM MODIFICAÇÃO ---
                  )
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
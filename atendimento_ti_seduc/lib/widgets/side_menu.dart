import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Importar para pegar usuário logado
import 'package:cloud_firestore/cloud_firestore.dart'; // Importar para buscar a role
import '../config/theme/app_theme.dart'; // Importa para usar cores e constantes do tema

// --- Tornando StatefulWidget ---
class SideMenu extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onLogout;

  const SideMenu({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onLogout,
  });

  @override
  State<SideMenu> createState() => _SideMenuState();
}

class _SideMenuState extends State<SideMenu> {
  // --- Estado para controlar visibilidade do item Admin ---
  bool _isAdmin = false; // Flag para indicar se o usuário é admin
  bool _isLoadingRole = true; // Flag para indicar que a role está sendo verificada

  @override
  void initState() {
    super.initState();
    _checkUserRole(); // Chama a verificação ao iniciar o widget
  }

  // --- Função para verificar a role do usuário logado ---
  Future<void> _checkUserRole() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    bool isAdminResult = false; // Resultado padrão

    if (currentUser != null) {
      try {
        final DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data() as Map<String, dynamic>;
          // Verifica se o campo role_temp existe e é 'admin'
          if (userData.containsKey('role_temp') && userData['role_temp'] == 'admin') {
            isAdminResult = true;
          }
        } else {
           print("SideMenu: Documento do usuário ${currentUser.uid} não encontrado.");
        }
      } catch (e) {
        print("SideMenu: Erro ao buscar role do usuário: $e");
        // Mantém isAdminResult como false em caso de erro
      }
    } else {
       print("SideMenu: Nenhum usuário logado para verificar a role.");
    }

    // Atualiza o estado após a verificação (ou falha)
    if (mounted) { // Verifica se o widget ainda está montado
      setState(() {
        _isAdmin = isAdminResult;
        _isLoadingRole = false; // Marca a verificação como concluída
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Obtém dados do tema (sem alterações)
    final ThemeData theme = Theme.of(context);
    // final ColorScheme colorScheme = theme.colorScheme; // Não usado diretamente
    // final Color? unselectedItemColor = theme.iconTheme.color?.withOpacity(0.8); // Não usado diretamente
    // final TextStyle? unselectedLabelStyle = theme.textTheme.bodyMedium?.copyWith(color: unselectedItemColor); // Não usado diretamente

    // --- Construção dinâmica dos destinos ---
    final List<NavigationRailDestination> destinations = [
      // Destinos Padrão (sempre visíveis)
      const NavigationRailDestination(
        icon: Tooltip(message: 'Chamados', child: Icon(Icons.list_alt_outlined)),
        selectedIcon: Tooltip(message: 'Chamados', child: Icon(Icons.list_alt)),
        label: Text('Chamados'),
      ),
      const NavigationRailDestination(
        icon: Tooltip(message: 'Novo Chamado', child: Icon(Icons.add_circle_outline)),
        selectedIcon: Tooltip(message: 'Novo Chamado', child: Icon(Icons.add_circle)),
        label: Text('Novo'),
      ),
      const NavigationRailDestination(
        icon: Tooltip(message: 'Agenda', child: Icon(Icons.calendar_month_outlined)),
        selectedIcon: Tooltip(message: 'Agenda', child: Icon(Icons.calendar_month)),
        label: Text('Agenda'),
      ),
      const NavigationRailDestination(
        icon: Tooltip(message: 'Meu Perfil', child: Icon(Icons.person_outline)),
        selectedIcon: Tooltip(message: 'Meu Perfil', child: Icon(Icons.person)),
        label: Text('Perfil'),
      ),
      // --- Destino Admin (condicional) ---
      // Adiciona apenas se não estiver carregando e o usuário for admin
      if (!_isLoadingRole && _isAdmin)
        const NavigationRailDestination(
          icon: Tooltip(message: 'Gerenciar Usuários', child: Icon(Icons.manage_accounts_outlined)),
          selectedIcon: Tooltip(message: 'Gerenciar Usuários', child: Icon(Icons.manage_accounts)),
          label: Text('Admin'), // Label curto para o menu
        ),
    ];
    // ---------------------------------------

    // Padding externo para efeito flutuante (mantido)
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 20.0, 0.0, 20.0), // Ajuste se necessário
      child: ClipRRect( // ClipRRect para aplicar o arredondamento
        borderRadius: BorderRadius.circular(24.0), // Arredondamento
        child: Container( // Container para o fundo com gradiente
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.kPrimaryColor.withOpacity(0.5),
                AppTheme.kSecondaryColor.withOpacity(0.3),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: NavigationRail(
            // Usa o índice passado pelo widget pai
            selectedIndex: widget.selectedIndex,
            // Chama o callback do widget pai com o índice selecionado
            // IMPORTANTE: O widget pai agora precisa saber interpretar o índice
            //             considerando se o item Admin está presente ou não.
            onDestinationSelected: widget.onDestinationSelected,

            // Fundo transparente para ver o gradiente
            backgroundColor: Colors.transparent,

            // Configurações de aparência (mantidas)
            labelType: NavigationRailLabelType.none,
            useIndicator: false, // Sem indicador de fundo na seleção
            minWidth: 64, // Largura mínima

            // Estilos dos Ícones/Labels (mantidos)
            selectedIconTheme: IconThemeData(color: AppTheme.kTextColor, size: 26),
            unselectedIconTheme: IconThemeData(color: AppTheme.kSecondaryTextColor, size: 24),
            selectedLabelTextStyle: theme.textTheme.bodyMedium?.copyWith( fontWeight: FontWeight.bold, color: AppTheme.kTextColor,),
            unselectedLabelTextStyle: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.kSecondaryTextColor), // Ajustado para usar cor secundária direto

            // Passa a lista de destinos (possivelmente com o item Admin)
            destinations: destinations,

            // Botão de Logout (mantido)
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: Tooltip(
                    message: 'Logout',
                    child: IconButton(
                      icon: Icon(Icons.logout, color: AppTheme.kErrorColor.withOpacity(0.8)),
                      onPressed: widget.onLogout, // Usa o callback do pai
                    ),
                  ),
                ),
              ),
            ), // Fim do Trailing (Logout)
          ), // Fim do NavigationRail
        ), // Fim do Container do Gradiente
      ), // Fim do ClipRRect
    ); // Fim do Padding externo
  }
}
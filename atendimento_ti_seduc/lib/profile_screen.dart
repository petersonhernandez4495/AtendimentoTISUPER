// lib/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart'; // Para a navegação do Logout

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _currentUser;
  Map<String, dynamic>? _userData; // Para guardar dados do Firestore
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Chama a função para carregar os dados quando a tela inicia
    _loadUserData();
  }

  // Função para buscar os dados do usuário logado (Auth e Firestore)
  Future<void> _loadUserData() async {
    // Garante que está no estado inicial antes de carregar
    if (!mounted) return; // Verifica se o widget ainda está na árvore
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    _currentUser = FirebaseAuth.instance.currentUser;

    if (_currentUser == null) {
      print("Erro: Usuário nulo na tela de perfil.");
       if (mounted) {
         setState(() {
           _isLoading = false;
           _errorMessage = "Usuário não autenticado. Faça login novamente.";
         });
         // Opcional: Forçar logout se chegar aqui inesperadamente
         // await _fazerLogout(context);
       }
      return;
    }

    try {
      // Busca o documento do usuário na coleção 'users' usando o UID do Auth
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .get();

      if (userDoc.exists) {
        _userData = userDoc.data() as Map<String, dynamic>?;
        print("Dados do Firestore carregados para ${_currentUser!.uid}: $_userData");
      } else {
         print("Documento de perfil não encontrado no Firestore para UID: ${_currentUser!.uid}");
         _userData = {}; // Define como vazio para evitar erros de null
         // Poderia mostrar uma mensagem indicando perfil incompleto
      }
       if (mounted) {
          setState(() { _isLoading = false; });
       }

    } catch (e) {
      print("Erro ao carregar dados do Firestore: $e");
      if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = "Erro ao carregar dados do perfil do Firestore.";
            _userData = {}; // Define como vazio em caso de erro
          });
      }
    }
  }

  // Função de Logout (com confirmação)
  Future<void> _fazerLogout(BuildContext context) async {
     bool confirmar = await showDialog<bool>( context: context, builder: (BuildContext context) { return AlertDialog( title: const Text('Confirmar Logout'), content: const Text('Tem certeza que deseja sair?'), actions: <Widget>[ TextButton( onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar'), ), TextButton( onPressed: () => Navigator.of(context).pop(true), child: const Text('Sair', style: TextStyle(color: Colors.red)), ), ], ); }, ) ?? false;
     if (!confirmar || !mounted) return;
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushAndRemoveUntil( MaterialPageRoute(builder: (context) => const LoginScreen()), (Route<dynamic> route) => false, );
    } catch (e) { print("Erro ao fazer logout: $e"); if(mounted) ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Erro ao fazer logout: ${e.toString()}')),); }
  }

  @override
  Widget build(BuildContext context) {
    // Nota: Esta tela NÃO tem Scaffold/AppBar próprios, pois será exibida
    // dentro da MainNavigationScreen que já tem o Scaffold principal.
    // Se precisar de um AppBar específico para o Perfil, adicione um Scaffold aqui.
    return _buildBody();
  }

  // Constrói o corpo da tela baseado no estado (loading, erro, dados)
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center( child: Padding( padding: const EdgeInsets.all(16.0), child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [ Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center), const SizedBox(height: 10), ElevatedButton(onPressed: _loadUserData, child: const Text('Tentar Novamente')) ] ), ));
    }

    // Se chegou aqui, temos _currentUser (verificado em _loadUserData)
    // Extrai os dados com segurança, usando fallbacks
    // Prioriza dados do Auth para nome/email, se disponíveis e atualizados
    final String displayName = _currentUser!.displayName?.isNotEmpty ?? false
        ? _currentUser!.displayName!
        : (_userData?['name'] as String? ?? 'Nome não definido');
    final String email = _currentUser!.email?.isNotEmpty ?? false
        ? _currentUser!.email!
        : (_userData?['email'] as String? ?? 'Email não disponível');
    // Pega dados extras do Firestore (do mapa _userData)
    final String phone = _userData?['phone'] as String? ?? 'Não informado';
    final String jobTitle = _userData?['jobTitle'] as String? ?? 'Não informado';
    final String institution = _userData?['institution'] as String? ?? 'Não informada';
    final String photoURL = _currentUser!.photoURL ?? ''; // Exemplo se usar foto

    return RefreshIndicator( // Permite puxar para atualizar
        onRefresh: _loadUserData,
        child: ListView( // Permite rolagem
          padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 20.0),
          children: [
            // --- Seção de Avatar e Nome/Email ---
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundImage: photoURL.isNotEmpty ? NetworkImage(photoURL) : null,
                backgroundColor: Colors.grey[300],
                child: photoURL.isEmpty ? const Icon(Icons.person, size: 60, color: Colors.white70) : null,
              ),
            ),
            const SizedBox(height: 15),
            Center(child: Text(displayName, style: Theme.of(context).textTheme.headlineSmall)),
            Center(child: Text(email, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]))),
            const SizedBox(height: 30),

            // --- Seção de Informações Adicionais ---
            _buildProfileInfoTile(context,'Telefone', phone, Icons.phone_outlined),
            _buildProfileInfoTile(context,'Cargo/Função', jobTitle, Icons.work_outline),
            _buildProfileInfoTile(context,'Instituição/Lotação', institution, Icons.account_balance_outlined),

            const SizedBox(height: 30),
            // TODO: Adicionar botões "Editar Perfil", "Alterar Senha" aqui

            const Divider(height: 20),

            // --- Botão de Logout ---
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Logout'),
                onPressed: () => _fazerLogout(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent[100], // Cor mais suave
                  foregroundColor: Colors.red[900],
                  elevation: 0, // Sem sombra
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10)
                ),
              ),
            ),
             const SizedBox(height: 20), // Espaço no final
          ],
        ),
    );
  }

  // Widget auxiliar para exibir informações do perfil
  Widget _buildProfileInfoTile(BuildContext context, String label, String value, IconData icon) {
     return Padding(
       padding: const EdgeInsets.symmetric(vertical: 8.0),
       child: Row(
         children: [
           Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
           const SizedBox(width: 16),
           Expanded(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                 const SizedBox(height: 2),
                 SelectableText(value, style: Theme.of(context).textTheme.bodyLarge), // Permite copiar
               ],
             ),
           ),
           // Opcional: Ícone de editar ao lado de cada campo
           // IconButton(icon: Icon(Icons.edit_outlined, size: 16), onPressed: () { /* Abrir edição para este campo */ })
         ],
       ),
     );
   }
}
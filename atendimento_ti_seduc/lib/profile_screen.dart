import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart'; // Para a navegação do Logout
import 'edit_profile_screen.dart'; // Para navegar para a tela de edição

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
       }
      return;
    }

    // Recarrega o usuário do Firebase Auth para pegar dados atualizados (como displayName)
    // Faça isso ANTES de buscar no Firestore se você atualizou o Auth na tela de edição
    try {
      await _currentUser!.reload();
      _currentUser = FirebaseAuth.instance.currentUser; // Pega a instância atualizada
    } catch (e) {
      print("Erro ao recarregar usuário do Auth: $e");
      // Lidar com o erro, talvez mostrar mensagem ou proceder com dados antigos
      // Poderia ocorrer se o token expirou ou houve problema de rede
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
    bool confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Logout'),
          content: const Text('Tem certeza que deseja sair?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sair', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    ) ?? false; // Garante que retorna false se o diálogo for dispensado

    if (!confirmar || !mounted) return;

    try {
      await FirebaseAuth.instance.signOut();
      // Garante que a navegação ocorra apenas se o widget ainda estiver montado
      if (mounted) {
         Navigator.of(context).pushAndRemoveUntil(
           MaterialPageRoute(builder: (context) => const LoginScreen()),
               (Route<dynamic> route) => false,
         );
      }
    } catch (e) {
      print("Erro ao fazer logout: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao fazer logout: ${e.toString()}')),
        );
      }
    }
  }

  // Função para enviar Email de Redefinição de Senha
  Future<void> _enviarEmailRedefinicaoSenha() async {
    // Verifica se o usuário e o email são válidos
    if (_currentUser == null || _currentUser!.email == null || _currentUser!.email!.isEmpty) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Não foi possível encontrar o email do usuário para redefinir a senha.')),
         );
       }
       return;
     }

     final String email = _currentUser!.email!;

     // Confirmação com o usuário
     bool confirmar = await showDialog<bool>(
       context: context,
       builder: (BuildContext context) {
         return AlertDialog(
           title: const Text('Redefinir Senha'),
           content: Text('Um email será enviado para $email com instruções para redefinir sua senha. Deseja continuar?'),
           actions: <Widget>[
             TextButton(
               onPressed: () => Navigator.of(context).pop(false),
               child: const Text('Cancelar'),
             ),
             TextButton(
               onPressed: () => Navigator.of(context).pop(true),
               child: const Text('Enviar Email'),
             ),
           ],
         );
       },
     ) ?? false;

     if (!confirmar || !mounted) return;

     try {
       await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Email de redefinição enviado para $email. Verifique sua caixa de entrada (e spam).')),
         );
       }
     } on FirebaseAuthException catch (e) {
       print("Erro ao enviar email de redefinição: ${e.code} - ${e.message}");
       String errorMessage = 'Ocorreu um erro ao enviar o email.';
       if (e.code == 'user-not-found') {
         errorMessage = 'Nenhum usuário encontrado com este email.';
       }
       // Adicione outros tratamentos de erro específicos do Firebase Auth se necessário
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(errorMessage)),
         );
       }
     } catch (e) {
       print("Erro inesperado ao enviar email de redefinição: $e");
        if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Ocorreu um erro inesperado.')),
         );
        }
     }
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

    // Se chegou aqui, temos _currentUser (verificado e recarregado em _loadUserData)
    // Extrai os dados com segurança, usando fallbacks
    // Prioriza dados do Auth para nome/email, pois eles foram recarregados
    final String displayName = _currentUser!.displayName?.isNotEmpty ?? false
        ? _currentUser!.displayName!
        : (_userData?['name'] as String? ?? 'Nome não definido'); // Fallback para Firestore se Auth estiver vazio
    final String email = _currentUser!.email?.isNotEmpty ?? false
        ? _currentUser!.email!
        : (_userData?['email'] as String? ?? 'Email não disponível'); // Fallback para Firestore
    // Pega dados extras do Firestore (do mapa _userData)
    final String phone = _userData?['phone'] as String? ?? 'Não informado';
    final String jobTitle = _userData?['jobTitle'] as String? ?? 'Não informado';
    final String institution = _userData?['institution'] as String? ?? 'Não informada';
    final String photoURL = _currentUser!.photoURL ?? ''; // Exemplo se usar foto

    return RefreshIndicator( // Permite puxar para atualizar
      onRefresh: _loadUserData, // Chama a função de carregar dados
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

          // --- Botões de Ação ---
           Wrap( // Usa Wrap para caso os botões não caibam lado a lado em telas menores
              spacing: 10.0, // Espaço horizontal entre os botões
              runSpacing: 10.0, // Espaço vertical se quebrar linha
              alignment: WrapAlignment.center,
              children: [
                 // --- BOTÃO EDITAR PERFIL ---
                 OutlinedButton.icon(
                   icon: const Icon(Icons.edit_outlined, size: 18),
                   label: const Text('Editar Perfil'),
                   onPressed: () async { // Torna o onPressed async
                     // Navega para a tela de edição
                     final result = await Navigator.push<bool>( // Espera um resultado booleano
                       context,
                       MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                     );

                     // Se a tela de edição retornou 'true' (indicando sucesso ao salvar),
                     // recarrega os dados do perfil na tela atual.
                     if (result == true && mounted) {
                       print("Retornou da edição com sucesso, recarregando dados do perfil...");
                       // Chama _loadUserData para buscar dados atualizados (incluindo reload do Auth)
                       _loadUserData();
                     }
                   },
                   style: OutlinedButton.styleFrom(
                       side: BorderSide(color: Theme.of(context).colorScheme.primary),
                       foregroundColor: Theme.of(context).colorScheme.primary
                   ),
                 ),
                 // --- FIM BOTÃO EDITAR PERFIL ---

                 // --- BOTÃO REDEFINIR SENHA ---
                 OutlinedButton.icon(
                   icon: const Icon(Icons.lock_reset_outlined, size: 18),
                   label: const Text('Redefinir Senha'),
                   onPressed: _enviarEmailRedefinicaoSenha, // Chama a função de redefinição
                   style: OutlinedButton.styleFrom(
                       side: BorderSide(color: Colors.orange.shade800),
                       foregroundColor: Colors.orange.shade800
                   ),
                 ),
                 // --- FIM BOTÃO REDEFINIR SENHA ---
              ],
            ),

          const Divider(height: 40, thickness: 1, indent: 20, endIndent: 20), // Divisor mais visível

          // --- Botão de Logout ---
          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Logout'),
              onPressed: () => _fazerLogout(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent[100]?.withOpacity(0.8),
                foregroundColor: Colors.red[900],
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12), // Aumenta um pouco o padding
                shape: RoundedRectangleBorder( // Bordas arredondadas
                  borderRadius: BorderRadius.circular(8),
                ),
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
                // Usa SelectableText se o valor for curto, senão Text normal para evitar overflow estranho
                value.length < 100
                  ? SelectableText(value, style: Theme.of(context).textTheme.bodyLarge)
                  : Text(value, style: Theme.of(context).textTheme.bodyLarge),
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
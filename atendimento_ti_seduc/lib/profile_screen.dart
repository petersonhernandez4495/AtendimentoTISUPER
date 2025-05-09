import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart'; // Para a navegação do Logout
import 'edit_profile_screen.dart'; // Para navegar para a tela de edição
import 'services/chamado_service.dart'; // <<< ADICIONADO IMPORT PARA CONSTANTES

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
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;
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

    try {
      await _currentUser!.reload();
      _currentUser = FirebaseAuth.instance.currentUser;
    } catch (e) {
      print("Erro ao recarregar usuário do Auth: $e");
    }

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection(kCollectionUsers) // Usa constante
          .doc(_currentUser!.uid)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        // Verifica se data não é nulo
        _userData = userDoc.data() as Map<String, dynamic>?; // Faz cast seguro
        print(
            "Dados do Firestore carregados para ${_currentUser!.uid}: $_userData");
      } else {
        print(
            "Documento de perfil não encontrado no Firestore para UID: ${_currentUser!.uid}");
        _userData = {};
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Erro ao carregar dados do Firestore: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Erro ao carregar dados do perfil do Firestore.";
          _userData = {};
        });
      }
    }
  }

  Future<void> _fazerLogout(BuildContext context) async {
    // ... (Lógica de logout sem alterações) ...
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
                  child:
                      const Text('Sair', style: TextStyle(color: Colors.red)),
                ),
              ],
            );
          },
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
      print("Erro ao fazer logout: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao fazer logout: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _enviarEmailRedefinicaoSenha() async {
    // ... (Lógica de redefinição de senha sem alterações) ...
    if (_currentUser == null ||
        _currentUser!.email == null ||
        _currentUser!.email!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Não foi possível encontrar o email do usuário para redefinir a senha.')),
        );
      }
      return;
    }
    final String email = _currentUser!.email!;
    bool confirmar = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Redefinir Senha'),
              content: Text(
                  'Um email será enviado para $email com instruções para redefinir sua senha. Deseja continuar?'),
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
        ) ??
        false;

    if (!confirmar || !mounted) return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Email de redefinição enviado para $email. Verifique sua caixa de entrada (e spam).')),
        );
      }
    } on FirebaseAuthException catch (e) {
      print("Erro ao enviar email de redefinição: ${e.code} - ${e.message}");
      String errorMessage = 'Ocorreu um erro ao enviar o email.';
      if (e.code == 'user-not-found') {
        errorMessage = 'Nenhum usuário encontrado com este email.';
      }
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
    return _buildBody();
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
          child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(_errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center),
          const SizedBox(height: 10),
          ElevatedButton(
              onPressed: _loadUserData, child: const Text('Tentar Novamente'))
        ]),
      ));
    }

    // Extrai os dados com segurança, usando fallbacks e constantes
    final String displayName = _currentUser?.displayName?.isNotEmpty ?? false
        ? _currentUser!.displayName!
        : (_userData?[kFieldName] as String? ?? 'Nome não definido');
    final String email = _currentUser?.email?.isNotEmpty ?? false
        ? _currentUser!.email!
        : (_userData?[kFieldEmail] as String? ?? 'Email não disponível');
    final String phone = _userData?[kFieldPhone] as String? ?? 'Não informado';
    final String photoURL = _currentUser?.photoURL ?? '';

    // <<<--- Lê os campos condicionais --- >>>
    final String? tipoSolicitante =
        _userData?[kFieldUserTipoSolicitante] as String?;
    final String? jobTitle =
        _userData?[kFieldJobTitle] as String?; // Para Escola
    final String? cidade = _userData?[kFieldCidade] as String?; // Para Escola
    final String? institution =
        _userData?[kFieldUserInstituicao] as String?; // Para Escola
    final String? setor =
        _userData?[kFieldUserSetor] as String?; // Para Superintendência

    return RefreshIndicator(
      onRefresh: _loadUserData,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 20.0),
        children: [
          // --- Seção de Avatar e Nome/Email ---
          Center(
            child: CircleAvatar(
              radius: 50,
              backgroundImage:
                  photoURL.isNotEmpty ? NetworkImage(photoURL) : null,
              backgroundColor: Colors.grey[300],
              child: photoURL.isEmpty
                  ? const Icon(Icons.person, size: 60, color: Colors.white70)
                  : null,
            ),
          ),
          const SizedBox(height: 15),
          Center(
              child: Text(displayName,
                  style: Theme.of(context).textTheme.headlineSmall)),
          Center(
              child: Text(email,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.grey[600]))),
          const SizedBox(height: 30),

          // --- Seção de Informações Adicionais (Condicional) ---
          _buildProfileInfoTile(
              context, 'Telefone', phone, Icons.phone_outlined),

          // Mostra Tipo de Lotação
          _buildProfileInfoTile(
              context,
              'Tipo de Lotação',
              tipoSolicitante ?? 'Não informado',
              Icons.business_center_outlined),

          // Mostra campos de Escola
          if (tipoSolicitante == 'ESCOLA') ...[
            _buildProfileInfoTile(context, 'Cargo/Função',
                jobTitle ?? 'Não informado', Icons.work_outline),
            _buildProfileInfoTile(
                context,
                'Cidade/Distrito',
                cidade ?? 'Não informada',
                Icons.location_city_outlined), // <<<--- CIDADE ADICIONADA AQUI
            _buildProfileInfoTile(context, 'Instituição/Lotação',
                institution ?? 'Não informada', Icons.account_balance_outlined),
          ],

          // Mostra campos de Superintendência
          if (tipoSolicitante == 'SUPERINTENDENCIA') ...[
            _buildProfileInfoTile(context, 'Setor do Servidor',
                setor ?? 'Não informado', Icons.groups_outlined),
          ],

          const SizedBox(height: 30),

          // --- Botões de Ação ---
          Wrap(
            spacing: 10.0,
            runSpacing: 10.0,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Editar Perfil'),
                onPressed: () async {
                  final result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const EditProfileScreen()),
                  );
                  if (result == true && mounted) {
                    print(
                        "Retornou da edição com sucesso, recarregando dados do perfil...");
                    _loadUserData();
                  }
                },
                style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: Theme.of(context).colorScheme.primary),
                    foregroundColor: Theme.of(context).colorScheme.primary),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.lock_reset_outlined, size: 18),
                label: const Text('Redefinir Senha'),
                onPressed: _enviarEmailRedefinicaoSenha,
                style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.orange.shade800),
                    foregroundColor: Colors.orange.shade800),
              ),
            ],
          ),

          const Divider(height: 40, thickness: 1, indent: 20, endIndent: 20),

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
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // Widget auxiliar para exibir informações do perfil
  Widget _buildProfileInfoTile(
      BuildContext context, String label, String value, IconData icon) {
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
                Text(label,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                const SizedBox(height: 2),
                value.length < 100
                    ? SelectableText(value,
                        style: Theme.of(context).textTheme.bodyLarge)
                    : Text(value, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

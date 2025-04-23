// lib/cadastro_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import necessário para Firestore

class CadastroScreen extends StatefulWidget {
  const CadastroScreen({super.key});

  @override
  State<CadastroScreen> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen> {
  final _formKey = GlobalKey<FormState>();
  // Controllers para todos os campos
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _jobTitleController = TextEditingController();
  final _institutionController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false; // Para indicador de carregamento

  @override
  void dispose() {
    // Limpar todos os controllers
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _jobTitleController.dispose();
    _institutionController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // --- Função Cadastrar Atualizada com Validação de Domínio ---
  Future<void> _cadastrar() async {
    // 1. Valida o formulário (se todos os campos preenchidos corretamente)
    if (_formKey.currentState!.validate()) {

      // --- ADICIONADA VERIFICAÇÃO DE DOMÍNIO ---
      final String email = _emailController.text.trim();
      const String dominioPermitido = '@seduc.ro.gov.br';

      if (!email.toLowerCase().endsWith(dominioPermitido)) {
        // Se o email NÃO termina com o domínio permitido:
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cadastro permitido apenas para emails $dominioPermitido'),
              backgroundColor: Colors.orange[800], // Cor de aviso
            ),
          );
        }
        return; // Interrompe o cadastro aqui
      }
      // -----------------------------------------

      // 2. Verifica se as senhas coincidem (já validado no form, mas boa prática)
      if (_passwordController.text != _confirmPasswordController.text) {
         if(mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('As senhas não coincidem!'), backgroundColor: Colors.orange),
            );
         }
        return;
      }

      // Ativa o indicador de carregamento
      setState(() { _isLoading = true; });

      try {
        // 3. Cria o usuário no Firebase Authentication
        UserCredential userCredential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email, // Usa a variável 'email' validada
          password: _passwordController.text.trim(),
        );

        // 4. Atualiza o displayName no Firebase Authentication
        final user = userCredential.user;
        if (user != null) {
          await user.updateDisplayName(_nameController.text.trim());
          print('Usuário criado e displayName atualizado para: ${_nameController.text.trim()}');

          // 5. SALVAR DADOS EXTRAS NO FIRESTORE na coleção 'users'
          final uid = user.uid;
          final profileData = {
            'uid': uid,
            'name': _nameController.text.trim(),
            'email': email, // Usa a variável 'email' validada
            'phone': _phoneController.text.trim(),
            'jobTitle': _jobTitleController.text.trim(),
            'institution': _institutionController.text.trim(),
            'createdAt': FieldValue.serverTimestamp(),
          };
          await FirebaseFirestore.instance.collection('users').doc(uid).set(profileData);
          print('Dados extras do usuário salvos no Firestore para UID: $uid');

        } else {
          print('Usuário criado no Auth, mas userCredential.user é nulo antes de salvar no Firestore.');
           throw Exception('Falha ao obter usuário após criação.');
        }

        // 6. Navega para login APÓS tudo dar certo
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Conta criada com sucesso! Faça login.')),
          );
        }

      } on FirebaseAuthException catch (e) {
        // Trata erros específicos do Firebase Auth
        String errorMessage = 'Ocorreu um erro ao criar a conta.';
        if (e.code == 'email-already-in-use') { errorMessage = 'Este email já está sendo usado.'; }
        else if (e.code == 'weak-password') { errorMessage = 'A senha deve ter pelo menos 6 caracteres.'; }
        else { errorMessage = e.message ?? errorMessage; }
        print('Erro FirebaseAuth: ${e.code} - ${e.message}');
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
           );
         }
      } catch (e) {
         // Trata outros erros (incluindo falha ao salvar no Firestore)
         print('Erro inesperado no cadastro: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Ocorreu um erro inesperado: ${e.toString()}'), backgroundColor: Colors.red),
            );
          }
      } finally {
        // Desativa o indicador de carregamento
         if (mounted) { setState(() { _isLoading = false; }); }
      }
    }
  } // Fim da função _cadastrar

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro de Nova Conta'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // --- Campo Nome ---
                TextFormField(
                  controller: _nameController,
                  enabled: !_isLoading, // Desabilita enquanto carrega
                  decoration: const InputDecoration( labelText: 'Nome Completo', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person), ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Por favor, digite seu nome.' : null,
                ),
                const SizedBox(height: 16.0),

                // --- Campo Email ---
                 TextFormField(
                   controller: _emailController,
                   enabled: !_isLoading,
                   keyboardType: TextInputType.emailAddress,
                   decoration: const InputDecoration( labelText: 'Email Institucional (@seduc.ro.gov.br)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email), ),
                   validator: (value) => (value == null || !value.contains('@') || !value.contains('.')) ? 'Email inválido.' : null,
                 ),
                const SizedBox(height: 16.0),

                 // --- CAMPO TELEFONE ---
                 TextFormField(
                  controller: _phoneController,
                  enabled: !_isLoading,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration( labelText: 'Telefone', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone), ),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Digite seu telefone.' : null, // Tornou-se obrigatório, ajuste se não for
                 ),
                const SizedBox(height: 16.0),
                // ----------------------

                // --- CAMPO CARGO/FUNÇÃO ---
                TextFormField(
                  controller: _jobTitleController,
                  enabled: !_isLoading,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration( labelText: 'Cargo / Função', border: OutlineInputBorder(), prefixIcon: Icon(Icons.work_outline), ),
                   validator: (value) => (value == null || value.trim().isEmpty) ? 'Digite seu cargo/função.' : null,
                ),
                const SizedBox(height: 16.0),
                // ------------------------

                 // --- CAMPO INSTITUIÇÃO/LOTAÇÃO ---
                 TextFormField(
                  controller: _institutionController,
                  enabled: !_isLoading,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration( labelText: 'Instituição / Lotação', border: OutlineInputBorder(), prefixIcon: Icon(Icons.account_balance_outlined), ),
                   validator: (value) => (value == null || value.trim().isEmpty) ? 'Digite sua instituição/lotação.' : null,
                ),
                const SizedBox(height: 16.0),
                // -----------------------------

                // --- Campo Senha ---
                TextFormField(
                  controller: _passwordController,
                  enabled: !_isLoading,
                  obscureText: true,
                  decoration: const InputDecoration( labelText: 'Senha (mínimo 6 caracteres)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock), ),
                  validator: (value) => (value == null || value.length < 6) ? 'Mínimo 6 caracteres.' : null,
                ),
                const SizedBox(height: 16.0),

                 // --- CAMPO CONFIRMAR SENHA ---
                 TextFormField(
                  controller: _confirmPasswordController,
                  enabled: !_isLoading,
                  obscureText: true,
                  decoration: const InputDecoration( labelText: 'Confirmar Senha', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock_outline), ),
                   validator: (value) {
                     if (value == null || value.isEmpty) { return 'Confirme sua senha.'; }
                     if (value != _passwordController.text) { return 'As senhas não coincidem.'; }
                     return null;
                   },
                ),
                const SizedBox(height: 24.0),
                // ---------------------------

                // --- Botão Cadastrar ---
                ElevatedButton(
                  onPressed: _isLoading ? null : _cadastrar,
                  style: ElevatedButton.styleFrom( padding: const EdgeInsets.symmetric(vertical: 16.0), textStyle: const TextStyle(fontSize: 16) ),
                  child: _isLoading
                      ? const SizedBox( width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white), )
                      : const Text('Cadastrar'),
                ),
                const SizedBox(height: 16.0),

                // --- Botão Voltar para Login ---
                TextButton(
                  onPressed: _isLoading ? null : () { Navigator.pop(context); },
                  child: const Text('Já tem uma conta? Faça login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
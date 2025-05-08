// lib/login_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Removido import não utilizado de cadastro_screen se a navegação for por nome
// import 'cadastro_screen.dart';

// --- IMPORT TELA PRINCIPAL ---
// Ajuste o caminho se necessário
// --- FIM IMPORT ---

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isSendingResetEmail = false; // Estado para o processo de reset

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- FUNÇÃO DE LOGIN (inalterada) ---
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) { return; }
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) {
         Navigator.pushReplacementNamed(context, '/main_nav'); // Ou use MaterialPageRoute
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Ocorreu um erro ao fazer login.';
       if (e.code == 'user-not-found' || e.code == 'invalid-email') { errorMessage = 'Usuário não encontrado ou email inválido.'; }
       else if (e.code == 'wrong-password' || e.code == 'invalid-credential') { errorMessage = 'Credenciais inválidas (email ou senha).'; }
       else if (e.code == 'too-many-requests') { errorMessage = 'Muitas tentativas de login. Tente novamente mais tarde.';}
       else if (e.code == 'network-request-failed') { errorMessage = 'Erro de rede. Verifique sua conexão.'; }
       else { print('Erro de login não tratado: ${e.code} - ${e.message}'); }
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text(errorMessage), backgroundColor: Colors.red), ); }
    } catch (e) {
      print("Erro inesperado no login: $e");
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Ocorreu um erro inesperado.'), backgroundColor: Colors.red), ); }
    } finally {
       if (mounted) { setState(() => _isLoading = false); }
    }
  }

  // --- FUNÇÃO DE RECUPERAÇÃO DE SENHA (Adaptada da ProfileScreen) ---
  Future<void> _enviarEmailRedefinicaoSenhaAdaptado() async {
    // Pega o email do CONTROLLER, não do currentUser
    final String email = _emailController.text.trim();

    // Validação básica do email antes de enviar
    if (email.isEmpty || !email.contains('@')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, digite um email válido no campo "Email" para redefinir a senha.'),
            backgroundColor: Colors.orange,
             duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // Confirmação com o usuário (opcional, mas boa prática)
    bool confirmar = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Não fechar clicando fora enquanto envia
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Redefinir Senha'),
          content: Text('Um email será enviado para $email com instruções para redefinir sua senha (se uma conta existir para este email). Deseja continuar?'),
          actions: <Widget>[
            TextButton(
              // Desabilita se já estiver enviando
              onPressed: _isSendingResetEmail ? null : () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              // Desabilita se já estiver enviando
              onPressed: _isSendingResetEmail ? null : () => Navigator.of(context).pop(true),
              child: const Text('Enviar Email'),
            ),
          ],
        );
      },
    ) ?? false; // Retorna false se dispensar

    if (!confirmar || !mounted) return;

    setState(() => _isSendingResetEmail = true); // Ativa loading do reset

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Email de redefinição enviado para $email. Verifique sua caixa de entrada (e spam).'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      print("Erro ao enviar email de redefinição (LoginScreen): ${e.code} - ${e.message}");
      String errorMessage = 'Ocorreu um erro ao enviar o email.';
      // NÃO informamos "user-not-found" por segurança.
      // A mensagem de sucesso já cobre isso ("se uma conta existir").
      if (e.code == 'invalid-email') {
        errorMessage = 'O formato do email digitado é inválido.';
      } else if (e.code == 'too-many-requests') {
         errorMessage = 'Muitas solicitações. Tente novamente mais tarde.';
      }
      // Mostra erro apenas para casos específicos ou o erro padrão
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      print("Erro inesperado ao enviar email de redefinição (LoginScreen): $e");
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ocorreu um erro inesperado ao redefinir a senha.')),
        );
       }
    } finally {
       if (mounted) {
          setState(() => _isSendingResetEmail = false); // Desativa loading do reset
       }
    }
  }
  // --- FIM FUNÇÃO RECUPERAÇÃO ---


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty || !value.contains('@')) {
                      return 'Por favor, digite um email válido.';
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                  enabled: !_isLoading && !_isSendingResetEmail, // Desabilita durante loads
                ),
                const SizedBox(height: 16.0),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Senha',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, digite sua senha.';
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.done,
                  onEditingComplete: _isLoading || _isSendingResetEmail ? null : _login,
                  enabled: !_isLoading && !_isSendingResetEmail, // Desabilita durante loads
                ),
                // --- BOTÃO ESQUECEU A SENHA ---
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      // Desabilita se algum loading estiver ativo
                      onPressed: _isLoading || _isSendingResetEmail
                        ? null
                        // <<< CHAMA A NOVA FUNÇÃO ADAPTADA >>>
                        : _enviarEmailRedefinicaoSenhaAdaptado,
                      child: Text(
                         _isSendingResetEmail ? 'Enviando email...' : 'Esqueceu a senha?',
                      ),
                    ),
                  ),
                ),
                // --- FIM BOTÃO ---
                const SizedBox(height: 16.0),
                ElevatedButton(
                  onPressed: _isLoading || _isSendingResetEmail ? null : _login,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _isLoading
                      ? const SizedBox( width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Entrar', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 16.0),
                TextButton(
                  onPressed: _isLoading || _isSendingResetEmail ? null : () {
                    Navigator.pushNamed(context, '/cadastro');
                  },
                  child: const Text('Não tem uma conta? Cadastre-se'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
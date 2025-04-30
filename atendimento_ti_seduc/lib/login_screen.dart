// lib/login_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'cadastro_screen.dart'; // Para o botão de cadastro

// --- IMPORT TELA PRINCIPAL ---
// !! IMPORTANTE !!
// Se você navega para a tela principal usando MaterialPageRoute (Opção 2 abaixo),
// importe o arquivo dela aqui. Substitua pelo caminho e nome corretos.
// Exemplo:
import '/main_navigation_screen.dart';
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // --- NAVEGAÇÃO CORRIGIDA ---
      // Após o login, navega para a TELA PRINCIPAL (que contém o Drawer/Menu)
      // em vez de ir direto para ListaChamadosScreen.
      if (mounted) {

        // <<< OPÇÃO 1: Rota Nomeada (Se configurada) >>>
        // Se sua tela principal (com Drawer) tem uma rota nomeada como '/main_nav'.
         Navigator.pushReplacementNamed(context, '/main_nav'); // <-- Use a rota correta aqui

        // <<< OPÇÃO 2: MaterialPageRoute (Alternativa) >>>
        // Se você navega diretamente para a classe da tela principal.
        // Comente a linha acima (Navigator.pushReplacementNamed) e descomente a abaixo.
        // Lembre-se de importar o arquivo da sua tela principal no topo deste arquivo!
        /*
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigationScreen()) // <-- Use o NOME DA CLASSE da sua tela principal
        );
        */
      }
      // --- FIM NAVEGAÇÃO CORRIGIDA ---

    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Ocorreu um erro ao fazer login.';
       if (e.code == 'user-not-found' || e.code == 'invalid-email') {
         errorMessage = 'Usuário não encontrado ou email inválido.';
       } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
         errorMessage = 'Credenciais inválidas (email ou senha).';
       } else if (e.code == 'too-many-requests') {
         errorMessage = 'Muitas tentativas de login. Tente novamente mais tarde.';
       } else if (e.code == 'network-request-failed') {
         errorMessage = 'Erro de rede. Verifique sua conexão.';
       } else {
         print('Erro de login não tratado: ${e.code} - ${e.message}');
       }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      print("Erro inesperado no login: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ocorreu um erro inesperado.'), backgroundColor: Colors.red),
        );
      }
    } finally {
       if (mounted) {
         setState(() => _isLoading = false);
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
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
                  onEditingComplete: _isLoading ? null : _login,
                ),
                const SizedBox(height: 24.0),
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Entrar', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 16.0),
                TextButton(
                  onPressed: _isLoading ? null : () {
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
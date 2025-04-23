// lib/cadastro_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Removidos imports duplicados e não utilizados

class CadastroScreen extends StatefulWidget {
  const CadastroScreen({super.key});

  @override
  State<CadastroScreen> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen> {
  final _formKey = GlobalKey<FormState>();
  // Adicionar controller para o nome
  final _nameController = TextEditingController(); // <--- NOVO CONTROLLER
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false; // Para mostrar indicador de carregamento

  @override
  void dispose() {
    // Limpar todos os controllers
    _nameController.dispose(); // <--- LIMPAR NOVO CONTROLLER
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _cadastrar() async {
    // Verifica se o formulário é válido
    if (_formKey.currentState!.validate()) {
      // Ativa o indicador de carregamento
      setState(() {
        _isLoading = true;
      });

      try {
        // 1. Cria o usuário com email e senha
        UserCredential userCredential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // 2. Atualiza o nome de exibição (displayName) do usuário recém-criado
        if (userCredential.user != null) {
          await userCredential.user!
              .updateDisplayName(_nameController.text.trim()); // <--- ATUALIZA NOME
          print(
              'Usuário criado e displayName atualizado para: ${_nameController.text.trim()}');
        } else {
          print('Usuário criado, mas userCredential.user é nulo.');
        }

        // 3. Navega para login APÓS tudo dar certo
        // Verifica se o widget ainda está montado antes de navegar/mostrar SnackBar
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Conta criada com sucesso! Faça login.')),
          );
        }

      } on FirebaseAuthException catch (e) {
        // Trata erros específicos do Firebase Auth
        String errorMessage = 'Ocorreu um erro ao criar a conta.';
        if (e.code == 'email-already-in-use') {
          errorMessage = 'Este email já está sendo usado.';
        } else if (e.code == 'weak-password') {
          errorMessage = 'A senha deve ter pelo menos 6 caracteres.';
        } else {
          // Para outros erros do Firebase Auth
          errorMessage = e.message ?? errorMessage; // Usa a mensagem do Firebase se disponível
        }
        print('Erro FirebaseAuth: ${e.code} - ${e.message}'); // Log do erro
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
           );
         }
      } catch (e) {
         // Trata outros erros inesperados
         print('Erro inesperado no cadastro: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Ocorreu um erro inesperado: $e'), backgroundColor: Colors.red),
            );
          }
      } finally {
        // Desativa o indicador de carregamento, ocorrendo erro ou não
         if (mounted) {
           setState(() {
             _isLoading = false;
           });
         }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro de Nova Conta'),
      ),
      body: Center( // Centraliza o conteúdo verticalmente
        child: SingleChildScrollView( // Permite rolagem em telas menores
          padding: const EdgeInsets.all(20.0), // Padding aumentado
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch, // Faz botões esticarem
              children: <Widget>[
                // --- Campo Nome ---
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome Completo',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person), // Ícone
                  ),
                  textCapitalization: TextCapitalization.words, // Primeira letra maiúscula
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) { // Verifica se está vazio após remover espaços
                      return 'Por favor, digite seu nome completo.';
                    }
                    return null;
                  },
                ),
                // ------------------
                const SizedBox(height: 16.0),
                // --- Campo Email ---
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email), // Ícone
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty || !value.contains('@') || !value.contains('.')) { // Validação um pouco melhor
                      return 'Por favor, digite um email válido.';
                    }
                    return null;
                  },
                ),
                // -------------------
                const SizedBox(height: 16.0),
                // --- Campo Senha ---
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Senha (mínimo 6 caracteres)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock), // Ícone
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty || value.length < 6) {
                      return 'A senha deve ter pelo menos 6 caracteres.';
                    }
                    return null;
                  },
                ),
                // -------------------
                const SizedBox(height: 24.0),
                // --- Botão Cadastrar ---
                ElevatedButton(
                  // Desabilita o botão enquanto carrega
                  onPressed: _isLoading ? null : _cadastrar,
                  style: ElevatedButton.styleFrom(
                     padding: const EdgeInsets.symmetric(vertical: 16.0), // Botão maior
                     textStyle: const TextStyle(fontSize: 16)
                  ),
                  child: _isLoading
                      ? const SizedBox( // Mostra indicador de progresso no botão
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                        )
                      : const Text('Cadastrar'),
                ),
                // ---------------------
                const SizedBox(height: 16.0),
                // --- Botão Voltar para Login ---
                TextButton(
                  onPressed: _isLoading ? null : () { // Desabilita enquanto carrega
                    Navigator.pop(context); // Volta para a tela anterior (Login)
                  },
                  child: const Text('Já tem uma conta? Faça login'),
                ),
                // --------------------------
              ],
            ),
          ),
        ),
      ),
    );
  }
}
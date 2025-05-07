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

  // --- REMOVIDO: Estado para o campo Role ---
  // String? _selectedRole;
  // final List<String> _roles = ['admin', 'requester'];
  // --- FIM DA REMOÇÃO ---

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

  // --- Função Cadastrar Atualizada ---
  Future<void> _cadastrar() async {
    // 1. Valida o formulário
    if (_formKey.currentState!.validate()) {
      final String email = _emailController.text.trim();
      // ATENÇÃO: Verifique se o domínio está correto para o seu caso.
      // Se for usar outro domínio ou permitir qualquer um, ajuste ou remova esta validação.
      const String dominioPermitido = '@seduc.ro.gov.br';

      // --- Validação de Domínio ---
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
      // --------------------------

      // 2. Verifica senhas (já validado no form, mas boa prática repetir aqui)
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
            // --- REMOVIDO: Salvar a Role selecionada ---
            // 'role_temp': _selectedRole,
            // --- FIM DA REMOÇÃO ---
            'createdAt': FieldValue.serverTimestamp(), // Data/Hora do cadastro
            // Poderia adicionar 'updatedAt': FieldValue.serverTimestamp() também
            // Por padrão, um novo usuário pode ter uma role 'requester' ou similar
            'role': 'requester', // Define uma role padrão
          };
          // Salva (ou sobrescreve se já existir por algum motivo) o documento com o UID do usuário
          await FirebaseFirestore.instance.collection('users').doc(uid).set(profileData);
          print('Dados extras do usuário (incluindo role padrão) salvos no Firestore para UID: $uid');

        } else {
          // Se user for nulo após a criação (muito improvável, mas defensivo)
          print('Usuário criado no Auth, mas userCredential.user é nulo antes de salvar no Firestore.');
            throw Exception('Falha ao obter usuário após criação.');
        }

        // 6. Navega para login APÓS tudo dar certo
        if (mounted) {
          // Usar pushReplacementNamed para remover a tela de cadastro da pilha
          Navigator.pushReplacementNamed(context, '/login');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Conta criada com sucesso! Faça login.'), backgroundColor: Colors.green),
          );
        }

      } on FirebaseAuthException catch (e) {
        // Trata erros específicos do Firebase Auth
        String errorMessage = 'Ocorreu um erro ao criar a conta.';
        if (e.code == 'email-already-in-use') { errorMessage = 'Este email já está sendo usado.'; }
        else if (e.code == 'weak-password') { errorMessage = 'A senha deve ter pelo menos 6 caracteres.'; }
        else if (e.code == 'invalid-email') { errorMessage = 'O formato do email é inválido.'; }
        // Adicione outros códigos de erro conforme necessário
        else { errorMessage = e.message ?? errorMessage; } // Usa a mensagem do Firebase se disponível
        print('Erro FirebaseAuth: ${e.code} - ${e.message}');
         if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
          );
         }
      } catch (e) {
         // Trata outros erros (incluindo falha ao salvar no Firestore ou Exception lançada)
         print('Erro inesperado no cadastro: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Ocorreu um erro inesperado: ${e.toString()}'), backgroundColor: Colors.red),
            );
          }
      } finally {
        // Desativa o indicador de carregamento, independentemente de sucesso ou erro
         if (mounted) { setState(() { _isLoading = false; }); }
      }
    } else {
      // Se o formulário não for válido (algum campo falhou na validação)
      print("Formulário inválido.");
      // O próprio TextFormField já mostrará a mensagem de erro definida no validator
    }
  } // Fim da função _cadastrar

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro de Nova Conta'),
        // backgroundColor: Colors.blueGrey[800], // Exemplo de cor
      ),
      // Definir uma cor de fundo pode melhorar a aparência
      // backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView( // Permite rolar se o conteúdo não couber
          padding: const EdgeInsets.all(20.0), // Espaçamento geral
          child: Form(
            key: _formKey, // Chave para gerenciar o estado do formulário
            // autovalidateMode: AutovalidateMode.onUserInteraction, // Valida enquanto o usuário digita (opcional)
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, // Centraliza verticalmente (no Center)
              crossAxisAlignment: CrossAxisAlignment.stretch, // Estica os widgets horizontalmente
              children: <Widget>[
                // --- Campo Nome ---
                TextFormField(
                  controller: _nameController,
                  enabled: !_isLoading, // Desabilita enquanto carrega
                  decoration: const InputDecoration(
                    labelText: 'Nome Completo *', // Indica campo obrigatório
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  textCapitalization: TextCapitalization.words, // Primeira letra de cada palavra maiúscula
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor, digite seu nome completo.';
                    }
                    return null; // Válido
                  },
                ),
                const SizedBox(height: 16.0), // Espaçamento padrão

                // --- Campo Email ---
                  TextFormField(
                    controller: _emailController,
                    enabled: !_isLoading,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email Institucional *', // O domínio é validado na função
                      hintText: 'exemplo${'@seduc.ro.gov.br'}', // Exibe o domínio esperado
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.email),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Por favor, digite seu email.';
                      }
                      // Validação básica de formato (contém @ e .)
                      if (!value.contains('@') || !value.contains('.')) {
                        return 'Formato de email inválido.';
                      }
                      // A validação específica do domínio é feita na função _cadastrar
                      return null; // Válido
                    },
                  ),
                const SizedBox(height: 16.0),

                  // --- CAMPO TELEFONE ---
                  TextFormField(
                  controller: _phoneController,
                  enabled: !_isLoading,
                  keyboardType: TextInputType.phone,
                  // TODO: Considerar usar um MaskTextInputFormatter para formatar (ex: (##) #####-####)
                  // inputFormatters: [_phoneMaskFormatter], // Se usar máscara
                  decoration: const InputDecoration(
                    labelText: 'Telefone *',
                    hintText: '(XX) XXXXX-XXXX', // Exemplo de formato
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Digite seu telefone para contato.';
                    }
                    // Poderia adicionar validação de formato/comprimento aqui se necessário
                    // Ex: if (!_phoneMaskFormatter.isFill()) return 'Telefone incompleto';
                    return null; // Válido
                  },
                  ),
                const SizedBox(height: 16.0),

                // --- CAMPO CARGO/FUNÇÃO ---
                TextFormField(
                  controller: _jobTitleController,
                  enabled: !_isLoading,
                  textCapitalization: TextCapitalization.sentences, // Primeira letra da sentença maiúscula
                  decoration: const InputDecoration(
                    labelText: 'Cargo / Função *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.work_outline),
                  ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Digite seu cargo ou função.';
                      }
                      return null; // Válido
                    },
                ),
                const SizedBox(height: 16.0),

                  // --- CAMPO INSTITUIÇÃO/LOTAÇÃO ---
                  TextFormField(
                  controller: _institutionController,
                  enabled: !_isLoading,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Instituição / Lotação *',
                    hintText: 'Ex: Escola XYZ, Superintendência ABC',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.account_balance_outlined),
                  ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Digite sua instituição ou local de lotação.';
                      }
                      return null; // Válido
                    },
                ),
                const SizedBox(height: 16.0),

                // --- REMOVIDO: Dropdown para Role ---
                // const SizedBox(height: 16.0),
                // --- FIM DA REMOÇÃO ---

                // --- Campo Senha ---
                TextFormField(
                  controller: _passwordController,
                  enabled: !_isLoading,
                  obscureText: true, // Esconde o texto digitado
                  decoration: const InputDecoration(
                    labelText: 'Senha *',
                    hintText: 'Mínimo 6 caracteres',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                    // TODO: Adicionar botão para mostrar/esconder senha (melhora UX)
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, digite uma senha.';
                    }
                    if (value.length < 6) {
                      return 'A senha deve ter no mínimo 6 caracteres.';
                    }
                    return null; // Válido
                  },
                ),
                const SizedBox(height: 16.0),

                  // --- CAMPO CONFIRMAR SENHA ---
                  TextFormField(
                  controller: _confirmPasswordController,
                  enabled: !_isLoading,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar Senha *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, confirme sua senha.';
                      }
                      // Compara com o valor atual do controller da senha
                      if (value != _passwordController.text) {
                        return 'As senhas não coincidem.';
                      }
                      return null; // Válido
                    },
                ),
                const SizedBox(height: 24.0), // Espaço maior antes do botão

                // --- Botão Cadastrar ---
                ElevatedButton(
                  // Desabilita o botão se estiver carregando (_isLoading == true)
                  onPressed: _isLoading ? null : _cadastrar,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16.0), // Botão mais alto
                    textStyle: const TextStyle(fontSize: 16) // Tamanho do texto
                    // backgroundColor: Colors.deepPurple, // Exemplo de cor primária
                    // foregroundColor: Colors.white, // Cor do texto/ícone no botão
                  ),
                  child: _isLoading
                      // Se estiver carregando, mostra um indicador de progresso
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                        )
                      // Se não, mostra o texto 'Cadastrar'
                      : const Text('Cadastrar'),
                ),
                const SizedBox(height: 16.0),

                // --- Botão Voltar para Login ---
                TextButton(
                  // Desabilita se estiver carregando
                  onPressed: _isLoading ? null : () {
                      // Volta para a tela anterior (presume-se que seja a de login)
                      Navigator.pop(context);
                  },
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

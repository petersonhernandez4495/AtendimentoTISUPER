import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CadastroScreen extends StatefulWidget {
  const CadastroScreen({super.key});

  @override
  State<CadastroScreen> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen> {
  final _formKey = GlobalKey<FormState>();
  // Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _jobTitleController = TextEditingController();
  // Controller de instituição não é mais necessário
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Estados para o Dropdown de Instituição
  List<String> _listaInstituicoes = [];
  String? _instituicaoSelecionada;
  bool _isLoadingInstituicoes = true;
  String? _erroCarregarInstituicoes;

  // Estado para o loading do cadastro geral
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _carregarInstituicoes(); // Carrega a lista ao iniciar
  }

  @override
  void dispose() {
    // Limpar controllers
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _jobTitleController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // --- FUNÇÃO CORRIGIDA PARA CARREGAR INSTITUIÇÕES ---
  Future<void> _carregarInstituicoes() async {
    if (!mounted) return;

    // --- Define as constantes ANTES do try para acesso no catch ---
    const String nomeColecao = 'configuracoes';
    const String nomeDocumento = 'localidades';
    const String nomeCampoMapa = 'escolasPorCidade';
    // -----------------------------------------------------------

    setState(() {
      _isLoadingInstituicoes = true;
      _erroCarregarInstituicoes = null;
    });

    try {
      // Usa as constantes definidas acima
      final docSnapshot = await FirebaseFirestore.instance
          .collection(nomeColecao)
          .doc(nomeDocumento)
          .get();

      List<String> todasInstituicoes = [];

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        if (data.containsKey(nomeCampoMapa) && data[nomeCampoMapa] is Map) {
           final Map<String, dynamic> escolasPorCidadeMap = Map<String, dynamic>.from(data[nomeCampoMapa]);

           for (final listaDeEscolas in escolasPorCidadeMap.values) {
              if (listaDeEscolas is List) {
                 todasInstituicoes.addAll(
                    listaDeEscolas
                       .map((escola) => escola?.toString())
                       .where((nome) => nome != null && nome.isNotEmpty)
                       .cast<String>()
                 );
              }
           }
           todasInstituicoes.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        } else {
           print("Campo '$nomeCampoMapa' não encontrado ou não é um Mapa no documento '$nomeDocumento'.");
           if(mounted) _erroCarregarInstituicoes = "Erro: Estrutura de dados de escolas inválida.";
        }
      } else {
        print("Documento '$nomeDocumento' não encontrado na coleção '$nomeColecao'.");
        if(mounted) _erroCarregarInstituicoes = "Erro: Configuração de localidades não encontrada.";
      }

      if (mounted) {
        setState(() {
          _listaInstituicoes = todasInstituicoes;
          _isLoadingInstituicoes = false;
          if (todasInstituicoes.isEmpty && _erroCarregarInstituicoes == null) {
             _erroCarregarInstituicoes = "Nenhuma instituição encontrada.";
          }
        });
      }
    } catch (e, s) {
      // Agora 'nomeColecao' e 'nomeDocumento' estão acessíveis aqui
      print("Erro ao carregar instituições de '$nomeColecao/$nomeDocumento': $e\nStackTrace: $s");
      if (mounted) {
        setState(() {
          _isLoadingInstituicoes = false;
          _erroCarregarInstituicoes = "Erro ao carregar instituições.";
        });
      }
    }
  }
  // --- FIM DA FUNÇÃO CORRIGIDA ---


  // --- Função Cadastrar (Atualizada para usar _instituicaoSelecionada) ---
  Future<void> _cadastrar() async {
    if (_formKey.currentState!.validate()) {
      final String email = _emailController.text.trim();
      const String dominioPermitido = '@seduc.ro.gov.br'; // Ajuste se necessário

      if (!email.toLowerCase().endsWith(dominioPermitido)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar( SnackBar( content: const Text('Cadastro permitido apenas para emails $dominioPermitido'), backgroundColor: Colors.orange[800]));
        }
        return;
      }

      setState(() { _isLoading = true; });

      try {
        UserCredential userCredential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: _passwordController.text,
        );

        final user = userCredential.user;
        if (user != null) {
          await user.updateDisplayName(_nameController.text.trim());

          final uid = user.uid;
          final profileData = {
            'uid': uid,
            'name': _nameController.text.trim(),
            'email': email,
            'phone': _phoneController.text.trim(),
            'jobTitle': _jobTitleController.text.trim(),
            'institution': _instituicaoSelecionada, // Usa o valor do dropdown
            'role': 'requester',
            'createdAt': FieldValue.serverTimestamp(),
          };

          await FirebaseFirestore.instance.collection('users').doc(uid).set(profileData);

          if (mounted) {
            Navigator.pushReplacementNamed(context, '/login');
            ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Conta criada com sucesso! Faça login.'), backgroundColor: Colors.green),);
          }
        } else { throw Exception('Falha ao obter usuário após criação.'); }

      } on FirebaseAuthException catch (e) {
        String errorMessage = 'Ocorreu um erro ao criar a conta.';
        if (e.code == 'email-already-in-use') { errorMessage = 'Este email já está sendo usado.'; }
        else if (e.code == 'weak-password') { errorMessage = 'A senha deve ter pelo menos 6 caracteres.'; }
        else if (e.code == 'invalid-email') { errorMessage = 'O formato do email é inválido.'; }
        else { errorMessage = e.message ?? errorMessage; }
        if (mounted) { ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text(errorMessage), backgroundColor: Colors.red)); }
      } catch (e) {
         if (mounted) { ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Ocorreu um erro inesperado: ${e.toString()}'), backgroundColor: Colors.red)); }
      } finally {
         if (mounted) { setState(() { _isLoading = false; }); }
      }
    } else {
      print("Formulário inválido.");
    }
  }

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
                  enabled: !_isLoading,
                  decoration: const InputDecoration(
                    labelText: 'Nome Completo *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) { return 'Por favor, digite seu nome completo.'; }
                    return null;
                  },
                ),
                const SizedBox(height: 16.0),

                // --- Campo Email ---
                  TextFormField(
                    controller: _emailController,
                    enabled: !_isLoading,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email Institucional *',
                      hintText: 'exemplo@seduc.ro.gov.br',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) { return 'Por favor, digite seu email.'; }
                      if (!value.contains('@') || !value.contains('.')) { return 'Formato de email inválido.'; }
                      return null;
                    },
                  ),
                const SizedBox(height: 16.0),

                // --- Campo Telefone ---
                 TextFormField(
                  controller: _phoneController,
                  enabled: !_isLoading,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefone *',
                    hintText: '(XX) XXXXX-XXXX',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) { return 'Digite seu telefone para contato.'; }
                    return null;
                  },
                 ),
                const SizedBox(height: 16.0),

                // --- Campo Cargo/Função ---
                TextFormField(
                  controller: _jobTitleController,
                  enabled: !_isLoading,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Cargo / Função *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.work_outline),
                  ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) { return 'Digite seu cargo ou função.'; }
                      return null;
                    },
                ),
                const SizedBox(height: 16.0),

                // --- Dropdown de Instituição ---
                DropdownButtonFormField<String>(
                  value: _instituicaoSelecionada,
                  isExpanded: true,
                  hint: _isLoadingInstituicoes
                      ? const Row(children: [SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 8), Text('Carregando...')])
                      : (_erroCarregarInstituicoes != null
                          ? Text(_erroCarregarInstituicoes!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 14))
                          : const Text('Selecione sua instituição *')),
                  decoration: InputDecoration(
                    labelText: 'Instituição / Lotação *',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.account_balance_outlined),
                    errorText: _erroCarregarInstituicoes != null && !_isLoadingInstituicoes && _listaInstituicoes.isEmpty
                               ? _erroCarregarInstituicoes // Mostra erro aqui se a lista não carregou
                               : null,
                  ),
                  items: _isLoadingInstituicoes || _erroCarregarInstituicoes != null
                      ? []
                      : _listaInstituicoes.map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                  onChanged: (_isLoading || _isLoadingInstituicoes || _erroCarregarInstituicoes != null)
                      ? null
                      : (String? newValue) {
                          setState(() { _instituicaoSelecionada = newValue; });
                        },
                  validator: (value) {
                    if (value == null) {
                      if (_isLoadingInstituicoes || _erroCarregarInstituicoes != null) return null; // Não valida se carregando/erro
                      return 'Por favor, selecione sua instituição.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16.0),

                // --- Campo Senha ---
                TextFormField(
                  controller: _passwordController,
                  enabled: !_isLoading,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Senha *',
                    hintText: 'Mínimo 6 caracteres',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) { return 'Por favor, digite uma senha.'; }
                    if (value.length < 6) { return 'A senha deve ter no mínimo 6 caracteres.'; }
                    return null;
                  },
                ),
                const SizedBox(height: 16.0),

                // --- Campo Confirmar Senha ---
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
                      if (value == null || value.isEmpty) { return 'Por favor, confirme sua senha.'; }
                      if (value != _passwordController.text) { return 'As senhas não coincidem.'; }
                      return null;
                    },
                 ),
                const SizedBox(height: 24.0),

                // --- Botão Cadastrar ---
                ElevatedButton(
                  onPressed: _isLoading ? null : _cadastrar,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    textStyle: const TextStyle(fontSize: 16)
                  ),
                  child: _isLoading
                      ? const SizedBox( width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
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
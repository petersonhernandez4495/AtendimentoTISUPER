import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

// Importe suas constantes de serviço
// Presumindo que kFieldCidadeSuperintendencia pode vir de chamado_service.dart ou um arquivo de constantes global.
// Se não, a constante local no final deste arquivo será usada.
// import '../services/chamado_service.dart';
import 'main_navigation_screen.dart';

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
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _instituicaoManualController = TextEditingController();

  // Estados para Dropdowns
  List<String> _listaTipos = [];
  String? _tipoSelecionado;
  List<String> _listaCidades = [];
  String? _cidadeSelecionada;
  List<String> _listaInstituicoes = [];
  List<String> _instituicoesDisponiveis = [];
  String? _instituicaoSelecionada;
  List<String> _listaCargos = []; // Apenas para tipo ESCOLA
  String? _cargoSelecionado;
  List<String> _listaSetores = []; // Para tipo SUPERINTENDENCIA
  String? _setorSelecionado;

  // --- NOVOS ESTADOS PARA CIDADE DA SUPERINTENDÊNCIA ---
  List<String> _listaCidadesSuperintendencia = [];
  String? _cidadeSuperintendenciaSelecionada;
  // --- FIM DOS NOVOS ESTADOS ---

  bool _isLoadingConfig = true;
  String? _erroCarregarConfig;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _carregarConfiguracoesDropdowns();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _instituicaoManualController.dispose();
    super.dispose();
  }

  Map<String, List<String>> _escolasPorCidadeMap = {};

  Future<void> _carregarConfiguracoesDropdowns() async {
    if (!mounted) return;
    setState(() {
      _isLoadingConfig = true;
      _erroCarregarConfig = null;
    });

    try {
      final db = FirebaseFirestore.instance;
      final results = await Future.wait([
        db.collection(kCollectionConfig).doc(kDocLocalidades).get(),
        db.collection(kCollectionConfig).doc(kDocOpcoes).get(),
      ]);

      final docLocalidades = results[0];
      final docOpcoes = results[1];

      // Processa Localidades/Cidades/Instituições e Cidades da Superintendência
      List<String> cidades = [];
      Map<String, List<String>> escolasMap = {};
      List<String> loadedCidadesSuper = []; // <<< NOVA LISTA TEMPORÁRIA
      String? erroLocalidades;

      if (docLocalidades.exists && docLocalidades.data() != null) {
        final data = docLocalidades.data()!;
        const String nomeCampoMapaEscolas = 'escolasPorCidade';
        if (data.containsKey(nomeCampoMapaEscolas) &&
            data[nomeCampoMapaEscolas] is Map) {
          final Map<String, dynamic> rawMap =
              Map<String, dynamic>.from(data[nomeCampoMapaEscolas]);
          rawMap.forEach((key, value) {
            if (key is String && value != null && value is List) {
              List<String> escolas = value
                  .map((escola) => escola?.toString())
                  .where((nome) => nome != null && nome.isNotEmpty)
                  .cast<String>()
                  .toList();
              escolas
                  .sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
              escolasMap[key] = escolas;
            }
          });
          cidades = escolasMap.keys.toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
          if (!escolasMap.containsKey("OUTRO")) {
            escolasMap["OUTRO"] = [];
            if (!cidades.contains("OUTRO")) {
              cidades.add("OUTRO");
              cidades
                  .sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
            }
          }
        } else {
          erroLocalidades =
              "Erro: Estrutura de dados de localidades (escolas) inválida.";
        }

        // --- CARREGAR CIDADES DA SUPERINTENDÊNCIA ---
        const String nomeCampoCidadesSuper = 'cidadesSuperintendecia';
        if (data.containsKey(nomeCampoCidadesSuper) &&
            data[nomeCampoCidadesSuper] is List) {
          loadedCidadesSuper = (data[nomeCampoCidadesSuper] as List)
              .map((cs) => cs?.toString())
              .where((nome) => nome != null && nome.isNotEmpty)
              .cast<String>()
              .toList();
          loadedCidadesSuper
              .sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        } else {
          erroLocalidades = (erroLocalidades ?? "") +
              "\nErro: Configuração de 'cidadesSuperintendecia' não encontrada ou inválida.";
        }
        if (loadedCidadesSuper.isEmpty && erroLocalidades == null) {
          // Apenas se não houver outro erro de localidades
          // Não definir erro aqui se a lista puder ser opcionalmente vazia
          print(
              "WARN: Lista 'cidadesSuperintendecia' está vazia ou não foi carregada.");
        }
        // --- FIM CARREGAR CIDADES DA SUPERINTENDÊNCIA ---
      } else {
        erroLocalidades = "Erro: Configuração de localidades não encontrada.";
      }
      if (cidades.isEmpty && erroLocalidades == null) {
        erroLocalidades = "Nenhuma cidade/instituição (escola) encontrada.";
      }

      // Processa Opcoes (Cargos, Tipos e Setores)
      List<String> cargos = [];
      List<String> tipos = [];
      List<String> setores = [];
      String? erroOpcoes;
      if (docOpcoes.exists && docOpcoes.data() != null) {
        final data = docOpcoes.data()!;
        const String nomeCampoCargos = 'cargosEscola';
        if (data.containsKey(nomeCampoCargos) &&
            data[nomeCampoCargos] is List) {
          cargos = (data[nomeCampoCargos] as List)
              .map((cargo) => cargo?.toString())
              .where((nome) => nome != null && nome.isNotEmpty)
              .cast<String>()
              .toList();
          cargos.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        } else {
          erroOpcoes = "Erro: Estrutura de dados de cargos inválida.";
        }

        const String nomeCampoTipos =
            'tipos'; // Supondo que 'tipos' é o campo para "ESCOLA", "SUPERINTENDENCIA"
        if (data.containsKey(nomeCampoTipos) && data[nomeCampoTipos] is List) {
          tipos = (data[nomeCampoTipos] as List)
              .map((tipo) => tipo?.toString())
              .where((nome) => nome != null && nome.isNotEmpty)
              .cast<String>()
              .toList();
        } else {
          erroOpcoes = (erroOpcoes ?? "") +
              "\nErro: Estrutura de dados de tipos de solicitante inválida.";
        }

        const String nomeCampoSetores = 'setoresSuper';
        if (data.containsKey(nomeCampoSetores) &&
            data[nomeCampoSetores] is List) {
          setores = (data[nomeCampoSetores] as List)
              .map((setor) => setor?.toString())
              .where((nome) => nome != null && nome.isNotEmpty)
              .cast<String>()
              .toList();
          setores.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        } else {
          erroOpcoes = (erroOpcoes ?? "") +
              "\nErro: Estrutura de dados de setores inválida.";
        }
      } else {
        erroOpcoes = "Erro: Configuração de opções não encontrada.";
      }

      if (cargos.isEmpty && tipos.contains('ESCOLA') && erroOpcoes == null) {
        // Cargos são para escola
        erroOpcoes = "Nenhum cargo encontrado para Escola.";
      }
      if (tipos.isEmpty && erroOpcoes == null) {
        erroOpcoes = "Nenhum tipo de solicitante encontrado.";
      }
      if (setores.isEmpty &&
          tipos.contains('SUPERINTENDENCIA') &&
          erroOpcoes == null) {
        // Setores são para SUPERINTENDENCIA
        erroOpcoes = "Nenhum setor encontrado para Superintendência.";
      }

      _erroCarregarConfig = (erroLocalidades != null || erroOpcoes != null)
          ? "${erroLocalidades ?? ''}${erroOpcoes ?? ''}".trim()
          : null;

      if (mounted) {
        setState(() {
          _listaCidades = cidades;
          _escolasPorCidadeMap = escolasMap;
          _listaInstituicoes = escolasMap.values
              .expand((list) => list)
              .toSet()
              .toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
          _instituicoesDisponiveis = [];
          _listaCargos = cargos;
          _listaTipos = tipos;
          _listaSetores = setores;
          _listaCidadesSuperintendencia =
              loadedCidadesSuper; // <<< ATRIBUI LISTA DE CIDADES SUPER
          _isLoadingConfig = false;
        });
      }
    } catch (e, s) {
      print("Erro ao carregar configurações de dropdowns: $e\nStackTrace: $s");
      if (mounted) {
        setState(() {
          _isLoadingConfig = false;
          _erroCarregarConfig =
              "Erro crítico ao carregar configurações: ${e.toString()}";
        });
      }
    }
  }

  void _atualizarInstituicoes(String? cidadeSelecionada) {
    setState(() {
      _cidadeSelecionada = cidadeSelecionada;
      _instituicaoSelecionada = null;
      _instituicaoManualController.clear();
      if (cidadeSelecionada != null &&
          cidadeSelecionada != "OUTRO" &&
          _escolasPorCidadeMap.containsKey(cidadeSelecionada)) {
        _instituicoesDisponiveis =
            List<String>.from(_escolasPorCidadeMap[cidadeSelecionada]!);
      } else {
        _instituicoesDisponiveis = [];
      }
    });
  }

  Future<void> _cadastrar() async {
    if (_formKey.currentState!.validate()) {
      final String email = _emailController.text.trim();
      const String dominioPermitido = '@seduc.ro.gov.br';

      if (!email.toLowerCase().endsWith(dominioPermitido)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('O email deve ser do domínio $dominioPermitido.'),
            backgroundColor: Colors.red,
          ));
        }
        return;
      }

      if (_tipoSelecionado == 'ESCOLA' &&
          _cargoSelecionado?.toUpperCase() == 'PROFESSOR') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text(
                'Apenas Gestores, Coordenadores do LIE e Secretários podem criar um Perfil de acesso para abertura de chamados escolares.'),
            backgroundColor: Colors.orange[800],
            duration: const Duration(seconds: 8),
          ));
        }
        return;
      }

      setState(() {
        _isLoading = true;
      });

      String? instituicaoFinal;
      if (_tipoSelecionado == 'ESCOLA') {
        if (_cidadeSelecionada == "OUTRO") {
          instituicaoFinal = _instituicaoManualController.text.trim();
        } else {
          instituicaoFinal = _instituicaoSelecionada;
        }
      }

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
          final profileData = <String, dynamic>{
            'uid': uid,
            kFieldName: _nameController.text.trim(),
            kFieldEmail: email,
            kFieldPhone: _phoneController.text.trim(),
            kFieldUserTipoSolicitante: _tipoSelecionado,
            'role': 'inativo', // ou 'pendente_aprovacao'
            'createdAt': FieldValue.serverTimestamp(),
            'ativo': true, // Adicionado para consistência com edit_profile
          };

          if (_tipoSelecionado == 'ESCOLA') {
            profileData[kFieldJobTitle] = _cargoSelecionado;
            profileData[kFieldUserInstituicao] = instituicaoFinal;
            profileData[kFieldCidade] = _cidadeSelecionada;
          } else if (_tipoSelecionado == 'SUPERINTENDENCIA') {
            profileData[kFieldUserSetor] = _setorSelecionado;
            profileData[kFieldCidadeSuperintendencia] =
                _cidadeSuperintendenciaSelecionada; // <<< SALVA A CIDADE DA SUPERINTENDÊNCIA
          }

          await FirebaseFirestore.instance
              .collection(kCollectionUsers)
              .doc(uid)
              .set(profileData);

          if (mounted) {
            // Enviar email de verificação
            // try {
            //   await user.sendEmailVerification();
            //   ScaffoldMessenger.of(context).showSnackBar(
            //     const SnackBar(content: Text('Email de verificação enviado! Por favor, verifique sua caixa de entrada.'), backgroundColor: Colors.blue),
            //   );
            // } catch (e) {
            //   print("Erro ao enviar email de verificação: $e");
            //    ScaffoldMessenger.of(context).showSnackBar(
            //     SnackBar(content: Text('Não foi possível enviar o email de verificação: ${e.toString()}'), backgroundColor: Colors.orange),
            //   );
            // }

            Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        const MainNavigationScreen())); // Ou para uma tela de "Verifique seu email"
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'Conta criada com sucesso! Faça login ou verifique seu email se necessário.'),
                  backgroundColor: Colors.green),
            );
          }
        } else {
          throw Exception('Falha ao obter usuário após criação.');
        }
      } on FirebaseAuthException catch (e) {
        String errorMessage = 'Ocorreu um erro ao criar a conta.';
        if (e.code == 'email-already-in-use') {
          errorMessage = 'Este email já está sendo usado.';
        } else if (e.code == 'weak-password') {
          errorMessage = 'A senha deve ter pelo menos 6 caracteres.';
        } else if (e.code == 'invalid-email') {
          errorMessage = 'O formato do email é inválido.';
        } else {
          errorMessage = e.message ?? errorMessage;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(errorMessage), backgroundColor: Colors.red));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Ocorreu um erro inesperado: ${e.toString()}'),
              backgroundColor: Colors.red));
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
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
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor, digite seu nome completo.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16.0),

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
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor, digite seu email.';
                    }
                    if (!value.contains('@') || !value.contains('.')) {
                      return 'Formato de email inválido.';
                    }
                    if (!value.toLowerCase().endsWith('@seduc.ro.gov.br')) {
                      return 'O email deve ser do domínio @seduc.ro.gov.br.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16.0),

                TextFormField(
                  controller: _phoneController,
                  enabled: !_isLoading,
                  keyboardType: TextInputType.phone,
                  // TODO: Adicionar MaskTextInputFormatter se desejar
                  decoration: const InputDecoration(
                    labelText: 'Telefone *',
                    hintText: '(XX) XXXXX-XXXX',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Digite seu telefone para contato.';
                    }
                    // Pode adicionar validação de formato de telefone aqui
                    return null;
                  },
                ),
                const SizedBox(height: 16.0),

                DropdownButtonFormField<String>(
                  value: _tipoSelecionado,
                  isExpanded: true,
                  hint: _isLoadingConfig
                      ? const Row(children: [
                          SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 8),
                          Text('Carregando...')
                        ])
                      : (_erroCarregarConfig != null && _listaTipos.isEmpty
                          ? Text(_erroCarregarConfig!,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 14))
                          : const Text(
                              'Você é de Escola ou Superintendência? *')),
                  decoration: InputDecoration(
                    labelText: 'Tipo de Lotação *',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.business_center_outlined),
                    errorMaxLines: 3,
                    errorText: _erroCarregarConfig != null &&
                            !_isLoadingConfig &&
                            _listaTipos.isEmpty
                        ? _erroCarregarConfig
                        : null,
                  ),
                  items: _isLoadingConfig ||
                          (_erroCarregarConfig != null && _listaTipos.isEmpty)
                      ? []
                      : _listaTipos
                          .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                  onChanged: (_isLoading ||
                          _isLoadingConfig ||
                          (_erroCarregarConfig != null && _listaTipos.isEmpty))
                      ? null
                      : (String? newValue) {
                          setState(() {
                            _tipoSelecionado = newValue;
                            // Resetar campos dependentes
                            _cargoSelecionado = null;
                            _cidadeSelecionada = null;
                            _instituicaoSelecionada = null;
                            _instituicaoManualController.clear();
                            _instituicoesDisponiveis = [];
                            _setorSelecionado = null;
                            _cidadeSuperintendenciaSelecionada =
                                null; // <<< RESETAR NOVO CAMPO
                          });
                        },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      if (_isLoadingConfig)
                        return null; // Não mostrar erro durante o carregamento inicial
                      if (_erroCarregarConfig != null && _listaTipos.isEmpty)
                        return _erroCarregarConfig; // Mostrar erro de config se houver
                      return 'Por favor, selecione o tipo de lotação.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16.0),

                // --- CAMPOS CONDICIONAIS PARA ESCOLA ---
                if (_tipoSelecionado == 'ESCOLA') ...[
                  DropdownButtonFormField<String>(
                    value: _cargoSelecionado,
                    isExpanded: true,
                    hint: _isLoadingConfig
                        ? const Row(children: [
                            SizedBox(
                                width: 12,
                                height: 12,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 8),
                            Text('Carregando...')
                          ])
                        : (_erroCarregarConfig != null && _listaCargos.isEmpty
                            ? Text(_erroCarregarConfig!,
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                    fontSize: 14))
                            : const Text('Selecione seu cargo/função *')),
                    decoration: InputDecoration(
                      labelText: 'Cargo / Função *',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.work_outline),
                      errorMaxLines: 3,
                      errorText: _erroCarregarConfig != null &&
                              !_isLoadingConfig &&
                              _listaCargos.isEmpty
                          ? _erroCarregarConfig
                          : null,
                    ),
                    items: _isLoadingConfig ||
                            (_erroCarregarConfig != null &&
                                _listaCargos.isEmpty)
                        ? []
                        : _listaCargos
                            .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value,
                                    overflow: TextOverflow.ellipsis));
                          }).toList(),
                    onChanged: (_isLoading ||
                            _isLoadingConfig ||
                            (_erroCarregarConfig != null &&
                                _listaCargos.isEmpty))
                        ? null
                        : (String? newValue) {
                            setState(() {
                              _cargoSelecionado = newValue;
                            });
                          },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        if (_isLoadingConfig) return null;
                        if (_erroCarregarConfig != null && _listaCargos.isEmpty)
                          return _erroCarregarConfig;
                        return 'Por favor, selecione seu cargo/função.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16.0),
                  DropdownButtonFormField<String>(
                    value: _cidadeSelecionada,
                    isExpanded: true,
                    hint: _isLoadingConfig
                        ? const Row(children: [
                            SizedBox(
                                width: 12,
                                height: 12,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 8),
                            Text('Carregando...')
                          ])
                        : (_erroCarregarConfig != null && _listaCidades.isEmpty
                            ? Text(_erroCarregarConfig!,
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                    fontSize: 14))
                            : const Text('Selecione a cidade/distrito *')),
                    decoration: InputDecoration(
                      labelText: 'Cidade / Distrito (Escola)*',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.location_city_outlined),
                      errorMaxLines: 3,
                      errorText: _erroCarregarConfig != null &&
                              !_isLoadingConfig &&
                              _listaCidades.isEmpty
                          ? _erroCarregarConfig
                          : null,
                    ),
                    items: _isLoadingConfig ||
                            (_erroCarregarConfig != null &&
                                _listaCidades.isEmpty)
                        ? []
                        : _listaCidades
                            .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value,
                                    overflow: TextOverflow.ellipsis));
                          }).toList(),
                    onChanged: (_isLoading ||
                            _isLoadingConfig ||
                            (_erroCarregarConfig != null &&
                                _listaCidades.isEmpty))
                        ? null
                        : _atualizarInstituicoes,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        if (_isLoadingConfig) return null;
                        if (_erroCarregarConfig != null &&
                            _listaCidades.isEmpty) return _erroCarregarConfig;
                        return 'Por favor, selecione a cidade/distrito.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16.0),
                  if (_cidadeSelecionada == "OUTRO")
                    TextFormField(
                      controller: _instituicaoManualController,
                      enabled: !_isLoading,
                      decoration: const InputDecoration(
                        labelText: 'Nome da Instituição (Escola)*',
                        hintText: 'Digite o nome completo da escola',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.account_balance_outlined),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (_cidadeSelecionada == "OUTRO" &&
                            (value == null || value.trim().isEmpty)) {
                          return 'Informe o nome da instituição';
                        }
                        return null;
                      },
                    )
                  else
                    DropdownButtonFormField<String>(
                      value: _instituicaoSelecionada,
                      isExpanded: true,
                      hint: _isLoadingConfig
                          ? const Row(children: [
                              SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                              SizedBox(width: 8),
                              Text('Carregando...')
                            ])
                          : (_cidadeSelecionada == null
                              ? const Text('Selecione a cidade primeiro')
                              : (_instituicoesDisponiveis.isEmpty &&
                                      _cidadeSelecionada != null &&
                                      !_isLoadingConfig
                                  ? const Text(
                                      'Nenhuma instituição para esta cidade')
                                  : const Text('Selecione sua instituição *'))),
                      decoration: InputDecoration(
                        labelText: 'Instituição / Lotação (Escola)*',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.account_balance_outlined),
                        errorMaxLines: 3,
                        errorText: (_erroCarregarConfig != null &&
                                !_isLoadingConfig &&
                                _instituicoesDisponiveis.isEmpty &&
                                _cidadeSelecionada != null &&
                                _cidadeSelecionada != "OUTRO")
                            ? "Nenhuma instituição para esta cidade."
                            : ((_erroCarregarConfig != null &&
                                    !_isLoadingConfig &&
                                    _listaInstituicoes.isEmpty &&
                                    _cidadeSelecionada != null &&
                                    _cidadeSelecionada !=
                                        "OUTRO") // Adicionado para erro geral de instituições
                                ? _erroCarregarConfig
                                : null),
                      ),
                      items: _isLoadingConfig ||
                              _cidadeSelecionada == null ||
                              _cidadeSelecionada == "OUTRO" ||
                              (_erroCarregarConfig != null &&
                                  _instituicoesDisponiveis.isEmpty &&
                                  _cidadeSelecionada != null)
                          ? []
                          : _instituicoesDisponiveis
                              .map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value,
                                      overflow: TextOverflow.ellipsis));
                            }).toList(),
                      onChanged: (_isLoading ||
                              _isLoadingConfig ||
                              _cidadeSelecionada == null ||
                              _cidadeSelecionada == "OUTRO" ||
                              (_erroCarregarConfig != null &&
                                  _instituicoesDisponiveis.isEmpty &&
                                  _cidadeSelecionada != null))
                          ? null
                          : (String? newValue) {
                              setState(() {
                                _instituicaoSelecionada = newValue;
                              });
                            },
                      validator: (value) {
                        if (_cidadeSelecionada != null &&
                            _cidadeSelecionada != "OUTRO") {
                          if (value == null || value.isEmpty) {
                            if (_isLoadingConfig) return null;
                            if (_erroCarregarConfig != null &&
                                _instituicoesDisponiveis.isEmpty)
                              return "Nenhuma instituição para esta cidade.";
                            return 'Por favor, selecione sua instituição.';
                          }
                        }
                        return null;
                      },
                    ),
                  const SizedBox(height: 16.0),
                ],

                // --- CAMPOS CONDICIONAIS PARA SUPERINTENDENCIA ---
                if (_tipoSelecionado == 'SUPERINTENDENCIA') ...[
                  DropdownButtonFormField<String>(
                    value: _setorSelecionado,
                    isExpanded: true,
                    hint: _isLoadingConfig
                        ? const Row(children: [
                            SizedBox(
                                width: 12,
                                height: 12,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 8),
                            Text('Carregando...')
                          ])
                        : (_erroCarregarConfig != null && _listaSetores.isEmpty
                            ? Text(_erroCarregarConfig!,
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                    fontSize: 14))
                            : const Text('Selecione o setor *')),
                    decoration: InputDecoration(
                      labelText: 'Setor (Superintendência)*',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.groups_outlined),
                      errorMaxLines: 3,
                      errorText: _erroCarregarConfig != null &&
                              !_isLoadingConfig &&
                              _listaSetores.isEmpty
                          ? _erroCarregarConfig
                          : null,
                    ),
                    items: _isLoadingConfig ||
                            (_erroCarregarConfig != null &&
                                _listaSetores.isEmpty)
                        ? []
                        : _listaSetores
                            .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value,
                                    overflow: TextOverflow.ellipsis));
                          }).toList(),
                    onChanged: (_isLoading ||
                            _isLoadingConfig ||
                            (_erroCarregarConfig != null &&
                                _listaSetores.isEmpty))
                        ? null
                        : (String? newValue) {
                            setState(() {
                              _setorSelecionado = newValue;
                            });
                          },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        if (_isLoadingConfig) return null;
                        if (_erroCarregarConfig != null &&
                            _listaSetores.isEmpty) return _erroCarregarConfig;
                        return 'Por favor, selecione o setor.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16.0),

                  // --- NOVO DROPDOWN PARA CIDADE DA SUPERINTENDÊNCIA ---
                  DropdownButtonFormField<String>(
                    value: _cidadeSuperintendenciaSelecionada,
                    isExpanded: true,
                    hint: _isLoadingConfig
                        ? const Row(children: [
                            SizedBox(
                                width: 12,
                                height: 12,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 8),
                            Text('Carregando cidades...')
                          ])
                        : (_erroCarregarConfig != null &&
                                _listaCidadesSuperintendencia.isEmpty &&
                                !_isLoadingConfig // Modificado para checar _isLoadingConfig
                            ? Text(
                                _erroCarregarConfig!
                                        .contains("cidadesSuperintendecia")
                                    ? _erroCarregarConfig!
                                    : "Erro ao carregar cidades SUPER.", // Mensagem mais específica
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                    fontSize: 14))
                            : const Text(
                                'Selecione a Cidade da Superintendência *')),
                    decoration: InputDecoration(
                      labelText: 'Cidade da Superintendência *',
                      border: const OutlineInputBorder(),
                      prefixIcon:
                          const Icon(Icons.map_outlined), // Ícone exemplo
                      errorMaxLines: 3,
                      errorText: _erroCarregarConfig != null &&
                              !_isLoadingConfig &&
                              _listaCidadesSuperintendencia.isEmpty
                          ? (_erroCarregarConfig!
                                  .contains("cidadesSuperintendecia")
                              ? _erroCarregarConfig!
                              : "Erro ao carregar cidades da SUPER.")
                          : null,
                    ),
                    items: _isLoadingConfig ||
                            (_erroCarregarConfig != null &&
                                _listaCidadesSuperintendencia.isEmpty &&
                                !_isLoadingConfig)
                        ? []
                        : _listaCidadesSuperintendencia
                            .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child:
                                  Text(value, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                    onChanged: (_isLoading ||
                            _isLoadingConfig ||
                            (_erroCarregarConfig != null &&
                                _listaCidadesSuperintendencia.isEmpty &&
                                !_isLoadingConfig))
                        ? null
                        : (String? newValue) {
                            setState(() {
                              _cidadeSuperintendenciaSelecionada = newValue;
                            });
                          },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        if (_isLoadingConfig) return null;
                        if (_erroCarregarConfig != null &&
                            _listaCidadesSuperintendencia.isEmpty &&
                            !_isLoadingConfig)
                          return (_erroCarregarConfig!
                                  .contains("cidadesSuperintendecia")
                              ? _erroCarregarConfig!
                              : "Erro ao carregar cidades da SUPER.");
                        return 'Selecione a cidade da Superintendência.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16.0),
                  // --- FIM NOVO DROPDOWN ---
                ],

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
                    if (value == null || value.isEmpty) {
                      return 'Por favor, digite uma senha.';
                    }
                    if (value.length < 6) {
                      return 'A senha deve ter no mínimo 6 caracteres.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16.0),

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
                    if (value != _passwordController.text) {
                      return 'As senhas não coincidem.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24.0),

                ElevatedButton(
                  onPressed: _isLoading || _isLoadingConfig ? null : _cadastrar,
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      textStyle: const TextStyle(fontSize: 16)),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 3, color: Colors.white))
                      : const Text('Cadastrar'),
                ),
                const SizedBox(height: 16.0),

                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          Navigator.pop(context); // Volta para a tela de Login
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

  // Constantes locais para nomes de campos do Firestore
  // É recomendável ter estas constantes em um arquivo compartilhado se usadas em múltiplos lugares.
  static const String kFieldName = 'name';
  static const String kFieldEmail = 'email';
  static const String kFieldPhone = 'phone';
  static const String kFieldJobTitle = 'jobTitle'; // Para ESCOLA
  static const String kFieldUserInstituicao = 'institution'; // Para ESCOLA
  static const String kFieldCidade = 'cidade'; // Para ESCOLA
  static const String kFieldUserTipoSolicitante = 'tipo_solicitante';
  static const String kFieldUserSetor =
      'setor_superintendencia'; // Para SUPERINTENDENCIA
  static const String kFieldCidadeSuperintendencia =
      'cidadeSuperintendencia'; // <<< NOVA CONSTANTE LOCAL (Para SUPERINTENDENCIA)
  // Certifique-se que é a mesma string usada no NovoChamadoScreen: `userData[kFieldCidadeSuperintendencia]`
  // No NovoChamadoScreen.dart, parece ser usada diretamente como 'cidadeSuperintendencia'.

  static const String kCollectionUsers = 'users';
  static const String kCollectionConfig = 'configuracoes';
  static const String kDocOpcoes = 'opcoesChamado';
  static const String kDocLocalidades = 'localidades';
}

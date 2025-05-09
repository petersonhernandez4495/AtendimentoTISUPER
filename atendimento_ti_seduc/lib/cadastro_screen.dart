import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

// Importe suas constantes de serviço
import '../services/chamado_service.dart';
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
  List<String> _listaSetores =
      []; // <<< NOVO ESTADO PARA SETORES (SUPERINTENDENCIA)
  String? _setorSelecionado; // <<< NOVO ESTADO PARA SETOR SELECIONADO

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

  // --- FUNÇÃO UNIFICADA PARA CARREGAR CONFIGURAÇÕES (Atualizada para incluir Setores) ---
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

      // Processa Localidades/Cidades/Instituições (sem alterações)
      List<String> cidades = [];
      Map<String, List<String>> escolasMap = {};
      String? erroLocalidades;
      if (docLocalidades.exists && docLocalidades.data() != null) {
        final data = docLocalidades.data()!;
        const String nomeCampoMapa = 'escolasPorCidade';
        if (data.containsKey(nomeCampoMapa) && data[nomeCampoMapa] is Map) {
          final Map<String, dynamic> rawMap =
              Map<String, dynamic>.from(data[nomeCampoMapa]);
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
          erroLocalidades = "Erro: Estrutura de dados de localidades inválida.";
        }
      } else {
        erroLocalidades = "Erro: Configuração de localidades não encontrada.";
      }
      if (cidades.isEmpty && erroLocalidades == null) {
        erroLocalidades = "Nenhuma cidade/instituição encontrada.";
      }

      // Processa Opcoes (Cargos, Tipos e Setores)
      List<String> cargos = [];
      List<String> tipos = [];
      List<String> setores = []; // <<< LISTA PARA SETORES
      String? erroOpcoes;
      if (docOpcoes.exists && docOpcoes.data() != null) {
        final data = docOpcoes.data()!;
        // Carrega Cargos
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
        // Carrega Tipos
        const String nomeCampoTipos = 'tipos';
        if (data.containsKey(nomeCampoTipos) && data[nomeCampoTipos] is List) {
          tipos = (data[nomeCampoTipos] as List)
              .map((tipo) => tipo?.toString())
              .where((nome) => nome != null && nome.isNotEmpty)
              .cast<String>()
              .toList();
        } else {
          erroOpcoes = (erroOpcoes ?? "") +
              " Erro: Estrutura de dados de tipos inválida.";
        }
        // Carrega Setores <<< NOVO
        const String nomeCampoSetores =
            'setoresSuper'; // Use a constante kFieldSetorSuper se definida no service
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
              " Erro: Estrutura de dados de setores inválida.";
        }
      } else {
        erroOpcoes = "Erro: Configuração de opções não encontrada.";
      }
      if (cargos.isEmpty && erroOpcoes == null) {
        erroOpcoes = "Nenhum cargo encontrado.";
      }
      if (tipos.isEmpty && erroOpcoes == null) {
        erroOpcoes = "Nenhum tipo de solicitante encontrado.";
      }
      if (setores.isEmpty && erroOpcoes == null) {
        erroOpcoes = "Nenhum setor encontrado.";
      } // <<< VALIDAÇÃO PARA SETORES

      _erroCarregarConfig = erroLocalidades ?? erroOpcoes;

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
          _listaSetores = setores; // <<< ATRIBUI LISTA DE SETORES
          _isLoadingConfig = false;
        });
      }
    } catch (e, s) {
      print("Erro ao carregar configurações de dropdowns: $e\nStackTrace: $s");
      if (mounted) {
        setState(() {
          _isLoadingConfig = false;
          _erroCarregarConfig = "Erro ao carregar configurações.";
        });
      }
    }
  }

  // --- FUNÇÃO PARA ATUALIZAR INSTITUIÇÕES (sem alterações) ---
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

  // --- Função Cadastrar (Atualizada para salvar dados condicionais) ---
  Future<void> _cadastrar() async {
    if (_formKey.currentState!.validate()) {
      final String email = _emailController.text.trim();
      const String dominioPermitido = '@seduc.ro.gov.br';

      if (!email.toLowerCase().endsWith(dominioPermitido)) {
        /* ... (validação email) ... */ return;
      }
      // Validação de professor só se aplica se o tipo for ESCOLA
      if (_tipoSelecionado == 'ESCOLA' &&
          _cargoSelecionado?.toUpperCase() == 'PROFESSOR') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text(
                'Apenas Gestores, Coordenadores do LIE e Secretários são permitidos criar um Perfil de acesso.'),
            backgroundColor: Colors.orange[800],
            duration: const Duration(seconds: 6),
          ));
        }
        return;
      }

      setState(() {
        _isLoading = true;
      });

      String? instituicaoFinal;
      if (_tipoSelecionado == 'ESCOLA') {
        // Determina instituição apenas para ESCOLA
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
          // --- Monta o profileData condicionalmente ---
          final profileData = <String, dynamic>{
            'uid': uid,
            kFieldName: _nameController.text.trim(),
            kFieldEmail: email,
            kFieldPhone: _phoneController.text.trim(),
            kFieldUserTipoSolicitante:
                _tipoSelecionado, // Salva o tipo selecionado
            'role': 'requester',
            'createdAt': FieldValue.serverTimestamp(),
          };

          if (_tipoSelecionado == 'ESCOLA') {
            profileData[kFieldJobTitle] = _cargoSelecionado;
            profileData[kFieldUserInstituicao] = instituicaoFinal;
            profileData[kFieldCidade] = _cidadeSelecionada;
          } else if (_tipoSelecionado == 'SUPERINTENDENCIA') {
            profileData[kFieldUserSetor] =
                _setorSelecionado; // <<< SALVA O SETOR (Use a constante correta)
            // Opcional: Salvar a cidade da superintendência se necessário no perfil
            // profileData[kFieldCidadeSuperintendencia] = _cidadeSuperController.text.trim();
          }
          // --- Fim da montagem condicional ---

          await FirebaseFirestore.instance
              .collection(kCollectionUsers)
              .doc(uid)
              .set(profileData);

          if (mounted) {
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (_) => const MainNavigationScreen()));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Conta criada com sucesso! Faça login.'),
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
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor, digite seu nome completo.';
                    }
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
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor, digite seu email.';
                    }
                    if (!value.contains('@') || !value.contains('.')) {
                      return 'Formato de email inválido.';
                    }
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
                    if (value == null || value.trim().isEmpty) {
                      return 'Digite seu telefone para contato.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16.0),

                // --- Dropdown Tipo Solicitante ---
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
                          // Reseta campos dependentes ao mudar o tipo
                          setState(() {
                            _tipoSelecionado = newValue;
                            _cargoSelecionado = null;
                            _cidadeSelecionada = null;
                            _instituicaoSelecionada = null;
                            _instituicaoManualController.clear();
                            _instituicoesDisponiveis = [];
                            _setorSelecionado = null;
                          });
                        },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      if (_isLoadingConfig) return null;
                      if (_erroCarregarConfig != null && _listaTipos.isEmpty)
                        return _erroCarregarConfig;
                      return 'Por favor, selecione o tipo de lotação.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16.0),

                // --- CAMPOS CONDICIONAIS PARA ESCOLA ---
                if (_tipoSelecionado == 'ESCOLA') ...[
                  // --- Dropdown de Cargo/Função ---
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
                              child:
                                  Text(value, overflow: TextOverflow.ellipsis),
                            );
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

                  // --- Dropdown de Cidade/Distrito ---
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
                      labelText: 'Cidade / Distrito *',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.location_city_outlined),
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
                              child:
                                  Text(value, overflow: TextOverflow.ellipsis),
                            );
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

                  // --- Campo Instituição (Dropdown ou Texto) ---
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
                              : const Text('Selecione sua instituição *')),
                      decoration: InputDecoration(
                        labelText: 'Instituição / Lotação *',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.account_balance_outlined),
                        errorText: (_erroCarregarConfig != null &&
                                !_isLoadingConfig &&
                                _instituicoesDisponiveis.isEmpty &&
                                _cidadeSelecionada != null &&
                                _cidadeSelecionada != "OUTRO")
                            ? "Nenhuma instituição para esta cidade."
                            : ((_erroCarregarConfig != null &&
                                    !_isLoadingConfig &&
                                    _listaInstituicoes.isEmpty)
                                ? _erroCarregarConfig
                                : null),
                      ),
                      items: _isLoadingConfig ||
                              _cidadeSelecionada == null ||
                              _cidadeSelecionada == "OUTRO" ||
                              (_erroCarregarConfig != null &&
                                  _instituicoesDisponiveis.isEmpty)
                          ? []
                          : _instituicoesDisponiveis
                              .map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value,
                                    overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                      onChanged: (_isLoading ||
                              _isLoadingConfig ||
                              _cidadeSelecionada == null ||
                              _cidadeSelecionada == "OUTRO" ||
                              (_erroCarregarConfig != null &&
                                  _instituicoesDisponiveis.isEmpty))
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

                // --- CAMPO CONDICIONAL PARA SUPERINTENDENCIA ---
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
                      labelText: 'Setor do servidor *',
                      border: const OutlineInputBorder(),
                      prefixIcon:
                          const Icon(Icons.groups_outlined), // Ícone exemplo
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
                              child:
                                  Text(value, overflow: TextOverflow.ellipsis),
                            );
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
                ],

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

                // --- Botão Cadastrar ---
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

                // --- Botão Voltar para Login ---
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
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

  // Constantes locais para nomes de campos
  static const String kFieldName = 'name';
  static const String kFieldEmail = 'email';
  static const String kFieldPhone = 'phone';
  static const String kFieldJobTitle = 'jobTitle';
  static const String kFieldUserInstituicao = 'institution';
  static const String kFieldCidade = 'cidade';
  static const String kFieldUserTipoSolicitante = 'tipo_solicitante';
  static const String kFieldUserSetor =
      'setor_superintendencia'; // <<< CONSTANTE LOCAL USADA
  static const String kCollectionUsers = 'users';
  static const String kCollectionConfig = 'configuracoes';
  static const String kDocOpcoes = 'opcoesChamado';
  static const String kDocLocalidades = 'localidades';
}

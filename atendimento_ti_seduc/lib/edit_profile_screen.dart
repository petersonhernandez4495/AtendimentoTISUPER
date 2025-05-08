import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Importe suas constantes de serviço, se aplicável, para nomes de campos.
import '../services/chamado_service.dart'; // Exemplo, ajuste o caminho

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  // Controller de cargo removido, usaremos _cargoSelecionado
  // final _jobTitleController = TextEditingController();
  String _currentEmail = '';

  User? _currentUser;
  Map<String, dynamic>? _userData;

  // Estados para Dropdown de Instituição
  List<String> _listaInstituicoes = [];
  String? _instituicaoSelecionada;
  bool _isLoadingInstituicoes = true;
  String? _erroCarregarInstituicoes;

  // Estados para Dropdown de Cargo/Função
  List<String> _listaCargos = [];
  String? _cargoSelecionado; // Substitui _jobTitleController
  bool _isLoadingCargos = true;
  String? _erroCarregarCargos;

  bool _isLoading = true; // Loading inicial da tela
  bool _isSaving = false; // Loading ao salvar

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuário não autenticado.')),
        );
        Navigator.of(context).pop();
      }
      return;
    }

    _currentEmail = _currentUser!.email ?? 'Email não disponível';

    try {
      // Carrega dados do Firestore E configurações em paralelo
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection(kCollectionUsers) // Usa constante
            .doc(_currentUser!.uid)
            .get(),
        _carregarConfiguracoesDropdowns(), // Carrega instituições E cargos
      ]);

      final userDoc = results[0] as DocumentSnapshot;

      if (userDoc.exists && mounted) {
        _userData = userDoc.data() as Map<String, dynamic>?;
        _nameController.text = _userData?[kFieldName] ??
            _currentUser!.displayName ??
            ''; // Usa constante kFieldName (ajuste se necessário)
        _phoneController.text = _userData?[kFieldPhone] ??
            ''; // Usa constante kFieldPhone (ajuste se necessário)
        // Define a instituição e cargo atuais para os dropdowns
        _instituicaoSelecionada =
            _userData?[kFieldUserInstituicao] as String?; // Usa constante
        _cargoSelecionado = _userData?[kFieldJobTitle]
            as String?; // Usa constante kFieldJobTitle (ajuste se necessário)

        // Garante que o valor inicial do cargo esteja na lista carregada
        if (_cargoSelecionado != null &&
            _cargoSelecionado!.isNotEmpty &&
            !_listaCargos.contains(_cargoSelecionado)) {
          // Talvez logar um aviso ou adicionar à lista se fizer sentido
          print(
              "Aviso: Cargo '$_cargoSelecionado' do perfil não encontrado na lista de opções.");
          // Decide se quer limpar ou manter. Manter pode ser melhor para não perder dados.
          // _cargoSelecionado = null; // Ou limpa se preferir forçar seleção
        }

        // Garante que o valor inicial da instituição esteja na lista carregada
        if (_instituicaoSelecionada != null &&
            _instituicaoSelecionada!.isNotEmpty &&
            !_listaInstituicoes.contains(_instituicaoSelecionada)) {
          print(
              "Aviso: Instituição '$_instituicaoSelecionada' do perfil não encontrada na lista de opções.");
          // Adiciona à lista para permitir que seja selecionado (pode ser instituição manual antiga)
          _listaInstituicoes.add(_instituicaoSelecionada!);
          _listaInstituicoes
              .sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dados do perfil não encontrados.')),
        );
      }
    } catch (e) {
      print("Erro ao carregar dados iniciais: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Função unificada para carregar dados dos dropdowns (Instituições e Cargos)
  Future<void> _carregarConfiguracoesDropdowns() async {
    if (!mounted) return;

    // Define estados de loading
    setState(() {
      _isLoadingInstituicoes = true;
      _erroCarregarInstituicoes = null;
      _isLoadingCargos = true;
      _erroCarregarCargos = null;
    });

    try {
      final db = FirebaseFirestore.instance;
      final results = await Future.wait([
        db.collection(kCollectionConfig).doc(kDocLocalidades).get(),
        db.collection(kCollectionConfig).doc(kDocOpcoes).get(),
      ]);

      final docLocalidades = results[0];
      final docOpcoes = results[1];

      // Processa Localidades/Instituições
      List<String> todasInstituicoes = [];
      String? erroInstituicoes;
      if (docLocalidades.exists && docLocalidades.data() != null) {
        final data = docLocalidades.data()!;
        const String nomeCampoMapa =
            'escolasPorCidade'; // Use a constante correta se tiver
        if (data.containsKey(nomeCampoMapa) && data[nomeCampoMapa] is Map) {
          final Map<String, dynamic> escolasPorCidadeMap =
              Map<String, dynamic>.from(data[nomeCampoMapa]);
          for (final listaDeEscolas in escolasPorCidadeMap.values) {
            if (listaDeEscolas is List) {
              todasInstituicoes.addAll(listaDeEscolas
                  .map((escola) => escola?.toString())
                  .where((nome) => nome != null && nome.isNotEmpty)
                  .cast<String>());
            }
          }
          todasInstituicoes
              .sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        } else {
          erroInstituicoes = "Erro: Estrutura de dados de escolas inválida.";
        }
      } else {
        erroInstituicoes = "Erro: Configuração de localidades não encontrada.";
      }
      if (todasInstituicoes.isEmpty && erroInstituicoes == null) {
        erroInstituicoes = "Nenhuma instituição encontrada.";
      }

      // Processa Opcoes/Cargos
      List<String> todosCargos = [];
      String? erroCargos;
      if (docOpcoes.exists && docOpcoes.data() != null) {
        final data = docOpcoes.data()!;
        const String nomeCampoCargos =
            'cargosEscola'; // Use a constante correta se tiver
        if (data.containsKey(nomeCampoCargos) &&
            data[nomeCampoCargos] is List) {
          todosCargos = (data[nomeCampoCargos] as List)
              .map((cargo) => cargo?.toString())
              .where((nome) => nome != null && nome.isNotEmpty)
              .cast<String>()
              .toList();
          todosCargos
              .sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        } else {
          erroCargos = "Erro: Estrutura de dados de cargos inválida.";
        }
      } else {
        erroCargos = "Erro: Configuração de opções não encontrada.";
      }
      if (todosCargos.isEmpty && erroCargos == null) {
        erroCargos = "Nenhum cargo encontrado.";
      }

      // Atualiza o estado
      if (mounted) {
        setState(() {
          _listaInstituicoes = todasInstituicoes;
          _erroCarregarInstituicoes = erroInstituicoes;
          _isLoadingInstituicoes = false;

          _listaCargos = todosCargos;
          _erroCarregarCargos = erroCargos;
          _isLoadingCargos = false;
        });
      }
    } catch (e, s) {
      print("Erro ao carregar configurações de dropdowns: $e\nStackTrace: $s");
      if (mounted) {
        setState(() {
          _isLoadingInstituicoes = false;
          _erroCarregarInstituicoes = "Erro ao carregar instituições.";
          _isLoadingCargos = false;
          _erroCarregarCargos = "Erro ao carregar cargos.";
        });
      }
    }
  }

  Future<void> _salvarPerfil() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuário não autenticado.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 1. Atualizar DisplayName no Firebase Auth (se mudou)
      if (_currentUser!.displayName != _nameController.text.trim()) {
        await _currentUser!.updateDisplayName(_nameController.text.trim());
        print("Nome no Firebase Auth atualizado.");
      }

      // 2. Preparar dados para Firestore
      final Map<String, dynamic> profileDataToUpdate = {
        kFieldName: _nameController.text.trim(), // Use constante
        kFieldPhone: _phoneController.text.trim(), // Use constante
        kFieldJobTitle:
            _cargoSelecionado, // Salva o cargo selecionado (Use constante kFieldJobTitle)
        kFieldUserInstituicao:
            _instituicaoSelecionada, // Salva a instituição selecionada (Use constante)
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // 3. Atualizar dados no Firestore
      await FirebaseFirestore.instance
          .collection(kCollectionUsers) // Use constante
          .doc(_currentUser!.uid)
          .update(profileDataToUpdate);

      print("Dados do perfil no Firestore atualizados.");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Perfil atualizado com sucesso!'),
              backgroundColor: Colors.green),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      print("Erro ao salvar perfil: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar perfil: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    // _jobTitleController.dispose(); // Removido
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            onPressed: _isSaving || _isLoading ? null : _salvarPerfil,
            tooltip: 'Salvar Alterações',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Campo Nome
                    TextFormField(
                      controller: _nameController,
                      enabled: !_isSaving,
                      decoration: const InputDecoration(
                        labelText: 'Nome Completo *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
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

                    // Campo Email (apenas exibição)
                    TextFormField(
                      initialValue: _currentEmail,
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: 'Email Institucional',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email_outlined),
                        fillColor: Colors.black12,
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 16.0),

                    // Campo Telefone
                    TextFormField(
                      controller: _phoneController,
                      enabled: !_isSaving,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Telefone *',
                        hintText: '(XX) XXXXX-XXXX',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Digite seu telefone para contato.';
                        }
                        // Adicionar validação de formato se necessário
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),

                    // Dropdown de Cargo/Função
                    DropdownButtonFormField<String>(
                      value: _cargoSelecionado,
                      isExpanded: true,
                      hint: _isLoadingCargos
                          ? const Row(children: [
                              SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                              SizedBox(width: 8),
                              Text('Carregando cargos...')
                            ])
                          : (_erroCarregarCargos != null
                              ? Text(_erroCarregarCargos!,
                                  style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.error,
                                      fontSize: 14))
                              : const Text('Selecione seu cargo/função *')),
                      decoration: InputDecoration(
                        labelText: 'Cargo / Função *',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.work_outline),
                        errorText: _erroCarregarCargos != null &&
                                !_isLoadingCargos &&
                                _listaCargos.isEmpty
                            ? _erroCarregarCargos
                            : null,
                      ),
                      items: _isLoadingCargos || _erroCarregarCargos != null
                          ? []
                          : _listaCargos
                              .map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value,
                                    overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                      onChanged: (_isSaving ||
                              _isLoadingCargos ||
                              _erroCarregarCargos != null)
                          ? null
                          : (String? newValue) {
                              setState(() {
                                _cargoSelecionado = newValue;
                              });
                            },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          if (_isLoadingCargos) return null;
                          if (_erroCarregarCargos != null &&
                              _listaCargos.isEmpty) return _erroCarregarCargos;
                          return 'Por favor, selecione seu cargo/função.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),

                    // Dropdown de Instituição
                    DropdownButtonFormField<String>(
                      value: _instituicaoSelecionada,
                      isExpanded: true,
                      hint: _isLoadingInstituicoes
                          ? const Row(children: [
                              SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                              SizedBox(width: 8),
                              Text('Carregando instituições...')
                            ])
                          : (_erroCarregarInstituicoes != null
                              ? Text(_erroCarregarInstituicoes!,
                                  style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.error,
                                      fontSize: 14))
                              : const Text('Selecione sua instituição *')),
                      decoration: InputDecoration(
                        labelText: 'Instituição / Lotação *',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.account_balance_outlined),
                        errorText: _erroCarregarInstituicoes != null &&
                                !_isLoadingInstituicoes &&
                                _listaInstituicoes.isEmpty
                            ? _erroCarregarInstituicoes
                            : null,
                      ),
                      items: _isLoadingInstituicoes ||
                              _erroCarregarInstituicoes != null
                          ? []
                          : _listaInstituicoes
                              .map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value,
                                    overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                      onChanged: (_isSaving ||
                              _isLoadingInstituicoes ||
                              _erroCarregarInstituicoes != null)
                          ? null
                          : (String? newValue) {
                              setState(() {
                                _instituicaoSelecionada = newValue;
                              });
                            },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          if (_isLoadingInstituicoes) return null;
                          if (_erroCarregarInstituicoes != null &&
                              _listaInstituicoes.isEmpty)
                            return _erroCarregarInstituicoes;
                          return 'Por favor, selecione sua instituição.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24.0),

                    // Botão Salvar
                    ElevatedButton.icon(
                      icon: _isSaving
                          ? Container()
                          : const Icon(Icons.save_alt_outlined),
                      label: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 3, color: Colors.white))
                          : const Text('Salvar Alterações'),
                      onPressed: _isSaving || _isLoading ? null : _salvarPerfil,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // Constantes locais para nomes de campos (substitua por import se preferir)
  static const String kFieldName = 'name';
  static const String kFieldPhone = 'phone';
  static const String kFieldJobTitle = 'jobTitle';
  static const String kFieldUserInstituicao = 'institution';
  static const String kCollectionUsers = 'users';
  static const String kCollectionConfig = 'configuracoes';
  static const String kDocOpcoes = 'opcoesChamado';
  static const String kDocLocalidades = 'localidades';
}

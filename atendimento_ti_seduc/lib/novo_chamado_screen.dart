import 'package:atendimento_ti_seduc/main_navigation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'dart:math';

// Importe os novos serviços e as constantes
import '../services/chamado_service.dart';
import '../services/duplicidade_service.dart';

class NovoChamadoScreen extends StatefulWidget {
  const NovoChamadoScreen({super.key});

  @override
  State<NovoChamadoScreen> createState() => _NovoChamadoScreenState();
}

class _NovoChamadoScreenState extends State<NovoChamadoScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isLoadingConfig = true;
  bool _hasLoadingError = false;
  int _currentStep = 0;

  final ChamadoService _chamadoService = ChamadoService();
  final DuplicidadeService _duplicidadeService = DuplicidadeService();

  final _celularController = TextEditingController();
  String? _equipamentoSelecionado;
  String? _internetConectadaSelecionado;
  final _marcaModeloController = TextEditingController();
  final _patrimonioController = TextEditingController();
  String? _problemaSelecionado;
  String? _cidadeSelecionada; // Para Escola
  String? _instituicaoSelecionada; // Para Escola
  String? _cargoSelecionado; // Para Escola
  String? _userTipoSolicitante;
  String? _atendimentoParaSelecionado; // Para Escola
  bool _isProfessorSelecionado = false; // Para Escola
  String? _setorSuperSelecionado; // Para Superintendencia

  String? _cidadeSuperSelecionada;

  final _instituicaoManualController = TextEditingController();
  final _equipamentoOutroController = TextEditingController();
  final _problemaOutroController = TextEditingController();

  List<String> _cargosEscola = [];
  List<String> _atendimentosEscola = [];
  List<String> _equipamentos = [];
  List<String> _opcoesSimNao = [];
  List<String> _problemasComuns = [];
  List<String> _setoresSuper = [];
  Map<String, List<String>> _escolasPorCidade = {};
  List<String> _cidadesDisponiveis = [];

  List<String> _instituicoesDisponiveis = [];

  List<String> _listaCidadesSuperintendencia = [];
  bool _isLoadingCidadesSuper = true;
  String? _erroCarregarCidadesSuper;

  final _phoneMaskFormatter = MaskTextInputFormatter(
      mask: '(##) #####-####',
      filter: {"#": RegExp(r'[0-9]')},
      type: MaskAutoCompletionType.lazy);

  bool _profileDataFilled = false;

  @override
  void initState() {
    super.initState();
    _loadDataSequentially();
  }

  Future<void> _loadDataSequentially() async {
    await _carregarConfiguracoes();
    if (!_hasLoadingError && mounted) {
      await _preencherDadosUsuario();
    }
  }

  @override
  void dispose() {
    _celularController.dispose();
    _marcaModeloController.dispose();
    _patrimonioController.dispose();
    _instituicaoManualController.dispose();
    _equipamentoOutroController.dispose();
    _problemaOutroController.dispose();
    super.dispose();
  }

  Future<void> _carregarConfiguracoes() async {
    print("--- Iniciando _carregarConfiguracoes ---");
    if (!_isLoadingConfig && !_hasLoadingError) {
      print("--- Carregamento já realizado. Saindo. ---");
      return;
    }
    setState(() {
      _isLoadingConfig = true;
      _hasLoadingError = false;
      _isLoadingCidadesSuper = true;
      _erroCarregarCidadesSuper = null;
    });
    try {
      final db = FirebaseFirestore.instance;
      final results = await Future.wait([
        db.collection(kCollectionConfig).doc(kDocOpcoes).get(),
        db.collection(kCollectionConfig).doc(kDocLocalidades).get(),
      ]);
      final docOpcoes = results[0];
      final docLocalidades = results[1];
      Map<String, dynamic>? dataOpcoes = docOpcoes.data();
      List<String> loadedCargosEscola =
          _parseStringList(dataOpcoes, 'cargosEscola');
      List<String> loadedAtendimentosEscola =
          _parseStringList(dataOpcoes, 'atendimentosEscola');
      List<String> loadedEquipamentos =
          _parseStringList(dataOpcoes, 'equipamentos');
      List<String> loadedOpcoesSimNao =
          _parseStringList(dataOpcoes, 'opcoesSimNao');
      List<String> loadedProblemasComuns =
          _parseStringList(dataOpcoes, 'problemasComuns');
      List<String> loadedSetoresSuper =
          _parseStringList(dataOpcoes, 'setoresSuper');
      if (!loadedEquipamentos.contains("OUTRO")) {
        loadedEquipamentos.add("OUTRO");
      }
      if (!loadedProblemasComuns.contains("OUTRO")) {
        loadedProblemasComuns.add("OUTRO");
      }
      Map<String, dynamic>? dataLocalidades = docLocalidades.data();
      Map<String, List<String>> loadedEscolasPorCidade = {};
      List<String> loadedCidadesDisponiveis = [];
      List<String> loadedCidadesSuper = [];

      const String nomeCampoMapaEscolas = 'escolasPorCidade';
      if (dataLocalidades != null &&
          dataLocalidades.containsKey(nomeCampoMapaEscolas)) {
        dynamic escolasMapData = dataLocalidades[nomeCampoMapaEscolas];
        if (escolasMapData is Map) {
          escolasMapData.forEach((key, value) {
            if (key is String && value != null) {
              List<String> escolas;
              if (key == "OUTRO" && value is String) {
                print(
                    "WARN (parse): Campo 'escolas para \"Outro\"' era String, tratando como lista vazia. Valor original: \"$value\"");
                escolas = [];
              } else {
                escolas =
                    _parseStringListFromDynamic(value, 'escolas para "$key"');
              }

              if (escolas.isNotEmpty || key == "OUTRO") {
                loadedEscolasPorCidade[key] = escolas
                  ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
              }
            }
          });
          if (!loadedEscolasPorCidade.containsKey("OUTRO")) {
            loadedEscolasPorCidade["OUTRO"] = [];
          }
          loadedCidadesDisponiveis = loadedEscolasPorCidade.keys.toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        }
      }

      const String nomeCampoCidadesSuper = 'cidadesSuperintendecia';
      if (dataLocalidades != null &&
          dataLocalidades.containsKey(nomeCampoCidadesSuper)) {
        loadedCidadesSuper = _parseStringListFromDynamic(
            dataLocalidades[nomeCampoCidadesSuper], nomeCampoCidadesSuper);
        loadedCidadesSuper
            .sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        if (loadedCidadesSuper.isEmpty &&
            dataLocalidades[nomeCampoCidadesSuper] is List) {
          _erroCarregarCidadesSuper =
              "Nenhuma cidade da superintendência configurada.";
          print(
              "WARN: Campo '$nomeCampoCidadesSuper' está vazio em configuracoes/localidades.");
        }
      } else {
        _erroCarregarCidadesSuper =
            "Configuração '$nomeCampoCidadesSuper' não encontrada.";
        print(
            "WARN: Campo '$nomeCampoCidadesSuper' não encontrado em configuracoes/localidades. Verifique o nome e a existência do campo no Firestore.");
      }

      bool configEssentialsOk = loadedCidadesDisponiveis.isNotEmpty;

      if (mounted) {
        setState(() {
          if (configEssentialsOk) {
            _cargosEscola = loadedCargosEscola;
            _atendimentosEscola = loadedAtendimentosEscola;
            _equipamentos = loadedEquipamentos;
            _opcoesSimNao = loadedOpcoesSimNao;
            _problemasComuns = loadedProblemasComuns;
            _setoresSuper = loadedSetoresSuper;
            _escolasPorCidade = loadedEscolasPorCidade;
            _cidadesDisponiveis = loadedCidadesDisponiveis;
            _listaCidadesSuperintendencia = loadedCidadesSuper;
            _hasLoadingError = false;
          } else {
            _hasLoadingError = true;
            String erroMsg =
                'Erro crítico ao carregar configurações de localidades (escolas)!';
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(erroMsg),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 10)));
          }
          _isLoadingConfig = false;
          _isLoadingCidadesSuper = false;
        });
      }
    } catch (e, stacktrace) {
      print("--- ERRO INESPERADO em _carregarConfiguracoes ---");
      print("Erro CRÍTICO: $e");
      print(stacktrace);
      if (mounted) {
        setState(() {
          _isLoadingConfig = false;
          _hasLoadingError = true;
          _isLoadingCidadesSuper = false;
          _erroCarregarCidadesSuper = "Erro fatal ao carregar configurações.";
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('Erro fatal ao carregar configurações: ${e.toString()}'),
            backgroundColor: Colors.red));
      }
    }
    print("--- Fim de _carregarConfiguracoes ---");
  }

  List<String> _parseStringList(Map<String, dynamic>? data, String fieldName) {
    if (data == null || !data.containsKey(fieldName)) {
      print(
          "WARN (parse): Campo '$fieldName' não encontrado no mapa de opções.");
      return [];
    }
    return _parseStringListFromDynamic(data[fieldName], fieldName);
  }

  List<String> _parseStringListFromDynamic(
      dynamic data, String fieldDescription) {
    if (data == null) {
      print("WARN (parse): Dado nulo para '$fieldDescription'.");
      return [];
    }
    if (data is List) {
      List<String> result = data
          .where((item) => item != null)
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList();
      return result;
    } else {
      print(
          "WARN (parse): Campo '$fieldDescription' não é Lista/Array no Firestore. Tipo encontrado: ${data.runtimeType}. Valor: $data");
      return [];
    }
  }

  void _atualizarInstituicoes(String? cidadeSelecionada) {
    setState(() {
      _cidadeSelecionada = cidadeSelecionada;
      _instituicaoSelecionada = null;
      _instituicaoManualController.clear();
      if (cidadeSelecionada != null &&
          cidadeSelecionada != "OUTRO" &&
          _escolasPorCidade.containsKey(cidadeSelecionada)) {
        _instituicoesDisponiveis =
            List<String>.from(_escolasPorCidade[cidadeSelecionada]!);
      } else {
        _instituicoesDisponiveis = [];
      }
    });
  }

  Future<void> _preencherDadosUsuario() async {
    if (_profileDataFilled) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    print("--- Iniciando _preencherDadosUsuario ---");
    setState(() {
      _isLoading = true;
    });
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection(kCollectionUsers)
          .doc(user.uid)
          .get();
      if (userDoc.exists && userDoc.data() != null && mounted) {
        final userData = userDoc.data()!;
        _userTipoSolicitante = userData[kFieldUserTipoSolicitante] as String?;
        if (_userTipoSolicitante == null || _userTipoSolicitante!.isEmpty) {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text(
                    'Tipo de solicitante não definido no perfil. Verifique seu cadastro.'),
                backgroundColor: Colors.orange));
        }
        final String? phoneFromProfile = userData[kFieldPhone] as String?;
        if (phoneFromProfile != null && phoneFromProfile.isNotEmpty) {
          try {
            _celularController.text =
                _phoneMaskFormatter.maskText(phoneFromProfile);
          } catch (e) {
            _celularController.text = phoneFromProfile;
          }
        } else {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text(
                    'Telefone não definido no perfil. Preencha para continuar.'),
                backgroundColor: Colors.orange));
        }

        if (_userTipoSolicitante == 'ESCOLA') {
          final String? cargoFromProfile = userData[kFieldJobTitle] as String?;
          if (cargoFromProfile != null &&
              _cargosEscola.contains(cargoFromProfile)) {
            _cargoSelecionado = cargoFromProfile;
            _isProfessorSelecionado = (cargoFromProfile == 'PROFESSOR');
          }
          final String? cidadeFromProfile = userData[kFieldCidade] as String?;
          if (cidadeFromProfile != null &&
              _cidadesDisponiveis.contains(cidadeFromProfile)) {
            _atualizarInstituicoes(cidadeFromProfile);

            final String? instituicaoFromProfile =
                userData[kFieldUserInstituicao] as String?;
            if (_cidadeSelecionada != "OUTRO" &&
                instituicaoFromProfile != null &&
                _instituicoesDisponiveis.contains(instituicaoFromProfile)) {
              _instituicaoSelecionada = instituicaoFromProfile;
            } else if (_cidadeSelecionada == "OUTRO" &&
                instituicaoFromProfile != null) {
              _instituicaoManualController.text = instituicaoFromProfile;
              _instituicaoSelecionada = instituicaoFromProfile;
            }
          }
        } else if (_userTipoSolicitante == 'SUPERINTENDENCIA') {
          final String? setorFromProfile = userData[kFieldUserSetor] as String?;
          if (setorFromProfile != null &&
              _setoresSuper.contains(setorFromProfile)) {
            _setorSuperSelecionado = setorFromProfile;
          }
          final String? cidadeSuperFromProfile =
              userData[kFieldCidadeSuperintendencia] as String?;
          if (cidadeSuperFromProfile != null &&
              !_isLoadingCidadesSuper &&
              _listaCidadesSuperintendencia.contains(cidadeSuperFromProfile)) {
            _cidadeSuperSelecionada = cidadeSuperFromProfile;
          }
        }
        _profileDataFilled = true;
      } else {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Dados do perfil não encontrados. Preencha os campos manualmente.'),
              backgroundColor: Colors.orange));
      }
    } catch (e, s) {
      print("Erro ao preencher dados do usuário: $e\n$s");
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Erro ao carregar dados do perfil.'),
            backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      print("--- Fim de _preencherDadosUsuario ---");
    }
  }

  void _resetDependentFields() {
    _setorSuperSelecionado = null;
    _atendimentoParaSelecionado = null;
    _isProfessorSelecionado = false;
    _cidadeSuperSelecionada = null;
    _instituicaoManualController.clear();
    _equipamentoOutroController.clear();
    _problemaOutroController.clear();
    _equipamentoSelecionado = null;
    _problemaSelecionado = null;
  }

  Future<void> _enviarChamado() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Por favor, preencha todos os campos obrigatórios.')));
      return;
    }
    if (_userTipoSolicitante == null || _userTipoSolicitante!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Tipo de solicitante não definido. Verifique seu perfil.'),
          backgroundColor: Colors.red));
      return;
    }
    if (_userTipoSolicitante == 'ESCOLA' &&
        (_cidadeSelecionada == null ||
            (_cidadeSelecionada == "OUTRO"
                ? _instituicaoManualController.text.trim().isEmpty
                : _instituicaoSelecionada == null) ||
            _cargoSelecionado == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Dados da escola incompletos. Verifique seu perfil ou preenchimento.'),
          backgroundColor: Colors.red));
      return;
    }
    if (_userTipoSolicitante == 'SUPERINTENDENCIA' &&
        (_setorSuperSelecionado == null || _cidadeSuperSelecionada == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Dados da superintendência incompletos.'),
          backgroundColor: Colors.red));
      return;
    }

    if (_userTipoSolicitante == 'ESCOLA' && _isProfessorSelecionado) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text(
            'Lembrete: Professores devem solicitar via Coordenação ou Direção.'),
        backgroundColor: Colors.orange.shade800,
        duration: const Duration(seconds: 5),
      ));
    }

    setState(() {
      _isLoading = true;
    });

    final String patrimonio = _patrimonioController.text.trim();
    final String? problemaSel = _problemaSelecionado;
    final String problemaOutro = _problemaOutroController.text.trim();
    final String? equipamentoSel = _equipamentoSelecionado;
    final String equipamentoOutro = _equipamentoOutroController.text.trim();

    try {
      final String? duplicateId =
          await _duplicidadeService.verificarDuplicidade(
        patrimonio: patrimonio,
        problemaSelecionado: problemaSel,
        problemaOutroDescricao: problemaOutro,
        equipamentoSelecionado: equipamentoSel,
        equipamentoOutroDescricao: equipamentoOutro,
      );

      bool prosseguirComCriacao = true;

      if (duplicateId != null && mounted) {
        prosseguirComCriacao = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (BuildContext dialogContext) {
                return AlertDialog(
                  title: const Text('Possível Duplicidade Encontrada'),
                  content: Text(
                      'Já existe um chamado ativo (#${duplicateId.substring(0, min(6, duplicateId.length))}...) com problema e equipamento semelhantes para este patrimônio. Deseja abrir um novo chamado mesmo assim?'),
                  actions: <Widget>[
                    TextButton(
                      child: const Text('Cancelar'),
                      onPressed: () {
                        Navigator.of(dialogContext).pop(false);
                      },
                    ),
                    ElevatedButton(
                      child: const Text('Continuar'),
                      onPressed: () {
                        Navigator.of(dialogContext).pop(true);
                      },
                    ),
                  ],
                );
              },
            ) ??
            false;

        if (!prosseguirComCriacao) {
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      final String novoChamadoId = await _chamadoService.criarChamado(
        tipoSelecionado: _userTipoSolicitante,
        celularContato: _celularController.text,
        equipamentoSelecionado: equipamentoSel,
        equipamentoOutro: equipamentoOutro,
        internetConectadaSelecionado: _internetConectadaSelecionado,
        marcaModelo: _marcaModeloController.text.trim(),
        patrimonio: patrimonio,
        problemaSelecionado: problemaSel,
        problemaOutro: problemaOutro,
        tecnicoResponsavel: '',
        cidadeSelecionada: _cidadeSelecionada,
        instituicaoSelecionada:
            (_cidadeSelecionada == "OUTRO" && _userTipoSolicitante == 'ESCOLA')
                ? _instituicaoManualController.text.trim()
                : _instituicaoSelecionada,
        cargoSelecionado: _cargoSelecionado,
        atendimentoParaSelecionado: _atendimentoParaSelecionado,
        isProfessorSelecionado: _isProfessorSelecionado,
        setorSuperSelecionado: _setorSuperSelecionado,
        cidadeSuper: _cidadeSuperSelecionada ?? '',
        instituicaoManual:
            (_cidadeSelecionada == "OUTRO" && _userTipoSolicitante == 'ESCOLA')
                ? _instituicaoManualController.text.trim()
                : null,
      );

      if (mounted) {
        _resetFormAndNavigate(novoChamadoId);
      }
    } catch (e) {
      print('Erro ao processar chamado: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao processar chamado: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 8),
        ));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _resetFormAndNavigate(String chamadoId) {
    print("DEBUG: Iniciando _resetFormAndNavigate...");
    try {
      _formKey.currentState?.reset();
      _marcaModeloController.clear();
      _patrimonioController.clear();
      _instituicaoManualController.clear();
      _equipamentoOutroController.clear();
      _problemaOutroController.clear();
      setState(() {
        _equipamentoSelecionado = null;
        _internetConectadaSelecionado = null;
        _problemaSelecionado = null;
        _atendimentoParaSelecionado = null;
        _isProfessorSelecionado = false;
        _cidadeSuperSelecionada = null;
        _currentStep = 0;
      });
      print("DEBUG: Campos resetados.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Chamado (#$chamadoId) aberto com sucesso!'),
            backgroundColor: Colors.green));
      }
      print("DEBUG: Antes de chamar Navigator.pushAndRemoveUntil...");
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
                builder: (context) => const MainNavigationScreen()),
            (Route<dynamic> route) => false,
          );
          print("DEBUG: Navegação executada.");
        } else {
          print(
              "DEBUG: Widget desmontado antes da navegação em _resetFormAndNavigate.");
        }
      });
    } catch (e) {
      print("ERRO dentro de _resetFormAndNavigate: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erro ao finalizar: ${e.toString()}'),
            backgroundColor: Colors.red));
      }
    }
  }

  void _handleStepContinue() {
    bool isStepValid = true;
    if (_currentStep == 0) {
      isStepValid = _validateStep1();
    } else if (_currentStep == 1) {
      isStepValid = _validateStep2();
    }
    if (!isStepValid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Preencha os campos obrigatórios deste passo.')));
      _formKey.currentState?.validate();
      return;
    }
    if (_currentStep < _buildSteps().length - 1) {
      setState(() {
        _currentStep += 1;
      });
    } else {
      _enviarChamado();
    }
  }

  void _handleStepCancel() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep -= 1;
      });
    }
  }

  bool _validateStep1() {
    if (_userTipoSolicitante == null || _userTipoSolicitante!.isEmpty)
      return false;
    if (_userTipoSolicitante == 'ESCOLA') {
      if (_atendimentoParaSelecionado == null) return false;
    } else if (_userTipoSolicitante == 'SUPERINTENDENCIA') {
      if (_setorSuperSelecionado == null) return false;
      if (_cidadeSuperSelecionada == null || _cidadeSuperSelecionada!.isEmpty)
        return false;
    }
    return true;
  }

  bool _validateStep2() {
    if (_equipamentoSelecionado == null) return false;
    if (_equipamentoSelecionado == "OUTRO" &&
        _equipamentoOutroController.text.trim().isEmpty) return false;
    if (_internetConectadaSelecionado == null) return false;
    if (_patrimonioController.text.trim().isEmpty ||
        _patrimonioController.text.trim() == '0' ||
        int.tryParse(_patrimonioController.text.trim()) == null) return false;
    if (_problemaSelecionado == null) return false;
    if (_problemaSelecionado == "OUTRO" &&
        _problemaOutroController.text.trim().isEmpty) return false;
    return _formKey.currentState?.validate() ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if ((_isLoadingConfig || _isLoading) && !_hasLoadingError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Abrir Novo Chamado')),
        body: const Center(
            child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Carregando dados...'),
          ],
        )),
      );
    }
    if (_hasLoadingError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Erro ao Carregar')),
        body: Center(
            child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700, size: 60),
              const SizedBox(height: 16),
              const Text('Não foi possível carregar os dados necessários...',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
              const SizedBox(height: 10),
              const Text(
                  'Verifique seu perfil, conexão ou a configuração no Firebase.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14)),
              const SizedBox(height: 25),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar Novamente'),
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12)),
                onPressed: _isLoadingConfig || _isLoading
                    ? null
                    : _loadDataSequentially,
              )
            ],
          ),
        )),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Abrir Novo Chamado'),
        automaticallyImplyLeading: _currentStep == 0,
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.disabled,
        child: Stepper(
          type: StepperType.vertical,
          currentStep: _currentStep,
          onStepContinue: _isLoading ? null : _handleStepContinue,
          onStepCancel: _isLoading ? null : _handleStepCancel,
          onStepTapped: null,
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: Row(
                children: <Widget>[
                  ElevatedButton(
                    onPressed: _isLoading ? null : details.onStepContinue,
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 25, vertical: 12)),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(details.stepIndex == _buildSteps().length - 1
                            ? 'Enviar Chamado'
                            : 'Próximo'),
                  ),
                  const SizedBox(width: 12),
                  if (details.stepIndex > 0)
                    TextButton(
                      onPressed: _isLoading ? null : details.onStepCancel,
                      child: const Text('Voltar'),
                    ),
                ],
              ),
            );
          },
          steps: _buildSteps(),
        ),
      ),
    );
  }

  List<Step> _buildSteps() {
    StepState getStepState(int stepIndex) {
      if (_hasLoadingError && stepIndex == 0) return StepState.error;
      if (_currentStep > stepIndex) return StepState.complete;
      if (_currentStep == stepIndex) return StepState.editing;
      return StepState.indexed;
    }

    bool isStep1Active = !_hasLoadingError;
    bool isStep2Active = _currentStep >= 1 &&
        !_hasLoadingError &&
        _userTipoSolicitante != null &&
        _userTipoSolicitante!.isNotEmpty;

    return [
      Step(
        title: const Text('1. Identificação e Local'),
        content: _buildStep1Content(),
        isActive: isStep1Active,
        state: getStepState(0),
      ),
      Step(
        title: const Text('2. Equipamento e Problema'),
        content: _userTipoSolicitante != null &&
                _userTipoSolicitante!.isNotEmpty
            ? _buildStep2Content()
            : _buildStepPlaceholder(
                "Complete os dados do seu perfil ou selecione o tipo de solicitante para prosseguir."),
        isActive: isStep2Active,
        state: getStepState(1),
      ),
    ];
  }

  Widget _buildStepPlaceholder(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30.0, horizontal: 10.0),
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: Theme.of(context).disabledColor.withOpacity(0.2))),
      child: Text(
        message,
        style: TextStyle(
            fontStyle: FontStyle.italic,
            color: Theme.of(context).disabledColor,
            fontSize: 14,
            height: 1.4),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildStep1Content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildInfoTile(
          icon: Icons.business_center_outlined,
          label: 'Tipo de Lotação (do seu perfil)',
          value: _userTipoSolicitante ??
              (_isLoading ? 'Carregando...' : 'Não definido no perfil'),
        ),
        const SizedBox(height: 20.0),
        if (_userTipoSolicitante == 'ESCOLA') ...[
          _buildInfoTile(
            icon: Icons.location_city_outlined,
            label: 'Cidade / Distrito (do seu perfil)',
            value: _cidadeSelecionada ??
                (_isLoading ? 'Carregando...' : 'Não definido no perfil'),
          ),
          _buildInfoTile(
            icon: Icons.account_balance_outlined,
            label: 'Instituição / Lotação (do seu perfil)',
            value: (_cidadeSelecionada == "OUTRO" &&
                    _instituicaoSelecionada != null)
                ? _instituicaoSelecionada! + " (Manual)"
                : _instituicaoSelecionada ??
                    (_isLoading ? 'Carregando...' : 'Não definida no perfil'),
          ),
          _buildInfoTile(
            icon: Icons.work_outline,
            label: 'Cargo / Função (do seu perfil)',
            value: _cargoSelecionado ??
                (_isLoading ? 'Carregando...' : 'Não definido no perfil'),
          ),
          const SizedBox(height: 16.0),
          _buildDropdown<String>(
            labelText: 'Atendimento técnico para:*',
            hintText: 'Selecione o setor da escola',
            value: _atendimentoParaSelecionado,
            items: _atendimentosEscola,
            onChanged: (v) => setState(() => _atendimentoParaSelecionado = v),
            validator: (value) =>
                (_userTipoSolicitante == 'ESCOLA' && value == null)
                    ? 'Selecione o setor'
                    : null,
          ),
          if (_isProfessorSelecionado)
            Padding(
              padding: const EdgeInsets.only(top: 10.0, bottom: 6.0),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    border: Border.all(color: Colors.orange.shade300),
                    borderRadius: BorderRadius.circular(4)),
                child: Text(
                  'Atenção: Professores devem solicitar via Coordenação Pedagógica ou Direção Escolar.',
                  style: TextStyle(
                      color: Colors.orange.shade900, fontSize: 13, height: 1.3),
                ),
              ),
            ),
        ],
        if (_userTipoSolicitante == 'SUPERINTENDENCIA') ...[
          _buildDropdown<String>(
            labelText: 'Em qual sala/setor da SUPER?*',
            hintText: 'Selecione seu setor',
            value: _setorSuperSelecionado,
            items: _setoresSuper,
            onChanged: (v) => setState(() => _setorSuperSelecionado = v),
            validator: (value) =>
                (_userTipoSolicitante == 'SUPERINTENDENCIA' && value == null)
                    ? 'Selecione o setor'
                    : null,
            isExpanded: true,
          ),
          const SizedBox(height: 16.0),
          _buildDropdown<String>(
            labelText: 'Cidade da Superintendência*',
            hintText: _isLoadingCidadesSuper
                ? 'Carregando cidades...'
                : (_erroCarregarCidadesSuper != null &&
                        _listaCidadesSuperintendencia.isEmpty
                    ? _erroCarregarCidadesSuper
                    : 'Selecione a cidade da SUPER'),
            value: _cidadeSuperSelecionada,
            items: _listaCidadesSuperintendencia,
            onChanged: (v) => setState(() => _cidadeSuperSelecionada = v),
            validator: (value) {
              if (_userTipoSolicitante == 'SUPERINTENDENCIA' &&
                  (value == null || value.isEmpty)) {
                if (_isLoadingCidadesSuper) return null;
                if (_erroCarregarCidadesSuper != null &&
                    _listaCidadesSuperintendencia.isEmpty) return null;
                return 'Selecione a cidade da Superintendência';
              }
              return null;
            },
            enabled: !_isLoadingCidadesSuper &&
                (_erroCarregarCidadesSuper == null ||
                    _listaCidadesSuperintendencia.isNotEmpty),
            errorText: (_erroCarregarCidadesSuper != null &&
                    _listaCidadesSuperintendencia.isEmpty &&
                    !_isLoadingCidadesSuper)
                ? _erroCarregarCidadesSuper
                : null,
          ),
        ],
        const SizedBox(height: 8.0),
      ],
    );
  }

  Widget _buildStep2Content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextFormField(
          controller: _celularController,
          enabled: false,
          keyboardType: TextInputType.phone,
          inputFormatters: [_phoneMaskFormatter],
          decoration: InputDecoration(
            labelText: 'Número de celular para contato (do perfil)',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.phone_outlined),
            fillColor: Theme.of(context).disabledColor.withOpacity(0.08),
            filled: true,
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty)
              return 'Telefone não carregado do perfil. Verifique seu cadastro.';
            return null;
          },
        ),
        const SizedBox(height: 16.0),
        _buildDropdown<String>(
          labelText: 'Para qual equipamento é a solicitação?*',
          hintText: 'Selecione o tipo de equipamento',
          value: _equipamentoSelecionado,
          items: _equipamentos,
          onChanged: (v) {
            setState(() {
              _equipamentoSelecionado = v;
              if (v != "OUTRO") {
                _equipamentoOutroController.clear();
              }
            });
          },
          validator: (v) =>
              v == null ? 'Selecione o tipo de equipamento' : null,
        ),
        if (_equipamentoSelecionado == "OUTRO") ...[
          const SizedBox(height: 16.0),
          _buildTextFormField(
            controller: _equipamentoOutroController,
            labelText: 'Especifique o equipamento*',
            hintText: 'Descreva qual é o equipamento',
            validator: (v) => (_equipamentoSelecionado == "OUTRO" &&
                    (v == null || v.trim().isEmpty))
                ? 'Especifique o equipamento'
                : null,
            maxLines: 2,
          ),
        ],
        const SizedBox(height: 16.0),
        _buildDropdown<String>(
          labelText: 'O equipamento está com internet conectada?*',
          hintText: 'Selecione Sim ou Não',
          value: _internetConectadaSelecionado,
          items: _opcoesSimNao,
          onChanged: (v) => setState(() => _internetConectadaSelecionado = v),
          validator: (v) => v == null ? 'Informe se há conexão' : null,
        ),
        const SizedBox(height: 16.0),
        _buildTextFormField(
          controller: _marcaModeloController,
          labelText: 'Marca/Modelo do equipamento? (Opcional)',
          hintText: 'Ex: Dell Optiplex 3080, Positivo N250i',
        ),
        const SizedBox(height: 16.0),
        _buildTextFormField(
          controller: _patrimonioController,
          labelText: 'Número de Patrimônio (Tombamento)?*',
          hintText: 'Digite apenas números',
          validator: (v) {
            if (v == null || v.trim().isEmpty)
              return 'Informe o nº de patrimônio';
            if (v.trim() == '0') return 'Patrimônio não pode ser 0';
            final number = int.tryParse(v.trim());
            if (number == null) return 'Digite apenas números';
            return null;
          },
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          helperText:
              'Caso não encontre a etiqueta, solicite à direção/secretaria a consulta no sistema.',
          helperMaxLines: 3,
        ),
        const SizedBox(height: 16.0),
        _buildDropdown<String>(
          labelText: 'Qual o problema que está ocorrendo?*',
          hintText: 'Selecione o problema principal',
          value: _problemaSelecionado,
          items: _problemasComuns,
          onChanged: (v) {
            setState(() {
              _problemaSelecionado = v;
              if (v != "OUTRO") {
                _problemaOutroController.clear();
              }
            });
          },
          validator: (v) => v == null ? 'Selecione o problema' : null,
        ),
        if (_problemaSelecionado == "OUTRO") ...[
          const SizedBox(height: 16.0),
          _buildTextFormField(
            controller: _problemaOutroController,
            labelText: 'Descreva o problema ocorrido*',
            hintText: 'Detalhe o que está acontecendo',
            validator: (v) => (_problemaSelecionado == "OUTRO" &&
                    (v == null || v.trim().isEmpty))
                ? 'Descreva o problema'
                : null,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
        const SizedBox(height: 8.0),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required String labelText,
    String? hintText, // MODIFICADO para aceitar String?
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    FormFieldValidator<T>? validator,
    bool isExpanded = true,
    bool enabled = true,
    String? errorText,
  }) {
    final bool effectiveEnabled = enabled && !_isLoading && !_isLoadingConfig;

    return DropdownButtonFormField<T>(
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText, // Agora aceita String?
        border: const OutlineInputBorder(),
        filled: !effectiveEnabled,
        fillColor: Theme.of(context).disabledColor.withOpacity(0.05),
        errorText: errorText,
      ),
      value: value,
      isExpanded: isExpanded,
      items: items.map((item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(item.toString(), overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: effectiveEnabled ? onChanged : null,
      validator: effectiveEnabled ? validator : null,
      style: TextStyle(
          color: effectiveEnabled
              ? Theme.of(context).textTheme.titleMedium?.color
              : Theme.of(context).disabledColor),
      iconDisabledColor: Theme.of(context).disabledColor,
      iconEnabledColor: Theme.of(context).colorScheme.primary,
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    FormFieldValidator<String>? validator,
    int maxLines = 1,
    String? hintText,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    Widget? suffixIcon,
    String? helperText,
    int helperMaxLines = 3,
    bool obscureText = false,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool enabled = true,
  }) {
    final bool fieldEnabled = enabled && !_isLoading;
    return TextFormField(
      controller: controller,
      enabled: fieldEnabled,
      decoration: InputDecoration(
          labelText: labelText,
          hintText: hintText,
          border: const OutlineInputBorder(),
          suffixIcon: suffixIcon,
          helperText: helperText,
          helperMaxLines: helperMaxLines,
          filled: !fieldEnabled,
          fillColor: Theme.of(context).disabledColor.withOpacity(0.08)),
      maxLines: maxLines,
      validator: fieldEnabled ? validator : null,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters ?? [],
      obscureText: obscureText,
      textCapitalization: textCapitalization,
    );
  }

  Widget _buildInfoTile(
      {required IconData icon, required String label, required String value}) {
    return ListTile(
      dense: true,
      leading:
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
      title:
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      subtitle: Text(
        value,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w500),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      contentPadding: EdgeInsets.zero,
    );
  }
}

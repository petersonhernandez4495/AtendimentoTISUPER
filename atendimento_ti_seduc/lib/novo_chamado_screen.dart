// lib/novo_chamado_screen.dart
import 'package:atendimento_ti_seduc/main_navigation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

// Importe os novos serviços
import 'services/chamado_service.dart';
import 'services/duplicidade_service.dart';

// --- Mantenha as constantes aqui ou mova para um arquivo dedicado ---
const String kFieldTipoSolicitante = 'tipo_solicitante';
const String kFieldNomeSolicitante = 'nome_solicitante';
const String kFieldCelularContato = 'celular_contato';
const String kFieldCidade = 'cidade';
const String kFieldInstituicao = 'instituicao';
const String kFieldCidadeSuperintendencia = 'cidade_superintendencia';
const String kCollectionChamados = 'chamados';
const String kCollectionConfig = 'configuracoes';
const String kDocOpcoes = 'opcoesChamado';
const String kDocLocalidades = 'localidades';
const String kFieldEscolasPorCidade = 'escolasPorCidade';
const String kFieldInstituicaoManual = 'instituicao_manual';
const String kFieldEquipamentoOutro = 'equipamento_outro_descricao';
const String kFieldProblemaOutro = 'problema_outro_descricao';


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

  // --- Instanciar os serviços ---
  final ChamadoService _chamadoService = ChamadoService();
  final DuplicidadeService _duplicidadeService = DuplicidadeService();

  // --- ESTADO DOS CAMPOS ---
  String? _tipoSelecionado;
  final _celularController = TextEditingController();
  String? _equipamentoSelecionado;
  String? _internetConectadaSelecionado;
  final _marcaModeloController = TextEditingController();
  final _patrimonioController = TextEditingController();
  String? _problemaSelecionado;
  // REMOVIDO: final _tecnicoResponsavelController = TextEditingController();
  String? _cidadeSelecionada;
  String? _instituicaoSelecionada;
  List<String> _instituicoesDisponiveis = [];
  String? _cargoSelecionado;
  String? _atendimentoParaSelecionado;
  bool _isProfessorSelecionado = false;
  String? _setorSuperSelecionado;
  final _cidadeSuperController = TextEditingController();
  final _instituicaoManualController = TextEditingController();
  final _equipamentoOutroController = TextEditingController();
  final _problemaOutroController = TextEditingController();

  // --- DADOS PARA DROPDOWNS ---
  List<String> _tipos = [];
  List<String> _cargosEscola = [];
  List<String> _atendimentosEscola = [];
  List<String> _equipamentos = [];
  List<String> _opcoesSimNao = [];
  List<String> _problemasComuns = [];
  List<String> _setoresSuper = [];
  Map<String, List<String>> _escolasPorCidade = {};
  List<String> _cidadesDisponiveis = [];

  final _phoneMaskFormatter = MaskTextInputFormatter(
      mask: '(##) #####-####',
      filter: {"#": RegExp(r'[0-9]')},
      type: MaskAutoCompletionType.lazy
  );

  @override
  void initState() {
    super.initState();
    _carregarConfiguracoes();
    _preencherDadosUsuario();
  }

  @override
  void dispose() {
    _celularController.dispose();
    _marcaModeloController.dispose();
    _patrimonioController.dispose();
    // REMOVIDO: _tecnicoResponsavelController.dispose();
    _cidadeSuperController.dispose();
    _instituicaoManualController.dispose();
    _equipamentoOutroController.dispose();
    _problemaOutroController.dispose();
    super.dispose();
  }

  // --- LÓGICA DE CARREGAMENTO ---
  Future<void> _carregarConfiguracoes() async {
    print("--- Iniciando _carregarConfiguracoes ---");
    if (!_isLoadingConfig && !_hasLoadingError) { print("--- Carregamento já realizado. Saindo. ---"); return; }
    setState(() { _isLoadingConfig = true; _hasLoadingError = false; });
    try {
      final db = FirebaseFirestore.instance;
      final results = await Future.wait([
        db.collection(kCollectionConfig).doc(kDocOpcoes).get(),
        db.collection(kCollectionConfig).doc(kDocLocalidades).get(),
      ]);
      final docOpcoes = results[0];
      final docLocalidades = results[1];
      Map<String, dynamic>? dataOpcoes = docOpcoes.data();

      List<String> loadedTipos = _parseStringList(dataOpcoes, 'tipos');
      List<String> loadedCargosEscola = _parseStringList(dataOpcoes, 'cargosEscola');
      List<String> loadedAtendimentosEscola = _parseStringList(dataOpcoes, 'atendimentosEscola');
      List<String> loadedEquipamentos = _parseStringList(dataOpcoes, 'equipamentos');
      List<String> loadedOpcoesSimNao = _parseStringList(dataOpcoes, 'opcoesSimNao');
      List<String> loadedProblemasComuns = _parseStringList(dataOpcoes, 'problemasComuns');
      List<String> loadedSetoresSuper = _parseStringList(dataOpcoes, 'setoresSuper');

      if (!loadedEquipamentos.contains("OUTRO")) {
        loadedEquipamentos.add("OUTRO");
        print("WARN: 'OUTRO' adicionado à lista de equipamentos.");
      }
      if (!loadedProblemasComuns.contains("OUTRO")) {
        loadedProblemasComuns.add("OUTRO");
        print("WARN: 'OUTRO' adicionado à lista de problemas comuns.");
      }

      Map<String, dynamic>? dataLocalidades = docLocalidades.data();
      Map<String, List<String>> loadedEscolasPorCidade = {};
      List<String> loadedCidadesDisponiveis = [];

      if (dataLocalidades != null && dataLocalidades.containsKey(kFieldEscolasPorCidade)) {
        dynamic escolasMapData = dataLocalidades[kFieldEscolasPorCidade];
        if (escolasMapData is Map) {
          escolasMapData.forEach((key, value) {
            if (key is String && value != null) {
              List<String> escolas = _parseStringListFromDynamic(value, 'escolas para "$key"');
              if (escolas.isNotEmpty || key == "OUTRO") {
                loadedEscolasPorCidade[key] = escolas..sort();
              }
            }
          });
          if (!loadedEscolasPorCidade.containsKey("OUTRO")) {
            loadedEscolasPorCidade["OUTRO"] = [];
            print("WARN: Chave 'OUTRO' adicionada a 'escolasPorCidade'.");
          }
          loadedCidadesDisponiveis = loadedEscolasPorCidade.keys.toList()..sort();
        }
      }

      bool configEssentialsOk = loadedTipos.isNotEmpty && loadedCidadesDisponiveis.isNotEmpty;
      if (mounted) {
        setState(() {
          if (configEssentialsOk) {
            _tipos = loadedTipos;
            _cargosEscola = loadedCargosEscola;
            _atendimentosEscola = loadedAtendimentosEscola;
            _equipamentos = loadedEquipamentos;
            _opcoesSimNao = loadedOpcoesSimNao;
            _problemasComuns = loadedProblemasComuns;
            _setoresSuper = loadedSetoresSuper;
            _escolasPorCidade = loadedEscolasPorCidade;
            _cidadesDisponiveis = loadedCidadesDisponiveis;
            _hasLoadingError = false;
          } else {
            _hasLoadingError = true;
            ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Erro crítico ao carregar configurações!'), backgroundColor: Colors.red, duration: Duration(seconds: 10)) );
          }
          _isLoadingConfig = false;
        });
      }
    } catch (e, stacktrace) {
      print("--- ERRO INESPERADO ---"); print("Erro CRÍTICO: $e"); print(stacktrace);
      if (mounted) { setState(() { _isLoadingConfig = false; _hasLoadingError = true; }); ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Erro fatal config: ${e.toString()}'), backgroundColor: Colors.red)); }
    }
    print("--- Fim de _carregarConfiguracoes ---");
  }

  List<String> _parseStringList(Map<String, dynamic>? data, String fieldName) { if (data == null || !data.containsKey(fieldName)) { print("WARN (parse): Campo '$fieldName' não encontrado."); return []; } return _parseStringListFromDynamic(data[fieldName], fieldName); }
  List<String> _parseStringListFromDynamic(dynamic data, String fieldDescription) { if (data == null) { print("WARN (parse): Dado nulo para '$fieldDescription'."); return []; } if (data is List) { List<String> result = data .where((item) => item != null) .map((item) => item.toString()) .toList(); if(data.any((item) => item is! String && item != null)){ print("WARN (parse): Itens não-string convertidos em '$fieldDescription'."); } return result; } else { print("WARN (parse): Campo '$fieldDescription' não é Lista/Array. Tipo: ${data.runtimeType}"); return []; } }

  Future<void> _preencherDadosUsuario() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
        try {
          _celularController.text = _phoneMaskFormatter.maskText(user.phoneNumber!);
        } catch (e) {
          print("Erro ao aplicar máscara no telefone do usuário: $e");
          _celularController.text = user.phoneNumber!;
        }
      }
      if (mounted) setState(() {});
    }
  }

  Future<String> _buscarTelefoneUsuario(String userId) async {
    const String fallbackPhone = "Telefone não informado";
    try { final userProfileDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get(); if (userProfileDoc.exists && userProfileDoc.data() != null) { final phone = userProfileDoc.data()!['phone'] as String?; return phone ?? fallbackPhone; } else { return fallbackPhone; } } catch (e) { print("Erro ao buscar telefone: $e"); return fallbackPhone; }
  }

  void _atualizarInstituicoes(String? cidadeSelecionada) {
    setState(() {
      _cidadeSelecionada = cidadeSelecionada;
      _instituicaoSelecionada = null;
      _instituicaoManualController.clear();
      if (cidadeSelecionada != null &&
          cidadeSelecionada != "OUTRO" &&
          _escolasPorCidade.containsKey(cidadeSelecionada)) {
        _instituicoesDisponiveis = List<String>.from(_escolasPorCidade[cidadeSelecionada]!);
      } else {
        _instituicoesDisponiveis = [];
      }
    });
  }

  void _resetDependentFields() {
    _cidadeSelecionada = null;
    _instituicaoSelecionada = null;
    _instituicoesDisponiveis = [];
    _setorSuperSelecionado = null;
    _cargoSelecionado = null;
    _atendimentoParaSelecionado = null;
    _isProfessorSelecionado = false;
    _cidadeSuperController.clear();
    _instituicaoManualController.clear();
    _equipamentoOutroController.clear();
    _problemaOutroController.clear();
    _equipamentoSelecionado = null;
    _problemaSelecionado = null;
  }

  Future<void> _enviarChamado() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, preencha todos os campos obrigatórios.')));
      return;
    }
    if (_tipoSelecionado == 'ESCOLA' && _isProfessorSelecionado) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Atenção: Professores devem solicitar via Coordenação...'),
        duration: Duration(seconds: 7),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    setState(() { _isLoading = true; });

    final String patrimonio = _patrimonioController.text.trim();
    final String? problemaSel = _problemaSelecionado;
    final String problemaOutro = _problemaOutroController.text.trim();

    try {
      if (problemaSel != null) {
        final String? duplicateId = await _duplicidadeService.verificarDuplicidade(
          patrimonio: patrimonio,
          problemaSelecionado: problemaSel,
          problemaOutroDescricao: problemaOutro,
        );

        if (duplicateId != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ERRO: Já existe um chamado ativo (#$duplicateId) para este problema e patrimônio.'),
              backgroundColor: Colors.orange.shade800,
              duration: const Duration(seconds: 8),
            ),
          );
          setState(() { _isLoading = false; });
          return;
        }
      } else {
        print("INFO: Verificação de duplicidade não realizada (problema não selecionado).");
      }

      final String novoChamadoId = await _chamadoService.criarChamado(
        tipoSelecionado: _tipoSelecionado,
        celularContato: _celularController.text,
        equipamentoSelecionado: _equipamentoSelecionado,
        internetConectadaSelecionado: _internetConectadaSelecionado,
        marcaModelo: _marcaModeloController.text.trim(),
        patrimonio: patrimonio,
        problemaSelecionado: problemaSel,
        // REMOVIDO: tecnicoResponsavel: _tecnicoResponsavelController.text.trim(),
        tecnicoResponsavel: '', // Ou null, dependendo de como o serviço trata
        cidadeSelecionada: _cidadeSelecionada,
        instituicaoSelecionada: _instituicaoSelecionada,
        cargoSelecionado: _cargoSelecionado,
        atendimentoParaSelecionado: _atendimentoParaSelecionado,
        isProfessorSelecionado: _isProfessorSelecionado,
        setorSuperSelecionado: _setorSuperSelecionado,
        cidadeSuper: _cidadeSuperController.text.trim(),
        instituicaoManual: _instituicaoManualController.text.trim(),
        equipamentoOutro: _equipamentoOutroController.text.trim(),
        problemaOutro: problemaOutro,
      );

      if (mounted) {
        _resetFormAndNavigate();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Chamado (#$novoChamadoId) aberto com sucesso!'),
            backgroundColor: Colors.green)
        );
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
        setState(() { _isLoading = false; });
      }
    }
  }

  void _resetFormAndNavigate() {
    _formKey.currentState?.reset();
    _celularController.clear();
    _marcaModeloController.clear();
    _patrimonioController.clear();
    // REMOVIDO: _tecnicoResponsavelController.clear();
    _cidadeSuperController.clear();
    _instituicaoManualController.clear();
    _equipamentoOutroController.clear();
    _problemaOutroController.clear();
    setState(() {
      _tipoSelecionado = null;
      _equipamentoSelecionado = null;
      _internetConectadaSelecionado = null;
      _problemaSelecionado = null;
      _resetDependentFields();
      _currentStep = 0;
    });
    _preencherDadosUsuario();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
          (Route<dynamic> route) => false,
    );
  }

  void _handleStepContinue() {
    bool isStepValid = true;
    if (_currentStep == 0) {
      isStepValid = _validateStep1();
    } else if (_currentStep == 1) {
      isStepValid = _validateStep2();
    }

    if (!isStepValid) {
      ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Preencha os campos obrigatórios deste passo.')));
      _formKey.currentState?.validate();
      return;
    }

    if (_currentStep < _buildSteps().length - 1) {
      setState(() { _currentStep += 1; });
    } else {
      _enviarChamado();
    }
  }

  void _handleStepCancel() { if (_currentStep > 0) { setState(() { _currentStep -= 1; }); } }

  bool _validateStep1() {
    if (_tipoSelecionado == null) return false;
    if (_tipoSelecionado == 'ESCOLA') {
      if (_cidadeSelecionada == null) return false;
      if (_cidadeSelecionada == "OUTRO" && _instituicaoManualController.text.trim().isEmpty) return false;
      if (_cidadeSelecionada != "OUTRO" && _instituicaoSelecionada == null) return false;
      if (_cargoSelecionado == null) return false;
      if (_atendimentoParaSelecionado == null) return false;
    } else if (_tipoSelecionado == 'SUPERINTENDENCIA') {
      if (_setorSuperSelecionado == null) return false;
      if (_cidadeSuperController.text.trim().isEmpty) return false;
    }
    return true;
  }

  bool _validateStep2() {
    if (_celularController.text.trim().isEmpty || !_phoneMaskFormatter.isFill()) return false;
    if (_equipamentoSelecionado == null) return false;
    if (_equipamentoSelecionado == "OUTRO" && _equipamentoOutroController.text.trim().isEmpty) return false;
    if (_internetConectadaSelecionado == null) return false;
    if (_patrimonioController.text.trim().isEmpty || _patrimonioController.text.trim() == '0' || int.tryParse(_patrimonioController.text.trim()) == null ) return false;
    if (_problemaSelecionado == null) return false;
    if (_problemaSelecionado == "OUTRO" && _problemaOutroController.text.trim().isEmpty) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingConfig) { return Scaffold( appBar: AppBar(title: const Text('Abrir Novo Chamado')), body: const Center(child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [ CircularProgressIndicator(), SizedBox(height: 16), Text('Carregando configurações...'), ],)), ); }
    if (_hasLoadingError) { return Scaffold( appBar: AppBar(title: const Text('Erro ao Carregar')), body: Center(child: Padding( padding: const EdgeInsets.all(20.0), child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [ Icon(Icons.error_outline, color: Colors.red.shade700, size: 60), const SizedBox(height: 16), const Text('Não foi possível carregar os dados necessários...', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)), const SizedBox(height: 10), const Text('Verifique sua conexão ou a configuração no Firebase.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14)), const SizedBox(height: 25), ElevatedButton.icon( icon: const Icon(Icons.refresh), label: const Text('Tentar Novamente'), style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)), onPressed: _isLoadingConfig ? null : _carregarConfiguracoes, ) ], ), )), ); }

    return Scaffold(
      appBar: AppBar( title: const Text('Abrir Novo Chamado'), automaticallyImplyLeading: _currentStep == 0, ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.disabled,
        child: Stepper(
          type: StepperType.vertical, currentStep: _currentStep,
          onStepContinue: _isLoading ? null : _handleStepContinue,
          onStepCancel: _isLoading ? null : _handleStepCancel,
          onStepTapped: null,
          controlsBuilder: (context, details) {
            return Padding( padding: const EdgeInsets.only(top: 24.0),
              child: Row( children: <Widget>[
                ElevatedButton(
                  onPressed: _isLoading ? null : details.onStepContinue,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12)),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(details.stepIndex == _buildSteps().length - 1 ? 'Enviar Chamado' : 'Próximo'),
                ),
                const SizedBox(width: 12),
                if (details.stepIndex > 0)
                  TextButton( onPressed: _isLoading ? null : details.onStepCancel, child: const Text('Voltar'), ),
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
      if (_hasLoadingError) return StepState.error;
      if (_currentStep > stepIndex) return StepState.complete;
      if (_currentStep == stepIndex) return StepState.editing;
      return StepState.indexed;
    }

    bool isStep1Active = !_hasLoadingError;
    bool isStep2Active = _currentStep >= 1 && !_hasLoadingError && _tipoSelecionado != null;

    return [
      Step(
        title: const Text('1. Identificação e Local'),
        content: _buildStep1Content(),
        isActive: isStep1Active,
        state: getStepState(0),
      ),
      Step(
        title: const Text('2. Equipamento e Problema'),
        content: _tipoSelecionado != null
            ? _buildStep2Content()
            : _buildStepPlaceholder("Selecione o tipo de solicitante no passo anterior para continuar."),
        isActive: isStep2Active,
        state: getStepState(1),
      ),
    ];
  }

  Widget _buildStepPlaceholder(String message) {
    return Container( padding: const EdgeInsets.symmetric(vertical: 30.0, horizontal: 10.0), alignment: Alignment.center, decoration: BoxDecoration( color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3), borderRadius: BorderRadius.circular(8), border: Border.all(color: Theme.of(context).disabledColor.withOpacity(0.2)) ), child: Text( message, style: TextStyle(fontStyle: FontStyle.italic, color: Theme.of(context).disabledColor, fontSize: 14, height: 1.4), textAlign: TextAlign.center, ), );
  }

  Widget _buildStep1Content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildDropdown<String>(
          labelText: '',
          hintText: 'Selecione Escola ou Superintendência*',
          value: _tipoSelecionado,
          items: _tipos,
          onChanged: (newValue) {
            if (_tipoSelecionado != newValue) {
              setState(() { _tipoSelecionado = newValue; _resetDependentFields(); });
            }
          },
          validator: (value) => value == null ? 'Selecione o tipo' : null,
        ),
        const SizedBox(height: 20.0),

        if (_tipoSelecionado == 'ESCOLA') ...[
          _buildDropdown<String>( labelText: 'Cidade/Distrito*', hintText: 'Selecione a cidade', value: _cidadeSelecionada, items: _cidadesDisponiveis, onChanged: _atualizarInstituicoes, validator: (value) => (_tipoSelecionado == 'ESCOLA' && value == null) ? 'Selecione a cidade' : null, ),
          const SizedBox(height: 16.0),
          if (_cidadeSelecionada == "OUTRO")
            _buildTextFormField(
              controller: _instituicaoManualController,
              labelText: 'Nome da Instituição (Escola)*',
              hintText: 'Digite o nome completo da escola',
              validator: (value) {
                if (_tipoSelecionado == 'ESCOLA' && _cidadeSelecionada == "OUTRO" && (value == null || value.trim().isEmpty)) {
                  return 'Informe o nome da instituição';
                }
                return null;
              },
              textCapitalization: TextCapitalization.words,
            )
          else
            _buildDropdown<String>(
              labelText: 'Instituição (Escola)*',
              hintText: _cidadeSelecionada == null ? 'Primeiro selecione a cidade' : 'Selecione a instituição',
              value: _instituicaoSelecionada,
              items: _instituicoesDisponiveis,
              enabled: _cidadeSelecionada != null && _cidadeSelecionada != "OUTRO",
              onChanged: (newValue) { setState(() { _instituicaoSelecionada = newValue; }); },
              validator: (value) {
                if (_tipoSelecionado == 'ESCOLA' &&
                    _cidadeSelecionada != null &&
                    _cidadeSelecionada != "OUTRO" &&
                    value == null) {
                  return 'Selecione a instituição';
                }
                return null;
              },
            ),
          const SizedBox(height: 16.0),
          _buildDropdown<String>( labelText: 'Seu cargo ou função*', hintText: 'Selecione seu cargo', value: _cargoSelecionado, items: _cargosEscola, onChanged: (newValue) { setState(() { _cargoSelecionado = newValue; _isProfessorSelecionado = (newValue == 'PROFESSOR'); }); }, validator: (value) => (_tipoSelecionado == 'ESCOLA' && value == null) ? 'Selecione o cargo' : null, ),
          if (_isProfessorSelecionado) Padding( padding: const EdgeInsets.only(top: 10.0, bottom: 6.0), child: Container( padding: const EdgeInsets.all(10), decoration: BoxDecoration( color: Colors.orange.withOpacity(0.1), border: Border.all(color: Colors.orange.shade300), borderRadius: BorderRadius.circular(4) ), child: Text( 'Atenção: Professores devem solicitar via Coordenação...', style: TextStyle(color: Colors.orange.shade900, fontSize: 13, height: 1.3), ), ), ),
          const SizedBox(height: 16.0),
          _buildDropdown<String>( labelText: 'Atendimento técnico para:*', hintText: 'Selecione o setor', value: _atendimentoParaSelecionado, items: _atendimentosEscola, onChanged: (v) => setState(() => _atendimentoParaSelecionado = v), validator: (value) => (_tipoSelecionado == 'ESCOLA' && value == null) ? 'Selecione o setor' : null, ),
        ],

        if (_tipoSelecionado == 'SUPERINTENDENCIA') ...[
          _buildDropdown<String>( labelText: 'Em qual sala/setor da SUPER?*', hintText: 'Selecione seu setor', value: _setorSuperSelecionado, items: _setoresSuper, onChanged: (v) => setState(() => _setorSuperSelecionado = v), validator: (value) => (_tipoSelecionado == 'SUPERINTENDENCIA' && value == null) ? 'Selecione o setor' : null, isExpanded: true, ),
          const SizedBox(height: 16.0),
          _buildTextFormField( controller: _cidadeSuperController, labelText: 'Cidade da Superintendência*', hintText: 'Digite o nome da cidade', validator: (value) { if (_tipoSelecionado == 'SUPERINTENDENCIA' && (value == null || value.trim().isEmpty)) { return 'Informe a cidade da Superintendência'; } return null; }, keyboardType: TextInputType.text, textCapitalization: TextCapitalization.words, ),
        ],
        const SizedBox(height: 8.0),
      ],
    );
  }

  Widget _buildStep2Content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildTextFormField( controller: _celularController, labelText: 'Número de celular para contato*', hintText: '(XX) XXXXX-XXXX', validator: (v) { if (v == null || v.trim().isEmpty) return 'Digite um número de celular'; if (!_phoneMaskFormatter.isFill()) return 'Número de celular incompleto'; return null; }, keyboardType: TextInputType.phone, inputFormatters: [_phoneMaskFormatter], ),
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
          validator: (v) => v == null ? 'Selecione o tipo de equipamento' : null,
        ),
        if (_equipamentoSelecionado == "OUTRO") ...[
          const SizedBox(height: 16.0),
          _buildTextFormField(
            controller: _equipamentoOutroController,
            labelText: 'Especifique o equipamento*',
            hintText: 'Descreva qual é o equipamento',
            validator: (v) => (_equipamentoSelecionado == "OUTRO" && (v == null || v.trim().isEmpty)) ? 'Especifique o equipamento' : null,
            maxLines: 2,
          ),
        ],
        const SizedBox(height: 16.0),
        _buildDropdown<String>( labelText: 'O equipamento está com internet conectada?*', hintText: 'Selecione Sim ou Não', value: _internetConectadaSelecionado, items: _opcoesSimNao, onChanged: (v) => setState(() => _internetConectadaSelecionado = v), validator: (v) => v == null ? 'Informe se há conexão' : null, ),
        const SizedBox(height: 16.0),
        _buildTextFormField( controller: _marcaModeloController, labelText: 'Marca/Modelo do equipamento? (Opcional)', hintText: 'Ex: Dell Optiplex 3080, Positivo N250i', ),
        const SizedBox(height: 16.0),
        _buildTextFormField( controller: _patrimonioController, labelText: 'Número de Patrimônio (Tombamento)?*', hintText: 'Digite apenas números', validator: (v) { if (v == null || v.trim().isEmpty) return 'Informe o nº de patrimônio'; if (v.trim() == '0') return 'Patrimônio não pode ser 0'; final number = int.tryParse(v.trim()); if (number == null) return 'Digite apenas números'; return null; }, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], helperText: 'Caso não encontre a etiqueta, solicite à direção/secretaria a consulta no sistema.', helperMaxLines: 3, ),
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
            validator: (v) => (_problemaSelecionado == "OUTRO" && (v == null || v.trim().isEmpty)) ? 'Descreva o problema' : null,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
        // REMOVIDO: Campo Técnico Responsável
        // const SizedBox(height: 16.0),
        // _buildTextFormField( controller: _tecnicoResponsavelController, labelText: 'Técnico Responsável (Opcional)', hintText: 'Se souber, indique um técnico', ),
        const SizedBox(height: 8.0),
      ],
    );
  }

  Widget _buildDropdown<T>({ required String labelText, required String hintText, required T? value, required List<T> items, required ValueChanged<T?> onChanged, FormFieldValidator<T>? validator, bool isExpanded = true, bool enabled = true,}) {
    final effectiveOnChanged = enabled && !_isLoading ? onChanged : null; final bool fieldEnabled = enabled && !_isLoading;
    return DropdownButtonFormField<T>( decoration: InputDecoration( labelText: labelText, hintText: hintText, ), value: value, isExpanded: isExpanded, items: items.map((item) { return DropdownMenuItem<T>( value: item, child: Text(item.toString(), overflow: TextOverflow.ellipsis), ); }).toList(), onChanged: effectiveOnChanged, validator: fieldEnabled ? validator : null,
      style: TextStyle( color: fieldEnabled ? Theme.of(context).textTheme.titleMedium?.color : Theme.of(context).disabledColor),
    );
  }

  Widget _buildTextFormField({ required TextEditingController controller, required String labelText, FormFieldValidator<String>? validator, int maxLines = 1, String? hintText, TextInputType? keyboardType, List<TextInputFormatter>? inputFormatters, Widget? suffixIcon, String? helperText, int helperMaxLines = 3, bool obscureText = false, TextCapitalization textCapitalization = TextCapitalization.none, }) {
    final bool fieldEnabled = !_isLoading;
    return TextFormField( controller: controller, enabled: fieldEnabled, decoration: InputDecoration( labelText: labelText, hintText: hintText, suffixIcon: suffixIcon, helperText: helperText, helperMaxLines: helperMaxLines, ), maxLines: maxLines, validator: fieldEnabled ? validator : null, keyboardType: keyboardType, inputFormatters: inputFormatters ?? [], obscureText: obscureText, textCapitalization: textCapitalization, );
  }
} // Fim da classe _NovoChamadoScreenState

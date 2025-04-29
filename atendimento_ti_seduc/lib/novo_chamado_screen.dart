// lib/novo_chamado_screen.dart
import 'package:atendimento_ti_seduc/main_navigation_screen.dart'; // Verifique se o caminho está correto
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

// --- Constantes ---
const String kFieldTipoSolicitante = 'tipo_solicitante';
const String kFieldNomeSolicitante = 'nome_solicitante';
const String kFieldCelularContato = 'celular_contato';
const String kFieldCidade = 'cidade';
const String kFieldInstituicao = 'instituicao';
const String kCollectionChamados = 'chamados';
const String kCollectionConfig = 'configuracoes'; // Coleção das configurações
const String kDocOpcoes = 'opcoesChamado';     // Documento com listas gerais
const String kDocLocalidades = 'localidades';   // Documento com cidades/escolas
const String kFieldEscolasPorCidade = 'escolasPorCidade'; // Campo Map dentro de localidades

class NovoChamadoScreen extends StatefulWidget {
  const NovoChamadoScreen({super.key});

  @override
  State<NovoChamadoScreen> createState() => _NovoChamadoScreenState();
}

class _NovoChamadoScreenState extends State<NovoChamadoScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false; // Loading para envio do formulário
  bool _isLoadingConfig = true; // Loading inicial das configurações
  bool _hasLoadingError = false; // Estado para indicar erro crítico no carregamento

  // --- Controle do Stepper ---
  int _currentStep = 0;

  // --- ESTADO DOS CAMPOS (Controladores e Seleções) ---
  String? _tipoSelecionado;
  final _nomeController = TextEditingController();
  final _celularController = TextEditingController();
  String? _equipamentoSelecionado;
  String? _internetConectadaSelecionado;
  final _marcaModeloController = TextEditingController();
  final _patrimonioController = TextEditingController();
  String? _problemaSelecionado;
  final _tecnicoResponsavelController = TextEditingController();
  String? _cidadeSelecionada;
  String? _instituicaoSelecionada;
  List<String> _instituicoesDisponiveis = [];
  String? _cargoSelecionado;
  String? _atendimentoParaSelecionado;
  bool _isProfessorSelecionado = false;
  String? _setorSuperSelecionado;

  // --- DADOS PARA DROPDOWNS (Carregados do Firebase) ---
  List<String> _tipos = [];
  List<String> _cargosEscola = [];
  List<String> _atendimentosEscola = [];
  List<String> _equipamentos = [];
  List<String> _opcoesSimNao = [];
  List<String> _problemasComuns = [];
  List<String> _setoresSuper = [];
  Map<String, List<String>> _escolasPorCidade = {};
  List<String> _cidadesDisponiveis = [];

  // Formatador de máscara para celular
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
    _nomeController.dispose();
    _celularController.dispose();
    _marcaModeloController.dispose();
    _patrimonioController.dispose();
    _tecnicoResponsavelController.dispose();
    super.dispose();
  }

 // --- LÓGICA DE CARREGAMENTO DE CONFIGURAÇÕES DO FIREBASE ---
  Future<void> _carregarConfiguracoes() async {
    print("--- Iniciando _carregarConfiguracoes ---");
    if (!_isLoadingConfig && !_hasLoadingError) {
        print("--- Carregamento já realizado com sucesso. Saindo. ---");
        return;
    }

    setState(() {
      _isLoadingConfig = true;
      _hasLoadingError = false;
    });

    try {
      final db = FirebaseFirestore.instance;
      print("--- Buscando documentos no Firestore... ---");
      final results = await Future.wait([
        db.collection(kCollectionConfig).doc(kDocOpcoes).get(),
        db.collection(kCollectionConfig).doc(kDocLocalidades).get(),
      ]);
      print("--- Documentos buscados. Processando... ---");

      final docOpcoes = results[0] as DocumentSnapshot<Map<String, dynamic>>;
      final docLocalidades = results[1] as DocumentSnapshot<Map<String, dynamic>>;

      print("--- Processando doc '$kDocOpcoes' ---");
      Map<String, dynamic>? dataOpcoes = docOpcoes.data();
      print("Dados brutos de '$kDocOpcoes': $dataOpcoes");

      List<String> loadedTipos = _parseStringList(dataOpcoes, 'tipos');
      print("Campo 'tipos' processado. Lista carregada: $loadedTipos");

      List<String> loadedCargosEscola = _parseStringList(dataOpcoes, 'cargosEscola');
      List<String> loadedAtendimentosEscola = _parseStringList(dataOpcoes, 'atendimentosEscola');
      List<String> loadedEquipamentos = _parseStringList(dataOpcoes, 'equipamentos');
      List<String> loadedOpcoesSimNao = _parseStringList(dataOpcoes, 'opcoesSimNao');
      List<String> loadedProblemasComuns = _parseStringList(dataOpcoes, 'problemasComuns');
      List<String> loadedSetoresSuper = _parseStringList(dataOpcoes, 'setoresSuper');

      if (!docOpcoes.exists) {
        print("WARN: Documento '$kDocOpcoes' não encontrado em /$kCollectionConfig");
      }

       print("--- Processando doc '$kDocLocalidades' ---");
      Map<String, dynamic>? dataLocalidades = docLocalidades.data();
      print("Dados brutos de '$kDocLocalidades': $dataLocalidades");

      Map<String, List<String>> loadedEscolasPorCidade = {};
      List<String> loadedCidadesDisponiveis = [];

      if (dataLocalidades != null && dataLocalidades.containsKey(kFieldEscolasPorCidade)) {
         dynamic escolasMapData = dataLocalidades[kFieldEscolasPorCidade];
         print("Campo '$kFieldEscolasPorCidade' encontrado. Tipo: ${escolasMapData.runtimeType}");
         print("Valor bruto de '$kFieldEscolasPorCidade': $escolasMapData");

         if (escolasMapData is Map) {
            print("'$kFieldEscolasPorCidade' é um Mapa. Iterando...");
            escolasMapData.forEach((key, value) {
              print("  Processando chave (cidade): '$key'");
              if (key is String && value != null) {
                 print("    Valor bruto para '$key': $value (Tipo: ${value.runtimeType})");
                 List<String> escolas = _parseStringListFromDynamic(value, 'escolas para cidade "$key"');
                 print("    Lista de escolas processada para '$key': $escolas");
                 if (escolas.isNotEmpty || key == 'Outro') {
                    loadedEscolasPorCidade[key] = escolas..sort();
                 } else {
                    print("    Lista de escolas vazia para '$key' (e não é 'Outro'), não adicionando.");
                 }
              } else {
                 print("  WARN: Chave ou valor inválido no mapa '$kFieldEscolasPorCidade'. Chave: $key (Tipo: ${key.runtimeType}), Valor: $value");
              }
            });
            loadedCidadesDisponiveis = loadedEscolasPorCidade.keys.toList()..sort();
            print("Mapa 'loadedEscolasPorCidade' final: $loadedEscolasPorCidade");
            print("Lista 'loadedCidadesDisponiveis' final: $loadedCidadesDisponiveis");
         } else {
            print("WARN: Campo '$kFieldEscolasPorCidade' em /$kCollectionConfig/$kDocLocalidades não é um Mapa.");
         }
      } else {
         print("WARN: Documento '$kDocLocalidades' não encontrado ou não contém o campo '$kFieldEscolasPorCidade'.");
      }


      print("--- Verificação Crítica ---");
      print("loadedTipos.isNotEmpty: ${loadedTipos.isNotEmpty}");
      print("loadedCidadesDisponiveis.isNotEmpty: ${loadedCidadesDisponiveis.isNotEmpty}");
      bool configEssentialsOk = loadedTipos.isNotEmpty && loadedCidadesDisponiveis.isNotEmpty;
      print("configEssentialsOk: $configEssentialsOk");

      if (mounted) {
        setState(() {
          if (configEssentialsOk) {
            print("--- Atualizando estado com sucesso ---");
            _tipos = loadedTipos; _cargosEscola = loadedCargosEscola; _atendimentosEscola = loadedAtendimentosEscola;
            _equipamentos = loadedEquipamentos; _opcoesSimNao = loadedOpcoesSimNao; _problemasComuns = loadedProblemasComuns;
            _setoresSuper = loadedSetoresSuper; _escolasPorCidade = loadedEscolasPorCidade; _cidadesDisponiveis = loadedCidadesDisponiveis;
            _hasLoadingError = false;
          } else {
             print("--- ERRO DETECTADO: Não foi possível carregar configurações essenciais. Marcando erro. ---");
             _hasLoadingError = true;
             ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Erro crítico ao carregar dados de configuração!'), backgroundColor: Colors.red, duration: Duration(seconds: 10)) );
          }
          _isLoadingConfig = false;
          print("--- setState concluído ---");
        });
      } else {
         print("--- Widget desmontado antes de setState ---");
      }

    } catch (e, stacktrace) {
      print("--- ERRO INESPERADO (Catch Block) ---");
      print("Erro CRÍTICO e Inesperado ao carregar configurações do Firestore: $e");
      print(stacktrace);
      if (mounted) {
         setState(() { _isLoadingConfig = false; _hasLoadingError = true; });
         ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Erro fatal ao carregar configurações: ${e.toString()}'), backgroundColor: Colors.red));
      }
    }
     print("--- Fim de _carregarConfiguracoes ---");
  }

  // --- Funções Auxiliares de Parsing Defensivo ---
  List<String> _parseStringList(Map<String, dynamic>? data, String fieldName) { if (data == null || !data.containsKey(fieldName)) { print("WARN (parse): Campo '$fieldName' não encontrado."); return []; } return _parseStringListFromDynamic(data[fieldName], fieldName); }
  List<String> _parseStringListFromDynamic(dynamic data, String fieldDescription) { if (data == null) { print("WARN (parse): Dado nulo para '$fieldDescription'."); return []; } if (data is List) { List<String> result = data .where((item) => item != null) .map((item) => item.toString()) .toList(); if(data.any((item) => item is! String && item != null)){ print("WARN (parse): Itens não-string convertidos em '$fieldDescription'."); } return result; } else { print("WARN (parse): Campo '$fieldDescription' não é Lista/Array. Tipo: ${data.runtimeType}"); return []; } }

  // Preenche nome/telefone do usuário logado
  Future<void> _preencherDadosUsuario() async {
     final user = FirebaseAuth.instance.currentUser;
     if (user != null) {
       if (user.displayName != null && user.displayName!.isNotEmpty) { _nomeController.text = user.displayName!; }
       if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) { _celularController.text = _phoneMaskFormatter.maskText(user.phoneNumber!); }
       if (mounted) setState(() {});
     }
  }

  // Busca telefone no Firestore (opcional)
  Future<String> _buscarTelefoneUsuario(String userId) async {
     const String fallbackPhone = "Telefone não informado";
     try { final userProfileDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get(); if (userProfileDoc.exists && userProfileDoc.data() != null) { final phone = userProfileDoc.data()!['phone'] as String?; return phone ?? fallbackPhone; } else { return fallbackPhone; } } catch (e) { print("Erro ao buscar telefone: $e"); return fallbackPhone; }
  }

  // Atualiza instituições baseadas na cidade selecionada
  void _atualizarInstituicoes(String? cidadeSelecionada) {
     setState(() { _cidadeSelecionada = cidadeSelecionada; _instituicaoSelecionada = null; if (cidadeSelecionada != null && cidadeSelecionada != "Outro" && _escolasPorCidade.containsKey(cidadeSelecionada)) { _instituicoesDisponiveis = List<String>.from(_escolasPorCidade[cidadeSelecionada]!); } else { _instituicoesDisponiveis = []; } });
  }

  // Reseta campos dependentes ao trocar tipo principal
  void _resetDependentFields() {
     _cidadeSelecionada = null; _instituicaoSelecionada = null; _instituicoesDisponiveis = []; _setorSuperSelecionado = null; _cargoSelecionado = null; _atendimentoParaSelecionado = null; _isProfessorSelecionado = false;
  }

  // --- LÓGICA DE ENVIO ---
  Future<void> _enviarChamado() async {
    if (!_formKey.currentState!.validate()) { ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Por favor, preencha todos os campos obrigatórios.'))); return; }
    if (_tipoSelecionado == 'Escola' && _isProfessorSelecionado) { ScaffoldMessenger.of(context).showSnackBar( const SnackBar( content: Text('Atenção: Professores devem solicitar via Coordenação...'), duration: Duration(seconds: 7), backgroundColor: Colors.orange, ) ); return; }
    setState(() { _isLoading = true; });
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { if (mounted) { ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Erro: Você precisa estar logado.'))); setState(() { _isLoading = false; }); } return; }
    final creatorUid = user.uid; final creatorName = _nomeController.text.trim(); final creatorPhone = _celularController.text.trim(); final unmaskedPhone = _phoneMaskFormatter.getUnmaskedText();
    final dadosChamado = <String, dynamic>{
      kFieldTipoSolicitante: _tipoSelecionado, kFieldNomeSolicitante: creatorName, kFieldCelularContato: creatorPhone, 'celular_contato_unmasked': unmaskedPhone,
      'equipamento_solicitacao': _equipamentoSelecionado, 'equipamento_conectado_internet': _internetConectadaSelecionado, 'marca_modelo_equipamento': _marcaModeloController.text.trim().isEmpty ? null : _marcaModeloController.text.trim(),
      'numero_patrimonio': _patrimonioController.text.trim(), 'problema_ocorre': _problemaSelecionado, 'tecnico_responsavel': _tecnicoResponsavelController.text.trim().isEmpty ? null : _tecnicoResponsavelController.text.trim(),
      'status': 'aberto', 'data_criacao': FieldValue.serverTimestamp(), 'data_atualizacao': FieldValue.serverTimestamp(), 'creatorUid': creatorUid, 'creatorName': creatorName, 'creatorPhone': creatorPhone,
      'authUserDisplayName': user.displayName, 'authUserEmail': user.email,
    };
    if (_tipoSelecionado == 'Escola') {
      dadosChamado[kFieldCidade] = _cidadeSelecionada; dadosChamado[kFieldInstituicao] = (_cidadeSelecionada == 'Outro') ? 'Outro (Especificar na descrição)' : _instituicaoSelecionada;
      dadosChamado['cargo_funcao'] = _cargoSelecionado; dadosChamado['atendimento_para'] = _atendimentoParaSelecionado;
      if (_isProfessorSelecionado) { dadosChamado['observacao_cargo'] = 'Solicitante é Professor...'; }
    } else if (_tipoSelecionado == 'Superintendência') {
      dadosChamado['setor_superintendencia'] = _setorSuperSelecionado;
    }
    try {
      final chamadosCollection = FirebaseFirestore.instance.collection(kCollectionChamados);
      await chamadosCollection.add(dadosChamado);
      if (mounted) {
        _formKey.currentState?.reset(); _nomeController.clear(); _celularController.clear(); _marcaModeloController.clear(); _patrimonioController.clear(); _tecnicoResponsavelController.clear();
        setState(() { _tipoSelecionado = null; _equipamentoSelecionado = null; _internetConectadaSelecionado = null; _problemaSelecionado = null; _resetDependentFields(); _currentStep = 0; });
        _preencherDadosUsuario();
        ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Chamado aberto com sucesso!'), backgroundColor: Colors.green) );
        Navigator.of(context).pushAndRemoveUntil( MaterialPageRoute(builder: (context) => const MainNavigationScreen()), (Route<dynamic> route) => false, );
      }
    } catch (error) {
       print('Erro ao abrir chamado: $error');
       if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar( content: Text('Erro ao salvar chamado. Verifique sua conexão...'), backgroundColor: Colors.red) ); }
    } finally { if (mounted) { setState(() { _isLoading = false; }); } }
  }

  // --- Funções de Controle do Stepper ---
  void _handleStepContinue() { if (_currentStep < _buildSteps().length - 1) { setState(() { _currentStep += 1; }); } else { _enviarChamado(); } }
  void _handleStepCancel() { if (_currentStep > 0) { setState(() { _currentStep -= 1; }); } }

  // --- BUILD PRINCIPAL com Stepper ---
  @override
  Widget build(BuildContext context) {
    if (_isLoadingConfig) { return Scaffold( appBar: AppBar(title: const Text('Abrir Novo Chamado')), body: const Center(child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [ CircularProgressIndicator(), SizedBox(height: 16), Text('Carregando configurações...'), ],)), ); }
    if (_hasLoadingError) { return Scaffold( appBar: AppBar(title: const Text('Erro ao Carregar')), body: Center(child: Padding( padding: const EdgeInsets.all(20.0), child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [ Icon(Icons.error_outline, color: Colors.red.shade700, size: 60), const SizedBox(height: 16), const Text('Não foi possível carregar os dados necessários...', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)), const SizedBox(height: 10), const Text('Verifique sua conexão ou a configuração no Firebase.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14)), const SizedBox(height: 25), ElevatedButton.icon( icon: const Icon(Icons.refresh), label: const Text('Tentar Novamente'), style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)), onPressed: _isLoadingConfig ? null : _carregarConfiguracoes, ) ], ), )), ); }

    return Scaffold(
      appBar: AppBar( title: const Text('Abrir Novo Chamado'), automaticallyImplyLeading: _currentStep == 0, ),
      body: Form( key: _formKey, autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Stepper(
          type: StepperType.vertical, currentStep: _currentStep,
          onStepContinue: _isLoading ? null : _handleStepContinue, onStepCancel: _isLoading ? null : _handleStepCancel,
          onStepTapped: null, // Desabilitado
          controlsBuilder: (context, details) {
             return Padding( padding: const EdgeInsets.only(top: 24.0),
               child: Row( children: <Widget>[
                   ElevatedButton( onPressed: _isLoading ? null : details.onStepContinue, style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12)), child: Text(details.stepIndex == _buildSteps().length - 1 ? 'Enviar Chamado' : 'Próximo'), ),
                   const SizedBox(width: 12),
                   if (details.stepIndex > 0) TextButton( onPressed: _isLoading ? null : details.onStepCancel, child: const Text('Voltar'), ),
                 ],
               ),
             );
           },
          steps: _buildSteps(),
        ),
      ),
    );
  }

  // --- Define os Passos do Stepper ---
  List<Step> _buildSteps() {
    StepState getStepState(int stepIndex) { if (_hasLoadingError) return StepState.error; if (_currentStep > stepIndex) return StepState.complete; if (_currentStep == stepIndex) return StepState.editing; return StepState.indexed; }
    bool isStep1Active = !_hasLoadingError; bool isStep2Active = _currentStep >= 1 && !_hasLoadingError && _tipoSelecionado != null;
    return [
      Step( title: const Text('1. Identificação e Local'), content: _buildStep1Content(), isActive: isStep1Active, state: getStepState(0), ),
      Step( title: const Text('2. Equipamento e Problema'), content: _tipoSelecionado != null ? _buildStep2Content() : _buildStepPlaceholder("Selecione o tipo de solicitante no passo anterior para continuar."), isActive: isStep2Active, state: getStepState(1), ),
    ];
  }

  // --- Conteúdo dos Passos (Widgets) ---
  Widget _buildStepPlaceholder(String message) {
     return Container( padding: const EdgeInsets.symmetric(vertical: 30.0, horizontal: 10.0), alignment: Alignment.center, decoration: BoxDecoration( color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3), borderRadius: BorderRadius.circular(8), border: Border.all(color: Theme.of(context).disabledColor.withOpacity(0.2)) ), child: Text( message, style: TextStyle(fontStyle: FontStyle.italic, color: Theme.of(context).disabledColor, fontSize: 14, height: 1.4), textAlign: TextAlign.center, ), );
  }

  Widget _buildStep1Content() {
    return Column( crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
        _buildDropdown<String>( labelText: 'Você é de:*', hintText: 'Selecione Escola ou Superintendência', value: _tipoSelecionado, items: _tipos, onChanged: (newValue) { if (_tipoSelecionado != newValue) { setState(() { _tipoSelecionado = newValue; _resetDependentFields(); }); } }, validator: (value) => value == null ? 'Selecione o tipo' : null, ),
        const SizedBox(height: 20.0),
        if (_tipoSelecionado == 'Escola') ...[
          _buildDropdown<String>( labelText: 'Cidade/Distrito*', hintText: 'Selecione a cidade da escola', value: _cidadeSelecionada, items: _cidadesDisponiveis, onChanged: _atualizarInstituicoes, validator: (value) => (_tipoSelecionado == 'Escola' && value == null) ? 'Selecione a cidade' : null, ),
          const SizedBox(height: 16.0),
          _buildDropdown<String>( labelText: 'Instituição (Escola)*', hintText: _cidadeSelecionada == null ? 'Selecione uma cidade primeiro' : (_cidadeSelecionada == 'Outro' ? 'Cidade "Outro" selecionada' : 'Selecione a instituição'), value: _instituicaoSelecionada, items: _instituicoesDisponiveis, enabled: _cidadeSelecionada != null && _cidadeSelecionada != 'Outro', onChanged: (newValue) { setState(() { _instituicaoSelecionada = newValue; }); }, validator: (_tipoSelecionado == 'Escola' && _cidadeSelecionada != null && _cidadeSelecionada != 'Outro' && _instituicaoSelecionada == null) ? (value) => 'Selecione a instituição' : null, ),
          const SizedBox(height: 16.0),
          _buildDropdown<String>( labelText: 'Seu cargo ou função*', hintText: 'Selecione seu cargo na escola', value: _cargoSelecionado, items: _cargosEscola, onChanged: (newValue) { setState(() { _cargoSelecionado = newValue; _isProfessorSelecionado = (newValue == 'PROFESSOR'); }); }, validator: (value) => (_tipoSelecionado == 'Escola' && value == null) ? 'Selecione o cargo' : null, ),
           if (_isProfessorSelecionado) Padding( padding: const EdgeInsets.only(top: 10.0, bottom: 6.0), child: Container( padding: const EdgeInsets.all(10), decoration: BoxDecoration( color: Colors.orange.withOpacity(0.1), border: Border.all(color: Colors.orange.shade300), borderRadius: BorderRadius.circular(4) ), child: Text( 'Atenção: Professores devem solicitar via Coordenação...', style: TextStyle(color: Colors.orange.shade900, fontSize: 13, height: 1.3), ), ), ),
          const SizedBox(height: 16.0),
          _buildDropdown<String>( labelText: 'Atendimento técnico para:*', hintText: 'Para qual setor da escola?', value: _atendimentoParaSelecionado, items: _atendimentosEscola, onChanged: (v) => setState(() => _atendimentoParaSelecionado = v), validator: (value) => (_tipoSelecionado == 'Escola' && value == null) ? 'Selecione o setor' : null, ),
        ],
        if (_tipoSelecionado == 'Superintendência') ...[
          _buildDropdown<String>( labelText: 'Em qual sala/setor da SUPER?*', hintText: 'Selecione seu setor', value: _setorSuperSelecionado, items: _setoresSuper, onChanged: (v) => setState(() => _setorSuperSelecionado = v), validator: (value) => (_tipoSelecionado == 'Superintendência' && value == null) ? 'Selecione o setor' : null, isExpanded: true, ),
        ],
         const SizedBox(height: 8.0),
      ],
    );
  }

  Widget _buildStep2Content() {
    return Column( crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
         _buildTextFormField(
           controller: _nomeController,
           labelText: 'Digite seu nome completo',
           // hintText removido para evitar redundância
           validator: (v) => (v == null || v.trim().isEmpty) ? '' : null,
         ),
         const SizedBox(height: 16.0),
         _buildTextFormField(
           controller: _celularController,
           labelText: 'Número de celular para contato*',
           hintText: '(XX) XXXXX-XXXX', // Hint mantido (útil para formato)
           validator: (v) { if (v == null || v.trim().isEmpty) return ''; if (!_phoneMaskFormatter.isFill()) return 'Número de celular incompleto'; return null; },
           keyboardType: TextInputType.phone, inputFormatters: [_phoneMaskFormatter],
         ),
         const SizedBox(height: 16.0),
         _buildDropdown<String>(
           labelText: 'Para qual equipamento é a solicitação?*',
           hintText: '', // Hint padrão mantido
           value: _equipamentoSelecionado, items: _equipamentos, onChanged: (v) => setState(() => _equipamentoSelecionado = v), validator: (v) => v == null ? 'Selecione o tipo de equipamento' : null,
         ),
         const SizedBox(height: 16.0),
         _buildDropdown<String>(
           labelText: 'O equipamento está com internet conectada?*',
           hintText: '', // Hint padrão mantido
           value: _internetConectadaSelecionado, items: _opcoesSimNao, onChanged: (v) => setState(() => _internetConectadaSelecionado = v), validator: (v) => v == null ? 'Informe se há conexão' : null,
         ),
         const SizedBox(height: 16.0),
         _buildTextFormField(
           controller: _marcaModeloController,
           labelText: 'Qual é a marca/modelo do equipamento? (Opcional)',
           hintText: 'Ex: Dell Optiplex 3080, Positivo Master N250i', // Hint mantido (exemplo útil)
         ),
         const SizedBox(height: 16.0),
         _buildTextFormField(
           controller: _patrimonioController,
           labelText: 'Qual número de patrimônio (tombamento)?*',
           hintText: 'Digite apenas números', // Hint mantido (instrução útil)
           validator: (v) { if (v == null || v.trim().isEmpty) return 'Informe o número de patrimônio'; if (v.trim() == '0') return 'O número de patrimônio não pode ser 0'; final number = int.tryParse(v.trim()); if (number == null) return 'Digite apenas números válidos'; return null; },
           keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly],
           helperText: '', helperMaxLines: 3,
         ),
         const SizedBox(height: 16.0),
         _buildDropdown<String>(
           labelText: 'Qual o problema que está ocorrendo?*',
           hintText: '', // Hint padrão mantido
           value: _problemaSelecionado, items: _problemasComuns, onChanged: (v) => setState(() => _problemaSelecionado = v), validator: (v) => v == null ? 'Selecione o problema' : null,
         ),
         const SizedBox(height: 16.0),
         _buildTextFormField(
           controller: _tecnicoResponsavelController,
           labelText: 'Técnico Responsável (Opcional)',
           hintText: '', // Hint mantido (instrução)
         ),
         const SizedBox(height: 8.0),
      ],
    );
  }

  // --- Widgets Auxiliares (_buildDropdown, _buildTextFormField) ---
  Widget _buildDropdown<T>({ required String labelText, required String hintText, required T? value, required List<T> items, required ValueChanged<T?> onChanged, FormFieldValidator<T>? validator, bool isExpanded = true, bool enabled = true,}) {
     final effectiveOnChanged = enabled && !_isLoading ? onChanged : null; final bool fieldEnabled = enabled && !_isLoading;
     return DropdownButtonFormField<T>( decoration: InputDecoration( labelText: labelText, hintText: hintText, border: const OutlineInputBorder(), filled: !fieldEnabled, fillColor: !fieldEnabled ? Colors.grey[200] : null, contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0), ), value: value, isExpanded: isExpanded, items: items.map((item) { return DropdownMenuItem<T>( value: item, child: Text(item.toString(), overflow: TextOverflow.ellipsis), ); }).toList(), onChanged: effectiveOnChanged, validator: fieldEnabled ? validator : null, );
  }

  Widget _buildTextFormField({ required TextEditingController controller, required String labelText, FormFieldValidator<String>? validator, int maxLines = 1, String? hintText, TextInputType? keyboardType, List<TextInputFormatter>? inputFormatters, Widget? suffixIcon, String? helperText, int helperMaxLines = 3, bool obscureText = false, }) {
     final bool fieldEnabled = !_isLoading;
     return TextFormField( controller: controller, enabled: fieldEnabled, decoration: InputDecoration( labelText: labelText, hintText: hintText, border: const OutlineInputBorder(), filled: !fieldEnabled, fillColor: !fieldEnabled ? Colors.grey[200] : null, contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0), suffixIcon: suffixIcon, helperText: helperText, helperMaxLines: helperMaxLines, ), maxLines: maxLines, validator: fieldEnabled ? validator : null, keyboardType: keyboardType, inputFormatters: inputFormatters ?? [], obscureText: obscureText, );
  }

} // Fim da classe _NovoChamadoScreenState
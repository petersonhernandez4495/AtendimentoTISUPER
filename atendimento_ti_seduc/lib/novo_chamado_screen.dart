// lib/novo_chamado_screen.dart
import 'package:atendimento_ti_seduc/main_navigation_screen.dart'; // Verifique se o caminho está correto
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart'; // <<< IMPORT MASK

// --- Constantes (Exemplo) ---
const String kFieldTipoSolicitante = 'tipo_solicitante';
const String kFieldNomeSolicitante = 'nome_solicitante';
const String kFieldCelularContato = 'celular_contato';
const String kFieldCidade = 'cidade';
const String kFieldInstituicao = 'instituicao';
// ... adicione outras constantes conforme necessário

class NovoChamadoScreen extends StatefulWidget {
  const NovoChamadoScreen({super.key});

  @override
  State<NovoChamadoScreen> createState() => _NovoChamadoScreenState();
}

class _NovoChamadoScreenState extends State<NovoChamadoScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false; // Loading para envio do formulário
  bool _isLoadingConfig = true; // Loading para dados iniciais (cidades/escolas)

  // --- CONTROLE PRINCIPAL ---
  String? _tipoSelecionado;
  final List<String> _tipos = ['Escola', 'Superintendência'];

  // --- ESTADO DOS CAMPOS ---
  // Comuns
  final _nomeController = TextEditingController();
  final _celularController = TextEditingController();
  String? _equipamentoSelecionado;
  String? _internetConectadaSelecionado;
  final _marcaModeloController = TextEditingController();
  final _patrimonioController = TextEditingController();
  String? _problemaSelecionado;
  final _tecnicoResponsavelController = TextEditingController();

  // Específicos Escola
  String? _cidadeSelecionada;
  String? _instituicaoSelecionada;
  List<String> _instituicoesDisponiveis = [];
  String? _cargoSelecionado;
  String? _atendimentoParaSelecionado;
  bool _isProfessorSelecionado = false;

  // Específico Superintendência
  String? _setorSuperSelecionado;

  // --- DADOS PARA DROPDOWNS ---
  // Mantido como fallback ou se não for usar Firestore para isso
  final Map<String, List<String>> _hardcodedEscolasPorCidade = {
    'Rolim de Moura': [ 'APAE R. TOCANTINS N°5884, B. BOA ESPERANÇA 3442-1473', /* ... */ 'EEEFM TANCREDO DE ALMEIDA NEVES', ],
    'Nova Brasilândia D\'Oeste': [ 'EEEFM AURÉLIO B. H. FERREIRA', /* ... */ 'CEEJA CECÍLIA MEIRELLES', ],
    'Santa Luzia D\'Oeste': [ 'CEEJA DOMINGOS VONA', /* ... */ 'EEEFM J. K.', ],
    'Novo Horizonte': [ 'CEEJA PROFª BÁRBARA CONCEIÇÃO DOS REIS', /* ... */ 'EEEFM MARECHAL CÂNDIDO RONDON', ],
    'Castanheiras': [ 'EEEFM EUGÊNIO LAZARIN', 'EEEFM FRANCISCA JÚLIA DA SILVA', ],
    'Alta Floresta D\'Oeste': [ 'CEEJA LUIZ VAZ DE CAMÕES', /* ... */ 'EEEFM PADRE EZEQUIEL RAMIN', ],
    'Alto Alegre do Parecis': [ 'EEEFM ARTUR DA COSTA E SILVA', ],
    'Outro': ['Outro (Especificar na descrição do problema)'],
  };

  // Estruturas para dados carregados (se usar Firestore)
  Map<String, List<String>> _escolasPorCidade = {};
  List<String> _cidadesDisponiveis = [];

  // Listas de opções fixas (podem vir do Firestore também se desejado)
  final List<String> _cargosEscola = ['GESTOR', 'SECRETÁRIO ESCOLAR', 'COORDENADOR DE LIE', 'PROFESSOR'];
  final List<String> _atendimentosEscola = ['Administrativo', 'LIE (Laboratório de Informática)', 'Pedagógico (Professores, Orientação, Supervisão)', 'Outro'];
  final List<String> _equipamentos = ['Desktop (Computador de mesa)', 'Notebook (Laptop)', 'Tablet Educacional', 'Lousa Digital', 'Impressora/scanner', 'Rede e Conexão com Internet', 'Outro'];
  final List<String> _opcoesSimNao = ['Sim', 'Não'];
  final List<String> _problemasComuns = [ 'Não Liga / Falha na inicialização', 'Lentidão ou travamento', 'Pacote Office (Word, Excel, Power Point) não funciona', 'Mensagens de Vírus', 'Teclado, Mouse ou monitor não funciona', 'Impressora e/ou Scanner com problemas ou desconectados', 'Sem internet ou problemas com a rede', 'Outro' ];
  final List<String> _setoresSuper = [ 'Lotação', 'Recursos Humanos', 'GFISC', 'NTE', 'Transporte Escolar', 'ADM/Financeiro/Nutrição', 'LIE', 'Inspeção Escolar', 'Pedagógico' ];

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

  // --- LÓGICA DE CARREGAMENTO E PREENCHIMENTO ---

  Future<void> _carregarConfiguracoes() async {
    // Não precisa setar _isLoadingConfig = true aqui, já começa true
    try {
      // --- EXEMPLO: Carregar do Firestore (descomente e adapte) ---
      /*
      final doc = await FirebaseFirestore.instance.collection('configuracoes').doc('localidades').get();
      if (doc.exists && doc.data() != null) {
         final data = doc.data()!['escolasPorCidade'] as Map<String, dynamic>? ?? {};
         _escolasPorCidade = data.map((key, value) {
            final escolasList = List<String>.from(value as List? ?? []);
            escolasList.sort();
            return MapEntry(key, escolasList);
         });
         _cidadesDisponiveis = _escolasPorCidade.keys.toList()..sort();

         // Carregar outras listas (cargos, problemas, etc.) se também vierem do Firestore
         // _cargosEscola = List<String>.from(doc.data()!['cargosEscola'] as List? ?? []);
         // _problemasComuns = List<String>.from(doc.data()!['problemasComuns'] as List? ?? []);
         // ... e assim por diante
      } else {
         print("Documento de configurações não encontrado.");
         // Usar dados hardcoded como fallback se o doc não existir
         _usarDadosHardcoded();
      }
      */

      // --- Fallback para dados hardcoded (REMOVA SE USAR FIRESTORE ACIMA) ---
       _usarDadosHardcoded();
      // --- Fim do Fallback ---

    } catch (e) {
      print("Erro ao carregar configurações: $e");
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro ao carregar dados. Usando valores padrão.'))
         );
      }
      // Usar dados hardcoded como fallback em caso de erro
      _usarDadosHardcoded();
    } finally {
      if (mounted) {
         setState(() { _isLoadingConfig = false; });
      }
    }
  }

  void _usarDadosHardcoded() {
     _escolasPorCidade = _hardcodedEscolasPorCidade.map((key, value) {
        final sortedList = List<String>.from(value)..sort();
        return MapEntry(key, sortedList);
     });
     _cidadesDisponiveis = _escolasPorCidade.keys.toList()..sort();
     // Garante que as outras listas fixas sejam usadas
  }


  Future<void> _preencherDadosUsuario() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Preenche o nome se estiver disponível no perfil do Firebase Auth
      if (user.displayName != null && user.displayName!.isNotEmpty) {
         _nomeController.text = user.displayName!;
      }

      // Tenta preencher o telefone (se disponível no Auth OU buscando no Firestore)
      if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
        // Formata o número do Auth se necessário (pode vir em formato internacional)
         _celularController.text = _phoneMaskFormatter.maskText(user.phoneNumber!);
      } else {
        // Ou tenta buscar do Firestore (sua função original)
        // final phone = await _buscarTelefoneUsuario(user.uid);
        // if (phone != "Telefone não informado") {
        //   _celularController.text = _phoneMaskFormatter.maskText(phone);
        // }
      }
       // Atualiza a UI se algo foi preenchido (importante se a busca for assíncrona)
       if (mounted) setState(() {});
    }
  }

  // Função _buscarTelefoneUsuario (mantida caso precise dela para preenchimento ou outra lógica)
  Future<String> _buscarTelefoneUsuario(String userId) async {
     const String fallbackPhone = "Telefone não informado";
     try {
       final userProfileDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
       if (userProfileDoc.exists && userProfileDoc.data() != null) {
         final phone = userProfileDoc.data()!['phone'] as String?;
         print("Telefone do criador encontrado: $phone");
         return phone ?? fallbackPhone;
       } else {
         print("Documento de perfil não encontrado para UID: $userId");
         return fallbackPhone;
       }
     } catch (e) {
       print("Erro ao buscar telefone do usuário $userId: $e");
       return fallbackPhone;
     }
  }

  // Atualiza lista de instituições quando a cidade muda
  void _atualizarInstituicoes(String? cidadeSelecionada) {
    setState(() {
      _cidadeSelecionada = cidadeSelecionada;
      _instituicaoSelecionada = null; // Reseta a instituição selecionada
      if (cidadeSelecionada != null && cidadeSelecionada != "Outro" && _escolasPorCidade.containsKey(cidadeSelecionada)) {
        _instituicoesDisponiveis = List<String>.from(_escolasPorCidade[cidadeSelecionada]!);
        // A lista já deve estar ordenada pelo _carregarConfiguracoes ou _usarDadosHardcoded
      } else {
        _instituicoesDisponiveis = [];
      }
    });
  }

  // Reseta campos dependentes ao mudar o tipo principal
  void _resetDependentFields() {
     _cidadeSelecionada = null;
     _instituicaoSelecionada = null;
     _instituicoesDisponiveis = [];
     _setorSuperSelecionado = null;
     _cargoSelecionado = null;
     _atendimentoParaSelecionado = null;
     _isProfessorSelecionado = false;
     // Não limpa os controllers comuns aqui, pois eles podem ser mantidos
  }

  // --- LÓGICA DE ENVIO ---
  Future<void> _enviarChamado() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, preencha todos os campos obrigatórios.')));
      return;
    }
    if (_tipoSelecionado == 'Escola' && _isProfessorSelecionado) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar( content: Text('Atenção: Professores devem solicitar via Coordenação Pedagógica, LIE ou Direção/Secretaria.'), duration: Duration(seconds: 7), backgroundColor: Colors.orange, )
       );
      return; // Impede o envio se for professor
    }

    setState(() { _isLoading = true; });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Erro: Você precisa estar logado.')));
       setState(() { _isLoading = false; });
     }
     return;
    }

    final creatorUid = user.uid;
    // Usa o nome do controller, que pode ter sido preenchido ou editado pelo usuário
    final creatorName = _nomeController.text.trim();
    // Usa o telefone do controller (já formatado pela máscara)
    final creatorPhone = _celularController.text.trim();
    // Pega o valor não mascarado se precisar guardar separadamente
    final unmaskedPhone = _phoneMaskFormatter.getUnmaskedText();

    final dadosChamado = <String, dynamic>{
      kFieldTipoSolicitante: _tipoSelecionado, // Usando constante
      kFieldNomeSolicitante: creatorName,      // Usando constante
      kFieldCelularContato: creatorPhone,      // Usando constante (valor mascarado)
      'celular_contato_unmasked': unmaskedPhone, // Opcional: guardar valor sem máscara
      'equipamento_solicitacao': _equipamentoSelecionado,
      'equipamento_conectado_internet': _internetConectadaSelecionado,
      'marca_modelo_equipamento': _marcaModeloController.text.trim().isEmpty ? null : _marcaModeloController.text.trim(),
      'numero_patrimonio': _patrimonioController.text.trim(),
      'problema_ocorre': _problemaSelecionado,
      'tecnico_responsavel': _tecnicoResponsavelController.text.trim().isEmpty ? null : _tecnicoResponsavelController.text.trim(),
      'status': 'aberto',
      'data_criacao': FieldValue.serverTimestamp(),
      'data_atualizacao': FieldValue.serverTimestamp(),
      'creatorUid': creatorUid,
      'creatorName': creatorName, // Nome do solicitante (do formulário)
      'creatorPhone': creatorPhone, // Telefone do solicitante (do formulário)
      'authUserDisplayName': user.displayName, // Nome do usuário autenticado
      'authUserEmail': user.email,           // Email do usuário autenticado
    };

    if (_tipoSelecionado == 'Escola') {
      dadosChamado[kFieldCidade] = _cidadeSelecionada; // Usando constante
      dadosChamado[kFieldInstituicao] = (_cidadeSelecionada == 'Outro')
          ? 'Outro (Especificar na descrição)'
          : _instituicaoSelecionada; // Usando constante
      dadosChamado['cargo_funcao'] = _cargoSelecionado;
      dadosChamado['atendimento_para'] = _atendimentoParaSelecionado;
      if (_isProfessorSelecionado) {
         dadosChamado['observacao_cargo'] = 'Solicitante é Professor (abertura não recomendada diretamente).';
      }
    } else if (_tipoSelecionado == 'Superintendência') {
      dadosChamado['setor_superintendencia'] = _setorSuperSelecionado;
    }

    try {
      final chamadosCollection = FirebaseFirestore.instance.collection('chamados');
      await chamadosCollection.add(dadosChamado);

      if (mounted) {
        // Limpa os campos após sucesso
        _formKey.currentState?.reset(); // Reseta estado de validação
        _nomeController.clear();
        _celularController.clear();
        _marcaModeloController.clear();
        _patrimonioController.clear();
        _tecnicoResponsavelController.clear();
        setState(() {
          _tipoSelecionado = null;
          _equipamentoSelecionado = null;
          _internetConectadaSelecionado = null;
          _problemaSelecionado = null;
          _resetDependentFields(); // Limpa campos dependentes (cidade, escola, setor, etc.)
        });
         _preencherDadosUsuario(); // Re-preenche nome/telefone padrão se aplicável

        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chamado aberto com sucesso!')));

        // Navega para a tela principal e remove as anteriores
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
              (Route<dynamic> route) => false,
        );
      }
    } catch (error) {
      print('Erro ao abrir chamado: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Erro ao abrir chamado. Tente novamente.')));
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  // --- WIDGET BUILDERS AUXILIARES (Dropdown e TextFormField - sem alterações) ---
  Widget _buildDropdown<T>({
    required String labelText,
    required String hintText,
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    FormFieldValidator<T>? validator,
    bool isExpanded = true,
    bool enabled = true,
  }) {
    // Desabilita onChanged se o campo estiver desabilitado OU se o formulário estiver enviando
    final effectiveOnChanged = enabled && !_isLoading ? onChanged : null;

    return DropdownButtonFormField<T>(
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        border: const OutlineInputBorder(),
        filled: !enabled || _isLoading, // Preenche se desabilitado ou carregando
        fillColor: !enabled || _isLoading ? Colors.grey[200] : null, // Cor de fundo
        contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
      ),
      value: value,
      isExpanded: isExpanded,
      items: items.map((item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(item.toString(), overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: effectiveOnChanged,
      validator: enabled ? validator : null, // Só valida se habilitado
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
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_isLoading, // Desabilita durante o envio
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        border: const OutlineInputBorder(),
        filled: _isLoading, // Preenche se carregando
        fillColor: _isLoading ? Colors.grey[200] : null, // Cor de fundo
        contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
        suffixIcon: suffixIcon,
        helperText: helperText,
        helperMaxLines: helperMaxLines,
      ),
      maxLines: maxLines,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters ?? [],
    );
  }

 // --- MÉTODOS BUILD PRINCIPAIS (Refatorados com Cards) ---

  @override
  Widget build(BuildContext context) {
    // Mostra loading geral enquanto carrega configurações iniciais
    if (_isLoadingConfig) {
      return Scaffold(
        appBar: AppBar(title: const Text('Abrir Novo Chamado')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Constrói a tela principal após carregar as configs
    return Scaffold(
      appBar: AppBar(
        title: const Text('Abrir Novo Chamado'),
        automaticallyImplyLeading: false, // Ou true se quiser botão voltar padrão
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0), // Padding geral menor para acomodar Cards
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction, // Validação interativa
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _buildTipoSolicitanteCard(),
                const SizedBox(height: 8), // Espaço entre cards

                // Mostra os cards de localização e detalhes apenas se um tipo foi selecionado
                if (_tipoSelecionado != null) ...[
                   _buildLocalizacaoCard(),
                   const SizedBox(height: 8),
                   _buildDetalhesCard(),
                   const SizedBox(height: 16),
                   _buildSubmitButton(), // Botão de envio
                   const SizedBox(height: 16),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Card para seleção do tipo de solicitante
  Widget _buildTipoSolicitanteCard() {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Identificação', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16.0),
            _buildDropdown<String>(
              labelText: 'Você é de:*',
              hintText: 'Selecione Escola ou Superintendência',
              value: _tipoSelecionado,
              items: _tipos,
              onChanged: (newValue) {
                setState(() {
                  _tipoSelecionado = newValue;
                  _resetDependentFields(); // Limpa campos dependentes ao trocar
                });
              },
              validator: (value) => value == null ? 'Selecione o tipo' : null,
            ),
          ],
        ),
      ),
    );
  }

  // Card para campos de localização (Escola ou Superintendência)
  Widget _buildLocalizacaoCard() {
     return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Text('Localização', style: Theme.of(context).textTheme.titleLarge),
             const SizedBox(height: 16.0),

              // --- CAMPOS CONDICIONAIS PARA "ESCOLA" ---
              if (_tipoSelecionado == 'Escola') ...[
                _buildDropdown<String>(
                  labelText: 'Cidade/Distrito*',
                  hintText: 'Selecione a cidade da escola',
                  value: _cidadeSelecionada,
                  items: _cidadesDisponiveis, // Usa a lista carregada/ordenada
                  onChanged: _atualizarInstituicoes,
                  validator: (value) => value == null ? 'Selecione a cidade' : null,
                ),
                const SizedBox(height: 16.0),
                _buildDropdown<String>(
                  labelText: 'Instituição (Escola)*',
                  hintText: _cidadeSelecionada == null
                      ? 'Selecione uma cidade primeiro'
                      : (_cidadeSelecionada == 'Outro'
                      ? 'Cidade "Outro" selecionada (especifique no problema)'
                      : 'Selecione a instituição'),
                  value: _instituicaoSelecionada,
                  items: _instituicoesDisponiveis,
                  enabled: _cidadeSelecionada != null && _cidadeSelecionada != 'Outro',
                  onChanged: (newValue) {
                    setState(() { _instituicaoSelecionada = newValue; });
                  },
                  validator: (_cidadeSelecionada != null && _cidadeSelecionada != 'Outro' && _instituicaoSelecionada == null)
                      ? (value) => 'Selecione a instituição'
                      : null,
                ),
                const SizedBox(height: 16.0),
                _buildDropdown<String>(
                  labelText: 'Seu cargo ou função*',
                  hintText: 'Selecione seu cargo na escola',
                  value: _cargoSelecionado,
                  items: _cargosEscola,
                  onChanged: (newValue) {
                    setState(() {
                      _cargoSelecionado = newValue;
                      _isProfessorSelecionado = (newValue == 'PROFESSOR');
                    });
                  },
                  validator: (value) => value == null ? 'Selecione o cargo' : null,
                ),
                if (_isProfessorSelecionado) Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                  child: Text(
                    'Atenção: Professores devem solicitar abertura de chamado via Coordenação Pedagógica, Laboratório de Informática (LIE) ou Direção/Secretaria.',
                    style: TextStyle(color: Colors.orange.shade700, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16.0),
                _buildDropdown<String>(
                  labelText: 'Atendimento técnico para:*',
                  hintText: 'Para qual setor da escola?',
                  value: _atendimentoParaSelecionado,
                  items: _atendimentosEscola,
                  onChanged: (v) => setState(() => _atendimentoParaSelecionado = v),
                  validator: (v) => v == null ? 'Selecione o setor' : null,
                ),
              ],

              // --- CAMPOS CONDICIONAIS PARA "SUPERINTENDENCIA" ---
              if (_tipoSelecionado == 'Superintendência') ...[
                _buildDropdown<String>(
                  labelText: 'Em qual sala/setor da SUPER?*',
                  hintText: 'Selecione seu setor na Superintendência',
                  value: _setorSuperSelecionado,
                  items: _setoresSuper,
                  onChanged: (v) => setState(() => _setorSuperSelecionado = v),
                  validator: (v) => v == null ? 'Selecione o setor' : null,
                  isExpanded: true,
                ),
              ],
           ],
        ),
      ),
     );
  }

  // Card para campos comuns (Detalhes do solicitante, equipamento, problema)
  Widget _buildDetalhesCard() {
     return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text('Detalhes do Chamado', style: Theme.of(context).textTheme.titleLarge),
             const SizedBox(height: 16.0),

             // --- CAMPOS COMUNS ---
              _buildTextFormField(
                controller: _nomeController,
                labelText: 'Seu nome completo*',
                hintText: 'Não coloque o nome da escola/setor aqui',
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Digite seu nome completo' : null,
              ),
              const SizedBox(height: 16.0),
              _buildTextFormField(
                controller: _celularController,
                labelText: 'Número de celular para contato*',
                hintText: '(XX) XXXXX-XXXX',
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Digite um número de celular';
                  if (!_phoneMaskFormatter.isFill()) return 'Número de celular incompleto'; // Valida máscara
                  return null;
                },
                keyboardType: TextInputType.phone,
                inputFormatters: [_phoneMaskFormatter], // Aplica máscara
              ),
              const SizedBox(height: 16.0),
              _buildDropdown<String>(
                labelText: 'Para qual equipamento é a solicitação?*',
                hintText: 'Ex: computador, monitor, roteador...',
                value: _equipamentoSelecionado,
                items: _equipamentos,
                onChanged: (v) => setState(() => _equipamentoSelecionado = v),
                validator: (v) => v == null ? 'Selecione o tipo de equipamento' : null,
              ),
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
                labelText: 'Qual é a marca/modelo do equipamento? (Opcional)',
                hintText: 'Ex: Dell Optiplex 3080, Positivo Master N250i',
              ),
              const SizedBox(height: 16.0),
              _buildTextFormField(
                controller: _patrimonioController,
                labelText: 'Qual número de patrimônio (tombamento)?*',
                hintText: 'Digite apenas números',
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Informe o número de patrimônio';
                  if (v.trim() == '0') return 'O número de patrimônio não pode ser 0';
                  final number = int.tryParse(v.trim());
                  if (number == null) return 'Digite apenas números válidos';
                  return null;
                },
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                helperText: 'Caso não encontre a etiqueta com o número do tombamento, solicite para a direção/secretaria a consulta no sistema do patrimônio.',
              ),
              const SizedBox(height: 16.0),
              _buildDropdown<String>(
                labelText: 'Qual o problema que está ocorrendo?*',
                hintText: 'Descreva o sintoma principal',
                value: _problemaSelecionado,
                items: _problemasComuns,
                onChanged: (v) => setState(() => _problemaSelecionado = v),
                validator: (v) => v == null ? 'Selecione o problema' : null,
              ),
              const SizedBox(height: 16.0),
              _buildTextFormField(
                controller: _tecnicoResponsavelController,
                labelText: 'Técnico Responsável (Opcional)',
                hintText: 'Se souber, indique um técnico',
              ),
          ],
        ),
      ),
     );
  }

  // Botão de Envio separado
  Widget _buildSubmitButton() {
     return Padding(
       // Adiciona padding horizontal se estiver fora de um Card
       padding: const EdgeInsets.symmetric(horizontal: 8.0),
       child: ElevatedButton(
         style: ElevatedButton.styleFrom(
           padding: const EdgeInsets.symmetric(vertical: 16.0),
           textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
           backgroundColor: Theme.of(context).primaryColor, // Cor primária do tema
           foregroundColor: Colors.white, // Cor do texto
         ),
         // Desabilita o botão se estiver carregando config OU enviando
         onPressed: _isLoadingConfig || _isLoading ? null : _enviarChamado,
         child: _isLoading
             ? const SizedBox(
               width: 24,
               height: 24,
               child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
             )
             : const Text('Enviar Chamado'),
       ),
     );
  }

} // Fim da classe _NovoChamadoScreenState
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:signature/signature.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;

// Importe suas constantes de serviço
import '../services/chamado_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _instituicaoManualController =
      TextEditingController(); // Para cidade 'OUTRO'
  String _currentEmail = '';

  User? _currentUser;
  Map<String, dynamic>? _userData;

  // Estados para Dropdowns e Dados do Perfil
  String? _userTipoSolicitante; // Armazena o tipo carregado do perfil
  List<String> _listaInstituicoes = [];
  String? _instituicaoSelecionada;
  bool _isLoadingInstituicoes = true;
  String? _erroCarregarInstituicoes;
  List<String> _listaCargos = [];
  String? _cargoSelecionado;
  bool _isLoadingCargos = true;
  String? _erroCarregarCargos;
  List<String> _listaCidades = []; // Adicionado para o dropdown de cidade
  String? _cidadeSelecionada; // Adicionado para o dropdown de cidade
  bool _isLoadingCidades = true; // Adicionado
  String? _erroCarregarCidades; // Adicionado
  List<String> _instituicoesDisponiveis =
      []; // Para filtrar instituições por cidade
  List<String> _listaSetores = []; // Para tipo Superintendência
  String? _setorSelecionado; // Para tipo Superintendência
  bool _isLoadingSetores = true; // Adicionado
  String? _erroCarregarSetores; // Adicionado

  // Estados para Assinatura
  String? _currentSignatureUrl;
  String? _newSignatureUrl;
  bool _isUploadingSignature = false;
  bool _signatureChanged = false;

  late final SignatureController _signatureController;

  bool _isLoading = true; // Loading inicial da tela
  bool _isSaving = false; // Loading ao salvar

  bool get _hasExistingSignature =>
      _currentSignatureUrl != null && _currentSignatureUrl!.isNotEmpty;
  Map<String, List<String>> _escolasPorCidadeMap = {}; // Mapa para filtro

  @override
  void initState() {
    super.initState();
    _signatureController = SignatureController(
        penStrokeWidth: 2.5,
        penColor: Colors.black,
        exportBackgroundColor: Colors.white,
        onDrawStart: () {
          if (!_hasExistingSignature) {
            setState(() => _signatureChanged = true);
          }
        });
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser == null) {
      /* ... (tratamento de erro) ... */ return;
    }
    _currentEmail = _currentUser!.email ?? 'Email não disponível';

    try {
      // Carrega dados do Firestore E configurações em paralelo
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection(kCollectionUsers)
            .doc(_currentUser!.uid)
            .get(),
        _carregarConfiguracoesDropdowns(), // Carrega todas as opções
      ]);

      final userDoc = results[0] as DocumentSnapshot;

      if (userDoc.exists && mounted) {
        _userData = userDoc.data() as Map<String, dynamic>?;
        _nameController.text =
            _userData?[kFieldName] ?? _currentUser!.displayName ?? '';
        _phoneController.text = _userData?[kFieldPhone] ?? '';

        // Carrega os dados do perfil
        _userTipoSolicitante = _userData?[kFieldUserTipoSolicitante] as String?;
        _cargoSelecionado = _userData?[kFieldJobTitle] as String?;
        _cidadeSelecionada = _userData?[kFieldCidade] as String?;
        _instituicaoSelecionada = _userData?[kFieldUserInstituicao] as String?;
        _setorSelecionado =
            _userData?[kFieldUserSetor] as String?; // Carrega setor
        _currentSignatureUrl = _userData?[kFieldUserAssinaturaUrl] as String?;

        print("DEBUG (Edit): Tipo Solicitante: $_userTipoSolicitante");
        print("DEBUG (Edit): Cargo: $_cargoSelecionado");
        print("DEBUG (Edit): Cidade: $_cidadeSelecionada");
        print("DEBUG (Edit): Instituição: $_instituicaoSelecionada");
        print("DEBUG (Edit): Setor: $_setorSelecionado");

        // Pré-filtra instituições se a cidade já estiver definida e for escola
        if (_userTipoSolicitante == 'ESCOLA' && _cidadeSelecionada != null) {
          _atualizarInstituicoes(_cidadeSelecionada!,
              preloading: true); // Chama para filtrar a lista inicial
        }

        // Validações e ajustes para dropdowns (como antes)...
        if (_cargoSelecionado != null &&
            _cargoSelecionado!.isNotEmpty &&
            !_listaCargos.contains(_cargoSelecionado)) {
          print(
              "Aviso (Edit): Cargo '$_cargoSelecionado' do perfil não encontrado na lista de opções.");
        }
        if (_instituicaoSelecionada != null &&
            _instituicaoSelecionada!.isNotEmpty &&
            !_listaInstituicoes.contains(_instituicaoSelecionada) &&
            _cidadeSelecionada != "OUTRO") {
          print(
              "Aviso (Edit): Instituição '$_instituicaoSelecionada' do perfil não encontrada na lista de opções.");
          // Não adiciona mais aqui, a filtragem por cidade cuida disso
        }
        if (_setorSelecionado != null &&
            _setorSelecionado!.isNotEmpty &&
            !_listaSetores.contains(_setorSelecionado)) {
          print(
              "Aviso (Edit): Setor '$_setorSelecionado' do perfil não encontrado na lista de opções.");
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

  // Função unificada para carregar dados dos dropdowns (Atualizada para Setores)
  Future<void> _carregarConfiguracoesDropdowns() async {
    if (!mounted) return;
    setState(() {
      _isLoadingInstituicoes = true;
      _erroCarregarInstituicoes = null;
      _isLoadingCargos = true;
      _erroCarregarCargos = null;
      _isLoadingCidades = true;
      _erroCarregarCidades = null;
      _isLoadingSetores = true;
      _erroCarregarSetores = null; // Adicionado
    });
    try {
      final db = FirebaseFirestore.instance;
      final results = await Future.wait([
        db.collection(kCollectionConfig).doc(kDocLocalidades).get(),
        db.collection(kCollectionConfig).doc(kDocOpcoes).get(),
      ]);
      final docLocalidades = results[0];
      final docOpcoes = results[1];

      // Processa Localidades/Cidades/Instituições
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

      // Processa Opcoes (Cargos e Setores)
      List<String> cargos = [];
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
              " Erro: Estrutura de dados de setores inválida.";
        }
      } else {
        erroOpcoes = "Erro: Configuração de opções não encontrada.";
      }
      if (cargos.isEmpty && erroOpcoes == null) {
        erroOpcoes = "Nenhum cargo encontrado.";
      }
      if (setores.isEmpty && erroOpcoes == null) {
        erroOpcoes = "Nenhum setor encontrado.";
      }

      // Atualiza o estado
      if (mounted) {
        setState(() {
          _listaCidades = cidades;
          _escolasPorCidadeMap = escolasMap;
          _listaInstituicoes = escolasMap.values
              .expand((list) => list)
              .toSet()
              .toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
          _erroCarregarCidades = erroLocalidades;
          _isLoadingCidades = false;
          _erroCarregarInstituicoes = erroLocalidades;
          _isLoadingInstituicoes = false;
          _listaCargos = cargos;
          _erroCarregarCargos = erroOpcoes;
          _isLoadingCargos = false;
          _listaSetores = setores;
          _erroCarregarSetores = erroOpcoes;
          _isLoadingSetores = false; // Atualiza estado dos setores
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
          _isLoadingCidades = false;
          _erroCarregarCidades = "Erro ao carregar cidades.";
          _isLoadingSetores = false;
          _erroCarregarSetores = "Erro ao carregar setores.";
        });
      }
    }
  }

  // Função para atualizar instituições disponíveis baseado na cidade selecionada
  void _atualizarInstituicoes(String? cidadeSelecionada,
      {bool preloading = false}) {
    if (!preloading) {
      // Só reseta se não for o pré-carregamento inicial
      setState(() {
        _instituicaoSelecionada = null;
        _instituicaoManualController.clear();
      });
    }
    if (cidadeSelecionada != null &&
        cidadeSelecionada != "OUTRO" &&
        _escolasPorCidadeMap.containsKey(cidadeSelecionada)) {
      _instituicoesDisponiveis =
          List<String>.from(_escolasPorCidadeMap[cidadeSelecionada]!);
    } else {
      _instituicoesDisponiveis = [];
    }
    if (!preloading) {
      // Atualiza estado da UI apenas se não for pré-carregamento
      setState(() {
        _cidadeSelecionada = cidadeSelecionada;
      });
    }
  }

  // --- FUNÇÃO PARA EXPORTAR E FAZER UPLOAD DA ASSINATURA (sem alterações) ---
  Future<String?> _exportAndUploadSignature() async {
    // ... (lógica igual à anterior) ...
    if (_signatureController.isEmpty) {
      return null;
    }
    setState(() => _isUploadingSignature = true);
    String? downloadUrl;
    try {
      final Uint8List? signatureBytes =
          await _signatureController.toPngBytes(height: 150, width: null);
      if (signatureBytes != null) {
        img.Image? signatureImage = img.decodePng(signatureBytes);
        if (signatureImage != null) {
          String userName = _nameController.text.trim();
          if (userName.isEmpty) {
            userName = _currentUser?.displayName ?? 'Nome não disponível';
          }
          int textYPosition = signatureImage.height + 5;
          int padding = 10;
          int textHeight = 20;
          int finalImageHeight = textYPosition + textHeight + padding;
          img.Image finalImage = img.Image(
              width: signatureImage.width,
              height: finalImageHeight,
              backgroundColor: img.ColorRgb8(255, 255, 255));
          img.compositeImage(finalImage, signatureImage, dstX: 0, dstY: 0);
          img.drawString(
            finalImage,
            userName,
            font: img.arial14,
            x: padding,
            y: textYPosition,
            color: img.ColorRgb8(0, 0, 0),
          );
          final Uint8List finalImageBytes =
              Uint8List.fromList(img.encodePng(finalImage));
          final userId = _currentUser!.uid;
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('assinaturas_usuarios')
              .child(userId)
              .child('assinatura.png');
          UploadTask uploadTask = storageRef.putData(
              finalImageBytes, SettableMetadata(contentType: 'image/png'));
          TaskSnapshot snapshot = await uploadTask;
          downloadUrl = await snapshot.ref.getDownloadURL();
          print("Assinatura com nome carregada com sucesso: $downloadUrl");
        }
      }
    } catch (e) {
      print("Erro ao exportar/adicionar nome/carregar assinatura: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao processar assinatura: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingSignature = false);
      }
    }
    return downloadUrl;
  }

  Future<void> _salvarPerfil() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_currentUser == null) {
      return;
    }

    setState(() => _isSaving = true);
    _newSignatureUrl = null;

    try {
      // Processa assinatura apenas se não houver uma existente e se foi alterada
      if (_signatureChanged &&
          !_signatureController.isEmpty &&
          !_hasExistingSignature) {
        _newSignatureUrl = await _exportAndUploadSignature();
        if (_newSignatureUrl == null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Falha ao processar a nova assinatura. Tente novamente.'),
                backgroundColor: Colors.red),
          );
          setState(() => _isSaving = false);
          return;
        }
      } else if (_signatureChanged && _hasExistingSignature) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'A assinatura já foi definida e não pode ser alterada.'),
                backgroundColor: Colors.orange),
          );
        }
        _signatureController.clear();
        _signatureChanged = false;
      }

      if (_currentUser!.displayName != _nameController.text.trim()) {
        await _currentUser!.updateDisplayName(_nameController.text.trim());
        print("Nome no Firebase Auth atualizado.");
      }

      // --- Monta o profileData condicionalmente com base no TIPO ORIGINAL do usuário ---
      final profileDataToUpdate = <String, dynamic>{
        kFieldName: _nameController.text.trim(),
        kFieldPhone: _phoneController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        // Adiciona a assinatura SOMENTE se uma nova foi gerada com sucesso
        if (_newSignatureUrl != null) kFieldUserAssinaturaUrl: _newSignatureUrl,
      };

      // Adiciona campos específicos baseado no _userTipoSolicitante carregado inicialmente
      if (_userTipoSolicitante == 'ESCOLA') {
        profileDataToUpdate[kFieldJobTitle] = _cargoSelecionado;
        profileDataToUpdate[kFieldUserInstituicao] =
            (_cidadeSelecionada == "OUTRO")
                ? _instituicaoManualController.text.trim()
                : _instituicaoSelecionada;
        profileDataToUpdate[kFieldCidade] = _cidadeSelecionada;
        // Remove o campo de setor se existir (caso o tipo tenha sido mudado incorretamente no DB)
        profileDataToUpdate[kFieldUserSetor] = FieldValue.delete();
      } else if (_userTipoSolicitante == 'SUPERINTENDENCIA') {
        profileDataToUpdate[kFieldUserSetor] = _setorSelecionado;
        // Remove campos de escola se existirem
        profileDataToUpdate[kFieldJobTitle] = FieldValue.delete();
        profileDataToUpdate[kFieldUserInstituicao] = FieldValue.delete();
        profileDataToUpdate[kFieldCidade] = FieldValue.delete();
      }
      // Não atualiza o kFieldUserTipoSolicitante aqui, pois não permitimos a edição dele.
      // --- Fim da montagem condicional ---

      await FirebaseFirestore.instance
          .collection(kCollectionUsers)
          .doc(_currentUser!.uid)
          .update(profileDataToUpdate);

      print("Dados do perfil no Firestore atualizados.");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Perfil atualizado com sucesso!'),
              backgroundColor: Colors.green),
        );
        _signatureController.clear();
        _signatureChanged = false;
        if (_newSignatureUrl != null) {
          _currentSignatureUrl = _newSignatureUrl;
        }
        _newSignatureUrl = null;
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
    _instituicaoManualController.dispose(); // Adicionado dispose
    _signatureController.dispose();
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
            onPressed: _isSaving || _isLoading || _isUploadingSignature
                ? null
                : _salvarPerfil,
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
                    // Campos Nome, Email, Telefone (como antes)...
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
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),

                    // Exibe o Tipo de Lotação (Não editável)
                    _buildInfoTile(
                        icon: Icons.business_center_outlined,
                        label: 'Tipo de Lotação',
                        value: _userTipoSolicitante ?? 'Não definido'),
                    const SizedBox(height: 16.0),

                    // --- CAMPOS CONDICIONAIS ---
                    if (_userTipoSolicitante == 'ESCOLA') ...[
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
                                Text('Carregando...')
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
                                _listaCargos.isEmpty)
                              return _erroCarregarCargos;
                            return 'Por favor, selecione seu cargo/função.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16.0),

                      // Dropdown de Cidade/Distrito
                      DropdownButtonFormField<String>(
                        value: _cidadeSelecionada,
                        isExpanded: true,
                        hint: _isLoadingCidades
                            ? const Row(children: [
                                SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)),
                                SizedBox(width: 8),
                                Text('Carregando...')
                              ])
                            : (_erroCarregarCidades != null
                                ? Text(_erroCarregarCidades!,
                                    style: TextStyle(
                                        color:
                                            Theme.of(context).colorScheme.error,
                                        fontSize: 14))
                                : const Text('Selecione a cidade/distrito *')),
                        decoration: InputDecoration(
                          labelText: 'Cidade / Distrito *',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.location_city_outlined),
                          errorText: _erroCarregarCidades != null &&
                                  !_isLoadingCidades &&
                                  _listaCidades.isEmpty
                              ? _erroCarregarCidades
                              : null,
                        ),
                        items: _isLoadingCidades || _erroCarregarCidades != null
                            ? []
                            : _listaCidades
                                .map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value,
                                      overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                        onChanged: (_isSaving ||
                                _isLoadingCidades ||
                                _erroCarregarCidades != null)
                            ? null
                            : (v) => _atualizarInstituicoes(
                                v), // Chama a função atualizada
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            if (_isLoadingCidades) return null;
                            if (_erroCarregarCidades != null &&
                                _listaCidades.isEmpty)
                              return _erroCarregarCidades;
                            return 'Por favor, selecione a cidade/distrito.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16.0),

                      // Campo Instituição (Dropdown ou Texto)
                      if (_cidadeSelecionada == "OUTRO")
                        TextFormField(
                          controller: _instituicaoManualController,
                          enabled: !_isSaving,
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
                          hint: _isLoadingInstituicoes
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
                            prefixIcon:
                                const Icon(Icons.account_balance_outlined),
                            errorText: (_erroCarregarInstituicoes != null &&
                                    !_isLoadingInstituicoes &&
                                    _instituicoesDisponiveis.isEmpty &&
                                    _cidadeSelecionada != null &&
                                    _cidadeSelecionada != "OUTRO")
                                ? "Nenhuma instituição para esta cidade."
                                : ((_erroCarregarInstituicoes != null &&
                                        !_isLoadingInstituicoes &&
                                        _listaInstituicoes.isEmpty)
                                    ? _erroCarregarInstituicoes
                                    : null),
                          ),
                          items: _isLoadingInstituicoes ||
                                  _cidadeSelecionada == null ||
                                  _cidadeSelecionada == "OUTRO" ||
                                  (_erroCarregarInstituicoes != null &&
                                      _instituicoesDisponiveis.isEmpty)
                              ? []
                              : _instituicoesDisponiveis
                                  .map<DropdownMenuItem<String>>(
                                      (String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value,
                                        overflow: TextOverflow.ellipsis),
                                  );
                                }).toList(),
                          onChanged: (_isSaving ||
                                  _isLoadingInstituicoes ||
                                  _cidadeSelecionada == null ||
                                  _cidadeSelecionada == "OUTRO" ||
                                  (_erroCarregarInstituicoes != null &&
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
                                if (_isLoadingInstituicoes) return null;
                                if (_erroCarregarInstituicoes != null &&
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

                    if (_userTipoSolicitante == 'SUPERINTENDENCIA') ...[
                      // Dropdown de Setor
                      DropdownButtonFormField<String>(
                        value: _setorSelecionado,
                        isExpanded: true,
                        hint: _isLoadingSetores
                            ? const Row(children: [
                                SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)),
                                SizedBox(width: 8),
                                Text('Carregando...')
                              ])
                            : (_erroCarregarSetores != null
                                ? Text(_erroCarregarSetores!,
                                    style: TextStyle(
                                        color:
                                            Theme.of(context).colorScheme.error,
                                        fontSize: 14))
                                : const Text('Selecione o setor *')),
                        decoration: InputDecoration(
                          labelText: 'Setor do servidor *',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.groups_outlined),
                          errorText: _erroCarregarSetores != null &&
                                  !_isLoadingSetores &&
                                  _listaSetores.isEmpty
                              ? _erroCarregarSetores
                              : null,
                        ),
                        items: _isLoadingSetores || _erroCarregarSetores != null
                            ? []
                            : _listaSetores
                                .map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value,
                                      overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                        onChanged: (_isSaving ||
                                _isLoadingSetores ||
                                _erroCarregarSetores != null)
                            ? null
                            : (String? newValue) {
                                setState(() {
                                  _setorSelecionado = newValue;
                                });
                              },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            if (_isLoadingSetores) return null;
                            if (_erroCarregarSetores != null &&
                                _listaSetores.isEmpty)
                              return _erroCarregarSetores;
                            return 'Por favor, selecione o setor.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16.0),
                    ],

                    // --- Seção de Assinatura (como antes) ---
                    Text('Assinatura Digital',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8.0),
                    if (_hasExistingSignature)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Assinatura Atual Salva:',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Container(
                            height: 100,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Image.network(
                              _currentSignatureUrl!,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, progress) =>
                                  progress == null
                                      ? child
                                      : const Center(
                                          child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        )),
                              errorBuilder: (context, error, stackTrace) =>
                                  const Center(
                                      child: Icon(Icons.error_outline,
                                          color: Colors.red)),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'A assinatura já foi definida e não pode ser alterada.',
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange.shade800,
                                fontStyle: FontStyle.italic),
                          ),
                          const SizedBox(height: 15),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Desenhe sua assinatura abaixo:',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 8.0),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: _signatureChanged
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Signature(
                              controller: _signatureController,
                              height: 180,
                              backgroundColor: Colors.grey[100]!,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.clear, size: 18),
                                label: const Text('Limpar Desenho'),
                                onPressed: _hasExistingSignature ||
                                        _isSaving ||
                                        _isUploadingSignature
                                    ? null
                                    : () {
                                        setState(() {
                                          _signatureController.clear();
                                          _signatureChanged = false;
                                          _newSignatureUrl = null;
                                        });
                                      },
                                style: TextButton.styleFrom(
                                    foregroundColor: Colors.red[700]),
                              ),
                              if (_isUploadingSignature)
                                const Padding(
                                  padding: EdgeInsets.only(right: 8.0),
                                  child: Row(children: [
                                    SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2)),
                                    SizedBox(width: 8),
                                    Text('Processando...',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic))
                                  ]),
                                )
                              else if (_signatureChanged &&
                                  !_signatureController.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: Text('Pronto para salvar.',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blueAccent[700])),
                                )
                            ],
                          ),
                        ],
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
                      onPressed:
                          _isSaving || _isLoading || _isUploadingSignature
                              ? null
                              : _salvarPerfil,
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

  // Widget auxiliar para exibir informações
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

  // Constantes locais
  static const String kFieldName = 'name';
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
  static const String kFieldUserAssinaturaUrl = 'assinatura_url';
}

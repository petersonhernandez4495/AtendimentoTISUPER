import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:signature/signature.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;
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
  final _instituicaoManualController = TextEditingController();
  String _currentEmail = '';

  User? _currentUser;
  Map<String, dynamic>? _userData;

  String? _userTipoSolicitante;
  List<String> _listaInstituicoes = [];
  String? _instituicaoSelecionada;
  bool _isLoadingInstituicoes = true;
  String? _erroCarregarInstituicoes;
  List<String> _listaCargos = [];
  String? _cargoSelecionado;
  bool _isLoadingCargos = true;
  String? _erroCarregarCargos;
  List<String> _listaCidades = [];
  String? _cidadeSelecionada;
  bool _isLoadingCidades = true;
  String? _erroCarregarCidades;
  List<String> _instituicoesDisponiveis = [];
  List<String> _listaSetores = [];
  String? _setorSelecionado;
  bool _isLoadingSetores = true;
  String? _erroCarregarSetores;

  List<String> _listaCidadesSuperintendenciaEdit = [];
  String? _cidadeSuperintendenciaSelecionadaEdit;
  bool _isLoadingCidadesSuperEdit = true;
  String? _erroCarregarCidadesSuperEdit;

  String? _currentSignatureUrl;
  String? _newSignatureUrl;
  bool _isUploadingSignature = false;
  bool _signatureChanged = false;

  late final SignatureController _signatureController;

  bool _isLoading = true;
  bool _isSaving = false;

  bool get _hasExistingSignature =>
      _currentSignatureUrl != null && _currentSignatureUrl!.isNotEmpty;
  Map<String, List<String>> _escolasPorCidadeMap = {};

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Usuário não autenticado. Por favor, faça login novamente.'),
              backgroundColor: Colors.red),
        );
        Navigator.of(context).pop();
      }
      setState(() => _isLoading = false);
      return;
    }
    _currentEmail = _currentUser!.email ?? 'Email não disponível';

    try {
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection(kCollectionUsers)
            .doc(_currentUser!.uid)
            .get(),
        _carregarConfiguracoesDropdowns(),
      ]);

      final userDoc = results[0] as DocumentSnapshot;

      if (userDoc.exists && mounted) {
        _userData = userDoc.data() as Map<String, dynamic>?;
        if (_userData == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Dados do perfil não encontrados ou corrompidos.'),
                backgroundColor: Colors.red),
          );
          setState(() => _isLoading = false);
          return;
        }

        _nameController.text =
            _userData![kFieldName] ?? _currentUser!.displayName ?? '';
        _phoneController.text = _userData![kFieldPhone] ?? '';
        _userTipoSolicitante = _userData![kFieldUserTipoSolicitante] as String?;
        _cargoSelecionado = _userData![kFieldJobTitle] as String?;
        _cidadeSelecionada = _userData![kFieldCidade] as String?;
        _instituicaoSelecionada = _userData![kFieldUserInstituicao] as String?;
        _setorSelecionado = _userData![kFieldUserSetor] as String?;
        _currentSignatureUrl = _userData![kFieldUserAssinaturaUrl] as String?;

        if (_userTipoSolicitante == 'SUPERINTENDENCIA') {
          _cidadeSuperintendenciaSelecionadaEdit =
              _userData![kFieldCidadeSuperintendencia] as String?;
        }

        if (_userTipoSolicitante == 'ESCOLA' && _cidadeSelecionada != null) {
          _atualizarInstituicoes(_cidadeSelecionada!, preloading: true);
          if (_cidadeSelecionada == "OUTRO" &&
              _instituicaoSelecionada != null) {
            _instituicaoManualController.text = _instituicaoSelecionada!;
          }
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Dados do perfil não encontrados.'),
              backgroundColor: Colors.red),
        );
      }
    } catch (e, s) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao carregar dados: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

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
      _erroCarregarSetores = null;
      _isLoadingCidadesSuperEdit = true;
      _erroCarregarCidadesSuperEdit = null;
    });

    try {
      final db = FirebaseFirestore.instance;
      final results = await Future.wait([
        db.collection(kCollectionConfig).doc(kDocLocalidades).get(),
        db.collection(kCollectionConfig).doc(kDocOpcoes).get(),
      ]);

      final docLocalidades = results[0];
      final docOpcoes = results[1];

      List<String> cidadesEscola = [];
      Map<String, List<String>> escolasMap = {};
      List<String> cidadesSuperintendenciaLoaded = [];
      String? erroLocalidadesAcumulado;

      if (docLocalidades.exists && docLocalidades.data() != null) {
        final dataLocalidades = docLocalidades.data()!;
        const String nomeCampoMapaEscolas = 'escolasPorCidade';
        if (dataLocalidades.containsKey(nomeCampoMapaEscolas) &&
            dataLocalidades[nomeCampoMapaEscolas] is Map) {
          final Map<String, dynamic> rawMap =
              Map<String, dynamic>.from(dataLocalidades[nomeCampoMapaEscolas]);
          rawMap.forEach((key, value) {
            if (key is String && value != null && value is List) {
              List<String> escolas = value
                  .map((e) => e?.toString())
                  .where((n) => n != null && n.isNotEmpty)
                  .cast<String>()
                  .toList();
              escolas
                  .sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
              escolasMap[key] = escolas;
            }
          });
          cidadesEscola = escolasMap.keys.toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
          if (!escolasMap.containsKey("OUTRO")) {
            escolasMap["OUTRO"] = [];
            if (!cidadesEscola.contains("OUTRO")) cidadesEscola.add("OUTRO");
            cidadesEscola
                .sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
          }
        } else {
          erroLocalidadesAcumulado = (erroLocalidadesAcumulado ?? "") +
              " Estrutura 'escolasPorCidade' inválida.\n";
        }

        const String nomeCampoCidadesSuper = 'cidadesSuperintendecia';
        if (dataLocalidades.containsKey(nomeCampoCidadesSuper) &&
            dataLocalidades[nomeCampoCidadesSuper] is List) {
          cidadesSuperintendenciaLoaded =
              (dataLocalidades[nomeCampoCidadesSuper] as List)
                  .map((cs) => cs?.toString())
                  .where((n) => n != null && n.isNotEmpty)
                  .cast<String>()
                  .toList();
          cidadesSuperintendenciaLoaded
              .sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        } else {
          erroLocalidadesAcumulado = (erroLocalidadesAcumulado ?? "") +
              " Configuração 'cidadesSuperintendecia' não encontrada/inválida.\n";
        }
      } else {
        erroLocalidadesAcumulado =
            "Configuração de localidades não encontrada.\n";
      }

      List<String> cargos = [];
      List<String> setores = [];
      String? erroOpcoesAcumulado;

      if (docOpcoes.exists && docOpcoes.data() != null) {
        final dataOpcoes = docOpcoes.data()!;
        const String nomeCampoCargos = 'cargosEscola';
        if (dataOpcoes.containsKey(nomeCampoCargos) &&
            dataOpcoes[nomeCampoCargos] is List) {
          cargos = (dataOpcoes[nomeCampoCargos] as List)
              .map((c) => c?.toString())
              .where((n) => n != null && n.isNotEmpty)
              .cast<String>()
              .toList();
          cargos.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        } else {
          erroOpcoesAcumulado = (erroOpcoesAcumulado ?? "") +
              " Estrutura 'cargosEscola' inválida.\n";
        }
        const String nomeCampoSetores = 'setoresSuper';
        if (dataOpcoes.containsKey(nomeCampoSetores) &&
            dataOpcoes[nomeCampoSetores] is List) {
          setores = (dataOpcoes[nomeCampoSetores] as List)
              .map((s) => s?.toString())
              .where((n) => n != null && n.isNotEmpty)
              .cast<String>()
              .toList();
          setores.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        } else {
          erroOpcoesAcumulado = (erroOpcoesAcumulado ?? "") +
              " Estrutura 'setoresSuper' inválida.\n";
        }
      } else {
        erroOpcoesAcumulado = "Configuração de opções não encontrada.\n";
      }

      if (mounted) {
        setState(() {
          _listaCidades = cidadesEscola;
          _escolasPorCidadeMap = escolasMap;
          _listaInstituicoes = escolasMap.values
              .expand((list) => list)
              .toSet()
              .toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
          _erroCarregarCidades = erroLocalidadesAcumulado;
          _isLoadingCidades = false;
          _erroCarregarInstituicoes = erroLocalidadesAcumulado;
          _isLoadingInstituicoes = false;
          _listaCargos = cargos;
          _erroCarregarCargos = erroOpcoesAcumulado;
          _isLoadingCargos = false;
          _listaSetores = setores;
          _erroCarregarSetores = erroOpcoesAcumulado;
          _isLoadingSetores = false;
          _listaCidadesSuperintendenciaEdit = cidadesSuperintendenciaLoaded;
          _erroCarregarCidadesSuperEdit = erroLocalidadesAcumulado;
          _isLoadingCidadesSuperEdit = false;
        });
      }
    } catch (e, s) {
      if (mounted) {
        final errorMsg = "Erro configs: ${e.toString()}";
        setState(() {
          _isLoadingInstituicoes = false;
          _erroCarregarInstituicoes = errorMsg;
          _isLoadingCargos = false;
          _erroCarregarCargos = errorMsg;
          _isLoadingCidades = false;
          _erroCarregarCidades = errorMsg;
          _isLoadingSetores = false;
          _erroCarregarSetores = errorMsg;
          _isLoadingCidadesSuperEdit = false;
          _erroCarregarCidadesSuperEdit = errorMsg;
        });
      }
    }
  }

  void _atualizarInstituicoes(String? cidadeSelecionada,
      {bool preloading = false}) {
    if (!mounted) return;

    List<String> novasInstituicoesDisponiveis = [];
    if (cidadeSelecionada != null &&
        cidadeSelecionada != "OUTRO" &&
        _escolasPorCidadeMap.containsKey(cidadeSelecionada)) {
      novasInstituicoesDisponiveis =
          List<String>.from(_escolasPorCidadeMap[cidadeSelecionada]!);
    }

    setState(() {
      _instituicoesDisponiveis = novasInstituicoesDisponiveis;
      if (!preloading) {
        _cidadeSelecionada = cidadeSelecionada;
        _instituicaoSelecionada = null;
        _instituicaoManualController.clear();
      } else {
        if (_instituicaoSelecionada != null &&
            !novasInstituicoesDisponiveis.contains(_instituicaoSelecionada)) {
          _instituicaoSelecionada = null;
          _instituicaoManualController.clear();
        }
      }
    });
  }

  Future<String?> _exportAndUploadSignature() async {
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
        } else {
          final userId = _currentUser!.uid;
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('assinaturas_usuarios')
              .child(userId)
              .child('assinatura.png');
          UploadTask uploadTask = storageRef.putData(
              signatureBytes, SettableMetadata(contentType: 'image/png'));
          TaskSnapshot snapshot = await uploadTask;
          downloadUrl = await snapshot.ref.getDownloadURL();
        }
      }
    } catch (e) {
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
      }

      final profileDataToUpdate = <String, dynamic>{
        kFieldName: _nameController.text.trim(),
        kFieldPhone: _phoneController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (_newSignatureUrl != null) kFieldUserAssinaturaUrl: _newSignatureUrl,
      };

      if (_userTipoSolicitante == 'ESCOLA') {
        profileDataToUpdate[kFieldJobTitle] = _cargoSelecionado;
        profileDataToUpdate[kFieldUserInstituicao] =
            (_cidadeSelecionada == "OUTRO")
                ? _instituicaoManualController.text.trim()
                : _instituicaoSelecionada;
        profileDataToUpdate[kFieldCidade] = _cidadeSelecionada;
        profileDataToUpdate[kFieldUserSetor] = FieldValue.delete();
        profileDataToUpdate[kFieldCidadeSuperintendencia] = FieldValue.delete();
      } else if (_userTipoSolicitante == 'SUPERINTENDENCIA') {
        profileDataToUpdate[kFieldUserSetor] = _setorSelecionado;
        profileDataToUpdate[kFieldCidadeSuperintendencia] =
            _cidadeSuperintendenciaSelecionadaEdit;

        profileDataToUpdate[kFieldJobTitle] = FieldValue.delete();
        profileDataToUpdate[kFieldUserInstituicao] = FieldValue.delete();
        profileDataToUpdate[kFieldCidade] = FieldValue.delete();
      }

      await FirebaseFirestore.instance
          .collection(kCollectionUsers)
          .doc(_currentUser!.uid)
          .update(profileDataToUpdate);

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
    } catch (e, s) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao salvar perfil: ${e.toString()}'),
              backgroundColor: Colors.red),
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
    _instituicaoManualController.dispose();
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
                    TextFormField(
                      controller: _nameController,
                      enabled: !_isSaving,
                      decoration: const InputDecoration(
                          labelText: 'Nome Completo *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline)),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Digite seu nome.'
                          : null,
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
                          filled: true),
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
                          prefixIcon: Icon(Icons.phone_outlined)),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Digite seu telefone.'
                          : null,
                    ),
                    const SizedBox(height: 16.0),
                    _buildInfoTile(
                        icon: Icons.business_center_outlined,
                        label: 'Tipo de Lotação (Não editável)',
                        value: _userTipoSolicitante ?? 'Não definido'),
                    const SizedBox(height: 16.0),
                    if (_userTipoSolicitante == 'ESCOLA') ...[
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
                            : (_erroCarregarCargos != null &&
                                    _listaCargos.isEmpty
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
                          errorMaxLines: 3,
                          errorText: _erroCarregarCargos != null &&
                                  !_isLoadingCargos &&
                                  _listaCargos.isEmpty
                              ? _erroCarregarCargos
                              : null,
                        ),
                        items: _isLoadingCargos ||
                                (_erroCarregarCargos != null &&
                                    _listaCargos.isEmpty)
                            ? []
                            : _listaCargos
                                .map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value,
                                        overflow: TextOverflow.ellipsis));
                              }).toList(),
                        onChanged: (_isSaving ||
                                _isLoadingCargos ||
                                (_erroCarregarCargos != null &&
                                    _listaCargos.isEmpty))
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
                            : (_erroCarregarCidades != null &&
                                    _listaCidades.isEmpty
                                ? Text(_erroCarregarCidades!,
                                    style: TextStyle(
                                        color:
                                            Theme.of(context).colorScheme.error,
                                        fontSize: 14))
                                : const Text('Selecione a cidade/distrito *')),
                        decoration: InputDecoration(
                          labelText: 'Cidade / Distrito (Escola)*',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.location_city_outlined),
                          errorMaxLines: 3,
                          errorText: _erroCarregarCidades != null &&
                                  !_isLoadingCidades &&
                                  _listaCidades.isEmpty
                              ? _erroCarregarCidades
                              : null,
                        ),
                        items: _isLoadingCidades ||
                                (_erroCarregarCidades != null &&
                                    _listaCidades.isEmpty)
                            ? []
                            : _listaCidades
                                .map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value,
                                        overflow: TextOverflow.ellipsis));
                              }).toList(),
                        onChanged: (_isSaving ||
                                _isLoadingCidades ||
                                (_erroCarregarCidades != null &&
                                    _listaCidades.isEmpty))
                            ? null
                            : (v) => _atualizarInstituicoes(v),
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
                                  : (_instituicoesDisponiveis.isEmpty &&
                                          _cidadeSelecionada != null &&
                                          !_isLoadingInstituicoes
                                      ? const Text(
                                          'Nenhuma instituição para esta cidade')
                                      : const Text(
                                          'Selecione sua instituição *'))),
                          decoration: InputDecoration(
                            labelText: 'Instituição / Lotação (Escola)*',
                            border: const OutlineInputBorder(),
                            prefixIcon:
                                const Icon(Icons.account_balance_outlined),
                            errorMaxLines: 3,
                            errorText: (_erroCarregarInstituicoes != null &&
                                    !_isLoadingInstituicoes &&
                                    _instituicoesDisponiveis.isEmpty &&
                                    _cidadeSelecionada != null &&
                                    _cidadeSelecionada != "OUTRO")
                                ? "Nenhuma instituição para esta cidade."
                                : ((_erroCarregarInstituicoes != null &&
                                        !_isLoadingInstituicoes &&
                                        _listaInstituicoes.isEmpty &&
                                        _cidadeSelecionada != null &&
                                        _cidadeSelecionada != "OUTRO")
                                    ? _erroCarregarInstituicoes
                                    : null),
                          ),
                          items: _isLoadingInstituicoes ||
                                  _cidadeSelecionada == null ||
                                  _cidadeSelecionada == "OUTRO" ||
                                  (_erroCarregarInstituicoes != null &&
                                      _instituicoesDisponiveis.isEmpty &&
                                      _cidadeSelecionada != null)
                              ? []
                              : _instituicoesDisponiveis
                                  .map<DropdownMenuItem<String>>(
                                      (String value) {
                                  return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value,
                                          overflow: TextOverflow.ellipsis));
                                }).toList(),
                          onChanged: (_isSaving ||
                                  _isLoadingInstituicoes ||
                                  _cidadeSelecionada == null ||
                                  _cidadeSelecionada == "OUTRO" ||
                                  (_erroCarregarInstituicoes != null &&
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
                            : (_erroCarregarSetores != null &&
                                    _listaSetores.isEmpty
                                ? Text(_erroCarregarSetores!,
                                    style: TextStyle(
                                        color:
                                            Theme.of(context).colorScheme.error,
                                        fontSize: 14))
                                : const Text('Selecione o setor *')),
                        decoration: InputDecoration(
                          labelText: 'Setor (Superintendência)*',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.groups_outlined),
                          errorMaxLines: 3,
                          errorText: _erroCarregarSetores != null &&
                                  !_isLoadingSetores &&
                                  _listaSetores.isEmpty
                              ? _erroCarregarSetores
                              : null,
                        ),
                        items: _isLoadingSetores ||
                                (_erroCarregarSetores != null &&
                                    _listaSetores.isEmpty)
                            ? []
                            : _listaSetores
                                .map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value,
                                        overflow: TextOverflow.ellipsis));
                              }).toList(),
                        onChanged: (_isSaving ||
                                _isLoadingSetores ||
                                (_erroCarregarSetores != null &&
                                    _listaSetores.isEmpty))
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
                      DropdownButtonFormField<String>(
                        value: _cidadeSuperintendenciaSelecionadaEdit,
                        isExpanded: true,
                        hint: _isLoadingCidadesSuperEdit
                            ? const Row(children: [
                                SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)),
                                SizedBox(width: 8),
                                Text('Carregando cidades...')
                              ])
                            : (_erroCarregarCidadesSuperEdit != null &&
                                    _listaCidadesSuperintendenciaEdit.isEmpty &&
                                    !_isLoadingCidadesSuperEdit
                                ? Text(
                                    _erroCarregarCidadesSuperEdit!
                                            .contains("cidadesSuperintendecia")
                                        ? _erroCarregarCidadesSuperEdit!
                                        : "Erro ao carregar cidades SUPER.",
                                    style: TextStyle(
                                        color:
                                            Theme.of(context).colorScheme.error,
                                        fontSize: 14))
                                : const Text(
                                    'Selecione a Cidade da Superintendência *')),
                        decoration: InputDecoration(
                          labelText: 'Cidade da Superintendência *',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.map_outlined),
                          errorMaxLines: 3,
                          errorText: _erroCarregarCidadesSuperEdit != null &&
                                  !_isLoadingCidadesSuperEdit &&
                                  _listaCidadesSuperintendenciaEdit.isEmpty
                              ? (_erroCarregarCidadesSuperEdit!
                                      .contains("cidadesSuperintendecia")
                                  ? _erroCarregarCidadesSuperEdit!
                                  : "Erro ao carregar cidades da SUPER.")
                              : null,
                        ),
                        items: _isLoadingCidadesSuperEdit ||
                                (_erroCarregarCidadesSuperEdit != null &&
                                    _listaCidadesSuperintendenciaEdit.isEmpty &&
                                    !_isLoadingCidadesSuperEdit)
                            ? []
                            : _listaCidadesSuperintendenciaEdit
                                .map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value,
                                      overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                        onChanged: (_isSaving ||
                                _isLoadingCidadesSuperEdit ||
                                (_erroCarregarCidadesSuperEdit != null &&
                                    _listaCidadesSuperintendenciaEdit.isEmpty &&
                                    !_isLoadingCidadesSuperEdit))
                            ? null
                            : (String? newValue) {
                                setState(() {
                                  _cidadeSuperintendenciaSelecionadaEdit =
                                      newValue;
                                });
                              },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            if (_isLoadingCidadesSuperEdit) return null;
                            if (_erroCarregarCidadesSuperEdit != null &&
                                _listaCidadesSuperintendenciaEdit.isEmpty &&
                                !_isLoadingCidadesSuperEdit)
                              return (_erroCarregarCidadesSuperEdit!
                                      .contains("cidadesSuperintendecia")
                                  ? _erroCarregarCidadesSuperEdit!
                                  : "Erro ao carregar cidades da SUPER.");
                            return 'Selecione a cidade da Superintendência.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16.0),
                    ],
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
                            'A assinatura já foi definida e não pode ser alterada através desta tela.',
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
                          textStyle: const TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
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
      subtitle: Text(value,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w500),
          maxLines: 2,
          overflow: TextOverflow.ellipsis),
      contentPadding: EdgeInsets.zero,
    );
  }

  static const String kFieldName = 'name';
  static const String kFieldPhone = 'phone';
  static const String kFieldJobTitle = 'jobTitle';
  static const String kFieldUserInstituicao = 'institution';
  static const String kFieldCidade = 'cidade';
  static const String kFieldUserTipoSolicitante = 'tipo_solicitante';
  static const String kFieldUserSetor = 'setor_superintendencia';
  static const String kFieldUserAssinaturaUrl = 'assinatura_url';
  static const String kFieldCidadeSuperintendencia = 'cidadeSuperintendencia';

  static const String kCollectionUsers = 'users';
  static const String kCollectionConfig = 'configuracoes';
  static const String kDocOpcoes = 'opcoesChamado';
  static const String kDocLocalidades = 'localidades';
}

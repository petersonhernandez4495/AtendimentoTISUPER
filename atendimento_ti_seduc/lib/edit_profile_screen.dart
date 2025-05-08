import 'dart:typed_data'; // Necessário para Uint8List (dados da imagem da assinatura)
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:signature/signature.dart'; // <<< ADICIONADO IMPORT DO PACOTE SIGNATURE
import 'package:firebase_storage/firebase_storage.dart';

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
  String? _cargoSelecionado;
  bool _isLoadingCargos = true;
  String? _erroCarregarCargos;

  // Estados para Assinatura (MODIFICADO)
  String? _currentSignatureUrl; // URL da assinatura salva anteriormente
  String?
      _newSignatureUrl; // URL da nova assinatura após upload (gerada do desenho)
  bool _isUploadingSignature = false; // Flag para indicar upload em andamento
  bool _signatureChanged =
      false; // Flag para indicar se o usuário desenhou algo novo

  // Controlador para o widget Signature
  late final SignatureController _signatureController;

  bool _isLoading = true; // Loading inicial da tela
  bool _isSaving = false; // Loading ao salvar

  @override
  void initState() {
    super.initState();
    // Inicializa o SignatureController
    _signatureController = SignatureController(
      penStrokeWidth: 2.5, // Espessura da caneta
      penColor: Colors.black,
      exportBackgroundColor: Colors.white, // Fundo da imagem exportada
      onDrawStart: () =>
          setState(() => _signatureChanged = true), // Marca que houve alteração
    );
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // ... (lógica de carregar usuário e configurações - sem alterações) ...
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
        _nameController.text =
            _userData?[kFieldName] ?? _currentUser!.displayName ?? '';
        _phoneController.text = _userData?[kFieldPhone] ?? '';
        _instituicaoSelecionada = _userData?[kFieldUserInstituicao] as String?;
        _cargoSelecionado = _userData?[kFieldJobTitle] as String?;
        _currentSignatureUrl = _userData?[kFieldUserAssinaturaUrl] as String?;

        if (_cargoSelecionado != null &&
            _cargoSelecionado!.isNotEmpty &&
            !_listaCargos.contains(_cargoSelecionado)) {
          print(
              "Aviso: Cargo '$_cargoSelecionado' do perfil não encontrado na lista de opções.");
        }
        if (_instituicaoSelecionada != null &&
            _instituicaoSelecionada!.isNotEmpty &&
            !_listaInstituicoes.contains(_instituicaoSelecionada)) {
          print(
              "Aviso: Instituição '$_instituicaoSelecionada' do perfil não encontrada na lista de opções.");
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

  // Função unificada para carregar dados dos dropdowns (sem alterações)
  Future<void> _carregarConfiguracoesDropdowns() async {
    // ... (lógica igual à anterior para carregar instituições e cargos) ...
    if (!mounted) return;
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
      List<String> todasInstituicoes = [];
      String? erroInstituicoes;
      if (docLocalidades.exists && docLocalidades.data() != null) {
        final data = docLocalidades.data()!;
        const String nomeCampoMapa = 'escolasPorCidade';
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
      List<String> todosCargos = [];
      String? erroCargos;
      if (docOpcoes.exists && docOpcoes.data() != null) {
        final data = docOpcoes.data()!;
        const String nomeCampoCargos = 'cargosEscola';
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

  // --- FUNÇÃO PARA EXPORTAR E FAZER UPLOAD DA ASSINATURA DESENHADA (Caminho Corrigido) ---
  Future<String?> _exportAndUploadSignature() async {
    if (_signatureController.isEmpty) {
      return null;
    }

    setState(() => _isUploadingSignature = true);
    String? downloadUrl;

    try {
      final Uint8List? data =
          await _signatureController.toPngBytes(height: 150, width: null);

      if (data != null) {
        final userId = _currentUser!.uid;
        // CORREÇÃO: Cria o caminho como /assinaturas_usuarios/{userId}/assinatura.png
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('assinaturas_usuarios') // Pasta principal
            .child(userId) // Pasta do usuário (com UID)
            .child(
                'assinatura.png'); // Nome fixo do arquivo dentro da pasta do usuário

        UploadTask uploadTask = storageRef.putData(
            data, SettableMetadata(contentType: 'image/png'));
        TaskSnapshot snapshot = await uploadTask;
        downloadUrl = await snapshot.ref.getDownloadURL();
        print("Assinatura desenhada carregada com sucesso: $downloadUrl");
      }
    } catch (e) {
      print("Erro ao exportar/carregar assinatura desenhada: $e");
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
      if (_signatureChanged && !_signatureController.isEmpty) {
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
      }

      if (_currentUser!.displayName != _nameController.text.trim()) {
        await _currentUser!.updateDisplayName(_nameController.text.trim());
        print("Nome no Firebase Auth atualizado.");
      }

      final Map<String, dynamic> profileDataToUpdate = {
        kFieldName: _nameController.text.trim(),
        kFieldPhone: _phoneController.text.trim(),
        kFieldJobTitle: _cargoSelecionado,
        kFieldUserInstituicao: _instituicaoSelecionada,
        'updatedAt': FieldValue.serverTimestamp(),
        if (_newSignatureUrl != null) kFieldUserAssinaturaUrl: _newSignatureUrl,
      };

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
                    // Campos Nome, Email, Telefone, Cargo, Instituição ...
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
                              _listaCargos.isEmpty) return _erroCarregarCargos;
                          return 'Por favor, selecione seu cargo/função.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
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

                    // --- Seção de Assinatura ---
                    Text('Assinatura Digital',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8.0),
                    if (_currentSignatureUrl != null &&
                        _currentSignatureUrl!.isNotEmpty)
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
                          const SizedBox(height: 15),
                          const Text('Desenhe abaixo para substituir:',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      )
                    else
                      const Text('Nenhuma assinatura salva. Desenhe abaixo:',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),

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
                          onPressed: _isSaving || _isUploadingSignature
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

  // Constantes locais
  static const String kFieldName = 'name';
  static const String kFieldPhone = 'phone';
  static const String kFieldJobTitle = 'jobTitle';
  static const String kFieldUserInstituicao = 'institution';
  static const String kCollectionUsers = 'users';
  static const String kCollectionConfig = 'configuracoes';
  static const String kDocOpcoes = 'opcoesChamado';
  static const String kDocLocalidades = 'localidades';
  static const String kFieldUserAssinaturaUrl = 'assinatura_url';
}

// lib/lista_chamados_screen.dart
import 'dart:math';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdf/pdf.dart' as pdf_page_format;
import 'package:printing/printing.dart';

import '../models/chamado_model.dart';
import '../services/chamado_search_logic.dart';
import '../widgets/chamado_list_item.dart';
// Removida a constante conflitante da importação de detalhes_chamado_screen
import '../detalhes_chamado_screen.dart' hide kFieldNomeRequerenteConfirmador;
import '../config/theme/app_theme.dart';
import '../services/chamado_service.dart'; // Importa kUserProfileCidadeSuperintendencia, kFieldCidadeSuperintendencia, etc.
import '../pdf_generator.dart' as pdfGen;

// Constante para o valor do papel/tipo de solicitante 'SUPERINTENDENCIA'.
// Ajuste se o valor real no Firestore for diferente.
const String kRoleSuperintendencia = 'SUPERINTENDENCIA';

// Nota:
// - kUserProfileCidadeSuperintendencia (para buscar a cidade do perfil do usuário SUPERINTENDENCIA)
//   é esperado que seja importado de 'chamado_service.dart' (valor: 'cidadeSuperintendencia').
// - kFieldCidadeSuperintendencia (para filtrar chamados pela cidade da SUPERINTENDENCIA)
//   é esperado que seja importado de 'chamado_service.dart' (valor: 'cidade_superintendencia').

class ListaChamadosScreen extends StatefulWidget {
  final String searchQuery;

  const ListaChamadosScreen({
    super.key,
    this.searchQuery = "",
  });

  @override
  State<ListaChamadosScreen> createState() => _ListaChamadosScreenState();
}

class _ListaChamadosScreenState extends State<ListaChamadosScreen> {
  final ChamadoService _chamadoService = ChamadoService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late ChamadoSearchLogic _searchLogic;

  String? _selectedStatusFilter;
  late Map<String, dynamic> _selectedSortOption;
  DateTime? _selectedDateFilter;
  bool _isAdmin = false;
  String _userRole = 'inativo';
  bool _isLoadingRole = true;
  User? _currentUser;
  String?
      _currentUserInstitution; // Para ESCOLA e outros tipos baseados em instituição
  String?
      _userCidadeSuperintendencia; // Para SUPERINTENDENCIA, armazena a cidade do usuário

  List<Chamado> _ultimosChamadosFiltradosParaExibicao = [];

  final List<String> _statusOptions = [
    kStatusAberto,
    kStatusEmAndamento,
    kStatusPendente,
    kStatusPadraoSolicionado,
    kStatusCancelado,
    kStatusAguardandoAprovacao,
    kStatusAguardandoPeca,
    kStatusChamadoDuplicado,
    kStatusAguardandoEquipamento,
    kStatusAtribuidoGSIOR,
    kStatusGarantiaFabricante,
  ];
  final List<Map<String, dynamic>> _sortOptions = [
    {'label': 'Mais Recentes', 'field': kFieldDataCriacao, 'descending': true},
    {'label': 'Mais Antigos', 'field': kFieldDataCriacao, 'descending': false},
    {'label': 'Prioridade', 'field': kFieldPrioridade, 'descending': true},
    {'label': 'Status', 'field': kFieldStatus, 'descending': false},
  ];

  String? _confirmingChamadoId;
  bool _isConfirmingAcceptance = false;
  String? _idChamadoGerandoPdf;
  String? _idChamadoFinalizandoDaLista;
  bool _isLoadingFinalizarDaLista = false;

  static const String _dummyNonExistentDocId =
      'dummy_id_para_nao_retornar_documentos_firestore_xyz123';

  @override
  void initState() {
    super.initState();
    _searchLogic = ChamadoSearchLogic();
    _selectedSortOption = _sortOptions[0];
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    if (!mounted) return;
    setState(() => _isLoadingRole = true);
    User? user = _auth.currentUser;
    bool isAdminResult = false;
    String roleResult = 'inativo'; // Papel/Tipo de Solicitante do usuário
    String? userInstitutionResult; // Instituição para ESCOLA
    String? userCidadeSuperintendenciaFetched; // Cidade para SUPERINTENDENCIA

    if (user != null) {
      _currentUser = user;
      try {
        final DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection(kCollectionUsers) // Constante de chamado_service.dart
            .doc(user.uid)
            .get();
        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data() as Map<String, dynamic>;

          // CORREÇÃO NA LÓGICA DE DETERMINAÇÃO DE PAPEL:
          // Priorizar kFieldUserTipoSolicitante para definir o papel principal.
          if (userData.containsKey(kFieldUserTipoSolicitante) &&
              userData[kFieldUserTipoSolicitante] != null &&
              (userData[kFieldUserTipoSolicitante] as String).isNotEmpty) {
            roleResult = userData[kFieldUserTipoSolicitante] as String;
          } else if (userData
                  .containsKey('role_temp') && // Fallback para role_temp
              userData['role_temp'] != null &&
              (userData['role_temp'] as String).isNotEmpty) {
            roleResult = userData['role_temp'] as String;
          } else if (userData.containsKey(
                  kFieldUserRole) && // Fallback para kFieldUserRole
              userData[kFieldUserRole] != null &&
              (userData[kFieldUserRole] as String).isNotEmpty) {
            roleResult = userData[kFieldUserRole] as String;
          }
          // FIM DA CORREÇÃO NA LÓGICA DE PAPEL

          if (roleResult.isEmpty) roleResult = 'inativo';
          isAdminResult = (roleResult == 'admin');

          userInstitutionResult = null;
          userCidadeSuperintendenciaFetched = null;

          if (!isAdminResult && roleResult != 'inativo') {
            if (roleResult == kRoleSuperintendencia) {
              // Compara com a constante local 'SUPERINTENDENCIA'
              // Para usuários SUPERINTENDENCIA, busca sua cidade no perfil
              // Usa kUserProfileCidadeSuperintendencia de chamado_service.dart (valor 'cidadeSuperintendencia')
              userCidadeSuperintendenciaFetched =
                  userData[kUserProfileCidadeSuperintendencia] as String?;
              if (userCidadeSuperintendenciaFetched != null &&
                  userCidadeSuperintendenciaFetched.isEmpty) {
                userCidadeSuperintendenciaFetched = null;
              }
            } else {
              // Para outros papéis não-admin (ex: ESCOLA), busca a instituição
              // Usa kFieldUserInstituicao de chamado_service.dart (valor 'institution')
              userInstitutionResult =
                  userData[kFieldUserInstituicao] as String?;
              if (userInstitutionResult != null &&
                  userInstitutionResult.isEmpty) {
                userInstitutionResult = null;
              }
            }
          }
        } else {
          roleResult = 'inativo';
        }
      } catch (e) {
        roleResult = 'inativo';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao verificar permissões: $e')),
          );
        }
        print("Erro em _checkUserRole: $e");
      }
    } else {
      roleResult = 'inativo';
    }

    if (mounted) {
      setState(() {
        _isAdmin = isAdminResult;
        _userRole = roleResult;
        _currentUserInstitution = userInstitutionResult;
        _userCidadeSuperintendencia = userCidadeSuperintendenciaFetched;
        _isLoadingRole = false;
      });
      print(
          "User role set to: $_userRole, Cidade Super: $_userCidadeSuperintendencia, Instituição: $_currentUserInstitution"); // Log para depuração
    }
  }

  bool get _isFilterActive {
    return _selectedStatusFilter != null ||
        _selectedDateFilter != null ||
        (_selectedSortOption['field'] != kFieldDataCriacao ||
            _selectedSortOption['descending'] != true) ||
        widget.searchQuery.isNotEmpty;
  }

  Query _buildFirestoreQuery() {
    Query query = FirebaseFirestore.instance.collection(kCollectionChamados);

    if (_isLoadingRole) {
      return query.where(FieldPath.documentId,
          isEqualTo: _dummyNonExistentDocId);
    }

    if (!_isAdmin && _userRole == 'inativo') {
      return query.where(FieldPath.documentId,
          isEqualTo: _dummyNonExistentDocId);
    }

    if (!_isAdmin && _currentUser != null) {
      bool canQueryBasedOnRole = false;

      if (_userRole == kRoleSuperintendencia) {
        // Usuário é SUPERINTENDENCIA
        if (_userCidadeSuperintendencia != null &&
            _userCidadeSuperintendencia!.isNotEmpty) {
          // Filtra chamados pela cidade da superintendência do usuário.
          // kFieldCidadeSuperintendencia (valor 'cidade_superintendencia') é o campo no DOC DE CHAMADO.
          query = query.where(kFieldCidadeSuperintendencia,
              isEqualTo: _userCidadeSuperintendencia);
          canQueryBasedOnRole = true;
        } else {
          print(
              "Usuário SUPERINTENDENCIA ($_userRole) sem cidade definida no perfil para filtro.");
        }
      } else {
        // Outros tipos de usuário não-admin (ex: ESCOLA, requester, etc.)
        if (_currentUserInstitution != null &&
            _currentUserInstitution!.isNotEmpty) {
          // Filtra pela unidade organizacional (instituição/escola) do usuário.
          // kFieldUnidadeOrganizacionalChamado é o campo no DOC DE CHAMADO.
          query = query.where(kFieldUnidadeOrganizacionalChamado,
              isEqualTo: _currentUserInstitution);
          canQueryBasedOnRole = true;
        } else {
          print(
              "Usuário não-SUPERINTENDENCIA ($_userRole) sem instituição definida para filtro.");
        }
      }

      if (!canQueryBasedOnRole) {
        // Se o critério específico do papel (cidade para SUPER ou instituição para outros)
        // não estiver definido no perfil do usuário, não retorna nenhum chamado para evitar vazamento de dados.
        print(
            "Critério de filtro baseado no papel não pôde ser aplicado para $_userRole. Retornando query vazia.");
        return query.where(FieldPath.documentId,
            isEqualTo: _dummyNonExistentDocId);
      }

      // Filtros comuns para usuários não-admin (status, admin_inativo)
      if (_selectedStatusFilter != null) {
        query = query.where(kFieldStatus, isEqualTo: _selectedStatusFilter);
      } else {
        query = query.where(kFieldStatus, whereNotIn: [kStatusFinalizado]);
      }
      query = query.where(kFieldAdminInativo, isEqualTo: false);
    } else if (_isAdmin) {
      // Lógica para Admin (vê todos os chamados, respeitando filtros de status)
      if (_selectedStatusFilter != null) {
        query = query.where(kFieldStatus, isEqualTo: _selectedStatusFilter);
      } else {
        query = query.where(kFieldStatus, whereNotIn: [kStatusFinalizado]);
      }
    } else {
      // Usuário não logado ou papel indeterminado após carregamento
      return query.where(FieldPath.documentId,
          isEqualTo: _dummyNonExistentDocId);
    }

    // Filtro de data (aplicado a todos os papéis se definido)
    if (_selectedDateFilter != null) {
      final DateTime startOfDay = DateTime(_selectedDateFilter!.year,
          _selectedDateFilter!.month, _selectedDateFilter!.day, 0, 0, 0);
      final DateTime endOfDay = DateTime(
          _selectedDateFilter!.year,
          _selectedDateFilter!.month,
          _selectedDateFilter!.day,
          23,
          59,
          59,
          999);
      query = query.where(kFieldDataCriacao,
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          isLessThanOrEqualTo: Timestamp.fromDate(endOfDay));
    }

    // Ordenação (aplicada a todos os papéis)
    final String sortField = _selectedSortOption['field'] as String;
    final bool sortDescending = _selectedSortOption['descending'] as bool;
    query = query.orderBy(sortField, descending: sortDescending);

    if (sortField != kFieldDataCriacao) {
      query = query.orderBy(kFieldDataCriacao, descending: true);
    }
    return query;
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16.0))),
      builder: (BuildContext builderContext) {
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter sheetSetState) {
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;
          return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.75,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              builder: (_, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16.0).copyWith(
                      bottom: MediaQuery.of(context).viewInsets.bottom + 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Filtros e Ordenação',
                              style: theme.textTheme.titleLarge),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedStatusFilter = null;
                                _selectedDateFilter = null;
                                _selectedSortOption = _sortOptions[0];
                              });
                              Navigator.pop(builderContext);
                            },
                            child: const Text('Limpar Tudo'),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Text('Filtrar por Status:',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children: _statusOptions.map((statusValue) {
                          final bool isSelected =
                              _selectedStatusFilter == statusValue;
                          return FilterChip(
                            label: Text(statusValue),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedStatusFilter =
                                    selected ? statusValue : null;
                              });
                              sheetSetState(() {});
                            },
                            selectedColor: colorScheme.primaryContainer,
                            checkmarkColor: colorScheme.onPrimaryContainer,
                            labelStyle: TextStyle(
                                color: isSelected
                                    ? colorScheme.onPrimaryContainer
                                    : colorScheme.onSurfaceVariant),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      Text('Filtrar por Data de Criação:',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.calendar_today, size: 18),
                              label: Text(
                                _selectedDateFilter == null
                                    ? 'Selecionar Data do Chamado'
                                    : 'Data: ${DateFormat('dd/MM/yyyy', 'pt_BR').format(_selectedDateFilter!)}',
                              ),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () async {
                                final DateTime? pickedDate =
                                    await showDatePicker(
                                  context: context,
                                  initialDate:
                                      _selectedDateFilter ?? DateTime.now(),
                                  firstDate: DateTime(DateTime.now().year - 5),
                                  lastDate: DateTime.now()
                                      .add(const Duration(days: 365)),
                                  locale: const Locale('pt', 'BR'),
                                );
                                if (pickedDate != null) {
                                  setState(() {
                                    _selectedDateFilter = pickedDate;
                                  });
                                  sheetSetState(() {});
                                }
                              },
                            ),
                          ),
                          if (_selectedDateFilter != null) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(Icons.clear,
                                  color: Colors.grey.shade600),
                              tooltip: 'Limpar Filtro de Data',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                setState(() {
                                  _selectedDateFilter = null;
                                });
                                sheetSetState(() {});
                              },
                            )
                          ]
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text('Ordenar por:', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children: _sortOptions.map((option) {
                          final bool isSelected =
                              _selectedSortOption['label'] == option['label'];
                          return ChoiceChip(
                            label: Text(option['label'] as String),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedSortOption = option;
                                });
                                sheetSetState(() {});
                              }
                            },
                            selectedColor: colorScheme.primaryContainer,
                            labelStyle: TextStyle(
                                color: isSelected
                                    ? colorScheme.onPrimaryContainer
                                    : colorScheme.onSurfaceVariant,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          child: const Text('Aplicar Filtros e Ordenação'),
                          onPressed: () {
                            Navigator.pop(builderContext);
                          },
                        ),
                      ),
                    ],
                  ),
                );
              });
        });
      },
    );
  }

  Future<void> _excluirChamado(BuildContext context, String chamadoId) async {
    if (!_isAdmin || !mounted) return;
    bool confirmar = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirmar Exclusão'),
            content: const Text(
                'Deseja realmente excluir este chamado? Esta ação é irreversível.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancelar')),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text('Excluir',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmar || !mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await _chamadoService.excluirChamado(chamadoId);
      if (mounted) {
        scaffoldMessenger.showSnackBar(const SnackBar(
            content: Text('Chamado excluído!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(SnackBar(
            content: Text('Erro ao excluir: ${e.toString()}'),
            backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _handleRequerenteConfirmar(String chamadoId) async {
    final user = _auth.currentUser;
    if (user == null || !mounted) return;

    setState(() {
      _isConfirmingAcceptance = true;
      _confirmingChamadoId = chamadoId;
    });
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await _chamadoService.confirmarServicoRequerente(chamadoId, user);
      if (mounted) {
        scaffoldMessenger.showSnackBar(const SnackBar(
            content: Text('Serviço confirmado com sucesso!'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(SnackBar(
            content: Text('Erro: ${e.toString()}'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConfirmingAcceptance = false;
          _confirmingChamadoId = null;
        });
      }
    }
  }

  Future<void> _handleFinalizarArquivarChamado(String chamadoId) async {
    if (!_isAdmin || _currentUser == null || !mounted) return;
    setState(() {
      _isLoadingFinalizarDaLista = true;
      _idChamadoFinalizandoDaLista = chamadoId;
    });
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await _chamadoService.adminConfirmarSolucaoFinal(
          chamadoId, _currentUser!);
      if (mounted) {
        scaffoldMessenger.showSnackBar(const SnackBar(
            content: Text('Chamado arquivado com sucesso!'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(SnackBar(
            content: Text('Erro ao arquivar: ${e.toString()}'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFinalizarDaLista = false;
          _idChamadoFinalizandoDaLista = null;
        });
      }
    }
  }

  Future<String?> _getSignatureUrlFromFirestoreLista(String? userId) async {
    if (userId == null || userId.isEmpty) return null;
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection(kCollectionUsers) // Constante de chamado_service.dart
          .doc(userId)
          .get();
      if (userDoc.exists && userDoc.data() != null) {
        final userData = userDoc.data() as Map<String, dynamic>;
        // Usa kFieldUserAssinaturaUrl de chamado_service.dart
        return userData[kFieldUserAssinaturaUrl] as String?;
      }
    } catch (e) {
      print(
          "ListaChamadosScreen: Erro ao buscar URL da assinatura para $userId: $e");
    }
    return null;
  }

  Future<void> _handleGerarPdfOpcoes(
      String chamadoId, Map<String, dynamic> chamadoData) async {
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    BuildContext currentContext =
        context; // Captura o context antes de async gaps

    setState(() {
      _idChamadoGerandoPdf = chamadoId;
    });

    // Mostra o diálogo de carregamento usando o context capturado
    showDialog(
      context: currentContext,
      barrierDismissible: false,
      builder: (dialogCtx) => const PopScope(
          canPop: false, // Impede fechar o diálogo com o botão voltar
          child: Center(
              child: CircularProgressIndicator(semanticsLabel: "Gerando PDF"))),
    );

    Uint8List? pdfBytes;
    try {
      String? adminSigUrl;
      final String? adminSolucionouUid =
          chamadoData[kFieldSolucaoPorUid] as String?;
      if (adminSolucionouUid != null && adminSolucionouUid.isNotEmpty) {
        adminSigUrl =
            await _getSignatureUrlFromFirestoreLista(adminSolucionouUid);
      }

      String? requesterSigUrl;
      final bool requerenteConfirmou =
          chamadoData[kFieldRequerenteConfirmou] as bool? ?? false;
      final String? uidDoRequerenteQueConfirmou =
          chamadoData[kFieldRequerenteConfirmouUid] as String?;
      if (requerenteConfirmou &&
          uidDoRequerenteQueConfirmou != null &&
          uidDoRequerenteQueConfirmou.isNotEmpty) {
        requesterSigUrl = await _getSignatureUrlFromFirestoreLista(
            uidDoRequerenteQueConfirmou);
      }

      pdfBytes = await pdfGen.PdfGenerator.generateTicketPdfBytes(
        chamadoId: chamadoId,
        dadosChamado: chamadoData,
        adminSignatureUrl: adminSigUrl,
        requesterSignatureUrl: requesterSigUrl,
      );
    } catch (e) {
      // Fecha o diálogo de carregamento se ainda estiver aberto
      if (Navigator.of(currentContext, rootNavigator: true).canPop()) {
        Navigator.of(currentContext, rootNavigator: true).pop();
      }
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
              content: Text('Erro ao gerar PDF: $e'),
              backgroundColor: Colors.red),
        );
      }
      setState(() {
        _idChamadoGerandoPdf = null;
      });
      return;
    }

    // Fecha o diálogo de carregamento após a geração do PDF (sucesso)
    if (Navigator.of(currentContext, rootNavigator: true).canPop()) {
      Navigator.of(currentContext, rootNavigator: true).pop();
    }

    setState(() {
      _idChamadoGerandoPdf = null;
    });

    if (!mounted || pdfBytes == null) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
              content: Text('Falha ao gerar bytes do PDF.'),
              backgroundColor: Colors.orange),
        );
      }
      return;
    }

    // Usa o context original do widget para o showDialog das opções
    showDialog(
      context: this.context, // Usar this.context para o diálogo de opções
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Opções do PDF'),
          content:
              const Text('O que você gostaria de fazer com o PDF do chamado?'),
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          actions: <Widget>[
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Compartilhar'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _compartilharPdfLista(pdfBytes!, chamadoId);
                  },
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Imprimir / Salvar'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _imprimirPdfLista(pdfBytes!);
                  },
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  icon: const Icon(Icons.open_in_new_outlined),
                  label: const Text('Abrir / Visualizar'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _abrirPdfLocalmenteLista(pdfBytes!, chamadoId);
                  },
                ),
                const SizedBox(height: 8),
                TextButton(
                  child: const Text('Cancelar'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _compartilharPdfLista(
      Uint8List pdfBytes, String chamadoId) async {
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await Printing.sharePdf(
          bytes: pdfBytes,
          filename:
              'chamado_${chamadoId.substring(0, min(6, chamadoId.length))}.pdf');
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
              content: Text('Erro ao compartilhar PDF: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _imprimirPdfLista(Uint8List pdfBytes) async {
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await Printing.layoutPdf(
          onLayout: (pdf_page_format.PdfPageFormat format) async => pdfBytes);
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
              content: Text('Erro ao preparar impressão: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _abrirPdfLocalmenteLista(
      Uint8List pdfBytes, String chamadoId) async {
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    BuildContext currentContextForDialog = context; // Captura context

    showDialog(
      context: currentContextForDialog, // Usa context capturado
      barrierDismissible: false,
      builder: (_) => const PopScope(
          canPop: false,
          child: Center(
              child: CircularProgressIndicator(semanticsLabel: "Abrindo PDF"))),
    );

    try {
      final outputDir = await getTemporaryDirectory();
      final filename =
          'chamado_${chamadoId.substring(0, min(6, chamadoId.length))}.pdf';
      final outputFile = File("${outputDir.path}/$filename");
      await outputFile.writeAsBytes(pdfBytes);

      // Fecha o diálogo de carregamento ANTES de tentar abrir o arquivo
      if (Navigator.of(currentContextForDialog, rootNavigator: true).canPop()) {
        Navigator.of(currentContextForDialog, rootNavigator: true).pop();
      }

      final result = await OpenFilex.open(outputFile.path);

      if (result.type != ResultType.done && mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
              content: Text('Não foi possível abrir o PDF: ${result.message}')),
        );
      }
    } catch (e) {
      // Garante que o diálogo de carregamento seja fechado em caso de erro
      if (Navigator.of(currentContextForDialog, rootNavigator: true).canPop()) {
        Navigator.of(currentContextForDialog, rootNavigator: true).pop();
      }
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
              content: Text('Erro ao abrir PDF localmente: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: Icon(
                  Icons.filter_list_alt,
                  color: _isFilterActive
                      ? colorScheme.primary
                      : AppTheme.kWinSecondaryText,
                  size: 20,
                ),
                label: Text('Filtros',
                    style: TextStyle(
                        color: _isFilterActive
                            ? colorScheme.primary
                            : AppTheme.kWinSecondaryText)),
                onPressed: _showFilterBottomSheet,
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingRole
              ? const Center(child: CircularProgressIndicator())
              : StreamBuilder<QuerySnapshot>(
                  stream: _buildFirestoreQuery().snapshots(),
                  builder: (BuildContext context,
                      AsyncSnapshot<QuerySnapshot> snapshot) {
                    if (snapshot.hasError) {
                      // Evita mostrar erro se for apenas a query dummy inicial
                      if (snapshot.error
                              .toString()
                              .contains(_dummyNonExistentDocId) ||
                          snapshot.error
                              .toString()
                              .contains('__inexistente__')) {
                        return Center(
                            child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                    'Aguardando dados do usuário...', // Mensagem mais clara
                                    textAlign: TextAlign.center)));
                      }
                      return Center(
                          child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text('Ocorreu um erro: ${snapshot.error}',
                                  textAlign: TextAlign.center)));
                    }

                    if (snapshot.connectionState == ConnectionState.waiting &&
                        _ultimosChamadosFiltradosParaExibicao.isEmpty &&
                        !_isFilterActive) {
                      // Considera se há filtros ativos
                      return const Center(child: CircularProgressIndicator());
                    }

                    List<Chamado> chamadosDoFirestore = [];
                    if (snapshot.hasData) {
                      chamadosDoFirestore = snapshot.data!.docs
                          .map((doc) {
                            try {
                              return Chamado.fromFirestore(doc
                                  as DocumentSnapshot<Map<String, dynamic>>);
                            } catch (e, s) {
                              print(
                                  "DEBUG: Erro ao converter chamado (ID: ${doc.id}): $e\nStackTrace: $s");
                              return null;
                            }
                          })
                          .where((chamado) => chamado != null)
                          .cast<Chamado>()
                          .toList();
                      _searchLogic.setChamadosSource(chamadosDoFirestore);
                    } else if (snapshot.connectionState !=
                        ConnectionState.waiting) {
                      // Se não há dados e não está esperando, usa a lista anterior (pode estar vazia)
                      _searchLogic.setChamadosSource(
                          _ultimosChamadosFiltradosParaExibicao);
                    }

                    _searchLogic.filterChamadosComQuery(widget.searchQuery);
                    _ultimosChamadosFiltradosParaExibicao =
                        _searchLogic.resultadosFiltrados;

                    if (_ultimosChamadosFiltradosParaExibicao.isEmpty) {
                      String msg = "Nenhum chamado encontrado.";
                      IconData icone = Icons.inbox_outlined;

                      if (!_isAdmin && _userRole == 'inativo') {
                        msg =
                            'Nenhum chamado disponível.\nSua conta está aguardando ativação.';
                        icone = Icons.hourglass_empty_rounded;
                      } else if (_isFilterActive) {
                        msg =
                            'Nenhum chamado encontrado com os critérios aplicados.';
                        if (widget.searchQuery.isNotEmpty) {
                          msg += '\nPesquisa: "${widget.searchQuery}"';
                        }
                        icone = Icons.filter_alt_off_outlined;
                      } else if (!_isLoadingRole) {
                        // Apenas mostra mensagens específicas se o papel já carregou
                        if (_isAdmin) {
                          msg =
                              'Nenhum chamado ativo no sistema (chamados finalizados não são exibidos aqui).';
                          icone = Icons.inbox_outlined;
                        } else {
                          // Usuário não-admin
                          if (_userRole == kRoleSuperintendencia) {
                            if (_userCidadeSuperintendencia == null ||
                                _userCidadeSuperintendencia!.isEmpty) {
                              msg =
                                  'Sua cidade de superintendência não está definida no perfil.\nNão é possível listar chamados.';
                              icone = Icons.location_city_outlined;
                            } else {
                              msg =
                                  'Nenhum chamado encontrado para sua cidade de superintendência ($_userCidadeSuperintendencia).\n(Chamados finalizados não são exibidos aqui).';
                              icone = Icons.assignment_late_outlined;
                            }
                          } else {
                            // Outros não-admin (ex: ESCOLA)
                            if (_currentUserInstitution == null ||
                                _currentUserInstitution!.isEmpty) {
                              msg =
                                  'Sua instituição não está definida no perfil.\nNão é possível listar chamados.';
                              icone = Icons.business_outlined;
                            } else {
                              msg =
                                  'Nenhum chamado encontrado para a sua instituição: "$_currentUserInstitution".\n(Chamados finalizados não são exibidos aqui).';
                              icone = Icons.assignment_late_outlined;
                            }
                          }
                        }
                      } else {
                        msg =
                            "Carregando chamados..."; // Mensagem enquanto _isLoadingRole é true
                        icone = Icons.hourglass_top_outlined;
                      }

                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(icone, size: 50, color: Colors.grey[500]),
                              const SizedBox(height: 16),
                              Text(msg,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(color: Colors.grey[600])),
                              if (_isFilterActive &&
                                  !(_userRole == 'inativo' && !_isAdmin)) ...[
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.clear_all),
                                  label:
                                      const Text('Limpar Filtros e Pesquisa'),
                                  onPressed: () {
                                    setState(() {
                                      _selectedStatusFilter = null;
                                      _selectedDateFilter = null;
                                      _selectedSortOption = _sortOptions[0];
                                      // Idealmente, a query de pesquisa também seria limpa aqui,
                                      // o que pode exigir um callback para o widget pai se a query vier de lá.
                                      // Se widget.searchQuery é gerenciado externamente, essa ação pode não limpá-la.
                                    });
                                  },
                                )
                              ]
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.only(
                          top: 8.0, left: 8.0, right: 8.0, bottom: 72.0),
                      itemCount: _ultimosChamadosFiltradosParaExibicao.length,
                      itemBuilder: (BuildContext context, int index) {
                        final Chamado chamado =
                            _ultimosChamadosFiltradosParaExibicao[index];
                        final String chamadoId = chamado.id;

                        Map<String, dynamic> chamadoDataMap;
                        DocumentSnapshot? originalDoc;

                        // Tenta encontrar o documento original no snapshot para ter os dados mais recentes
                        if (snapshot.hasData) {
                          try {
                            originalDoc = snapshot.data!.docs.firstWhere(
                              (doc) => doc.id == chamado.id,
                              // orElse: () => null, // Em versões mais antigas do Dart, pode precisar disso
                            );
                          } catch (e) {
                            // firstWhere lança StateError se não encontrar
                            originalDoc = null;
                          }
                        }

                        if (originalDoc != null &&
                            originalDoc.exists &&
                            originalDoc.data() != null) {
                          chamadoDataMap =
                              originalDoc.data() as Map<String, dynamic>;
                        } else {
                          // CORREÇÃO: Fallback para atribuição manual dos campos do objeto Chamado.
                          print(
                              "WARN: Usando dados de fallback para ChamadoListItem ID: ${chamado.id}. Snapshot pode estar desalinhado ou doc ausente.");
                          chamadoDataMap = {
                            'id': chamado
                                .id, // Embora já tenhamos chamadoId, é bom ter no mapa.
                            kFieldStatus: chamado.status,
                            kFieldPrioridade: chamado.prioridade,
                            kFieldDataCriacao: chamado.dataAbertura,
                            kFieldNomeSolicitante: chamado.nomeSolicitante,
                            kFieldTipoSolicitante: chamado.tipoSolicitante,
                            kFieldUnidadeOrganizacionalChamado:
                                chamado.unidadeOrganizacionalChamado,
                            kFieldEquipamentoSolicitacao:
                                chamado.equipamentoSelecionado,
                            kFieldProblemaOcorre: chamado.problemaSelecionado,
                            kFieldPatrimonio: chamado.patrimonio,
                            kFieldCreatorUid: chamado.solicitanteUid,
                            kFieldTecnicoResponsavel:
                                chamado.tecnicoResponsavelNome,
                            kFieldTecnicoUid: chamado.tecnicoUid,
                            kFieldDataAtualizacao: chamado.dataAtualizacao,
                            kFieldSolucao: chamado.solucao,
                            kFieldRequerenteConfirmou:
                                chamado.requerenteConfirmouSolucao,
                            kFieldRequerenteConfirmouData:
                                chamado.requerenteConfirmouData,
                            kFieldNomeRequerenteConfirmador:
                                chamado.nomeRequerenteConfirmador,
                            kFieldAdminFinalizou: chamado.adminFinalizouChamado,
                            kFieldAdminFinalizouNome:
                                chamado.adminFinalizouNome,
                            kFieldAdminFinalizouData:
                                chamado.adminFinalizouData,
                            kFieldAdminFinalizouUid: chamado.adminFinalizouUid,
                            kFieldSolucaoPorNome: chamado.solucaoPorNome,
                            kFieldSolucaoPorUid: chamado.solucaoPorUid,
                            kFieldDataDaSolucao: chamado.dataSolucao,
                            kFieldAdminInativo: chamado.adminInativo,
                            kFieldRequerenteConfirmouUid:
                                chamado.requerenteConfirmouUid,
                            // Campos específicos que podem ser nulos no modelo mas precisam estar no mapa para ChamadoListItem
                            kFieldCelularContato: chamado.celularContato,
                            kFieldEmailSolicitante: chamado.emailSolicitante,
                            kFieldConectadoInternet: chamado.internetConectada,
                            kFieldMarcaModelo: chamado.marcaModelo,
                            kFieldProblemaOutro: chamado.problemaOutro,
                            kFieldEquipamentoOutro: chamado.equipamentoOutro,
                            kFieldAuthUserDisplay:
                                _auth.currentUser?.displayName ?? '',
                            kFieldAuthUserEmail: _auth.currentUser?.email ?? '',
                            kFieldDataAtendimento: chamado.dataAtendimento,
                            kFieldCidade: chamado.cidade, // Para ESCOLA
                            kFieldInstituicao:
                                chamado.instituicao, // Para ESCOLA
                            kFieldInstituicaoManual:
                                chamado.instituicaoManual, // Para ESCOLA
                            kFieldCargoFuncao:
                                chamado.cargoSolicitante, // Para ESCOLA
                            kFieldAtendimentoPara:
                                chamado.atendimentoPara, // Para ESCOLA
                            kFieldSetorSuper:
                                chamado.setorSuperintendencia, // Para SUPER
                            kFieldCidadeSuperintendencia:
                                chamado.cidadeSuperintendencia, // Para SUPER
                          };
                        }

                        final bool isLoadingConfirmation =
                            _isConfirmingAcceptance &&
                                _confirmingChamadoId == chamadoId;
                        final bool isLoadingPdfItem =
                            _idChamadoGerandoPdf == chamadoId;
                        final bool isLoadingFinalizarItem =
                            _isLoadingFinalizarDaLista &&
                                _idChamadoFinalizandoDaLista == chamadoId;

                        return ChamadoListItem(
                          key: ValueKey(chamadoId +
                              (chamadoDataMap[kFieldDataAtualizacao]
                                      ?.millisecondsSinceEpoch
                                      .toString() ??
                                  chamado.id)),
                          chamadoId: chamadoId,
                          chamadoData: chamadoDataMap,
                          currentUser: _currentUser,
                          isAdmin: _isAdmin,
                          onConfirmar: (id) {
                            if (chamadoDataMap[kFieldCreatorUid] ==
                                _currentUser?.uid) {
                              _handleRequerenteConfirmar(id);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Apenas o solicitante original pode confirmar este chamado.'),
                                    backgroundColor: Colors.orange),
                              );
                            }
                          },
                          isLoadingConfirmation: isLoadingConfirmation,
                          onDelete: _isAdmin
                              ? () => _excluirChamado(context, chamadoId)
                              : null,
                          onNavigateToDetails: (id) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      DetalhesChamadoScreen(chamadoId: id)),
                            ).then((_) {
                              // Recarrega o estado da lista ao voltar para refletir possíveis mudanças
                              if (mounted) {
                                // Não é ideal chamar _checkUserRole aqui, pois pode refazer toda a query.
                                // Apenas um setState() pode ser suficiente se o StreamBuilder reconstruir
                                // ou forçar um refresh do stream.
                                // Para atualizações de itens individuais, o StreamBuilder deve lidar com isso.
                                setState(() {});
                              }
                            });
                          },
                          isLoadingPdfDownload: isLoadingPdfItem,
                          onGerarPdfOpcoes: (id, data) {
                            _handleGerarPdfOpcoes(id, data);
                          },
                          onFinalizarArquivar: (id) {
                            _handleFinalizarArquivarChamado(id);
                          },
                          isLoadingFinalizarArquivar: isLoadingFinalizarItem,
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

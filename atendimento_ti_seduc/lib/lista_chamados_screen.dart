import 'dart:math';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;

// Seus imports de projeto
import '../pdf_generator.dart' as pdfGen;
import '../detalhes_chamado_screen.dart' show DetalhesChamadoScreen;
import '../config/theme/app_theme.dart';
import '../widgets/chamado_list_item.dart'; // Seu widget de item da lista
import '../services/chamado_service.dart'; // Importa o serviço e as constantes

class ListaChamadosScreen extends StatefulWidget {
  const ListaChamadosScreen({super.key});

  @override
  State<ListaChamadosScreen> createState() => _ListaChamadosScreenState();
}

class _ListaChamadosScreenState extends State<ListaChamadosScreen> {
  final ChamadoService _chamadoService = ChamadoService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<QueryDocumentSnapshot>? _currentDocs;
  String? _selectedStatusFilter;

  // Usando constantes do chamado_service.dart
  final List<String> _statusOptions = [
    kStatusAberto, // 'Aberto'
    'Em Andamento', // Adicione como constante se for usado em mais lugares
    'Pendente',     // Adicione como constante
    kStatusPadraoSolicionado, // 'Solucionado'
    // kStatusFinalizado, // 'Finalizado' - Geralmente não é um filtro "ativo"
    kStatusCancelado, // 'Cancelado'
    'Aguardando Aprovação',
    'Aguardando Peça',
    'Chamado Duplicado',
    'Aguardando Equipamento',
    'Atribuido para GSIOR',
    'Garantia Fabricante',
  ];

  final List<Map<String, dynamic>> _sortOptions = [
    {'label': 'Mais Recentes', 'field': kFieldDataCriacao, 'descending': true},
    {'label': 'Mais Antigos', 'field': kFieldDataCriacao, 'descending': false},
    // Adicione kFieldPrioridade ao seu chamado_service.dart se não estiver lá
    {'label': 'Prioridade', 'field': kFieldPrioridade, 'descending': true},
    {'label': 'Status', 'field': kFieldStatus, 'descending': false},
  ];
  late Map<String, dynamic> _selectedSortOption;

  DateTime? _selectedDateFilter;
  bool _isAdmin = false;
  bool _isLoadingRole = true;
  User? _currentUser;
  String? _currentUserInstitution; // Para armazenar a instituição do requisitante

  bool _isConfirmingAcceptance = false;
  String? _confirmingChamadoId;

  String? _idChamadoGerandoPdf;
  String? _idChamadoFinalizandoDaLista;
  bool _isLoadingFinalizarDaLista = false;

  // Lista de status considerados "ativos" para a visualização principal do requisitante
  final List<String> _statusAtivosRequisitante = [
    kStatusAberto,
    'Em Andamento',
    'Pendente',
    // kStatusPadraoSolicionado, // Decida se "Solucionado" é ativo para esta lista
    'Aguardando Aprovação',
    'Aguardando Peça',
    'Chamado Duplicado',
    'Aguardando Equipamento',
    'Atribuido para GSIOR',
    'Garantia Fabricante',
  ];


  @override
  void initState() {
    super.initState();
    _selectedSortOption = _sortOptions[0]; // Padrão: Mais recentes
    // _currentUser = _auth.currentUser; // Será definido em _checkUserRole
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    if (!mounted) return;
    setState(() {
      _isLoadingRole = true;
    });

    User? user = _auth.currentUser;
    bool isAdminResult = false;
    String? userInstitutionResult;

    if (user != null) {
      _currentUser = user; // Atualiza _currentUser aqui
      try {
        final DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection(kCollectionUsers) // Usando constante
            .doc(user.uid)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data() as Map<String, dynamic>;
          isAdminResult = (userData[kFieldUserRole] == 'admin'); // Usando constante

          if (!isAdminResult) {
            // IMPORTANTE: Use o nome exato do campo da instituição no seu doc de usuário
            userInstitutionResult = userData[kFieldUserInstituicao] as String?;
            if (userInstitutionResult != null && userInstitutionResult.isEmpty) {
                userInstitutionResult = null; // Tratar string vazia como nula
            }
          }
        } else {
           print("ListaChamadosScreen: Documento do usuário ${user.uid} não encontrado.");
           // Definir como não admin e sem instituição se o doc não existe
           isAdminResult = false;
           userInstitutionResult = null;
        }
      } catch (e) {
        print("ListaChamadosScreen: Erro ao verificar role/instituição do usuário: $e");
        isAdminResult = false;
        userInstitutionResult = null;
      }
    } else {
      _currentUser = null;
      isAdminResult = false;
      userInstitutionResult = null;
    }

    if (mounted) {
      setState(() {
        _isAdmin = isAdminResult;
        _currentUserInstitution = userInstitutionResult;
        _isLoadingRole = false;
      });
    }
  }

  bool get _isFilterActive {
    return _selectedStatusFilter != null ||
        _selectedDateFilter != null ||
        _selectedSortOption['field'] != kFieldDataCriacao; // Considera ordenação diferente de padrão como filtro ativo
  }

  Query _buildFirestoreQuery() {
    Query query = FirebaseFirestore.instance.collection(kCollectionChamados);

    if (_isLoadingRole) {
      return query.where('__inexistente__', isEqualTo: '__aguardando_role__');
    }

    if (_currentUser == null) {
      return query.where('__inexistente__', isEqualTo: '__sem_resultados_user_null__');
    }

    // Lógica para REQUISITANTES
    if (!_isAdmin) {
      if (_currentUserInstitution == null || _currentUserInstitution!.isEmpty) {
        // Requisitante sem instituição: mostra APENAS os seus próprios chamados ativos
        print("Aviso: Requisitante ${_currentUser!.uid} sem instituição. Mostrando apenas seus chamados ativos.");
        query = query.where(kFieldCreatorUid, isEqualTo: _currentUser!.uid);
        // E filtra por status ativos, se nenhum filtro de status específico estiver selecionado
        if (_selectedStatusFilter == null) {
             query = query.where(kFieldStatus, whereIn: _statusAtivosRequisitante);
        } else {
             query = query.where(kFieldStatus, isEqualTo: _selectedStatusFilter);
        }

      } else {
        // Requisitante COM instituição:
        query = query.where(
          Filter.or(
            Filter(kFieldCreatorUid, isEqualTo: _currentUser!.uid),
            Filter(kFieldUnidadeOrganizacionalChamado,isEqualTo: _currentUserInstitution),
          ),
        );
        // Adicionalmente, para requisitantes, sempre filtramos por status ativos,
        // a menos que um filtro de status específico esteja selecionado.
        if (_selectedStatusFilter == null) {
            query = query.where(kFieldStatus, whereIn: _statusAtivosRequisitante);
        } else {
            // Se um status foi selecionado no filtro, ele já está sendo aplicado
            query = query.where(kFieldStatus, isEqualTo: _selectedStatusFilter);
        }
      }
    } else { // Lógica para ADMINS
        // Admins veem todos os chamados, exceto se um filtro de status específico for aplicado
        if (_selectedStatusFilter != null) {
            query = query.where(kFieldStatus, isEqualTo: _selectedStatusFilter);
        } else {
            // Se nenhum filtro de status, admin vê todos os status exceto os explicitamente "finalizados/arquivados"
            // Se você quiser que o admin veja TODOS MESMO por padrão (incluindo finalizados), remova este where.
             query = query.where(kFieldStatus, whereNotIn: [kStatusFinalizado, kStatusCancelado]);
        }
    }


    // Filtro de data (comum a todos os perfis quando aplicado)
    if (_selectedDateFilter != null) {
      final DateTime startOfDay = DateTime(_selectedDateFilter!.year, _selectedDateFilter!.month, _selectedDateFilter!.day, 0, 0, 0);
      final DateTime endOfDay = DateTime(_selectedDateFilter!.year, _selectedDateFilter!.month, _selectedDateFilter!.day, 23, 59, 59, 999);
      query = query.where(kFieldDataCriacao, isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay), isLessThanOrEqualTo: Timestamp.fromDate(endOfDay));
    }

    // Ordenação
    final String sortField = _selectedSortOption['field'] as String;
    final bool sortDescending = _selectedSortOption['descending'] as bool;

    query = query.orderBy(sortField, descending: sortDescending);

    if (sortField != kFieldDataCriacao) {
      // Adicionar ordenação secundária por data de criação para consistência,
      // se a ordenação primária não for por data.
      query = query.orderBy(kFieldDataCriacao, descending: true); // Mais recentes primeiro como desempate
    }
    return query;
  }

 void _applyCustomClientSort(List<QueryDocumentSnapshot> docs) {
    // Se a ordenação principal for por status "Solucionado" primeiro
    if (_selectedSortOption['field'] == kFieldStatus && _selectedSortOption['label'] == 'Status') { // Ajuste o 'label' se necessário
        docs.sort((aDoc, bDoc) {
            Map<String, dynamic> aData = aDoc.data() as Map<String, dynamic>;
            Map<String, dynamic> bData = bDoc.data() as Map<String, dynamic>;

            String statusA = aData[kFieldStatus]?.toString().toLowerCase() ?? '';
            String statusB = bData[kFieldStatus]?.toString().toLowerCase() ?? '';
            String solvedForSortLower = kStatusPadraoSolicionado.toLowerCase();

            bool aIsSolved = (statusA == solvedForSortLower);
            bool bIsSolved = (statusB == solvedForSortLower);

            // "Solucionado" primeiro, outros depois.
            // Se 'descending' for true na opção de sort por status, inverteria a lógica (não solucionados primeiro)
            // Aqui, vamos assumir que "Solucionado" é sempre prioritário na exibição quando ordenado por status.
            if (aIsSolved && !bIsSolved) return -1; // a vem antes
            if (!aIsSolved && bIsSolved) return 1;  // b vem antes

            // Se ambos são "Solucionado" ou ambos não são, ordena por data de criação (mais recente primeiro)
            Timestamp? aTimestamp = aData[kFieldDataCriacao] as Timestamp?;
            Timestamp? bTimestamp = bData[kFieldDataCriacao] as Timestamp?;
            if (aTimestamp != null && bTimestamp != null) return bTimestamp.compareTo(aTimestamp);
            if (bTimestamp != null) return 1;
            if (aTimestamp != null) return -1;
            return 0;
        });
    }
    // Adicione outras lógicas de sort no cliente se necessário.
    // Por padrão, a ordenação do Firestore já deve ser suficiente com os orderBy.
}


  Future<void> _excluirChamado(BuildContext context, String chamadoId) async {
    if (!_isAdmin || !mounted) return;
    bool confirmar = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirmar Exclusão'),
            content: const Text(
                'Deseja realmente excluir este chamado?\nEsta ação é irreversível e também excluirá todos os comentários associados.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text('Excluir', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmar || !mounted) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Excluindo chamado...')));
    try {
      await _chamadoService.excluirChamado(chamadoId); // Chama o método do serviço
      if (mounted) {
        scaffoldMessenger.removeCurrentSnackBar();
        scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Chamado excluído com sucesso!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.removeCurrentSnackBar();
        scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('Erro ao excluir chamado: ${e.toString()}'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _handleRequerenteConfirmar(String chamadoId) async {
    final user = _auth.currentUser;
    if (user == null || !mounted) return;

    // Verifica se é o criador do chamado ANTES de tentar a operação
    // Isso pode ser feito buscando o chamado ou se você já tiver o creatorUid no item da lista
    // Para simplificar, vamos assumir que ChamadoListItem pode passar `data[kFieldCreatorUid] == _currentUser?.uid`

    setState(() {
      _isConfirmingAcceptance = true;
      _confirmingChamadoId = chamadoId;
    });
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await _chamadoService.confirmarServicoRequerente(chamadoId, user);
      if (mounted) {
        scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Serviço confirmado com sucesso!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('Erro: ${e.toString()}'), backgroundColor: Colors.red));
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
      await _chamadoService.adminConfirmarSolucaoFinal(chamadoId, _currentUser!);
      if (mounted) {
        scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Chamado arquivado com sucesso!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('Erro ao arquivar: ${e.toString()}'), backgroundColor: Colors.red));
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

  Future<String?> _getSignatureUrlFromFirestore(String? userId) async {
    if (userId == null || userId.isEmpty) return null;
    try {
      DocumentSnapshot userDoc =
          await FirebaseFirestore.instance.collection(kCollectionUsers).doc(userId).get(); // Usando constante
      if (userDoc.exists && userDoc.data() != null) {
        final userData = userDoc.data() as Map<String, dynamic>;
        return userData[kFieldUserAssinaturaUrl] as String?; // Usando constante
      }
    } catch (e) {
      print("ListaChamadosScreen: Erro ao buscar URL da assinatura para $userId: $e");
    }
    return null;
  }

  Future<void> _handleGerarPdfOpcoes(String chamadoId, Map<String, dynamic> chamadoData) async {
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    BuildContext currentContext = context;

    setState(() {
      _idChamadoGerandoPdf = chamadoId;
    });

    showDialog(
      context: currentContext,
      barrierDismissible: false,
      builder: (dialogCtx) => PopScope(
          canPop: false,
          child: const Center(child: CircularProgressIndicator(backgroundColor: Colors.white))),
    );

    Uint8List? pdfBytes;
    String? adminSigUrl;
    String? requesterSigUrl;
    String? nomeRequerenteConfirmadorParaPdf; // Para passar ao gerador de PDF

    try {
      final String? adminSolucionouUid = chamadoData[kFieldSolucaoPorUid] as String?;
      if (adminSolucionouUid != null && adminSolucionouUid.isNotEmpty) {
        adminSigUrl = await _getSignatureUrlFromFirestore(adminSolucionouUid);
      }

      final bool requerenteConfirmouChamado = chamadoData[kFieldRequerenteConfirmou] as bool? ?? false;
      final String? uidDoRequerenteQueConfirmou = chamadoData[kFieldRequerenteConfirmouUid] as String?;
      if (requerenteConfirmouChamado && uidDoRequerenteQueConfirmou != null && uidDoRequerenteQueConfirmou.isNotEmpty) {
        requesterSigUrl = await _getSignatureUrlFromFirestore(uidDoRequerenteQueConfirmou);
        nomeRequerenteConfirmadorParaPdf = chamadoData[kFieldNomeRequerenteConfirmador] as String?;
         if (nomeRequerenteConfirmadorParaPdf == null || nomeRequerenteConfirmadorParaPdf.isEmpty) {
          // Fallback se o nome não foi salvo (deve ser salvo em confirmarServicoRequerente)
          DocumentSnapshot userConfirmadorDoc = await FirebaseFirestore.instance.collection(kCollectionUsers).doc(uidDoRequerenteQueConfirmou).get();
          if(userConfirmadorDoc.exists){
            nomeRequerenteConfirmadorParaPdf = (userConfirmadorDoc.data() as Map<String,dynamic>)['displayName'] as String? ?? // Assumindo campo 'displayName'
                                             (userConfirmadorDoc.data() as Map<String,dynamic>)['nome'] as String? ?? // Ou 'nome'
                                             'Requerente (${uidDoRequerenteQueConfirmou.substring(0,6)})';

          } else {
            nomeRequerenteConfirmadorParaPdf = 'Requerente (${uidDoRequerenteQueConfirmou.substring(0,6)})';
          }
        }
      }


      pdfBytes = await pdfGen.PdfGenerator.generateTicketPdfBytes(
        chamadoId: chamadoId,
        dadosChamado: chamadoData,
        adminSignatureUrl: adminSigUrl,
        requesterSignatureUrl: requesterSigUrl,
        // Adicionar o nome do requerente que confirmou ao gerador de PDF
        nomeRequerenteConfirmou: nomeRequerenteConfirmadorParaPdf,
      );

    } catch (e) {
      if (Navigator.of(currentContext, rootNavigator: true).canPop()) {
        Navigator.of(currentContext, rootNavigator: true).pop();
      }
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Erro ao gerar PDF: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
      setState(() {
        _idChamadoGerandoPdf = null;
      });
      return;
    }

    if (Navigator.of(currentContext, rootNavigator: true).canPop()) {
      Navigator.of(currentContext, rootNavigator: true).pop();
    }

    if (mounted) {
      setState(() {
        _idChamadoGerandoPdf = null;
      });
    }

    if (pdfBytes != null && mounted) {
      _mostrarOpcoesPdfDialog(pdfBytes, chamadoId);
    } else if (mounted) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Falha ao gerar dados para o PDF.'), backgroundColor: Colors.orange),
      );
    }
  }

  void _mostrarOpcoesPdfDialog(Uint8List pdfBytes, String chamadoId) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Opções do PDF'),
          content: const Text('O que você gostaria de fazer com o PDF do chamado?'),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          actions: <Widget>[
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Imprimir / Salvar'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _imprimirPdfLista(pdfBytes);
                  },
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  icon: const Icon(Icons.open_in_new_outlined),
                  label: const Text('Abrir / Visualizar'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _abrirPdfLocalmenteLista(pdfBytes, chamadoId);
                  },
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Compartilhar'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _compartilharPdfLista(pdfBytes, chamadoId);
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

  Future<void> _imprimirPdfLista(Uint8List pdfBytes) async {
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdfBytes);
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Erro ao preparar impressão: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _abrirPdfLocalmenteLista(Uint8List pdfBytes, String chamadoId) async {
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    BuildContext currentContextForDialog = context;

    showDialog(
      context: currentContextForDialog,
      barrierDismissible: false,
      builder: (_) => PopScope(canPop: false, child: const Center(child: CircularProgressIndicator(backgroundColor: Colors.white))),
    );

    try {
      final outputDir = await getTemporaryDirectory();
      final filename = 'chamado_${chamadoId.substring(0, min(8, chamadoId.length))}_${DateTime.now().millisecondsSinceEpoch}.pdf'; // Nome mais único
      final outputFile = File("${outputDir.path}/$filename");
      await outputFile.writeAsBytes(pdfBytes);

      if (Navigator.of(currentContextForDialog, rootNavigator: true).canPop()) {
        Navigator.of(currentContextForDialog, rootNavigator: true).pop();
      }

      final result = await OpenFilex.open(outputFile.path);

      if (result.type != ResultType.done && mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Não foi possível abrir o PDF: ${result.message}')),
        );
      }
    } catch (e) {
      if (Navigator.of(currentContextForDialog, rootNavigator: true).canPop()) {
        Navigator.of(currentContextForDialog, rootNavigator: true).pop();
      }
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Erro ao abrir PDF localmente: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _compartilharPdfLista(Uint8List pdfBytes, String chamadoId) async {
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final filename = 'chamado_${chamadoId.substring(0, min(8, chamadoId.length))}.pdf';
      await Printing.sharePdf(bytes: pdfBytes, filename: filename);
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Erro ao compartilhar PDF: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16.0))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter sheetSetState) {
            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;
            return DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.75, // Aumentar um pouco para mais espaço
                minChildSize: 0.4,
                maxChildSize: 0.9,
                builder: (_, scrollController) {
                  return SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16.0)
                        .copyWith(bottom: MediaQuery.of(context).viewInsets.bottom + 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Filtros e Ordenação', style: theme.textTheme.titleLarge),
                            TextButton(
                              onPressed: () {
                                setState(() { // Atualiza o estado principal da tela
                                  _selectedStatusFilter = null;
                                  _selectedDateFilter = null;
                                  _selectedSortOption = _sortOptions[0]; // Volta para o padrão
                                });
                                sheetSetState(() {}); // Atualiza o estado do bottom sheet
                                // Navigator.pop(context); // Fechar após limpar tudo se desejado
                              },
                              child: const Text('Limpar Tudo'),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Text('Filtrar por Status:', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 4.0,
                          children: _statusOptions
                              // .where((status) => status != kStatusFinalizado) // Remover filtro de finalizado daqui se admin puder ver
                              .map((statusValue) {
                            final bool isSelected = _selectedStatusFilter == statusValue;
                            return FilterChip(
                              label: Text(statusValue),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() { // Atualiza o estado principal da tela
                                  _selectedStatusFilter = selected ? statusValue : null;
                                });
                                sheetSetState(() {});// Atualiza o estado do bottom sheet
                              },
                              selectedColor: colorScheme.primaryContainer,
                              checkmarkColor: colorScheme.onPrimaryContainer,
                              labelStyle: TextStyle(
                                  color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                        Text('Filtrar por Data de Criação:', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.calendar_today, size: 18),
                                label: Text(
                                  _selectedDateFilter == null
                                      ? 'Selecionar Data do Chamado'
                                      : 'Data: ${DateFormat('dd/MM/yyyy').format(_selectedDateFilter!)}',
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () async {
                                  final DateTime? pickedDate = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedDateFilter ?? DateTime.now(),
                                    firstDate: DateTime(DateTime.now().year - 5),
                                    lastDate: DateTime.now().add(const Duration(days: 365)), // Permite selecionar datas futuras
                                    helpText: 'SELECIONE A DATA DO CHAMADO',
                                    cancelText: 'CANCELAR',
                                    confirmText: 'OK',
                                    locale: const Locale('pt', 'BR'),
                                  );
                                  if (pickedDate != null) {
                                    setState(() { // Atualiza o estado principal da tela
                                      _selectedDateFilter = pickedDate;
                                    });
                                    sheetSetState(() {}); // Atualiza o estado do bottom sheet
                                  }
                                },
                              ),
                            ),
                            if (_selectedDateFilter != null) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(Icons.clear, color: Colors.grey.shade600),
                                tooltip: 'Limpar Filtro de Data',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  setState(() { // Atualiza o estado principal da tela
                                    _selectedDateFilter = null;
                                  });
                                  sheetSetState(() {}); // Atualiza o estado do bottom sheet
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
                            final bool isSelected = _selectedSortOption['label'] == option['label'];
                            return ChoiceChip(
                              label: Text(option['label'] as String),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() { // Atualiza o estado principal da tela
                                    _selectedSortOption = option;
                                  });
                                  sheetSetState(() {}); // Atualiza o estado do bottom sheet
                                }
                              },
                              selectedColor: colorScheme.primaryContainer,
                              labelStyle: TextStyle(
                                  color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            child: const Text('Aplicar Filtros e Ordenação'),
                            onPressed: () {
                              Navigator.pop(context); // Fecha o BottomSheet e o StreamBuilder será reconstruído
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.kWinBackground, // Sua cor de fundo
                  Colors.white,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.7], // Ajuste conforme necessário
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        icon: Icon(
                          Icons.filter_list_alt,
                          color: _isFilterActive ? colorScheme.primary : AppTheme.kWinSecondaryText,
                          size: 20,
                        ),
                        label: Text('Filtros',
                            style: TextStyle(
                                color: _isFilterActive ? colorScheme.primary : AppTheme.kWinSecondaryText)),
                        onPressed: _showFilterBottomSheet,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                          builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                            if (snapshot.hasError) {
                              print("Erro no StreamBuilder: ${snapshot.error}"); // Log detalhado do erro
                              return Center(
                                  child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text('Ocorreu um erro ao carregar os chamados: ${snapshot.error}',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
                              ));
                            }

                            if (snapshot.connectionState == ConnectionState.waiting && _currentDocs == null) {
                              // Mostra loading apenas na primeira carga se _currentDocs for nulo
                              return const Center(child: CircularProgressIndicator());
                            }

                            // Atualiza _currentDocs apenas se houver novos dados,
                            // mantendo os dados antigos durante o carregamento de atualizações para evitar piscar.
                            if (snapshot.hasData) {
                               _currentDocs = snapshot.data?.docs;
                              // A ordenação customizada no cliente agora está em _applyCustomClientSort
                              // Se você precisar dela, chame-a aqui:
                              // if (_currentDocs != null && _currentDocs!.isNotEmpty) {
                              //   _applyCustomClientSort(_currentDocs!);
                              // }
                            }


                            if (_currentDocs == null || _currentDocs!.isEmpty) {
                              bool filtroAtivoLocal = _selectedStatusFilter != null || _selectedDateFilter != null;
                              String msg = "Nenhum chamado encontrado.";
                              IconData icone = Icons.inbox_outlined;

                              if (filtroAtivoLocal) {
                                msg = 'Nenhum chamado encontrado com os filtros aplicados.';
                                icone = Icons.filter_alt_off_outlined;
                              } else {
                                msg = _isAdmin
                                    ? 'Nenhum chamado ativo no sistema.'
                                    : 'Você não possui chamados ativos ou nenhum chamado da sua instituição está ativo.';
                                icone = _isAdmin ? Icons.inbox_outlined : Icons.assignment_late_outlined;
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
                                      if (filtroAtivoLocal) ...[
                                        const SizedBox(height: 20),
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.clear_all),
                                          label: const Text('Limpar Filtros Aplicados'),
                                          onPressed: () {
                                            setState(() {
                                              _selectedStatusFilter = null;
                                              _selectedDateFilter = null;
                                              // _selectedSortOption = _sortOptions[0]; // Se quiser resetar a ordenação também
                                            });
                                          },
                                          style: ElevatedButton.styleFrom(
                                              foregroundColor: colorScheme.onSecondaryContainer,
                                              backgroundColor: colorScheme.secondaryContainer.withOpacity(0.8)),
                                        )
                                      ]
                                    ],
                                  ),
                                ),
                              );
                            }

                            return ListView.builder(
                              padding: const EdgeInsets.only(top: 8.0, left: 8.0, right: 8.0, bottom: 72.0), // Espaço para FAB
                              itemCount: _currentDocs!.length,
                              itemBuilder: (BuildContext context, int index) {
                                final DocumentSnapshot document = _currentDocs![index];
                                final Map<String, dynamic> data =
                                    document.data() as Map<String, dynamic>? ?? {};
                                final chamadoId = document.id;

                                final bool isLoadingConfirmation =
                                    _isConfirmingAcceptance && _confirmingChamadoId == chamadoId;
                                final bool isLoadingPdfItem = _idChamadoGerandoPdf == chamadoId;
                                final bool isLoadingFinalizarItem =
                                    _isLoadingFinalizarDaLista && _idChamadoFinalizandoDaLista == chamadoId;
                                
                                // Chave única para o item da lista, importante para atualizações eficientes
                                final String? dataAtualizacaoKey = data[kFieldDataAtualizacao]?.toString() ?? data[kFieldDataCriacao]?.toString();


                                return ChamadoListItem(
                                  key: ValueKey(chamadoId + (dataAtualizacaoKey ?? DateTime.now().millisecondsSinceEpoch.toString())),
                                  chamadoId: chamadoId,
                                  chamadoData: data,
                                  currentUser: _currentUser,
                                  isAdmin: _isAdmin,
                                  onConfirmar: (id) { // Adicionado para verificar se é o criador
                                    if (data[kFieldCreatorUid] == _currentUser?.uid) {
                                      _handleRequerenteConfirmar(id);
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Apenas o solicitante original pode confirmar.'), backgroundColor: Colors.orange),
                                      );
                                    }
                                  },
                                  isLoadingConfirmation: isLoadingConfirmation,
                                  onDelete: _isAdmin ? () => _excluirChamado(context, chamadoId) : null,
                                  onNavigateToDetails: (id) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => DetalhesChamadoScreen(chamadoId: id)),
                                    ).then((value) { // O 'value' pode ser usado para passar dados de volta
                                      if (mounted) {
                                        // Força um rebuild da lista se algo puder ter mudado na tela de detalhes
                                        // que afete a lista (ex: status).
                                        // Para evitar rebuilds desnecessários, só chame setState se houver chance de mudança.
                                        // setState(() {}); // Pode ser muito agressivo.
                                        // Uma abordagem melhor seria se DetalhesChamadoScreen retornasse um bool
                                        // indicando se houve alteração, e aí chamar setState.
                                      }
                                    });
                                  },
                                  isLoadingPdfDownload: isLoadingPdfItem,
                                  onGerarPdfOpcoes: _handleGerarPdfOpcoes,
                                  onFinalizarArquivar: _handleFinalizarArquivarChamado,
                                  isLoadingFinalizarArquivar: isLoadingFinalizarItem,
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
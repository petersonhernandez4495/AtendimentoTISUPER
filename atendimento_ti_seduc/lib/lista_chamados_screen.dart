// lib/lista_chamados_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// Seus imports de projeto
import '../models/chamado_model.dart';
import '../services/chamado_search_logic.dart';
import '../widgets/chamado_list_item.dart';
import '../detalhes_chamado_screen.dart';
import '../config/theme/app_theme.dart'; // Verifique se este arquivo existe e está correto
// Importa o serviço que agora (ou já) contém as constantes
import '../services/chamado_service.dart';

class ListaChamadosScreen extends StatefulWidget {
  final String searchQuery;

  const ListaChamadosScreen({
    super.key,
    this.searchQuery = "",
  });

  @override
  State<ListaChamadosScreen> createState() => _ListaChamadosScreenState();
}

// --- INÍCIO DA CLASSE _ListaChamadosScreenState ---
class _ListaChamadosScreenState extends State<ListaChamadosScreen> {
  // --- Variáveis de Estado e Serviços ---
  final ChamadoService _chamadoService = ChamadoService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late ChamadoSearchLogic _searchLogic;

  String? _selectedStatusFilter;
  late Map<String, dynamic> _selectedSortOption;
  DateTime? _selectedDateFilter;
  bool _isAdmin = false;
  bool _isLoadingRole = true;
  User? _currentUser;
  // String? _currentUserInstitution; // Removido pois a lógica de instituição foi alterada

  List<Chamado> _ultimosChamadosFiltradosParaExibicao = [];

  // Constantes de status e ordenação
  // Usa as constantes definidas em chamado_service.dart
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
  final List<String> _statusAtivosRequisitante = [
    kStatusAberto,
    kStatusEmAndamento,
    kStatusPendente,
    kStatusAguardandoAprovacao,
    kStatusAguardandoPeca,
    kStatusChamadoDuplicado,
    kStatusAguardandoEquipamento,
    kStatusAtribuidoGSIOR,
    kStatusGarantiaFabricante,
  ];

  String? _confirmingChamadoId;
  bool _isConfirmingAcceptance = false;
  String? _idChamadoGerandoPdf; // Usado para controlar o loading do PDF no item
  String? _idChamadoFinalizandoDaLista;
  bool _isLoadingFinalizarDaLista = false;

  // --- Métodos do Ciclo de Vida ---
  @override
  void initState() {
    super.initState();
    _searchLogic = ChamadoSearchLogic();
    _selectedSortOption = _sortOptions[0]; // Padrão: Mais recentes
    _checkUserRole();
  }

  // --- Métodos de Lógica ---
  Future<void> _checkUserRole() async {
    if (!mounted) return;
    setState(() => _isLoadingRole = true);
    User? user = _auth.currentUser;
    bool isAdminResult = false;
    // String? userInstitutionResult; // Removido

    if (user != null) {
      _currentUser = user;
      try {
        final DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection(kCollectionUsers) // Constante importada
            .doc(user.uid)
            .get();
        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data() as Map<String, dynamic>;
          isAdminResult =
              (userData[kFieldUserRole] == 'admin'); // Constante importada
          // A lógica para buscar a instituição do usuário foi removida daqui
          // pois não será mais usada na query principal de chamados para não-admins.
          // Se _currentUserInstitution fosse usada em outro lugar, a remoção completa
          // precisaria de mais análise.
        } else {
          // Usuário não encontrado no Firestore ou sem dados
          isAdminResult = false;
        }
      } catch (e) {
        // Erro ao buscar dados do usuário
        isAdminResult = false;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Erro ao verificar permissões do usuário: $e')),
          );
        }
      }
    } else {
      // Usuário não logado
      _currentUser = null;
      isAdminResult = false;
    }

    if (mounted) {
      setState(() {
        _isAdmin = isAdminResult;
        // _currentUserInstitution = userInstitutionResult; // Removido
        _isLoadingRole = false;
      });
    }
  }

  bool get _isFilterActive {
    return _selectedStatusFilter != null ||
        _selectedDateFilter != null ||
        (_selectedSortOption['field'] != kFieldDataCriacao ||
            _selectedSortOption['descending'] !=
                true) || // Verifica se não é o sort padrão
        widget.searchQuery.isNotEmpty;
  }

  Query _buildFirestoreQuery() {
    Query query = FirebaseFirestore.instance.collection(kCollectionChamados);

    if (_isLoadingRole) {
      // Retorna uma query que não trará resultados enquanto o papel do usuário está sendo carregado
      return query.where('__inexistente__', isEqualTo: '__aguardando_role__');
    }
    if (_currentUser == null && !_isAdmin) {
      // Retorna uma query que não trará resultados se não houver usuário logado e não for admin
      return query.where('__inexistente__',
          isEqualTo: '__sem_resultados_user_null__');
    }

    // Lógica para usuários NÃO administradores
    if (!_isAdmin && _currentUser != null) {
      // Usuário não admin vê apenas os seus próprios chamados.
      query = query.where(kFieldCreatorUid, isEqualTo: _currentUser!.uid);

      // Aplica filtro de status padrão para requisitante (não vê finalizados/solucionados por padrão)
      // ou o filtro de status selecionado pelo usuário.
      if (_selectedStatusFilter == null) {
        query = query.where(kFieldStatus, whereIn: _statusAtivosRequisitante);
      } else {
        query = query.where(kFieldStatus, isEqualTo: _selectedStatusFilter);
      }
      // Todos os não-admins não veem chamados inativos administrativamente
      query = query.where(kFieldAdminInativo, isEqualTo: false);

      // Lógica para administradores
    } else if (_isAdmin) {
      // Admin vê todos os chamados (respeitando filtros de status e data)
      // Por padrão, admin não vê 'Finalizado', a menos que filtre especificamente por esse status
      if (_selectedStatusFilter != null) {
        query = query.where(kFieldStatus, isEqualTo: _selectedStatusFilter);
      } else {
        // Se nenhum filtro de status específico for aplicado pelo admin,
        // ele não verá os chamados com status 'Finalizado'.
        // Para ver os finalizados, o admin deve explicitamente filtrar por 'Finalizado'.
        query = query.where(kFieldStatus, whereNotIn: [kStatusFinalizado]);
      }
    }

    // Aplica filtro de data de criação, se selecionado
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

    // Aplica ordenação
    final String sortField = _selectedSortOption['field'] as String;
    final bool sortDescending = _selectedSortOption['descending'] as bool;
    query = query.orderBy(sortField, descending: sortDescending);

    // Adiciona ordenação secundária por data para consistência se a primária não for data
    // Isso ajuda a evitar problemas com cursores do Firestore se múltiplos documentos tiverem o mesmo valor no campo de ordenação primário.
    if (sortField != kFieldDataCriacao) {
      query = query.orderBy(kFieldDataCriacao,
          descending: true); // Ou false, dependendo da consistência desejada
    }
    return query;
  }

  // --- Métodos de Ação e UI ---

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
                initialChildSize: 0.75, // Ajuste conforme necessário
                minChildSize: 0.4,
                maxChildSize: 0.9,
                builder: (_, scrollController) {
                  return SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16.0).copyWith(
                        bottom:
                            MediaQuery.of(context).viewInsets.bottom + 16.0),
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
                                // Limpa no setState principal da tela, não só do sheet
                                setState(() {
                                  _selectedStatusFilter = null;
                                  _selectedDateFilter = null;
                                  _selectedSortOption =
                                      _sortOptions[0]; // Reset para o padrão
                                });
                                // sheetSetState(() {}); // Não é mais necessário se o setState principal é chamado
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
                                // Atualiza o estado principal da tela
                                setState(() {
                                  _selectedStatusFilter =
                                      selected ? statusValue : null;
                                });
                                // Atualiza o estado do BottomSheet
                                sheetSetState(() {
                                  // _selectedStatusFilter já foi atualizado pelo setState principal
                                });
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
                                icon:
                                    const Icon(Icons.calendar_today, size: 18),
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
                                    context:
                                        context, // Usar o context principal
                                    initialDate:
                                        _selectedDateFilter ?? DateTime.now(),
                                    firstDate:
                                        DateTime(DateTime.now().year - 5),
                                    lastDate: DateTime.now()
                                        .add(const Duration(days: 365)),
                                    locale: const Locale('pt', 'BR'),
                                  );
                                  if (pickedDate != null) {
                                    setState(() {
                                      // Atualiza o estado principal
                                      _selectedDateFilter = pickedDate;
                                    });
                                    sheetSetState(
                                        () {}); // Atualiza o estado do sheet
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
                                    // Atualiza o estado principal
                                    _selectedDateFilter = null;
                                  });
                                  sheetSetState(
                                      () {}); // Atualiza o estado do sheet
                                },
                              )
                            ]
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text('Ordenar por:',
                            style: theme.textTheme.titleMedium),
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
                                    // Atualiza o estado principal
                                    _selectedSortOption = option;
                                  });
                                  sheetSetState(
                                      () {}); // Atualiza o estado do sheet
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
          },
        );
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
        false; // Garante que não seja nulo

    if (!confirmar || !mounted) return;
    final scaffoldMessenger =
        ScaffoldMessenger.of(context); // Captura antes do async
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
  // Adicione os outros handlers (_handleGerarPdfOpcoes, etc.) aqui se necessário

  // --- MÉTODO build() ---
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
                      : AppTheme
                          .kWinSecondaryText, // Verifique AppTheme.kWinSecondaryText
                  size: 20,
                ),
                label: Text('Filtros',
                    style: TextStyle(
                        color: _isFilterActive
                            ? colorScheme.primary
                            : AppTheme
                                .kWinSecondaryText)), // Verifique AppTheme.kWinSecondaryText
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
                      return Center(
                          child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text('Ocorreu um erro: ${snapshot.error}',
                                  textAlign: TextAlign.center)));
                    }

                    // Mostra loading apenas na carga inicial e se não houver dados em cache ou filtros ativos
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        _ultimosChamadosFiltradosParaExibicao.isEmpty &&
                        widget.searchQuery.isEmpty &&
                        _selectedStatusFilter == null &&
                        _selectedDateFilter == null) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    List<Chamado> chamadosDoFirestore = [];
                    if (snapshot.hasData) {
                      chamadosDoFirestore = snapshot.data!.docs
                          .map((doc) {
                            try {
                              // Assegura que o doc é do tipo correto para fromFirestore
                              return Chamado.fromFirestore(doc
                                  as DocumentSnapshot<Map<String, dynamic>>);
                            } catch (e) {
                              // Logar erro se necessário, e.g., print('Erro ao converter chamado: $e, Doc ID: ${doc.id}');
                              return null;
                            }
                          })
                          .where((chamado) => chamado != null)
                          .cast<Chamado>()
                          .toList();
                      _searchLogic.setChamadosSource(chamadosDoFirestore);
                    } else if (snapshot.connectionState !=
                        ConnectionState.waiting) {
                      // Se não tem dados e não está esperando, usa la lista cacheada (pode estar vazia)
                      _searchLogic.setChamadosSource(
                          _ultimosChamadosFiltradosParaExibicao);
                    }

                    _searchLogic.filterChamadosComQuery(widget.searchQuery);
                    _ultimosChamadosFiltradosParaExibicao =
                        _searchLogic.resultadosFiltrados;

                    if (_ultimosChamadosFiltradosParaExibicao.isEmpty) {
                      String msg = "Nenhum chamado encontrado.";
                      IconData icone = Icons.inbox_outlined;
                      if (_isFilterActive) {
                        msg =
                            'Nenhum chamado encontrado com os critérios aplicados.';
                        if (widget.searchQuery.isNotEmpty) {
                          msg += '\nPesquisa: "${widget.searchQuery}"';
                        }
                        icone = Icons.filter_alt_off_outlined;
                      } else if (!_isLoadingRole) {
                        // Só define msg padrão se não estiver carregando role
                        msg = _isAdmin
                            ? 'Nenhum chamado ativo no sistema.'
                            // Mensagem ajustada para refletir a nova lógica de visualização
                            : 'Você não possui chamados ativos.';
                        icone = _isAdmin
                            ? Icons.inbox_outlined
                            : Icons.assignment_late_outlined;
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
                              if (_isFilterActive) ...[
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
                                      // A limpeza da searchQuery deve ser feita no widget pai que a controla (ex: MainNavigationScreen ou SideMenu)
                                      // Se este widget pudesse limpar, seria: widget.searchQuery = ""; (mas props são finais)
                                      // Ou chame um callback para o pai: widget.onClearSearch?.call();
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
                          top: 8.0,
                          left: 8.0,
                          right: 8.0,
                          bottom: 72.0), // Espaço para FAB
                      itemCount: _ultimosChamadosFiltradosParaExibicao.length,
                      itemBuilder: (BuildContext context, int index) {
                        final Chamado chamado =
                            _ultimosChamadosFiltradosParaExibicao[index];
                        final String chamadoId = chamado.id;

                        // Tenta obter o DocumentSnapshot original para passar ao ChamadoListItem se possível
                        // Isso é útil se ChamadoListItem espera um Map<String, dynamic> ou DocumentSnapshot
                        Map<String, dynamic> chamadoDataMap = {};
                        if (snapshot.hasData) {
                          DocumentSnapshot? originalDoc;
                          try {
                            originalDoc = snapshot.data!.docs.firstWhere(
                              (doc) => doc.id == chamado.id,
                            );
                          } catch (e) {
                            // firstWhere lança StateError se não encontrar
                            originalDoc = null;
                          }

                          if (originalDoc != null &&
                              originalDoc.exists &&
                              originalDoc.data() != null) {
                            chamadoDataMap =
                                originalDoc.data() as Map<String, dynamic>;
                          }
                        }
                        // Fallback se não encontrar o doc original ou se precisar de campos do objeto Chamado
                        if (chamadoDataMap.isEmpty) {
                          // Use o método toMap() do seu modelo Chamado se ele existir e for adequado
                          // Exemplo: chamadoDataMap = chamado.toMap();
                          // Ou preencha manualmente como antes, garantindo todos os campos necessários:
                          chamadoDataMap = {
                            'id': chamado
                                .id, // Adicione o ID se ChamadoListItem precisar
                            'status': chamado.status,
                            'prioridade': chamado.prioridade,
                            'data_criacao': chamado
                                .dataAbertura, // ou dataCriacao se for o nome no modelo
                            'nome_solicitante': chamado.nomeSolicitante,
                            'patrimonio': chamado.patrimonio,
                            'problema_selecionado': chamado.problemaSelecionado,
                            'equipamento_selecionado':
                                chamado.equipamentoSelecionado,
                            'creatorUid':
                                chamado.solicitanteUid, // ou creatorUid
                            // Adicione outros campos que ChamadoListItem espera
                            // Ex: 'unidadeOrganizacionalChamado': chamado.unidadeOrganizacional,
                            // 'tecnico_responsavel': chamado.tecnicoResponsavel,
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
                              (chamado.dataAtualizacao?.millisecondsSinceEpoch
                                      .toString() ??
                                  chamado.dataAbertura.millisecondsSinceEpoch
                                      .toString())),
                          chamadoId: chamadoId,
                          chamadoData: chamadoDataMap, // Passa o Map construído
                          currentUser: _currentUser,
                          isAdmin: _isAdmin,
                          onConfirmar: (id) {
                            if (chamado.solicitanteUid == _currentUser?.uid) {
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
                              if (mounted) setState(() {});
                            }); // Atualiza a lista ao voltar
                          },
                          isLoadingPdfDownload:
                              isLoadingPdfItem, // Necessita da variável de estado _idChamadoGerandoPdf
                          onGerarPdfOpcoes: (id, data) {
                            // Implementar lógica de _handleGerarPdfOpcoes ou similar
                            // Exemplo: _handleGerarPdfOpcoes(id, data);
                            // setState(() => _idChamadoGerandoPdf = id); // Para mostrar loading
                            // Lembre-se de resetar _idChamadoGerandoPdf = null; no finally
                            print(
                                'Gerar PDF para $id não implementado neste exemplo.');
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
// --- FIM DA CLASSE _ListaChamadosScreenState ---
} // <--- CHAVE FINAL DA CLASSE

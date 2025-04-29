// lib/lista_chamados_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'pdf_generator.dart';
import 'detalhes_chamado_screen.dart';
import 'config/theme/app_theme.dart';
import 'widgets/ticket_card.dart';
import 'widgets/horizontal_date_selector.dart';

class ListaChamadosScreen extends StatefulWidget {
  const ListaChamadosScreen({super.key});

  @override
  State<ListaChamadosScreen> createState() => _ListaChamadosScreenState();
}

class _ListaChamadosScreenState extends State<ListaChamadosScreen> {
  List<QueryDocumentSnapshot>? _currentDocs;
  String? _selectedStatusFilter;
  String _sortField = 'data_criacao';
  bool _sortDescending = true;
  final List<String> _statusOptions = ['Todos', 'aberto', 'em andamento', 'pendente', 'resolvido', 'fechado'];
  final List<Map<String, dynamic>> _sortOptions = [
    {'label': 'Mais Recentes', 'field': 'data_criacao', 'descending': true},
    {'label': 'Mais Antigos', 'field': 'data_criacao', 'descending': false},
    // Adicione outras opções de ordenação se necessário (ex: por prioridade)
    // {'label': 'Prioridade (Alta > Baixa)', 'field': 'prioridade', 'descending': true}, // Exemplo
  ];
  late Map<String, dynamic> _selectedSortOption;
  DateTime? _selectedDateFilter;

  @override
  void initState() {
    super.initState();
    _selectedSortOption = _sortOptions[0]; // Define a opção inicial
    // Configura o locale padrão para pt_BR para formatação de data
    // Se ainda não estiver configurado globalmente, pode ser feito aqui ou no main.dart
    // initializeDateFormatting('pt_BR', null); // Descomente se necessário
  }

  // Constrói a query do Firestore com base nos filtros e ordenação selecionados
  Query _buildFirestoreQuery() {
    Query query = FirebaseFirestore.instance.collection('chamados');

    // Aplica filtro de status
    if (_selectedStatusFilter != null && _selectedStatusFilter != 'Todos') {
      query = query.where('status', isEqualTo: _selectedStatusFilter);
    }

    // Aplica filtro de data
    if (_selectedDateFilter != null) {
      final DateTime startOfDay = DateTime(_selectedDateFilter!.year, _selectedDateFilter!.month, _selectedDateFilter!.day, 0, 0, 0);
      final DateTime endOfDay = DateTime(_selectedDateFilter!.year, _selectedDateFilter!.month, _selectedDateFilter!.day, 23, 59, 59);
      // Converte para Timestamps do Firestore
      final Timestamp startTimestamp = Timestamp.fromDate(startOfDay);
      final Timestamp endTimestamp = Timestamp.fromDate(endOfDay);
      // Aplica filtros de data_criacao
      query = query.where('data_criacao', isGreaterThanOrEqualTo: startTimestamp);
      query = query.where('data_criacao', isLessThanOrEqualTo: endTimestamp);
    }

    // Aplica ordenação principal
    query = query.orderBy(_sortField, descending: _sortDescending);

    // Aplica ordenação secundária por data_criacao para garantir consistência
    // se a ordenação principal não for por data_criacao e não houver filtro de data
    // (Evita problemas de paginação/ordenação inconsistente no Firestore)
    if (_sortField != 'data_criacao') {
       // Ordena secundariamente pela data para garantir ordem estável
       // A direção aqui pode ser a mesma da principal ou oposta, dependendo do desejado.
       // Usar a mesma direção da data_criacao original (descendente) é comum.
       query = query.orderBy('data_criacao', descending: true);
    }


    return query;
  }

  // Função para mostrar diálogo de confirmação e excluir chamado
  Future<void> _excluirChamado(BuildContext context, String chamadoId) async {
    bool confirmarExclusao = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Exclusão'),
          content: const Text(
            'Tem certeza que deseja excluir este chamado?\nEsta ação não pode ser desfeita.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop(false); // Retorna false
              },
            ),
            TextButton(
              child: Text('Excluir', style: TextStyle(color: AppTheme.kErrorColor)),
              onPressed: () {
                Navigator.of(context).pop(true); // Retorna true
              },
            ),
          ],
        );
      },
    ) ?? false; // Retorna false se o diálogo for dispensado

    // Só prossegue se a exclusão foi confirmada e o widget ainda está montado
    if (!confirmarExclusao || !mounted) return;

    try {
      await FirebaseFirestore.instance.collection('chamados').doc(chamadoId).delete();
      // Mostra feedback de sucesso se ainda estiver montado
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chamado excluído com sucesso!')),
        );
      }
    } catch (error) {
      print('Erro ao excluir chamado: $error');
      // Mostra feedback de erro se ainda estiver montado
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir chamado: ${error.toString()}')),
        );
      }
    }
  }

  // Função para gerar e compartilhar PDF da lista filtrada
  Future<void> _gerarECompartilharPdfLista() async {
    if (_currentDocs == null || _currentDocs!.isEmpty) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum chamado na lista atual para gerar PDF.'))
      );
      return;
    }
    // Mostra indicador de progresso
     if(mounted) {
        showDialog(
           context: context,
           barrierDismissible: false,
           builder: (_) => const Center(child: CircularProgressIndicator())
        );
     }

    try {
      // Gera o PDF com os documentos atualmente exibidos
      final Uint8List pdfBytes = await generateTicketListPdf(_currentDocs!);

      // Salva o PDF em um arquivo temporário
      final Directory tempDir = await getTemporaryDirectory();
      final String filePath = '${tempDir.path}/lista_chamados_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
      final File file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      // Fecha o diálogo de progresso se ainda estiver montado
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      // Compartilha o arquivo PDF usando share_plus
      final result = await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Lista de Chamados - ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'
      );

      // Verifica o resultado do compartilhamento (opcional)
      if (result.status == ShareResultStatus.success && mounted) {
        print("Compartilhamento da lista de chamados iniciado com sucesso.");
        // Pode mostrar uma mensagem de sucesso se desejar
        // ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compartilhamento iniciado.')));
      } else if (mounted) {
        print("Compartilhamento cancelado ou falhou: ${result.status}");
         // Pode mostrar uma mensagem de aviso/erro se desejar
         // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Compartilhamento: ${result.status}')));
      }

    } catch (e) {
      // Fecha o diálogo de progresso em caso de erro, se ainda estiver montado
      if(mounted) Navigator.of(context, rootNavigator: true).pop();
      print("Erro ao gerar/compartilhar PDF da lista: $e");
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao gerar PDF da lista: ${e.toString()}'))
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- Barra de Filtros ---
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.kBackgroundGradientStart,
                AppTheme.kBackgroundGradientEnd,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            // Opcional: Adicionar sombra sutil
            // boxShadow: [
            //   BoxShadow(
            //     color: Colors.black.withOpacity(0.1),
            //     blurRadius: 4,
            //     offset: Offset(0, 2),
            //   ),
            // ],
          ),
          child: Row(
            children: [
              // Dropdown de Status
              Expanded(
                flex: 3, // Ajuste a proporção conforme necessário
                child: DropdownButtonFormField<String>(
                  value: _selectedStatusFilter ?? 'Todos', // Garante um valor selecionado
                  items: _statusOptions.map((String status) => DropdownMenuItem<String>(
                    value: status,
                    child: Text(status, style: const TextStyle(fontSize: 12)),
                  )).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedStatusFilter = (newValue == 'Todos') ? null : newValue;
                    });
                  },
                  style: textTheme.bodySmall,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: colorScheme.surface.withOpacity(0.8),
                    prefixIcon: const Icon(Icons.filter_list, size: 16),
                    contentPadding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Dropdown de Ordenação
              Expanded(
                flex: 4, // Ajuste a proporção conforme necessário
                child: DropdownButtonFormField<Map<String, dynamic>>(
                  value: _selectedSortOption,
                  items: _sortOptions.map((Map<String, dynamic> option) => DropdownMenuItem<Map<String, dynamic>>(
                    value: option,
                    // Usar FittedBox para ajustar texto se for muito longo
                    child: FittedBox(
                       fit: BoxFit.scaleDown,
                       child: Text(option['label'] as String, overflow: TextOverflow.ellipsis)
                    ),
                  )).toList(),
                  onChanged: (Map<String, dynamic>? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedSortOption = newValue;
                        _sortField = newValue['field'] as String;
                        _sortDescending = newValue['descending'] as bool;
                      });
                    }
                  },
                  style: textTheme.bodySmall,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: colorScheme.surface.withOpacity(0.8),
                    prefixIcon: const Icon(Icons.sort, size: 16),
                    contentPadding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    isDense: true,
                  ),
                  isExpanded: true, // Garante que o dropdown ocupe o espaço do Expanded
                ),
              ),
              // Botão PDF
              IconButton(
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  onPressed: _gerarECompartilharPdfLista,
                  tooltip: 'Gerar PDF da Lista',
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                  color: theme.iconTheme.color // Usa cor padrão do tema para ícones
               ),
            ],
          ),
        ),
        // --- Carrossel de Datas ---
        HorizontalDateSelector(
          initialSelectedDate: _selectedDateFilter,
          onDateSelected: (date) {
            setState(() {
              _selectedDateFilter = date;
            });
          },
        ),

        // --- Lista/Grade de Chamados ---
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _buildFirestoreQuery().snapshots(), // Usa a query construída
            builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
              // Tratamento de Erro
              if (snapshot.hasError) {
                return Center(child: Text('Erro ao carregar chamados: ${snapshot.error}'));
              }
              // Estado de Carregamento
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              // Atualiza a lista de documentos atual (para PDF)
              _currentDocs = snapshot.data?.docs;

              // Nenhum Documento Encontrado
              if (_currentDocs == null || _currentDocs!.isEmpty) {
                 bool filtroAtivo = (_selectedStatusFilter != null && _selectedStatusFilter != 'Todos') || _selectedDateFilter != null;
                 String mensagem = filtroAtivo
                   ? 'Nenhum chamado encontrado com os filtros atuais.'
                   : 'Nenhum chamado registrado no momento.';
                 IconData icone = filtroAtivo ? Icons.filter_alt_off_outlined : Icons.inbox_outlined;

                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                         Icon(icone, size: 50, color: Colors.grey[500]),
                         const SizedBox(height: 16),
                         Text(
                           mensagem,
                           textAlign: TextAlign.center,
                           style: textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
                         ),
                      ]
                    ),
                  ),
                );
              }

              // Exibe a Grade de Chamados
              return GridView.builder(
                  padding: const EdgeInsets.only(left: 8.0, right: 8.0, top: 16.0, bottom: 16.0), // Ajuste o padding se necessário
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 300.0, // Largura máxima de cada item na grade (ajuste conforme necessário)
                      mainAxisSpacing: 0, // Espaçamento vertical (ajustado pela margem do card)
                      crossAxisSpacing: 0, // Espaçamento horizontal (ajustado pela margem do card)
                      childAspectRatio: (300 / 300), // Proporção Largura/Altura (ajuste fino aqui) -> Aumentei a altura relativa
                    ),
                  itemCount: _currentDocs!.length,
                  itemBuilder: (BuildContext context, int index) {
                    final DocumentSnapshot document = _currentDocs![index];
                    // Usa um Map seguro, tratando caso data() seja null
                    final Map<String, dynamic> data = document.data() as Map<String, dynamic>? ?? {};

                    // === Extração de dados com tratamento para campos ausentes ===

                    // *** MODIFICAÇÃO AQUI ***
                    // Pega o 'problema_ocorre' para usar como título.
                    // Se 'problema_ocorre' não existir, tenta pegar 'titulo', senão usa um fallback.
                    final String titulo = data['problema_ocorre'] as String? ?? data['titulo'] as String? ?? 'Problema não descrito';

                    final String prioridade = data['prioridade'] as String? ?? 'Normal';
                    final String status = data['status'] as String? ?? 'aberto';
                    // Tenta pegar 'creatorName', se não existir, tenta 'nome_solicitante', senão 'Anônimo'
                    final String creatorName = data['creatorName'] as String? ?? data['nome_solicitante'] as String? ?? 'Anônimo';
                    // Pega telefone: tenta 'celular_contato', depois 'creatorPhone'
                    final String? creatorPhone = data['celular_contato'] as String? ?? data['creatorPhone'] as String?;
                    final String? tecnicoResponsavel = data['tecnico_responsavel'] as String?;

                    // Formata a data de criação
                    final Timestamp? dataCriacaoTimestamp = data['data_criacao'] as Timestamp?;
                    final String dataFormatada = dataCriacaoTimestamp != null
                        ? DateFormat('dd/MM/yy', 'pt_BR').format(dataCriacaoTimestamp.toDate())
                        : '--'; // Fallback para data

                    // Instancia o TicketCard passando os dados extraídos
                    return TicketCard(
                      key: ValueKey(document.id), // Chave para melhor performance do Flutter
                      chamadoId: document.id,
                      titulo: titulo, // <<< Passa o problema (ou fallback) como título
                      prioridade: prioridade,
                      status: status,
                      creatorName: creatorName,
                      dataFormatada: dataFormatada,
                      creatorPhone: creatorPhone,
                      tecnicoResponsavel: tecnicoResponsavel,
                      onTap: () {
                        // Navega para a tela de detalhes ao tocar no card
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DetalhesChamadoScreen(chamadoId: document.id),
                          ),
                        );
                      },
                      onDelete: () {
                        // Chama a função para excluir o chamado ao tocar no ícone
                        _excluirChamado(context, document.id);
                      },
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
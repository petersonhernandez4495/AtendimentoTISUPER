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

// --- Alterado para StatefulWidget ---
class ListaChamadosScreen extends StatefulWidget {
  // Removido const por ser StatefulWidget agora
  // Se não precisar de parâmetros, pode manter const se preferir, mas o State não será const.
  const ListaChamadosScreen({super.key});

  @override
  State<ListaChamadosScreen> createState() => _ListaChamadosScreen();
}

class _ListaChamadosScreen extends State<ListaChamadosScreen> {
  // Guarda a lista atual de documentos para a função de PDF da lista
  List<QueryDocumentSnapshot>? _currentDocs;

  // --- Variáveis de Estado para Filtro e Ordenação ---
  String? _selectedStatusFilter; // null significa 'Todos'
  String _sortField = 'data_criacao'; // Campo padrão para ordenar
  bool _sortDescending = true;       // Direção padrão (true = mais recente primeiro)

  // --- Opções para os Dropdowns ---
  final List<String> _statusOptions = ['Todos', 'aberto', 'em andamento', 'pendente', 'resolvido', 'fechado'];
  final List<Map<String, dynamic>> _sortOptions = [
    {'label': 'Mais Recentes', 'field': 'data_criacao', 'descending': true},
    {'label': 'Mais Antigos', 'field': 'data_criacao', 'descending': false},
  ];
  late Map<String, dynamic> _selectedSortOption; // Guarda a opção de sort selecionada

  @override
  void initState() {
    super.initState();
    _selectedSortOption = _sortOptions[0]; // Define sort inicial
  }

  // --- Funções Helper de Cor e Exclusão ---
  Color? _getCorPrioridade(String prioridade) {
     switch (prioridade.toLowerCase()) {
      case 'urgente': case 'crítica': return Colors.red[100];
      case 'alta': return Colors.orange[100];
      case 'média': case 'media': return Colors.yellow[100];
      case 'baixa': return Colors.blue[50];
      default: return null;
    }
  }
  Color? _getCorStatus(String status) {
     switch (status.toLowerCase()) {
      case 'aberto': return Colors.blue[700];
      case 'em andamento': return Colors.orange[700];
      case 'pendente': return Colors.deepPurple[500];
      case 'resolvido': return Colors.green[700];
      case 'fechado': return Colors.grey[800];
      default: return Colors.grey[500];
    }
  }
  Future<void> _excluirChamado(BuildContext context, String chamadoId) async {
     bool confirmarExclusao = await showDialog( context: context, builder: (BuildContext context) { return AlertDialog( title: const Text('Confirmar Exclusão'), content: const Text( 'Tem certeza?'), actions: <Widget>[ TextButton( child: const Text('Cancelar'), onPressed: () { Navigator.of(context).pop(false); }, ), TextButton( child: const Text('Excluir', style: TextStyle(color: Colors.red)), onPressed: () { Navigator.of(context).pop(true); }, ), ], ); } ) ?? false;
     if (!confirmarExclusao || !mounted) return; // Adicionado !mounted check
     try {
       await FirebaseFirestore.instance.collection('chamados').doc(chamadoId).delete();
        if (mounted) { ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Chamado excluído!')), ); }
     } catch (error) {
       print('Erro ao excluir: $error');
        if (mounted) { ScaffoldMessenger.of(context).showSnackBar( const SnackBar( content: Text('Erro ao excluir.')), ); }
     }
  }
  // --- Função para Gerar/Compartilhar PDF da Lista ---
  Future<void> _gerarECompartilharPdfLista() async {
    if (_currentDocs == null || _currentDocs!.isEmpty) {
       if(mounted) ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Nenhum chamado para gerar PDF.')));
      return;
    }
    // Mostra loading
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
       final Uint8List pdfBytes = await generateTicketListPdf(_currentDocs!); 
       final tempDir = await getTemporaryDirectory();
       final filePath = '${tempDir.path}/lista_chamados_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
       final file = File(filePath); await file.writeAsBytes(pdfBytes);
       if (!mounted) return; Navigator.of(context, rootNavigator: true).pop(); // Fecha loading
       final result = await Share.shareXFiles( [XFile(filePath)], text: 'Lista de Chamados ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}' );
       if (result.status == ShareResultStatus.success && mounted) { /* ... */ }
    } catch (e) {
       if(mounted) Navigator.of(context, rootNavigator: true).pop(); print("Erro PDF Lista: $e");
       if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao gerar PDF: $e')));
    }
  }
  // -------------------------------------------------------

  // --- Função para construir a Query Dinâmica ---
  Query _buildFirestoreQuery() {
    Query query = FirebaseFirestore.instance.collection('chamados');
    // Aplica Filtro de Status
    if (_selectedStatusFilter != null && _selectedStatusFilter != 'Todos') {
      query = query.where('status', isEqualTo: _selectedStatusFilter);
    }
    // Aplica Ordenação
    query = query.orderBy(_sortField, descending: _sortDescending);
    // Adicionar ordenação secundária se necessário (e criar índice no Firestore)
    if (_sortField != 'data_criacao') {
       query = query.orderBy('data_criacao', descending: true);
    }
    return query;
  }
  // -----------------------------------------

  @override
  Widget build(BuildContext context) {
    // --- Retorna DIRETAMENTE o CONTEÚDO (Column com Filtros + Lista) ---
    // --- SEM Scaffold ou AppBar AQUI ---
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- Barra de Filtros e Ordenação ---
        Container(
           padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
           color: Theme.of(context).colorScheme.surfaceContainerLowest,
           child: Row(
            children: [
              // Dropdown Filtro Status
              Expanded( flex: 3, child: DropdownButtonFormField<String>( /* ... Configuração Dropdown Status ... */ value: _selectedStatusFilter ?? 'Todos', items: _statusOptions.map((String status) { return DropdownMenuItem<String>( value: status, child: Text(status, style: const TextStyle(fontSize: 13)), ); }).toList(), onChanged: (String? newValue) { setState(() { _selectedStatusFilter = (newValue == 'Todos') ? null : newValue; }); }, style: Theme.of(context).textTheme.bodySmall, decoration: InputDecoration( filled: true, fillColor: Theme.of(context).colorScheme.surface, prefixIcon: const Icon(Icons.filter_list, size: 16), contentPadding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), isDense: true, ), ), ),
              const SizedBox(width: 10),
              // Dropdown Ordenação
              Expanded( flex: 4, child: DropdownButtonFormField<Map<String, dynamic>>( /* ... Configuração Dropdown Sort ... */ value: _selectedSortOption, items: _sortOptions.map((Map<String, dynamic> option) { return DropdownMenuItem<Map<String, dynamic>>( value: option, child: Text(option['label'] as String, overflow: TextOverflow.ellipsis), ); }).toList(), onChanged: (Map<String, dynamic>? newValue) { if (newValue != null) { setState(() { _selectedSortOption = newValue; _sortField = newValue['field'] as String; _sortDescending = newValue['descending'] as bool; }); } }, style: Theme.of(context).textTheme.bodySmall, decoration: InputDecoration( filled: true, fillColor: Theme.of(context).colorScheme.surface, prefixIcon: const Icon(Icons.sort, size: 16), contentPadding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), isDense: true, ), isExpanded: true, ), ),
              // Botão PDF Lista
               IconButton( icon: const Icon(Icons.picture_as_pdf_outlined), onPressed: _gerarECompartilharPdfLista, tooltip: 'Gerar PDF da Lista', iconSize: 20, visualDensity: VisualDensity.compact, ),
            ],
          ),
        ),
        // const Divider(height: 1, thickness: 1), // Divisor opcional

        // --- Lista/Grade de Chamados ---
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _buildFirestoreQuery().snapshots(), // Usa query dinâmica
            builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
              // Tratamento de erro/loading
              if (snapshot.hasError) { return Center(child: Text('Erro ao carregar chamados: ${snapshot.error}'));}
              if (snapshot.connectionState == ConnectionState.waiting) { return const Center(child: CircularProgressIndicator());}

              // Atualiza a lista de documentos para o botão PDF usar
              _currentDocs = snapshot.data?.docs;

              // Tratamento de lista vazia
              if (_currentDocs == null || _currentDocs!.isEmpty) { /* ... Mensagem lista vazia ... */ }

              // GridView
              return GridView.builder(
                 padding: const EdgeInsets.all(12.0),
                 gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 190.0, mainAxisSpacing: 12.0,
                      crossAxisSpacing: 12.0, childAspectRatio: (1 / 1.8), // Ajuste
                    ),
                 itemCount: _currentDocs!.length,
                 itemBuilder: (BuildContext context, int index) {
                    final DocumentSnapshot document = _currentDocs![index];
                    final Map<String, dynamic> data = document.data()! as Map<String, dynamic>;
                    // ... (extração de dados, cores) ...
                    final String titulo = data['titulo'] ?? 'S/ Título';
                    final String prioridade = data['prioridade'] ?? 'S/P';
                    final String status = data['status'] ?? 'S/S';
                    final String creatorName = data['creatorName'] ?? 'Anônimo';
                    final String creatorPhone = data['creatorPhone'] ?? 'N/I';
                    final Timestamp? dataCriacaoTimestamp = data['data_criacao'] as Timestamp?;
                    final String dataFormatada = dataCriacaoTimestamp != null ? DateFormat('dd/MM/yy', 'pt_BR').format(dataCriacaoTimestamp.toDate()) : '--';
                    final Color? corDeFundoCard = _getCorPrioridade(prioridade);
                    final Color? corDaBarraStatus = _getCorStatus(status);

                    // --- Cria o CARD ---
                    return Card(
                       color: corDeFundoCard, elevation: 2, clipBehavior: Clip.antiAlias,
                       child: InkWell(
                         onTap: () { Navigator.push( context, MaterialPageRoute( builder: (context) => DetalhesChamadoScreen(chamadoId: document.id),),); },
                         child: IntrinsicHeight( child: Row( crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                             Container( width: 6.0, color: corDaBarraStatus ?? Colors.transparent ), // Barra Status
                             const SizedBox(width: 8.0),
                             Expanded( child: Padding( padding: const EdgeInsets.only(top: 6.0, right: 6.0, bottom: 6.0), child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row( crossAxisAlignment: CrossAxisAlignment.start, children: [ Expanded( child: Text( titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 3, overflow: TextOverflow.ellipsis, ),), InkWell( onTap: () => _excluirChamado(context, document.id), child: const Padding( padding: EdgeInsets.only(left: 3.0), child: Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),)) ], ),
                                  const Spacer(),
                                  Text('Prior: $prioridade', style: const TextStyle(fontSize: 11)), const SizedBox(height: 1),
                                  Text('Status: $status', style: const TextStyle(fontSize: 11)), const SizedBox(height: 1),
                                  Text( 'Por: $creatorName', style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey[800]), maxLines: 1, overflow: TextOverflow.ellipsis,), const SizedBox(height: 1),
                                  Row( children: [ Icon(Icons.phone_outlined, size: 10, color: Colors.grey[700]), const SizedBox(width: 2), Expanded( child: Text( creatorPhone, style: TextStyle(fontSize: 10, color: Colors.grey[800]), maxLines: 1, overflow: TextOverflow.ellipsis, ), ), ], ), const SizedBox(height: 1),
                                  Text( dataFormatada, style: TextStyle(fontSize: 10, color: Colors.grey[700]),),
                             ],),),),
                         ],),),
                       ),
                    ); // Fim do Card
                 } // Fim do itemBuilder
              ); // Fim GridView.builder
            } // Fim builder StreamBuilder
          ), // Fim StreamBuilder
        ), // Fim Expanded
      ], // Fim Column principal
    ); // Fim Column
  } // Fim build
} // Fim State
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
// Importe a tela de detalhes se quiser permitir navegação ao clicar no card
// import 'detalhes_chamado_screen.dart'; // << DESCOMENTE SE NECESSÁRIO

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  // --- Estado para o calendário e marcação de dias ---
  final Set<DateTime> _scheduledDates = {};
  bool _isLoadingCalendar = true;
  String? _calendarError;

  // --- Estado para o calendário TableCalendar ---
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // --- Estado para a lista de visitas do dia selecionado ---
  Stream<QuerySnapshot>? _selectedDayVisitsStream;
  DateTime? _streamConfiguredForDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchScheduledDates();
    _updateSelectedDayStream(_selectedDay!);
  }

  // --- FUNÇÕES PARA O CALENDÁRIO (MARCADORES) ---
  Future<void> _fetchScheduledDates() async {
    if (!mounted) return;
    setState(() { _isLoadingCalendar = true; _calendarError = null; _scheduledDates.clear(); });
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collectionGroup('visitas_agendadas')
          .get();
      if (!mounted) return;
      final Set<DateTime> fetchedDates = {};
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final Timestamp? timestamp = data['dataHoraAgendada'] as Timestamp?;
        if (timestamp != null) {
          final DateTime dateTime = timestamp.toDate();
          final DateTime dateOnly = DateTime(dateTime.year, dateTime.month, dateTime.day);
          fetchedDates.add(dateOnly);
        }
      }
      if (!mounted) return;
      setState(() { _scheduledDates.addAll(fetchedDates); _isLoadingCalendar = false; });
    } catch (e) {
      print("Erro ao buscar datas agendadas (marcadores): $e");
      if (!mounted) return;
      setState(() { _calendarError = "Erro ao carregar marcadores."; _isLoadingCalendar = false; });
    }
  }

  List<Object> _getEventsForDay(DateTime day) {
    final DateTime dateOnly = DateTime(day.year, day.month, day.day);
    return _scheduledDates.contains(dateOnly) ? ['evento'] : [];
  }

  // --- FUNÇÕES PARA A LISTA DE VISITAS DO DIA SELECIONADO ---
  void _updateSelectedDayStream(DateTime selectedDay) {
      final DateTime startOfDay = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
      if (_streamConfiguredForDay != null && isSameDay(_streamConfiguredForDay!, startOfDay)) { return; }
      if (!mounted) return;
      setState(() {
        final DateTime endOfDay = startOfDay.add(const Duration(days: 1));
        final query = FirebaseFirestore.instance
            .collectionGroup('visitas_agendadas')
            .where('dataHoraAgendada', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .where('dataHoraAgendada', isLessThan: Timestamp.fromDate(endOfDay))
            .orderBy('dataHoraAgendada', descending: false);
        _selectedDayVisitsStream = query.snapshots();
        _streamConfiguredForDay = startOfDay;
      });
  }

  // --- FUNÇÃO PARA ATUALIZAR STATUS DA VISITA ---
  Future<void> _updateVisitaStatus(DocumentReference visitaRef, String newStatus) async {
    if (!mounted) return;
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
    try {
      await visitaRef.update({'statusVisita': newStatus});
      if (mounted) Navigator.of(context, rootNavigator: true).pop(); // Fecha loading
      ScaffoldMessenger.of(context).showSnackBar( SnackBar( content: Text('Status da visita atualizado para "$newStatus".'), behavior: SnackBarBehavior.floating, backgroundColor: Colors.green[700], ), );
    } catch (e) {
      print("Erro ao atualizar status da visita: $e");
      if (mounted) Navigator.of(context, rootNavigator: true).pop(); // Fecha loading
      ScaffoldMessenger.of(context).showSnackBar( SnackBar( content: Text('Erro ao atualizar status: ${e.toString()}'), backgroundColor: Theme.of(context).colorScheme.error, behavior: SnackBarBehavior.floating, ), );
    }
  }

  // --- FUNÇÃO PARA EXCLUIR Visita Agendada ---
  Future<void> _deleteVisita(DocumentReference visitaRef, String? tecnicoNome, String? dataHora) async {
    if (!mounted) return;
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Exclusão'),
          content: Text('Tem certeza que deseja excluir a visita ${tecnicoNome != null && tecnicoNome != 'Não definido' ? 'do técnico $tecnicoNome ' : ''}${dataHora != null && dataHora.isNotEmpty ? 'agendada para $dataHora' : 'agendada'}?\nEsta ação não pode ser desfeita.'),
          actions: <Widget>[
            TextButton( child: const Text('Cancelar'), onPressed: () => Navigator.of(context).pop(false), ),
            TextButton( child: Text('Excluir', style: TextStyle(color: Theme.of(context).colorScheme.error)), onPressed: () => Navigator.of(context).pop(true), ),
          ],
        );
      },
    );

    if (confirmar != true) { setState(() {}); return; } // Retorna se não confirmar

    try {
      await visitaRef.delete();
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar( const SnackBar( content: Text('Visita excluída com sucesso.'), behavior: SnackBarBehavior.floating, backgroundColor: Colors.green, ), ); }
    } catch (e) {
      print("Erro ao excluir visita: $e");
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar( SnackBar( content: Text('Erro ao excluir visita: ${e.toString()}'), backgroundColor: Theme.of(context).colorScheme.error, behavior: SnackBarBehavior.floating, ), ); }
      setState(() {}); // Garante rebuild para Dismissible voltar em caso de erro
    }
  }
  // --- FIM DA FUNÇÃO DE EXCLUSÃO ---

  // --- Funções Helper para Status da Visita ---
  IconData _getVisitaStatusIcon(String? status) { switch (status?.toLowerCase()) { case 'agendada': return Icons.event_available; case 'realizada': return Icons.check_circle; case 'cancelada': return Icons.cancel; case 'reagendada': return Icons.history_toggle_off; default: return Icons.help_outline; } }
  Color _getVisitaStatusColor(String? status) { switch (status?.toLowerCase()) { case 'agendada': return Colors.blue.shade700; case 'realizada': return Colors.green.shade700; case 'cancelada': return Colors.red.shade700; case 'reagendada': return Colors.orange.shade800; default: return Colors.grey.shade600; } }
  // ---------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
         title: const Text('Agenda Geral'),
         actions: [ /* ... Ações existentes (refresh) ... */
           IconButton(
             icon: const Icon(Icons.refresh),
             onPressed: (_isLoadingCalendar) ? null : () { /* ... Lógica de refresh ... */ },
             tooltip: 'Recarregar Agenda',
           ),
         ],
      ),
      body: Column(
        children: [
          // --- Seção do Calendário ---
          if (_isLoadingCalendar) const Padding(padding: EdgeInsets.symmetric(vertical: 20.0), child: Center(child: CircularProgressIndicator()))
          else if (_calendarError != null) Padding(padding: const EdgeInsets.all(16.0), child: Center(child: Text(_calendarError!, style: TextStyle(color: colorScheme.error))))
          else TableCalendar( /* ... Configuração Completa do TableCalendar ... */
                locale: 'pt_BR',
                firstDay: DateTime.utc(DateTime.now().year - 2, 1, 1),
                lastDay: DateTime.utc(DateTime.now().year + 2, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                eventLoader: _getEventsForDay,
                onDaySelected: (selectedDay, focusedDay) { if (!isSameDay(_selectedDay, selectedDay)) { if (!mounted) return; setState(() { _selectedDay = selectedDay; _focusedDay = focusedDay; _updateSelectedDayStream(selectedDay); }); } },
                onPageChanged: (focusedDay) { _focusedDay = focusedDay; },
                onFormatChanged: (format) { if (_calendarFormat != format) { if (!mounted) return; setState(() { _calendarFormat = format; }); } },
                calendarStyle: CalendarStyle( /* ... Estilos ... */ ),
                headerStyle: HeaderStyle( /* ... Estilos ... */ ),
                calendarBuilders: CalendarBuilders( /* ... Builders ... */ ),
              ),

          Divider(height: 1, thickness: 1, color: colorScheme.outlineVariant.withOpacity(0.5)),

          // --- Título da Seção da Lista ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
            child: Row( /* ... Row do Título ... */ ),
          ),

          // --- Lista de Visitas (StreamBuilder com ITEMBUILDER DETALHADO + DISMISSIBLE) ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _selectedDayVisitsStream,
              builder: (context, snapshotVisitas) {
                // ... (código existente de loading, error, sem dados) ...
                 if (!snapshotVisitas.hasData || snapshotVisitas.data!.docs.isEmpty) {
                   return Center( /* ... Mensagem "Nenhuma visita agendada..." ... */ );
                 }

                final visitasDoDia = snapshotVisitas.data!.docs;

                // ### ITEM BUILDER COM CARD DETALHADO E DISMISSIBLE ###
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                  itemCount: visitasDoDia.length,
                  itemBuilder: (context, index) {
                    final docVisita = visitasDoDia[index];
                    final dataVisita = docVisita.data() as Map<String, dynamic>;
                    final DocumentReference visitaRef = docVisita.reference;

                    // --- Extrai TODOS os dados necessários (INCLUINDO DENORMALIZADOS) ---
                    final Timestamp? timestampAgendado = dataVisita['dataHoraAgendada'] as Timestamp?;
                    final String horaAgendada = timestampAgendado != null ? DateFormat('HH:mm', 'pt_BR').format(timestampAgendado.toDate()) : '--:--';
                     final String dataAgendadaFormatada = timestampAgendado != null ? DateFormat('dd/MM HH:mm', 'pt_BR').format(timestampAgendado.toDate()) : ""; // Para msg de exclusão
                    final String tecnicoVisita = dataVisita['tecnicoNome'] as String? ?? 'Não definido';
                    final String statusAtual = dataVisita['statusVisita'] as String? ?? 'N/I';
                    final String obs = dataVisita['observacoes'] as String? ?? '';
                    final String instituicao = dataVisita['instituicao'] as String? ?? "";

                    // >> CAMPOS DENORMALIZADOS << (Verifique os nomes corretos!)
                    final String criadorChamado = dataVisita['creatorName'] as String? ?? dataVisita['nome_solicitante'] as String? ?? 'Desconhecido';
                    final String tituloChamado = dataVisita['problema_ocorre'] as String? ?? dataVisita['tituloChamado'] as String? ?? 'Chamado sem título';
                    // ------------------------------------------------------

                    // --- USA DISMISSIBLE PARA EXCLUSÃO ---
                    return Dismissible(
                      key: ValueKey(docVisita.id), // Chave única
                      direction: DismissDirection.endToStart,
                      onDismissed: (direction) {
                        // Chama a função de exclusão
                        _deleteVisita(visitaRef, tecnicoVisita, dataAgendadaFormatada);
                      },
                      background: Container( // Fundo vermelho ao deslizar
                        color: Colors.red.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        alignment: Alignment.centerRight,
                        child: const Row( mainAxisSize: MainAxisSize.min, children: [ Text('Excluir', style: TextStyle(color: Colors.white)), SizedBox(width: 8), Icon(Icons.delete_sweep_outlined, color: Colors.white), ], ),
                      ),
                      // --- Child: O CARD DETALHADO ORIGINAL ---
                      child: Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        elevation: 2.0,
                        shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(12.0), ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                           onTap: () { /* ... onTap Opcional ... */ },
                           child: Padding(
                             padding: const EdgeInsets.all(12.0),
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 // --- Linha Superior: Hora e Status Editável ---
                                 Row(
                                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                     Padding( padding: const EdgeInsets.only(top: 4.0), child: Text( horaAgendada, style: textTheme.titleLarge?.copyWith( fontWeight: FontWeight.bold, color: colorScheme.primary, ), ), ),
                                     PopupMenuButton<String>( /* ... Popup de Status ... */
                                        tooltip: "Mudar Status da Visita",
                                        icon: Icon( _getVisitaStatusIcon(statusAtual), color: _getVisitaStatusColor(statusAtual), size: 28, ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onSelected: (String newStatus) { if (newStatus != statusAtual) { _updateVisitaStatus(visitaRef, newStatus); } },
                                        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                          const PopupMenuItem<String>(value: 'agendada', child: Text('Agendada')),
                                          const PopupMenuItem<String>(value: 'realizada', child: Text('Realizada')),
                                          const PopupMenuItem<String>(value: 'cancelada', child: Text('Cancelada')),
                                          const PopupMenuItem<String>(value: 'reagendada', child: Text('Reagendada')),
                                        ],
                                     ),
                                   ],
                                 ),
                                 const SizedBox(height: 8),
                                 Divider(color: colorScheme.outlineVariant.withOpacity(0.4)),
                                 const SizedBox(height: 8),

                                 // --- Informações Principais (DETALHADO) ---
                                 _buildInfoRow(context, Icons.school_outlined, instituicao.isNotEmpty ? instituicao : "Local não informado"),
                                 const SizedBox(height: 4),
                                 _buildInfoRow(context, Icons.description_outlined, tituloChamado),
                                 const SizedBox(height: 4),
                                 _buildInfoRow(context, Icons.person_pin_circle_outlined, "Criador: $criadorChamado"),
                                 const SizedBox(height: 4),
                                 _buildInfoRow(context, Icons.engineering_outlined, "Téc. Visita: $tecnicoVisita"),
                                 const SizedBox(height: 4),
                                 _buildInfoRow(context, Icons.flag_outlined, "Status: $statusAtual", statusColor: _getVisitaStatusColor(statusAtual)),

                                 // --- Observações (se houver) ---
                                 if (obs.isNotEmpty) ...[
                                   const SizedBox(height: 8),
                                   Divider(color: colorScheme.outlineVariant.withOpacity(0.2)),
                                   const SizedBox(height: 8),
                                    Row( crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Icon(Icons.notes_outlined, size: 16, color: Colors.grey.shade600),
                                        const SizedBox(width: 8),
                                        Expanded( child: Text( obs, style: textTheme.bodySmall?.copyWith(color: Colors.black87), ), ),
                                      ],
                                    ),
                                 ]
                               ],
                             ),
                           ),
                        ),
                      ), // Fim do Card Detalhado
                    ); // Fim do Dismissible
                  }, // Fim do itemBuilder
                ); // Fim do ListView.builder
              }, // Fim do builder do StreamBuilder
            ), // Fim do StreamBuilder
          ), // Fim do Expanded
        ],
      ),
    );
  }

  // --- Widget Auxiliar para Linhas de Informação (NECESSÁRIO PARA O CARD DETALHADO) ---
  Widget _buildInfoRow(BuildContext context, IconData icon, String text, {Color? statusColor}) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding( padding: const EdgeInsets.only(top: 2.0), child: Icon(icon, size: 16, color: statusColor ?? colorScheme.onSurfaceVariant.withOpacity(0.8)), ),
          const SizedBox(width: 8),
          Expanded( child: Text( text.isEmpty ? '-' : text, style: textTheme.bodyMedium, ), ),
        ],
    );
  }
  // -----------------------------------------------

} // Fim da classe _AgendaScreenState
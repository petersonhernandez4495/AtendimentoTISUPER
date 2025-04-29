// lib/screens/agenda_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
// Importe a tela de detalhes se quiser permitir navegação ao clicar no card
// import 'detalhes_chamado_screen.dart';

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  // --- Estado para o calendário e marcação de dias ---
  final Set<DateTime> _scheduledDates = {}; // Datas com eventos (para marcadores)
  bool _isLoadingCalendar = true; // Loading dos marcadores do calendário
  String? _calendarError; // Erro ao carregar marcadores

  // --- Estado para o calendário TableCalendar ---
  CalendarFormat _calendarFormat = CalendarFormat.month; // Formato inicial
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay; // Dia selecionado pelo usuário

  // --- Estado para a lista de visitas do dia selecionado ---
  Stream<QuerySnapshot>? _selectedDayVisitsStream; // Stream para as visitas
  DateTime? _streamConfiguredForDay; // Guarda para qual dia o stream está ativo

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay; // Seleciona o dia atual inicialmente
    _fetchScheduledDates(); // Busca datas para marcadores
    _updateSelectedDayStream(_selectedDay!); // Busca visitas para o dia inicial
  }

  // --- FUNÇÕES PARA O CALENDÁRIO (MARCADORES) ---
  Future<void> _fetchScheduledDates() async {
    // Busca todas as datas que têm *alguma* visita agendada
    if (!mounted) return;
    setState(() {
      _isLoadingCalendar = true;
      _calendarError = null;
      _scheduledDates.clear();
    });
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
      setState(() {
        _scheduledDates.addAll(fetchedDates);
        _isLoadingCalendar = false;
      });
    } catch (e) {
      print("Erro ao buscar datas agendadas (marcadores): $e");
      if (!mounted) return;
      setState(() {
        _calendarError = "Erro ao carregar marcadores.";
        _isLoadingCalendar = false;
      });
    }
  }

  List<Object> _getEventsForDay(DateTime day) {
    // Usado pelo TableCalendar para colocar os marcadores (bolinhas)
    final DateTime dateOnly = DateTime(day.year, day.month, day.day);
    return _scheduledDates.contains(dateOnly) ? ['evento'] : [];
  }

  // --- FUNÇÕES PARA A LISTA DE VISITAS DO DIA SELECIONADO ---
  void _updateSelectedDayStream(DateTime selectedDay) {
    // Cria/atualiza o Stream que busca os detalhes das visitas para o dia selecionado.
     final DateTime startOfDay = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
     if (_streamConfiguredForDay != null && isSameDay(_streamConfiguredForDay!, startOfDay)) {
       return; // Otimização: já está buscando para este dia
     }
    if (!mounted) return;
    setState(() {
      final DateTime endOfDay = startOfDay.add(const Duration(days: 1));
      // Query no Collection Group filtrando pelo campo 'dataHoraAgendada'
      final query = FirebaseFirestore.instance
          .collectionGroup('visitas_agendadas')
          .where('dataHoraAgendada', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('dataHoraAgendada', isLessThan: Timestamp.fromDate(endOfDay))
          .orderBy('dataHoraAgendada', descending: false); // Ordena pela hora
      _selectedDayVisitsStream = query.snapshots(); // Define o stream para o StreamBuilder
      _streamConfiguredForDay = startOfDay; // Marca o dia configurado
    });
  }

  // --- Funções Helper para Status da Visita ---
  IconData _getVisitaStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'agendada': return Icons.event_available;
      case 'realizada': return Icons.check_circle;
      case 'cancelada': return Icons.cancel;
      case 'reagendada': return Icons.history_toggle_off;
      default: return Icons.help_outline;
    }
  }

  Color _getVisitaStatusColor(String? status) {
     switch (status?.toLowerCase()) {
      case 'agendada': return Colors.blue.shade700;
      case 'realizada': return Colors.green.shade700;
      case 'cancelada': return Colors.red.shade700;
      case 'reagendada': return Colors.orange.shade800;
      default: return Colors.grey.shade600;
    }
  }
  // ---------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda Geral'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: (_isLoadingCalendar) ? null : () {
                _fetchScheduledDates(); // Recarrega marcadores
                if (_selectedDay != null) {
                  _streamConfiguredForDay = null; // Força recriação do stream
                  _updateSelectedDayStream(_selectedDay!); // Recarrega lista do dia
                }
            },
            tooltip: 'Recarregar Agenda',
          ),
        ],
      ),
      body: Column(
        children: [
          // --- Seção do Calendário ---
          if (_isLoadingCalendar)
             const Padding(padding: EdgeInsets.symmetric(vertical: 20.0), child: Center(child: CircularProgressIndicator()))
           else if (_calendarError != null)
             Padding(padding: const EdgeInsets.all(16.0), child: Center(child: Text(_calendarError!, style: TextStyle(color: colorScheme.error))))
           else
             TableCalendar(
               locale: 'pt_BR',
               firstDay: DateTime.utc(DateTime.now().year - 2, 1, 1),
               lastDay: DateTime.utc(DateTime.now().year + 2, 12, 31),
               focusedDay: _focusedDay,
               calendarFormat: _calendarFormat,
               selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
               eventLoader: _getEventsForDay,
               onDaySelected: (selectedDay, focusedDay) {
                 if (!isSameDay(_selectedDay, selectedDay)) {
                   if (!mounted) return;
                   setState(() {
                     _selectedDay = selectedDay;
                     _focusedDay = focusedDay;
                     _updateSelectedDayStream(selectedDay);
                   });
                 }
               },
               onPageChanged: (focusedDay) { _focusedDay = focusedDay; },
               onFormatChanged: (format) {
                   if (_calendarFormat != format) {
                     if (!mounted) return;
                     setState(() { _calendarFormat = format; });
                   }
                 },
               // --- Estilização do Calendário ---
               calendarStyle: CalendarStyle(
                 outsideDaysVisible: false,
                 markerDecoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle),
                 markerSize: 5.0,
                 markersMaxCount: 1,
                 todayDecoration: BoxDecoration(color: colorScheme.primaryContainer.withOpacity(0.5), shape: BoxShape.circle),
                 todayTextStyle: TextStyle(color: colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold),
                 selectedDecoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle),
                 selectedTextStyle: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold),
                 weekendTextStyle: TextStyle(color: colorScheme.error.withOpacity(0.8)),
               ),
               headerStyle: HeaderStyle(
                 titleCentered: true,
                 formatButtonVisible: true,
                 formatButtonShowsNext: false,
                 formatButtonTextStyle: TextStyle(color: colorScheme.primary, fontSize: 12),
                 formatButtonDecoration: BoxDecoration(
                     border: Border.all(color: colorScheme.primary.withOpacity(0.5)),
                     borderRadius: BorderRadius.circular(12.0),
                 ),
                  titleTextStyle: textTheme.titleMedium ?? const TextStyle(),
               ),
               calendarBuilders: CalendarBuilders(
                   dowBuilder: (context, day) { // Dias da semana (SEG, TER...)
                     final text = DateFormat.E('pt_BR').format(day);
                     TextStyle? style = textTheme.bodySmall;
                     if (day.weekday == DateTime.sunday || day.weekday == DateTime.saturday) {
                        style = style?.copyWith(color: colorScheme.error.withOpacity(0.9));
                     }
                     return Center(child: Text(text.substring(0,3).toUpperCase(), style: style));
                   },
                ),
             ),

          Divider(height: 1, thickness: 1, color: colorScheme.outlineVariant.withOpacity(0.5)),

          // --- Título da Seção da Lista ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                 Text(
                  _selectedDay != null
                      ? 'Visitas em ${DateFormat('dd/MM/yyyy', 'pt_BR').format(_selectedDay!)}'
                      : 'Selecione um dia',
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // --- Lista de Visitas (StreamBuilder) ---
          Expanded( // Garante que a lista use o espaço restante e seja scrollable
            child: StreamBuilder<QuerySnapshot>(
              stream: _selectedDayVisitsStream,
              builder: (context, snapshotVisitas) {
                // Tratamento de estados (loading, error, sem dados, etc.)
                if (snapshotVisitas.connectionState == ConnectionState.waiting && !snapshotVisitas.hasData) {
                  return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: SizedBox(width: 25, height: 25, child: CircularProgressIndicator(strokeWidth: 3))));
                }
                if (snapshotVisitas.hasError) {
                  print("Erro no Stream de Visitas: ${snapshotVisitas.error}");
                  return Center(child: Text("Erro ao carregar visitas.", style: TextStyle(color: colorScheme.error)));
                }
                if (_selectedDay == null || _selectedDayVisitsStream == null) {
                   return const Center(child: Text("Selecione um dia no calendário."));
                }
                if (!snapshotVisitas.hasData || snapshotVisitas.data!.docs.isEmpty) {
                  return Center(child: Text("Nenhuma visita agendada para este dia.", style: textTheme.bodyMedium?.copyWith(color: Colors.grey)));
                }

                // Dados recebidos, construir a lista
                final visitasDoDia = snapshotVisitas.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                  itemCount: visitasDoDia.length,
                  itemBuilder: (context, index) {
                    final docVisita = visitasDoDia[index];
                    final dataVisita = docVisita.data() as Map<String, dynamic>;

                    // --- Extrai os dados da visita ---
                    final Timestamp? timestampAgendado = dataVisita['dataHoraAgendada'] as Timestamp?;
                    final String horaAgendada = timestampAgendado != null
                        ? DateFormat('HH:mm', 'pt_BR').format(timestampAgendado.toDate())
                        : '--:--';
                    final String tecnico = dataVisita['tecnicoNome'] as String? ?? 'Não definido';
                    final String status = dataVisita['statusVisita'] as String? ?? 'N/I';
                    final String obs = dataVisita['observacoes'] as String? ?? '';

                    // --- !!! DADO DA ESCOLA (ASSUMINDO DENORMALIZAÇÃO) !!! ---
                    final String escola = dataVisita['instituicao'] as String? ?? ""; // Pega do documento da visita

                    // Pega ID do chamado pai
                    final DocumentReference? chamadoRef = docVisita.reference.parent.parent;
                    final String chamadoId = chamadoRef?.id ?? "ID não encontrado";
                    final String chamadoIdCurto = chamadoId.length > 8 ? "...${chamadoId.substring(chamadoId.length - 8)}" : chamadoId;

                    // --- Constrói o Card da Visita (Estrutura de Coluna) ---
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      elevation: 2.0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                         onTap: () {
                           // Opcional: Navegar para detalhes do chamado
                           // if (chamadoRef != null) {
                           //   Navigator.push(context, MaterialPageRoute(builder: (context) => DetalhesChamadoScreen(chamadoId: chamadoId)));
                           // }
                         },
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // --- Linha Superior: Hora e Ícone de Status ---
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    horaAgendada,
                                    style: textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                  Icon(
                                    _getVisitaStatusIcon(status),
                                    color: _getVisitaStatusColor(status),
                                    size: 28,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Divider(color: colorScheme.outlineVariant.withOpacity(0.4)),
                              const SizedBox(height: 8),

                              // --- Informações Principais usando _buildInfoRow ---
                              _buildInfoRow(context, Icons.person_outline, "Téc: $tecnico"),

                              // Exibe a Escola SOMENTE se o campo 'escola' tiver valor
                              if (escola.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: _buildInfoRow(context, Icons.school_outlined, escola),
                                ),

                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: _buildInfoRow(context, Icons.confirmation_number_outlined, "Chamado: $chamadoIdCurto"),
                              ),

                               Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: _buildInfoRow(context, Icons.flag_outlined, "Status: $status", statusColor: _getVisitaStatusColor(status)),
                              ),

                              // --- Observações (se houver) ---
                              if (obs.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Divider(color: colorScheme.outlineVariant.withOpacity(0.2)),
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.notes_outlined, size: 16, color: Colors.grey.shade600),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        obs,
                                        style: textTheme.bodySmall?.copyWith(color: Colors.black87),
                                      ),
                                    ),
                                  ],
                                ),
                              ]
                            ],
                          ),
                        ),
                      ),
                    ); // Fim do Card
                  }, // Fim do itemBuilder
                ); // Fim do ListView.builder
              }, // Fim do builder do StreamBuilder
            ), // Fim do StreamBuilder
          ), // Fim do Expanded
        ],
      ),
    );
  }

  // --- Widget Auxiliar para Linhas de Informação ---
  Widget _buildInfoRow(BuildContext context, IconData icon, String text, {Color? statusColor}) {
    // Constrói uma linha padrão com Ícone e Texto para o card
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
       crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: statusColor ?? colorScheme.onSurfaceVariant.withOpacity(0.8)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }
  // -----------------------------------------------

} // Fim da classe _AgendaScreenState
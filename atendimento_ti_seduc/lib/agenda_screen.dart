// lib/screens/agenda_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

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
    // Busca todas as datas que têm *alguma* visita agendada (exceto canceladas, opcional)
    // para poder colocar os marcadores no calendário.
    if (!mounted) return; // Verifica se o widget ainda está na árvore
    setState(() {
      _isLoadingCalendar = true;
      _calendarError = null;
      _scheduledDates.clear();
    });

    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collectionGroup('visitas_agendadas')
          // Se quiser ignorar visitas canceladas nos marcadores:
          // .where('statusVisita', isNotEqualTo: 'cancelada')
          .get();

      if (!mounted) return; // Verifica novamente após a operação assíncrona

      final Set<DateTime> fetchedDates = {};
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final Timestamp? timestamp = data['dataHoraAgendada'] as Timestamp?;
        if (timestamp != null) {
          final DateTime dateTime = timestamp.toDate();
          // Normaliza para meia-noite para comparar apenas a data
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
    // Função usada pelo TableCalendar para saber se um dia deve ter um marcador.
    final DateTime dateOnly = DateTime(day.year, day.month, day.day);
    return _scheduledDates.contains(dateOnly) ? ['evento'] : [];
  }

  // --- FUNÇÕES PARA A LISTA DE VISITAS DO DIA SELECIONADO ---

  void _updateSelectedDayStream(DateTime selectedDay) {
    // Cria ou atualiza o Stream que busca os detalhes das visitas
    // APENAS para o dia que foi selecionado no calendário.
     final DateTime startOfDay = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
     // Otimização: Se o stream já estiver configurado para este dia, não faz nada.
     if (_streamConfiguredForDay != null && isSameDay(_streamConfiguredForDay!, startOfDay)) {
       print("Stream já configurado para $startOfDay");
       return;
     }
     print("Configurando stream para $startOfDay");

    if (!mounted) return;
    setState(() {
      final DateTime endOfDay = startOfDay.add(const Duration(days: 1));

      // Query no Collection Group filtrando pelo campo 'dataHoraAgendada'
      final query = FirebaseFirestore.instance
          .collectionGroup('visitas_agendadas')
          .where('dataHoraAgendada', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('dataHoraAgendada', isLessThan: Timestamp.fromDate(endOfDay))
          .orderBy('dataHoraAgendada', descending: false); // Ordena pela hora da visita

      _selectedDayVisitsStream = query.snapshots(); // Define o stream para o StreamBuilder
      _streamConfiguredForDay = startOfDay; // Marca o dia configurado
    });
  }

  // --- Funções Helper para Status da Visita (COPIADAS de detalhes_chamado_screen.dart) ---
  // Essenciais para exibir os ícones e cores corretos na lista de visitas.
  IconData _getVisitaStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'agendada': return Icons.event_available;
      case 'realizada': return Icons.check_circle;
      case 'cancelada': return Icons.cancel;
      case 'reagendada': return Icons.history_toggle_off;
      default: return Icons.help_outline; // Ícone padrão para status desconhecido/nulo
    }
  }

  Color _getVisitaStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'agendada': return Colors.blue.shade700;
      case 'realizada': return Colors.green.shade700;
      case 'cancelada': return Colors.red.shade700;
      case 'reagendada': return Colors.orange.shade800;
      default: return Colors.grey.shade600; // Cor padrão
    }
  }
  // ------------------------------------------------------------------------------------


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda Geral'), // Título mais curto
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
          // Exibe o loading ou erro referente aos MARCADORES do calendário
          if (_isLoadingCalendar)
            const Padding(padding: EdgeInsets.symmetric(vertical: 20.0), child: Center(child: CircularProgressIndicator()))
          else if (_calendarError != null)
            Padding(padding: const EdgeInsets.all(16.0), child: Center(child: Text(_calendarError!, style: TextStyle(color: colorScheme.error))))
          else
            // O widget TableCalendar em si
            TableCalendar(
              locale: 'pt_BR', // Português do Brasil
              firstDay: DateTime.utc(DateTime.now().year - 2, 1, 1), // Dois anos atrás
              lastDay: DateTime.utc(DateTime.now().year + 2, 12, 31), // Dois anos à frente
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              // Carrega os marcadores (bolinhas) nos dias com eventos
              eventLoader: _getEventsForDay,

              // --- Ações do Calendário ---
              onDaySelected: (selectedDay, focusedDay) {
                if (!isSameDay(_selectedDay, selectedDay)) {
                  if (!mounted) return;
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay; // Move o foco para o dia selecionado
                    // Atualiza o STREAM para buscar as visitas do novo dia
                    _updateSelectedDayStream(selectedDay);
                  });
                }
              },
              onPageChanged: (focusedDay) {
                 // Não precisa chamar setState aqui, apenas atualiza o foco interno
                _focusedDay = focusedDay;
              },
               onFormatChanged: (format) {
                 // Permite mudar entre mês/semana/etc. (opcional)
                  if (_calendarFormat != format) {
                    if (!mounted) return;
                    setState(() { _calendarFormat = format; });
                  }
                },

              // --- Estilização do Calendário (Adapte conforme seu AppTheme) ---
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false, // Esconde dias de outros meses
                markerDecoration: BoxDecoration( // Estilo dos marcadores de evento
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                 markerSize: 5.0,
                 markersMaxCount: 1, // Mostrar no máximo 1 marcador por dia
                todayDecoration: BoxDecoration( // Dia atual
                  color: colorScheme.primaryContainer.withOpacity(0.5),
                  shape: BoxShape.circle,
                 // border: Border.all(color: colorScheme.primary, width: 1.5)
                ),
                 todayTextStyle: TextStyle(color: colorScheme.onPrimaryContainer),
                selectedDecoration: BoxDecoration( // Dia selecionado
                  color: colorScheme.primary, // Usa cor primária para seleção
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: TextStyle(color: colorScheme.onPrimary), // Texto sobre a seleção
                weekendTextStyle: TextStyle(color: colorScheme.error.withOpacity(0.8)), // Fim de semana
              ),
              headerStyle: HeaderStyle(
                titleCentered: true,
                formatButtonVisible: true, // Mostra botão para trocar formato (mês/semana)
                formatButtonShowsNext: false,
                formatButtonTextStyle: TextStyle(color: colorScheme.primary),
                formatButtonDecoration: BoxDecoration(
                    border: Border.all(color: colorScheme.primary.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(12.0),
                ),
                 titleTextStyle: textTheme.titleMedium ?? const TextStyle(), // Usa estilo do tema
              ),
              calendarBuilders: CalendarBuilders( // Para traduções e customizações finas
                  dowBuilder: (context, day) { // Dias da semana (Seg, Ter, ...)
                    final text = DateFormat.E('pt_BR').format(day);
                    TextStyle? style = textTheme.bodySmall;
                    if (day.weekday == DateTime.sunday || day.weekday == DateTime.saturday) {
                       style = style?.copyWith(color: colorScheme.error.withOpacity(0.9));
                    }
                    return Center(child: Text(text.substring(0,3), style: style)); // Mostra 3 letras
                  },
               ),
            ),

          Divider(height: 1, thickness: 1, color: colorScheme.outlineVariant.withOpacity(0.5)),

          // --- Seção da Lista de Visitas do Dia Selecionado ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                 Text(
                  _selectedDay != null
                      ? 'Visitas em ${DateFormat('dd/MM/yyyy', 'pt_BR').format(_selectedDay!)}'
                      : 'Selecione um dia',
                  style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                // Poderia adicionar um contador de visitas aqui se quisesse
              ],
            ),
          ),

          // O StreamBuilder que ouve as visitas DO DIA selecionado
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _selectedDayVisitsStream,
              builder: (context, snapshotVisitas) {
                // 1. Estado de Loading (mostra só se não tiver dados antigos)
                if (snapshotVisitas.connectionState == ConnectionState.waiting && !snapshotVisitas.hasData) {
                  return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: SizedBox(width: 25, height: 25, child: CircularProgressIndicator(strokeWidth: 3))));
                }
                // 2. Estado de Erro
                if (snapshotVisitas.hasError) {
                  print("Erro no Stream de Visitas: ${snapshotVisitas.error}");
                  return Center(child: Text("Erro ao carregar visitas.", style: TextStyle(color: colorScheme.error)));
                }
                 // 3. Sem dia selecionado ou stream não pronto
                if (_selectedDay == null || _selectedDayVisitsStream == null) {
                   return const Center(child: Text("Selecione um dia no calendário."));
                }
                // 4. Nenhuma visita encontrada para o dia
                if (!snapshotVisitas.hasData || snapshotVisitas.data!.docs.isEmpty) {
                  return const Center(child: Text("Nenhuma visita agendada para este dia.", style: TextStyle(color: Colors.grey)));
                }

                // 5. TEM VISITAS! Construir a lista
                final visitasDoDia = snapshotVisitas.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0), // Padding da lista
                  itemCount: visitasDoDia.length,
                  itemBuilder: (context, index) {
                    final docVisita = visitasDoDia[index];
                    final dataVisita = docVisita.data() as Map<String, dynamic>;

                    // --- Extrai os dados da visita ---
                    final Timestamp? timestampAgendado = dataVisita['dataHoraAgendada'] as Timestamp?;
                    // Formata apenas a HORA:MINUTO para a lista do dia
                    final String horaAgendada = timestampAgendado != null
                        ? DateFormat('HH:mm', 'pt_BR').format(timestampAgendado.toDate())
                        : 'Inválida';
                    final String tecnico = dataVisita['tecnicoNome'] as String? ?? 'Não definido';
                    final String status = dataVisita['statusVisita'] as String? ?? 'N/I';
                    final String obs = dataVisita['observacoes'] as String? ?? '';
                     // Pega a referência do chamado pai para exibir info extra (opcional)
                    final DocumentReference chamadoRef = docVisita.reference.parent.parent!;
                    final String chamadoIdCurto = chamadoRef.id.length > 8 ? chamadoRef.id.substring(0, 8) : chamadoRef.id; // Pega parte do ID do chamado


                    // --- Constrói o Card da Visita (Reutilizando estilo) ---
                    return Card(
                      // Usar CardTheme do seu AppTheme ou definir aqui
                      margin: const EdgeInsets.symmetric(vertical: 5.0),
                      elevation: 1.5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: ListTile(
                        leading: Column( // Coluna para Hora e Ícone
                          mainAxisAlignment: MainAxisAlignment.center,
                           crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                             Text(horaAgendada, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary)),
                             const SizedBox(height: 4),
                            Icon(
                               _getVisitaStatusIcon(status),
                               color: _getVisitaStatusColor(status),
                               size: 28 // Tamanho do ícone um pouco menor aqui
                             ),
                          ],
                        ),
                        // Título principal pode ser o técnico ou status
                        title: Text(
                          "Técnico: $tecnico",
                          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 3),
                            // Adiciona o ID do chamado pai
                             Text("Chamado: ...${chamadoIdCurto}", style: textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
                             const SizedBox(height: 2),
                            // Observações, se houver
                            if (obs.isNotEmpty)
                              Text(
                                "Obs: $obs",
                                style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                             const SizedBox(height: 2),
                            // Status como linha final do subtítulo
                            Text(
                              "Status: $status",
                              style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        dense: true, // Torna o ListTile mais compacto
                        // Pode adicionar um trailing IconButton para ações futuras (editar/cancelar visita?)
                        // trailing: IconButton(icon: Icon(Icons.more_vert), onPressed: () { /* Ações */ }),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
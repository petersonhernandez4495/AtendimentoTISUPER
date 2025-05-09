// lib/widgets/agenda_section.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AgendaSection extends StatelessWidget {
  final String chamadoId; // Recebe o ID do chamado

  const AgendaSection({super.key, required this.chamadoId});

  // --- Funções Helper movidas para cá ---
  IconData _getVisitaStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'agendada':
        return Icons.event_available;
      case 'realizada':
        return Icons.check_circle;
      case 'cancelada':
        return Icons.cancel;
      case 'reagendada':
        return Icons.history_toggle_off;
      default:
        return Icons.help_outline;
    }
  }

  Color _getVisitaStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'agendada':
        return Colors.blue.shade700;
      case 'realizada':
        return Colors.green.shade700;
      case 'cancelada':
        return Colors.red.shade700;
      case 'reagendada':
        return Colors.orange.shade800;
      default:
        return Colors.grey.shade600;
    }
  }
  // -------------------------------------

  @override
  Widget build(BuildContext context) {
    // Retorna o StreamBuilder que antes estava em _buildAgendaSection
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chamados')
          .doc(chamadoId) // Usa o ID recebido
          .collection('visitas_agendadas')
          .orderBy('dataHoraAgendada', descending: false)
          .limit(10)
          .snapshots(),
      builder: (context, snapshotVisitas) {
        if (snapshotVisitas.hasError) {
          return Text("Erro ao carregar agenda: ${snapshotVisitas.error}",
              style: const TextStyle(color: Colors.red));
        }
        if (snapshotVisitas.connectionState == ConnectionState.waiting) {
          // Retorna um indicador de carregamento menor
          return const Padding(
              padding: EdgeInsets.all(8.0),
              child: Center(
                  child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))));
        }
        if (!snapshotVisitas.hasData || snapshotVisitas.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 15.0),
            child: Center(
                child: Text("Nenhuma visita agendada.",
                    style: TextStyle(color: Colors.grey))),
          );
        }

        // Constrói a lista de visitas
        return Column(
          // shrinkWrap: true, // Não precisa mais pois Column já se ajusta
          children: snapshotVisitas.data!.docs.map((docVisita) {
            final dataVisita = docVisita.data() as Map<String, dynamic>;
            final Timestamp? timestampAgendado =
                dataVisita['dataHoraAgendada'] as Timestamp?;
            final String dataHoraAgendada = timestampAgendado != null
                ? DateFormat('dd/MM/yy HH:mm', 'pt_BR')
                    .format(timestampAgendado.toDate())
                : 'Data Inválida';
            final String tecnico =
                dataVisita['tecnicoNome'] as String? ?? 'Não definido';
            final String status =
                dataVisita['statusVisita'] as String? ?? 'N/I';
            final String obs = dataVisita['observacoes'] as String? ?? '';

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 0),
              elevation: 1.5,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              child: ListTile(
                leading: Icon(_getVisitaStatusIcon(status),
                    color: _getVisitaStatusColor(status), size: 32),
                title: Text("Agendado: $dataHoraAgendada",
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 3),
                    if (tecnico != 'Não definido') Text("Técnico: $tecnico"),
                    if (obs.isNotEmpty)
                      Text("Obs: $obs",
                          style: const TextStyle(fontStyle: FontStyle.italic)),
                    Text("Status: $status",
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
                dense: true,
                // trailing: IconButton(icon: Icon(Icons.more_vert), onPressed: () {}), // Ações futuras
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

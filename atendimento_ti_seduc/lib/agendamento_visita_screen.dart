// lib/agendamento_visita_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Para formatar data/hora
import 'agendamento_visita_screen.dart';
class AgendamentoVisitaScreen extends StatefulWidget {
  final String chamadoId; // ID do chamado para o qual agendar

  const AgendamentoVisitaScreen({super.key, required this.chamadoId});

  @override
  State<AgendamentoVisitaScreen> createState() => _AgendamentoVisitaScreenState();
}

class _AgendamentoVisitaScreenState extends State<AgendamentoVisitaScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final _tecnicoController = TextEditingController();
  final _observacoesController = TextEditingController();
  bool _isLoading = false;

  // Função para mostrar o Date Picker
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(), // Não permite agendar no passado
      lastDate: DateTime.now().add(const Duration(days: 90)), // Limite de 90 dias
      locale: const Locale('pt', 'BR'), // Para calendário em português
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // Função para mostrar o Time Picker
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      // Poderia adicionar restrições de horário comercial aqui se necessário
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  // Função para salvar o agendamento
  Future<void> _agendarVisita() async {
    if (_formKey.currentState!.validate()) {
       // Validação extra para data e hora
       if (_selectedDate == null || _selectedTime == null) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Por favor, selecione data e hora.'), backgroundColor: Colors.orange),
         );
         return;
       }

      setState(() { _isLoading = true; });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
         if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro: Usuário não autenticado.')));
         setState(() { _isLoading = false; });
         return;
      }

      // Combina data e hora selecionadas
      final DateTime agendamentoCompleto = DateTime(
        _selectedDate!.year, _selectedDate!.month, _selectedDate!.day,
        _selectedTime!.hour, _selectedTime!.minute,
      );

      // Converte para Timestamp do Firestore
      final Timestamp dataHoraTimestamp = Timestamp.fromDate(agendamentoCompleto);

      final visitaData = {
        'dataHoraAgendada': dataHoraTimestamp,
        'tecnicoNome': _tecnicoController.text.trim().isEmpty ? null : _tecnicoController.text.trim(),
        'observacoes': _observacoesController.text.trim().isEmpty ? null : _observacoesController.text.trim(),
        'statusVisita': 'agendada', // Status inicial
        'criadoPorUid': user.uid,
        'criadoEm': FieldValue.serverTimestamp(),
        // Poderia adicionar o chamadoId aqui também por redundância/facilidade em queries futuras
        'chamadoId': widget.chamadoId,
      };

      try {
         await FirebaseFirestore.instance
          .collection('chamados')
          .doc(widget.chamadoId) // ID do chamado recebido
          .collection('visitas_agendadas') // Cria/Acessa a subcoleção
          .add(visitaData); // Adiciona o novo agendamento

         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Visita agendada com sucesso!'), backgroundColor: Colors.green),
            );
            Navigator.pop(context); // Volta para a tela anterior (Detalhes)
         }

      } catch (e) {
         print("Erro ao agendar visita: $e");
         if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text('Erro ao agendar visita: ${e.toString()}'), backgroundColor: Colors.red),
             );
         }
      } finally {
         if (mounted) { setState(() { _isLoading = false; }); }
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    // Formata a data e hora selecionadas para exibição
    final String dataFormatada = _selectedDate == null ? 'Selecione a data' : DateFormat('dd/MM/yyyy').format(_selectedDate!);
    final String horaFormatada = _selectedTime == null ? 'Selecione a hora' : _selectedTime!.format(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agendar Visita Técnica'),
      ),
      body: SingleChildScrollView( // Permite rolagem
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Agendamento para o Chamado ID: ${widget.chamadoId.substring(0, 6)}...', // Mostra parte do ID
                  style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 20),

              // Seletores de Data e Hora
              Row(
                children: [
                  Expanded(
                    child: InkWell( // Botão improvisado para data
                      onTap: () => _selectDate(context),
                      child: InputDecorator(
                        decoration: const InputDecoration( labelText: 'Data', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_month)),
                        child: Text(dataFormatada),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                   Expanded(
                    child: InkWell( // Botão improvisado para hora
                      onTap: () => _selectTime(context),
                      child: InputDecorator(
                        decoration: const InputDecoration( labelText: 'Hora', border: OutlineInputBorder(), prefixIcon: Icon(Icons.access_time)),
                        child: Text(horaFormatada),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Campo Técnico (Opcional)
              TextFormField(
                controller: _tecnicoController,
                decoration: const InputDecoration( labelText: 'Técnico Designado (Opcional)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_pin_outlined)),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

               // Campo Observações (Opcional)
              TextFormField(
                controller: _observacoesController,
                 decoration: const InputDecoration( labelText: 'Observações (Opcional)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.notes)),
                 textCapitalization: TextCapitalization.sentences,
                 maxLines: 3,
              ),
              const SizedBox(height: 30),

              // Botão Agendar
              ElevatedButton.icon(
                icon: const Icon(Icons.event_available),
                label: const Text('Confirmar Agendamento'),
                onPressed: _isLoading ? null : _agendarVisita,
                style: ElevatedButton.styleFrom( padding: const EdgeInsets.symmetric(vertical: 15)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
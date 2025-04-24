// lib/agendamento_visita_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Para formatar data/hora
// import 'agendamento_visita_screen.dart'; // <<< REMOVIDO

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

  @override
  void dispose() {
    _tecnicoController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }

  // Função para mostrar o Date Picker
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker( context: context, initialDate: _selectedDate ?? DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)), locale: const Locale('pt', 'BR'), );
    if (picked != null && picked != _selectedDate) { setState(() { _selectedDate = picked; }); }
  }

  // Função para mostrar o Time Picker
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker( context: context, initialTime: _selectedTime ?? TimeOfDay.now(), );
    if (picked != null && picked != _selectedTime) { setState(() { _selectedTime = picked; }); }
  }

  // Função para salvar o agendamento
  Future<void> _agendarVisita() async {
    if (_formKey.currentState!.validate()) {
       if (_selectedDate == null || _selectedTime == null) { if(mounted) ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Selecione data e hora.'), backgroundColor: Colors.orange), ); return; }
      setState(() { _isLoading = true; });
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuário não autenticado.'))); setState(() { _isLoading = false; }); return; }
      final DateTime agendamentoCompleto = DateTime( _selectedDate!.year, _selectedDate!.month, _selectedDate!.day, _selectedTime!.hour, _selectedTime!.minute, );
      final Timestamp dataHoraTimestamp = Timestamp.fromDate(agendamentoCompleto);
      final visitaData = { 'dataHoraAgendada': dataHoraTimestamp, 'tecnicoNome': _tecnicoController.text.trim().isEmpty ? null : _tecnicoController.text.trim(), 'observacoes': _observacoesController.text.trim().isEmpty ? null : _observacoesController.text.trim(), 'statusVisita': 'agendada', 'criadoPorUid': user.uid, 'criadoEm': FieldValue.serverTimestamp(), 'chamadoId': widget.chamadoId, };
      try {
         await FirebaseFirestore.instance .collection('chamados') .doc(widget.chamadoId) .collection('visitas_agendadas') .add(visitaData);
         if (mounted) { ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Visita agendada com sucesso!'), backgroundColor: Colors.green), ); Navigator.pop(context); }
      } catch (e) { print("Erro ao agendar visita: $e"); if (mounted) { ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Erro ao agendar visita: ${e.toString()}'), backgroundColor: Colors.red), ); }
      } finally { if (mounted) { setState(() { _isLoading = false; }); } }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String dataFormatada = _selectedDate == null ? 'Selecione a data' : DateFormat('dd/MM/yyyy').format(_selectedDate!);
    final String horaFormatada = _selectedTime == null ? 'Selecione a hora' : _selectedTime!.format(context);

    return Scaffold(
      appBar: AppBar( title: const Text('Agendar Visita Técnica'), ),
      body: SingleChildScrollView( padding: const EdgeInsets.all(20.0), child: Form( key: _formKey, child: Column( crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Agendamento para Chamado ID: ${widget.chamadoId.substring(0, 6)}...', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 20),
            Row( children: [ Expanded( child: InkWell( onTap: _isLoading ? null : () => _selectDate(context), child: InputDecorator( decoration: const InputDecoration( labelText: 'Data', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_month)), child: Text(dataFormatada), ), ), ), const SizedBox(width: 10), Expanded( child: InkWell( onTap: _isLoading ? null : () => _selectTime(context), child: InputDecorator( decoration: const InputDecoration( labelText: 'Hora', border: OutlineInputBorder(), prefixIcon: Icon(Icons.access_time)), child: Text(horaFormatada), ), ), ), ], ),
            const SizedBox(height: 20),
            TextFormField( enabled: !_isLoading, controller: _tecnicoController, decoration: const InputDecoration( labelText: 'Técnico Designado (Opcional)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_pin_outlined)), textCapitalization: TextCapitalization.words, ),
            const SizedBox(height: 16),
            TextFormField( enabled: !_isLoading, controller: _observacoesController, decoration: const InputDecoration( labelText: 'Observações (Opcional)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.notes)), textCapitalization: TextCapitalization.sentences, maxLines: 3, ),
            const SizedBox(height: 30),
            ElevatedButton.icon( icon: const Icon(Icons.event_available), label: const Text('Confirmar Agendamento'), onPressed: _isLoading ? null : _agendarVisita, style: ElevatedButton.styleFrom( padding: const EdgeInsets.symmetric(vertical: 15)), ),
          ],
        ),
      ),),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

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

  // Informações do chamado pai (para denormalização)
  String? _chamadoCreatorName;
  String? _chamadoTitulo;
  String? _chamadoInstituicao;
  bool _chamadoDataFetched = false; // Controle para buscar dados do chamado só uma vez

  @override
  void initState() {
    super.initState();
    _fetchChamadoData(); // Busca os dados do chamado ao iniciar a tela
  }


  @override
  void dispose() {
    _tecnicoController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }

  // --- NOVA FUNÇÃO: Buscar dados do chamado pai ---
  Future<void> _fetchChamadoData() async {
    if (_chamadoDataFetched) return; // Já buscou
    setState(() { _isLoading = true; }); // Mostra loading geral

    try {
      final chamadoSnapshot = await FirebaseFirestore.instance
          .collection('chamados')
          .doc(widget.chamadoId)
          .get();

      if (mounted && chamadoSnapshot.exists) {
        final data = chamadoSnapshot.data() as Map<String, dynamic>;
        setState(() {
          // Ajuste os nomes dos campos conforme estão no seu Firestore!
          _chamadoCreatorName = data['nome_solicitante'] as String? ?? data['creatorName'] as String? ?? 'Desconhecido';
          _chamadoTitulo = data['problema_ocorre'] as String? ?? data['titulo'] as String? ?? 'Chamado sem título';
          _chamadoInstituicao = data['instituicao'] as String?; // Pode ser nulo
          _chamadoDataFetched = true;
        });
      } else if (mounted) {
        // Chamado não encontrado
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: Chamado ${widget.chamadoId} não encontrado.'), backgroundColor: Colors.red),
        );
        Navigator.pop(context); // Fecha a tela se o chamado não existe
      }
    } catch (e) {
      print("Erro ao buscar dados do chamado: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados do chamado: ${e.toString()}'), backgroundColor: Colors.red),
        );
         Navigator.pop(context); // Fecha a tela em caso de erro grave
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; }); // Esconde loading geral
      }
    }
  }


  // Função para mostrar o Date Picker
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)), // Permite agendar para alguns dias atrás? Ajuste se necessário
      lastDate: DateTime.now().add(const Duration(days: 365)), // Permite agendar até 1 ano a frente
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() { _selectedDate = picked; });
    }
  }

  // Função para mostrar o Time Picker
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay initialTime = _selectedTime ?? TimeOfDay.now();
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      // Opcional: Defina um builder para usar o tema do app no picker
      // builder: (BuildContext context, Widget? child) {
      //   return Theme(
      //     data: ThemeData.light().copyWith( // Ou Theme.of(context) se preferir
      //       // ... customizações de tema para o picker ...
      //     ),
      //     child: child!,
      //   );
      // },
    );
    if (picked != null && picked != _selectedTime) {
      setState(() { _selectedTime = picked; });
    }
  }

  // --- Função para salvar o agendamento (MODIFICADA) ---
  Future<void> _agendarVisita() async {
    // Verifica se os dados do chamado foram carregados
    if (!_chamadoDataFetched) {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aguarde, carregando dados do chamado...'), backgroundColor: Colors.orange),
        );
        }
        _fetchChamadoData(); // Tenta buscar novamente se não buscou
        return;
    }

    if (_formKey.currentState!.validate()) {
      if (_selectedDate == null || _selectedTime == null) {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecione data e hora.'), backgroundColor: Colors.orange),
        );
        }
        return;
      }

      setState(() { _isLoading = true; }); // Ativa loading específico do botão/salvamento

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuário não autenticado.')));
        setState(() { _isLoading = false; });
        return;
      }

      final DateTime agendamentoCompleto = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );
      final Timestamp dataHoraTimestamp = Timestamp.fromDate(agendamentoCompleto);

      // --- Cria o mapa de dados da visita COM os campos denormalizados ---
      final visitaData = {
        // Dados da visita
        'dataHoraAgendada': dataHoraTimestamp,
        'tecnicoNome': _tecnicoController.text.trim().isEmpty ? null : _tecnicoController.text.trim(),
        'observacoes': _observacoesController.text.trim().isEmpty ? null : _observacoesController.text.trim(),
        'statusVisita': 'agendada', // Status inicial padrão
        'criadoPorUid': user.uid,
        'criadoEm': FieldValue.serverTimestamp(),
        'creatorName': _chamadoCreatorName, // Copiado do chamado
        'tituloChamado': _chamadoTitulo,    // Copiado do chamado (usando 'tituloChamado' como exemplo)
        'instituicao': _chamadoInstituicao, // Copiado do chamado (se não for nulo)
        
      };

      // Remove campos nulos do mapa se não quiser salvá-los no Firestore
      visitaData.removeWhere((key, value) => value == null);

      try {
          // Salva na subcoleção do chamado correto
          await FirebaseFirestore.instance
              .collection('chamados')
              .doc(widget.chamadoId)
              .collection('visitas_agendadas')
              .add(visitaData);

          // Opcional: Atualizar o status do chamado principal para "em andamento" ou "agendado"
          // await FirebaseFirestore.instance.collection('chamados').doc(widget.chamadoId).update({
          //   'status': 'em andamento', // ou 'agendado'
          //   'data_atualizacao': FieldValue.serverTimestamp(),
          // });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Visita agendada com sucesso!'), backgroundColor: Colors.green),
            );
            Navigator.pop(context); // Volta para a tela anterior
          }
      } catch (e) {
          print("Erro ao agendar visita: $e");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erro ao agendar visita: ${e.toString()}'), backgroundColor: Colors.red),
            );
          }
      } finally {
          if (mounted) {
            setState(() { _isLoading = false; }); // Desativa loading do botão/salvamento
          }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Formata data e hora para exibição
    final String dataFormatada = _selectedDate == null ? 'Selecione a data' : DateFormat('dd/MM/yyyy', 'pt_BR').format(_selectedDate!);
    final String horaFormatada = _selectedTime == null ? 'Selecione a hora' : _selectedTime!.format(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agendar Visita Técnica'),
      ),
      body: _isLoading && !_chamadoDataFetched // Mostra loading inicial se estiver buscando dados do chamado
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Mostra info básica do chamado (opcional)
                    if (_chamadoDataFetched)
                      Card(
                        margin: const EdgeInsets.only(bottom: 20),
                        elevation: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                               Text('Chamado: ${_chamadoTitulo ?? "..."}', style: Theme.of(context).textTheme.titleSmall),
                               const SizedBox(height: 4),
                               Text('Criador: ${_chamadoCreatorName ?? "..."}', style: Theme.of(context).textTheme.bodySmall),
                               if (_chamadoInstituicao != null && _chamadoInstituicao!.isNotEmpty) ...[
                                 const SizedBox(height: 4),
                                 Text('Local: $_chamadoInstituicao', style: Theme.of(context).textTheme.bodySmall),
                               ]
                            ],
                          ),
                        ),
                      ),

                    // Seletores de Data e Hora
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _isLoading ? null : () => _selectDate(context),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Data',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.calendar_month),
                                // Mostra erro se data não selecionada após tentar salvar
                                errorText: _formKey.currentState?.validate() == false && _selectedDate == null ? '' : null,
                                errorStyle: const TextStyle(height: 0), // Oculta texto de erro padrão
                              ),
                              child: Text(dataFormatada),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: _isLoading ? null : () => _selectTime(context),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Hora',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.access_time),
                                errorText: _formKey.currentState?.validate() == false && _selectedTime == null ? '' : null,
                                errorStyle: const TextStyle(height: 0),
                              ),
                              child: Text(horaFormatada),
                            ),
                          ),
                        ),
                      ],
                    ),
                     // Mensagem de erro explícita para data/hora
                    if (_formKey.currentState?.validate() == false && (_selectedDate == null || _selectedTime == null))
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Data e Hora são obrigatórias.',
                          style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                        ),
                      ),

                    const SizedBox(height: 20),

                    // Campo Técnico
                    TextFormField(
                      enabled: !_isLoading,
                      controller: _tecnicoController,
                      decoration: const InputDecoration(
                          labelText: 'Técnico Designado (Opcional)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_pin_outlined)),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),

                    // Campo Observações
                    TextFormField(
                      enabled: !_isLoading,
                      controller: _observacoesController,
                      decoration: const InputDecoration(
                          labelText: 'Observações (Opcional)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.notes)),
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 3,
                      minLines: 1,
                    ),
                    const SizedBox(height: 30),

                    // Botão Confirmar
                    ElevatedButton.icon(
                      icon: _isLoading
                          ? Container( // Loading dentro do botão
                              width: 20,
                              height: 20,
                              margin: const EdgeInsets.only(right: 8),
                              child: CircularProgressIndicator( strokeWidth: 2.5, color: Theme.of(context).colorScheme.onPrimary,),
                            )
                          : const Icon(Icons.event_available),
                      label: Text(_isLoading ? 'Agendando...' : 'Confirmar Agendamento'),
                      onPressed: _isLoading ? null : _agendarVisita,
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
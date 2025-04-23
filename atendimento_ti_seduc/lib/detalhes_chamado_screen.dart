// lib/detalhes_chamado_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DetalhesChamadoScreen extends StatefulWidget {
  final String chamadoId;
  const DetalhesChamadoScreen({super.key, required this.chamadoId});

  @override
  State<DetalhesChamadoScreen> createState() => _DetalhesChamadoScreenState();
}

class _DetalhesChamadoScreenState extends State<DetalhesChamadoScreen> {
  // Listas e função _mostrarDialogoEdicao (mantidas como na versão anterior)
  final List<String> _listaStatus = ['aberto', 'em andamento', 'pendente', 'resolvido', 'fechado'];
  final List<String> _listaPrioridades = ['Baixa', 'Média', 'Alta', 'Crítica'];

  Future<void> _mostrarDialogoEdicao(Map<String, dynamic> dadosAtuais) async {
    // ... (código completo da função _mostrarDialogoEdicao aqui, sem alterações) ...
     String? statusSelecionado = dadosAtuais['status'] as String?;
    String? prioridadeSelecionada = dadosAtuais['prioridade'] as String?;
    final formKeyDialog = GlobalKey<FormState>();

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Editar Status e Prioridade'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKeyDialog,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      DropdownButtonFormField<String>( /* Dropdown Status */
                         decoration: const InputDecoration(labelText: 'Status'),
                        value: statusSelecionado,
                        items: _listaStatus.map((String status) { /* ... */ }).toList(),
                        onChanged: (String? newValue) { setDialogState(() { statusSelecionado = newValue; }); },
                        validator: (value) => value == null ? 'Selecione um status' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>( /* Dropdown Prioridade */
                         decoration: const InputDecoration(labelText: 'Prioridade'),
                        value: prioridadeSelecionada,
                        items: _listaPrioridades.map((String prioridade) { /* ... */ }).toList(),
                        onChanged: (String? newValue) { setDialogState(() { prioridadeSelecionada = newValue; }); },
                         validator: (value) => value == null ? 'Selecione uma prioridade' : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton( /* Botão Cancelar */
                   child: const Text('Cancelar'),
                  onPressed: () { Navigator.of(dialogContext).pop(); },
                ),
                ElevatedButton( /* Botão Salvar */
                   child: const Text('Salvar'),
                  onPressed: () async {
                    if (formKeyDialog.currentState!.validate()) {
                        try {
                          final dadosUpdate = { /* ... dados para update ... */ };
                          await FirebaseFirestore.instance.collection('chamados').doc(widget.chamadoId).update(dadosUpdate);
                           if (mounted) { Navigator.of(dialogContext).pop(); /* ... SnackBar sucesso ... */ }
                        } catch (error) {
                           print("Erro ao atualizar chamado: $error");
                            if (mounted) { Navigator.of(dialogContext).pop(); /* ... SnackBar erro ... */ }
                        }
                    }
                  },
                ),
              ],
            );
          }
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes do Chamado'),
        actions: [ // Botão Editar (mantido)
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('chamados').doc(widget.chamadoId).snapshots(),
            builder: (context, snapshot) {
               if (snapshot.hasData && snapshot.data!.exists) {
                 final currentData = snapshot.data!.data()! as Map<String, dynamic>;
                 return IconButton( icon: const Icon(Icons.edit_note), tooltip: 'Editar Status/Prioridade', onPressed: () => _mostrarDialogoEdicao(currentData), );
               }
               return const SizedBox.shrink();
            }
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('chamados').doc(widget.chamadoId).snapshots(),
        builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot> snapshot) {
          // Tratamento de erro e loading (mantido)
          if (snapshot.hasError) { return Center(child: Text('Erro: ${snapshot.error}')); }
          if (snapshot.connectionState == ConnectionState.waiting) { return const Center(child: CircularProgressIndicator()); }
          if (!snapshot.hasData || !snapshot.data!.exists) { return const Center(child: Text('Chamado não encontrado')); }

          // Extração de dados do chamado (mantido)
          final Map<String, dynamic> data = snapshot.data!.data()! as Map<String, dynamic>;
          final String titulo = data['titulo'] as String? ?? 'S/ Título';
          final String descricao = data['descricao'] as String? ?? 'S/ Descrição';
          final String categoria = data['categoria'] as String? ?? 'S/ Categoria';
          final String status = data['status'] as String? ?? 'S/ Status';
          final String prioridade = data['prioridade'] as String? ?? 'S/ Prioridade';
          final String criadorNome = data['creatorName'] as String? ?? 'Desconhecido';
          final String equipamento = data['equipamento'] as String? ?? 'N/I';
          final String departamento = data['departamento'] as String? ?? 'N/I';
          final String? creatorUid = data['creatorUid'] as String?; // <<< Pega o UID do criador

          // Datas (mantido)
           final Timestamp? dataCriacaoTimestamp = data['data_criacao'] is Timestamp ? data['data_criacao'] as Timestamp : null;
           final String dataCriacaoFormatada = dataCriacaoTimestamp != null ? DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(dataCriacaoTimestamp.toDate()) : 'N/I';
           final Timestamp? dataAtualizacaoTimestamp = data['data_atualizacao'] is Timestamp ? data['data_atualizacao'] as Timestamp : null;
           final String dataAtualizacaoFormatada = dataAtualizacaoTimestamp != null ? DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(dataAtualizacaoTimestamp.toDate()) : '--';

          // --- Layout para exibir os detalhes ---
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: <Widget>[
              _buildDetailItem(context, 'Título', titulo),
              _buildDetailItem(context, 'Descrição', descricao, isMultiline: true),
              const Divider(height: 20, thickness: 1),
              Row( children: [ Expanded(child: _buildDetailItem(context, 'Status', status)), Expanded(child: _buildDetailItem(context, 'Prioridade', prioridade)), ], ),
              Row( children: [ Expanded(child: _buildDetailItem(context, 'Categoria', categoria)), Expanded(child: _buildDetailItem(context, 'Departamento', departamento)), ], ),
              _buildDetailItem(context, 'Equipamento/Sistema', equipamento),
              const Divider(height: 20, thickness: 1),
              _buildDetailItem(context, 'Criado por', criadorNome),

              // --- Bloco para Buscar e Exibir Telefone ---
              if (creatorUid != null && creatorUid.isNotEmpty) // Verifica se temos um UID válido
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(creatorUid).get(), // Busca na coleção 'users'
                  builder: (context, snapshotUser) {
                    // Enquanto busca o telefone
                    if (snapshotUser.connectionState == ConnectionState.waiting) {
                      return _buildDetailItem(context, 'Telefone Criador', 'Carregando...');
                    }
                    // Se deu erro ou não encontrou o usuário/documento
                    if (snapshotUser.hasError || !snapshotUser.hasData || !snapshotUser.data!.exists) {
                      print("Erro ao buscar user $creatorUid: ${snapshotUser.error}"); // Log do erro
                      return _buildDetailItem(context, 'Telefone Criador', 'Não disponível');
                    }
                    // Se encontrou o documento do usuário
                    final userData = snapshotUser.data!.data() as Map<String, dynamic>;
                    // --- Use o nome EXATO do campo onde salvou o telefone ---
                    final String phone = userData['phone'] as String? ?? 'Não informado'; // <<< Pega o telefone
                    // ------------------------------------------------------
                    return _buildDetailItem(context, 'Telefone Criador', phone);
                  },
                )
              else
                _buildDetailItem(context, 'Telefone Criador', 'UID do criador não encontrado'), // Caso não tenha UID no chamado
              // -----------------------------------------

              _buildDetailItem(context, 'Criado em', dataCriacaoFormatada),
              _buildDetailItem(context, 'Última Atualização', dataAtualizacaoFormatada),
            ],
          );
        },
      ),
    );
  }

  // Widget auxiliar (mantido)
  Widget _buildDetailItem(BuildContext context, String label, String value, {bool isMultiline = false}) {
     // ... (código da função _buildDetailItem aqui, sem alterações) ...
     return Padding( /* ... */ );
  }
}
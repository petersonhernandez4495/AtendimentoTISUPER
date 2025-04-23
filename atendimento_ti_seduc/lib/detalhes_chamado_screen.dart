// lib/detalhes_chamado_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Para formatar datas

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

  // --- Função para mostrar diálogo de edição ---
  Future<void> _mostrarDialogoEdicao(Map<String, dynamic> dadosAtuais) async {
    String? statusSelecionado = dadosAtuais['status'] as String?;
    String? prioridadeSelecionada = dadosAtuais['prioridade'] as String?;
    final formKeyDialog = GlobalKey<FormState>(); // Chave para o formulário do diálogo

    // Garante que os valores iniciais existam nas listas, caso contrário, define como null
    if (statusSelecionado != null && !_listaStatus.contains(statusSelecionado)) {
      statusSelecionado = null;
    }
     if (prioridadeSelecionada != null && !_listaPrioridades.contains(prioridadeSelecionada)) {
      prioridadeSelecionada = null;
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // O usuário deve tocar em um botão para fechar
      builder: (BuildContext dialogContext) {
        return StatefulBuilder( // Permite atualizar o estado dentro do diálogo
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Editar Status e Prioridade'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKeyDialog,
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // Para o conteúdo ocupar o mínimo de espaço vertical
                    children: <Widget>[
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Status'),
                        value: statusSelecionado,
                        // CORREÇÃO 1: Mapear a lista para DropdownMenuItem<String>
                        items: _listaStatus.map<DropdownMenuItem<String>>((String status) {
                          return DropdownMenuItem<String>(
                            value: status,
                            child: Text(status),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setDialogState(() { // Atualiza o estado do diálogo
                            statusSelecionado = newValue;
                          });
                        },
                        validator: (value) => value == null ? 'Selecione um status' : null, // Validação
                      ),
                      const SizedBox(height: 16), // Espaçamento
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Prioridade'),
                        value: prioridadeSelecionada,
                         // CORREÇÃO 2: Mapear a lista para DropdownMenuItem<String>
                        items: _listaPrioridades.map<DropdownMenuItem<String>>((String prioridade) {
                          return DropdownMenuItem<String>(
                            value: prioridade,
                            child: Text(prioridade),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setDialogState(() { // Atualiza o estado do diálogo
                            prioridadeSelecionada = newValue;
                          });
                        },
                         validator: (value) => value == null ? 'Selecione uma prioridade' : null, // Validação
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancelar'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop(); // Fecha o diálogo
                  },
                ),
                ElevatedButton(
                  child: const Text('Salvar'),
                  onPressed: () async {
                    // Valida o formulário antes de salvar
                    if (formKeyDialog.currentState!.validate()) {
                      try {
                        // CORREÇÃO 3: Definir dadosUpdate com tipo correto e valores
                        final dadosUpdate = <String, Object?>{
                            'status': statusSelecionado,
                            'prioridade': prioridadeSelecionada,
                            'data_atualizacao': FieldValue.serverTimestamp(), // Atualiza a data/hora
                        };

                        // Atualiza o documento no Firestore
                        await FirebaseFirestore.instance
                            .collection('chamados')
                            .doc(widget.chamadoId)
                            .update(dadosUpdate); // Passa o mapa corrigido

                        if (mounted) { // Verifica se o widget ainda está na árvore
                           Navigator.of(dialogContext).pop(); // Fecha o diálogo
                           ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Chamado atualizado com sucesso!'), backgroundColor: Colors.green),
                           );
                        }
                      } catch (error) {
                         print("Erro ao atualizar chamado: $error");
                          if (mounted) { // Verifica se o widget ainda está na árvore
                            Navigator.of(dialogContext).pop(); // Fecha o diálogo
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Erro ao atualizar chamado: $error'), backgroundColor: Colors.red),
                           );
                         }
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


  // --- Construção da Tela Principal ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes do Chamado'),
        actions: [ // Botão Editar na AppBar
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('chamados').doc(widget.chamadoId).snapshots(),
            builder: (context, snapshot) {
              // Mostra o botão editar apenas se os dados existirem
              if (snapshot.hasData && snapshot.data!.exists) {
                // Pega os dados atuais para passar ao diálogo
                final currentData = snapshot.data!.data()! as Map<String, dynamic>;
                return IconButton(
                  icon: const Icon(Icons.edit_note),
                  tooltip: 'Editar Status/Prioridade',
                  onPressed: () => _mostrarDialogoEdicao(currentData), // Chama o diálogo
                );
              }
              // Se não houver dados (ou durante o carregamento), não mostra nada
              return const SizedBox.shrink();
            }
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('chamados').doc(widget.chamadoId).snapshots(),
        builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot> snapshot) {
          // Tratamento de erro
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }
          // Indicador de carregamento
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // Se o documento não existe
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Chamado não encontrado'));
          }

          // Extração segura dos dados do chamado
          final Map<String, dynamic> data = snapshot.data!.data()! as Map<String, dynamic>;
          final String titulo = data['titulo'] as String? ?? 'S/ Título';
          final String descricao = data['descricao'] as String? ?? 'S/ Descrição';
          final String categoria = data['categoria'] as String? ?? 'S/ Categoria';
          final String status = data['status'] as String? ?? 'S/ Status';
          final String prioridade = data['prioridade'] as String? ?? 'S/ Prioridade';
          final String criadorNome = data['creatorName'] as String? ?? 'Desconhecido';
          final String equipamento = data['equipamento'] as String? ?? 'N/I';
          final String departamento = data['departamento'] as String? ?? 'N/I';
          final String? creatorUid = data['creatorUid'] as String?; // UID do criador

          // Formatação de Datas
          final Timestamp? dataCriacaoTimestamp = data['data_criacao'] is Timestamp ? data['data_criacao'] as Timestamp : null;
          final String dataCriacaoFormatada = dataCriacaoTimestamp != null
              ? DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(dataCriacaoTimestamp.toDate())
              : 'N/I';

          final Timestamp? dataAtualizacaoTimestamp = data['data_atualizacao'] is Timestamp ? data['data_atualizacao'] as Timestamp : null;
          final String dataAtualizacaoFormatada = dataAtualizacaoTimestamp != null
              ? DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(dataAtualizacaoTimestamp.toDate())
              : '--'; // Se não houver atualização, mostra '--'

          // Layout para exibir os detalhes em uma lista rolável
          return ListView(
            padding: const EdgeInsets.all(16.0), // Padding geral da lista
            children: <Widget>[
              _buildDetailItem(context, 'Título', titulo),
              _buildDetailItem(context, 'Descrição', descricao, isMultiline: true),
              const Divider(height: 30, thickness: 1), // Divisor visual

              // Linha para Status e Prioridade
              Row(
                children: [
                  Expanded(child: _buildDetailItem(context, 'Status', status)),
                  Expanded(child: _buildDetailItem(context, 'Prioridade', prioridade)),
                ],
              ),
              // Linha para Categoria e Departamento
              Row(
                children: [
                  Expanded(child: _buildDetailItem(context, 'Categoria', categoria)),
                  Expanded(child: _buildDetailItem(context, 'Departamento', departamento)),
                ],
              ),
              _buildDetailItem(context, 'Equipamento/Sistema', equipamento),
              const Divider(height: 30, thickness: 1), // Divisor visual

              _buildDetailItem(context, 'Criado por', criadorNome),

              // --- Bloco para Buscar e Exibir Telefone do Criador ---
              if (creatorUid != null && creatorUid.isNotEmpty) // Só busca se tiver UID
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(creatorUid).get(), // Busca na coleção 'users'
                  builder: (context, snapshotUser) {
                    // Enquanto busca o telefone
                    if (snapshotUser.connectionState == ConnectionState.waiting) {
                      return _buildDetailItem(context, 'Telefone Criador', 'Carregando...');
                    }
                    // Se deu erro ou não encontrou o usuário/documento
                    if (snapshotUser.hasError || !snapshotUser.hasData || !snapshotUser.data!.exists) {
                      print("Erro ao buscar user $creatorUid: ${snapshotUser.error}"); // Log para debug
                      return _buildDetailItem(context, 'Telefone Criador', 'Não disponível');
                    }
                    // Se encontrou o documento do usuário
                    final userData = snapshotUser.data!.data() as Map<String, dynamic>;
                    // Pega o telefone (use o nome EXATO do campo no Firestore)
                    final String phone = userData['phone'] as String? ?? 'Não informado'; // Ajuste 'phone' se necessário
                    return _buildDetailItem(context, 'Telefone Criador', phone);
                  },
                )
              else
                 _buildDetailItem(context, 'Telefone Criador', 'UID não encontrado'), // Caso não tenha UID no chamado
              // ---------------------------------------------------------

              _buildDetailItem(context, 'Criado em', dataCriacaoFormatada),
              _buildDetailItem(context, 'Última Atualização', dataAtualizacaoFormatada),
            ],
          );
        },
      ),
    );
  }

  // --- Widget auxiliar para criar itens de detalhe ---
  // CORREÇÃO 4: Implementação completa com Padding obrigatório
  Widget _buildDetailItem(BuildContext context, String label, String value, {bool isMultiline = false}) {
    return Padding(
      // Adiciona o padding obrigatório aqui:
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0), // Padding vertical e um pouco horizontal
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // Alinha no topo
        children: <Widget>[
          SizedBox(
            width: 130, // Largura fixa para o rótulo (ajuste conforme necessário)
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold), // Texto do rótulo em negrito
            ),
          ),
          const SizedBox(width: 10), // Espaçamento entre rótulo e valor
          Expanded( // O valor ocupa o espaço restante
            child: SelectableText( // Permite copiar o valor
              value,
              style: Theme.of(context).textTheme.bodyMedium, // Estilo padrão para o valor
              //textAlign: isMultiline ? TextAlign.justify : TextAlign.start, // Opcional: Justificar texto multilinha
            ),
          ),
        ],
      ),
    );
  }
}
// lib/lista_chamados_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Certifique-se que está importado
import 'detalhes_chamado_screen.dart';
import 'novo_chamado_screen.dart';
import 'package:intl/date_symbol_data_local.dart';

class ListaChamadosScreen extends StatelessWidget {
  const ListaChamadosScreen({super.key});

  // --- Função helper para obter a cor baseada na prioridade ---
  Color? _getCorPrioridade(String prioridade) {
    switch (prioridade.toLowerCase()) { // Usar toLowerCase para ser flexível
      case 'urgente':
        return Colors.red[100];
      case 'alta':
        return Colors.orange[100];
      case 'média':
      case 'media':
        return Colors.yellow[100];
      case 'baixa':
        return Colors.blue[50];
      default:
        return null; // Cor padrão do Card
    }
  }

  Future<void> _excluirChamado(BuildContext context, String chamadoId) async {
    // (Código do diálogo de confirmação e exclusão - está correto)
    bool confirmarExclusao = await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirmar Exclusão'),
              content: const Text(
                  'Tem certeza de que deseja excluir este chamado? Esta ação não pode ser desfeita.'),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancelar'),
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                ),
                TextButton(
                  child: const Text('Excluir', style: TextStyle(color: Colors.red)),
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                ),
              ],
            );
          },
        ) ?? false;

    if (!confirmarExclusao) {
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('chamados')
          .doc(chamadoId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chamado excluído com sucesso!')),
      );
    } catch (error) {
      print('Erro ao excluir chamado: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Erro ao excluir o chamado. Tente novamente.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de Chamados'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chamados')
            .orderBy('data_criacao', descending: true)
            .snapshots(),
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          // (Tratamento de erro, loading, lista vazia - está correto)
          if (snapshot.hasError) {
            print('Erro no StreamBuilder: ${snapshot.error}'); // Log mais detalhado
            return const Center(
                child: Text('Algo deu errado ao carregar os chamados'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Nenhum chamado aberto ainda.'));
          }

          // --- Construção da Lista ---
          return ListView(
            children: snapshot.data!.docs.map((DocumentSnapshot document) {
              final Map<String, dynamic> data =
                  document.data()! as Map<String, dynamic>;

              // Extração de dados (mantida)
              final String titulo = data['titulo'] as String? ?? 'Sem Título';
              final String categoria = data['categoria'] as String? ?? 'Sem Categoria';
              final String status = data['status'] as String? ?? 'Desconhecido';
              final String departamento = data['departamento'] as String? ?? 'Sem Departamento';
              final String equipamento = data['equipamento'] as String? ?? 'Sem Equipamento';
              final String prioridade = data['prioridade'] as String? ?? 'Sem Prioridade';

              // --- Tratamento mais seguro para data_criacao ---
              final Timestamp? dataCriacaoTimestamp = data['data_criacao'] is Timestamp
                  ? data['data_criacao'] as Timestamp
                  : null;
              final String dataFormatada;
              if (dataCriacaoTimestamp != null) {
                final DateTime dataCriacao = dataCriacaoTimestamp.toDate();
                // Aplica formatação com locale pt_BR (requer init no main.dart)
                dataFormatada = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(dataCriacao);
              } else {
                dataFormatada = 'Data indisponível'; // Fallback se data for nula/inválida
              }
              // ---------------------------------------------

              // --- Obter a cor baseada na prioridade ---
              final Color? corDoCard = _getCorPrioridade(prioridade);
              // -----------------------------------------

              return Card(
                // --- Propriedades do Card atualizadas ---
                margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                elevation: 3,
                color: corDoCard, // Aplica a cor dinâmica
                // ---------------------------------------
                child: ListTile(
                  title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)), // Título em negrito
                  subtitle: Padding( // Padding para organizar subtítulo
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Reordenado para melhor leitura
                        Text('Prioridade: $prioridade'),
                        Text('Status: $status'),
                        Text('Categoria: $categoria'),
                        Text('Departamento: $departamento'),
                        // Text('Equipamento: $equipamento'), // Descomente se quiser mostrar
                        Text('Criado em: $dataFormatada'),
                      ],
                    ),
                  ),
                  trailing: IconButton( // Botão excluir (está correto)
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: 'Excluir Chamado',
                    onPressed: () {
                      _excluirChamado(context, document.id);
                    },
                  ),
                  onTap: () { // Navegação para detalhes (está correto)
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            DetalhesChamadoScreen(chamadoId: document.id),
                      ),
                    );
                  },
                ),
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton( // Botão adicionar (está correto)
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NovoChamadoScreen()), // Se NovoChamadoScreen foi adaptada para edição, remova 'const'
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
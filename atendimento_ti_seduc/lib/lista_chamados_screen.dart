// lib/lista_chamados_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'detalhes_chamado_screen.dart';
import 'novo_chamado_screen.dart';

class ListaChamadosScreen extends StatelessWidget {
  const ListaChamadosScreen({super.key});

   Future<void> _excluirChamado(BuildContext context, String chamadoId) async {
    // Exibe um diálogo de confirmação antes de excluir
    bool confirmarExclusao = await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirmar Exclusão'),
              content: const Text('Tem certeza de que deseja excluir este chamado? Esta ação não pode ser desfeita.'),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancelar'),
                  onPressed: () {
                    Navigator.of(context).pop(false); // Retorna false para não excluir
                  },
                ),
                TextButton(
                  child: const Text('Excluir', style: TextStyle(color: Colors.red)),
                  onPressed: () {
                     Navigator.of(context).pop(true); // Retorna true para confirmar a exclusão
                  },
                ),
              ],
            );
          },
        ) ?? false; // Garante que se o diálogo for fechado sem clicar, retorne false

    if (!confirmarExclusao) {
      return; // Não faz nada se o usuário cancelou
    }

    try {
      await FirebaseFirestore.instance.collection('chamados').doc(chamadoId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chamado excluído com sucesso!')),
      );
    } catch (error) {
      print('Erro ao excluir chamado: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao excluir o chamado. Tente novamente.')),
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
        stream: FirebaseFirestore.instance.collection('chamados').orderBy('data_criacao', descending: true).snapshots(),
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Algo deu errado ao carregar os chamados'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Nenhum chamado aberto ainda.'));
          }

          return ListView(
            children: snapshot.data!.docs.map((DocumentSnapshot document) {
              final Map<String, dynamic> data = document.data()! as Map<String, dynamic>;
              final String titulo = data['titulo'] as String? ?? 'Sem Título';
              final String categoria = data['categoria'] as String? ?? 'Sem Categoria';
              final String status = data['status'] as String? ?? 'Desconhecido';
              final Timestamp dataCriacaoTimestamp = data['data_criacao'] as Timestamp;
              final DateTime dataCriacao = dataCriacaoTimestamp.toDate();
              final String dataFormatada = DateFormat('dd/MM/yyyy HH:mm').format(dataCriacao);
              final String departamento = data['departamento'] as String? ?? 'Sem Departamento';
              final String equipamento = data['equipamento'] as String? ?? 'Sem Equipamento';
              final String prioridade = data['prioridade'] as String? ?? 'Sem Prioridade';

              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  title: Text(titulo),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Categoria: $categoria'),
                      Text('Departamento: $departamento'),
                      Text('Equipamento: $equipamento'),
                      Text('Prioridade: $prioridade'),
                      Text('Status: $status'),
                      Text('Criado em: $dataFormatada'),
                    ],
                  ),
                  // --- ADICIONAR O BOTÃO DE EXCLUSÃO AQUI ---
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: 'Excluir Chamado', // Boa prática para acessibilidade
                    onPressed: () {
                      // Chama a função de exclusão passando o ID do documento
                      _excluirChamado(context, document.id);
                    },
                  ),
                  // -------------------------------------------
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DetalhesChamadoScreen(chamadoId: document.id),
                      ),
                    );
                  },
                ),
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NovoChamadoScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
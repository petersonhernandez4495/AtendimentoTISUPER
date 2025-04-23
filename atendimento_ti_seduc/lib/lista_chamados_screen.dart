// lib/lista_chamados_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'detalhes_chamado_screen.dart';
import 'novo_chamado_screen.dart';

class ListaChamadosScreen extends StatelessWidget {
  const ListaChamadosScreen({super.key});

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
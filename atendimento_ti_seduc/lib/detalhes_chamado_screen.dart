// lib/detalhes_chamado_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore_desktop/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Para formatar a data

class DetalhesChamadoScreen extends StatelessWidget {
  final String chamadoId;

  const DetalhesChamadoScreen({super.key, required this.chamadoId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes do Chamado'),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('chamados').doc(chamadoId).get(),
        builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot> snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Algo deu errado ao carregar os detalhes: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Chamado não encontrado'));
          }

          final Map<String, dynamic> data = snapshot.data!.data()! as Map<String, dynamic>;
          final String titulo = data['titulo'] as String? ?? 'Sem Título';
          final String descricao = data['descricao'] as String? ?? 'Sem Descrição';
          final String urgencia = data['urgencia'] as String? ?? 'Não especificada';
          final String categoria = data['categoria'] as String? ?? 'Não especificada';
          final String status = data['status'] as String? ?? 'Desconhecido';
          final Timestamp dataCriacaoTimestamp = data['data_criacao'] as Timestamp;
          final DateTime dataCriacao = dataCriacaoTimestamp.toDate();
          final String dataFormatada = DateFormat('dd/MM/yyyy HH:mm:ss').format(dataCriacao);

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Título:', style: Theme.of(context).textTheme.titleMedium),
                Text(titulo, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 16.0),
                Text('Descrição:', style: Theme.of(context).textTheme.titleMedium),
                Text(descricao, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 16.0),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Urgência:', style: Theme.of(context).textTheme.titleSmall),
                          Text(urgencia, style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Categoria:', style: Theme.of(context).textTheme.titleSmall),
                          Text(categoria, style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16.0),
                Text('Status:', style: Theme.of(context).textTheme.titleSmall),
                Text(status, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 16.0),
                Text('Criado em:', style: Theme.of(context).textTheme.titleSmall),
                Text(dataFormatada, style: Theme.of(context).textTheme.bodyMedium),
                // Adicione mais informações conforme necessário
              ],
            ),
          );
        },
      ),
    );
  }
}
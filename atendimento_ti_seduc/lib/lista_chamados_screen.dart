// lib/lista_chamados_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'detalhes_chamado_screen.dart';
import 'novo_chamado_screen.dart';
import 'login_screen.dart'; // Para o logout no (removido) drawer

//FirebaseAuth pode não ser mais necessário aqui se o drawer foi removido
// import 'package:firebase_auth/firebase_auth.dart';

class ListaChamadosScreen extends StatelessWidget {
  // Adicionando construtor const
  const ListaChamadosScreen({super.key});

  // Função helper para cor (mantida)
  Color? _getCorPrioridade(String prioridade) {
     switch (prioridade.toLowerCase()) {
      case 'urgente':
      case 'crítica':
        return Colors.red[100];
      case 'alta':
        return Colors.orange[100];
      case 'média':
      case 'media':
        return Colors.yellow[100];
      case 'baixa':
        return Colors.blue[50];
      default:
        return null;
    }
  }

  // Função de exclusão (mantida)
  Future<void> _excluirChamado(BuildContext context, String chamadoId) async {
    bool confirmarExclusao = await showDialog(
        context: context,
        builder: (BuildContext context) { /* ... diálogo de confirmação ... */
            return AlertDialog(
              title: const Text('Confirmar Exclusão'),
              content: const Text(
                  'Tem certeza de que deseja excluir este chamado? Esta ação não pode ser desfeita.'),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancelar'),
                  onPressed: () { Navigator.of(context).pop(false); },
                ),
                TextButton(
                  child: const Text('Excluir', style: TextStyle(color: Colors.red)),
                  onPressed: () { Navigator.of(context).pop(true); },
                ),
              ],
            );
        }
      ) ?? false;

    if (!confirmarExclusao) return;

    try {
      await FirebaseFirestore.instance.collection('chamados').doc(chamadoId).delete();
      // Verifica se o widget ainda está montado antes de usar o context
       if (ScaffoldMessenger.of(context).mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Chamado excluído com sucesso!')),
         );
       }
    } catch (error) {
      print('Erro ao excluir chamado: $error');
       if (ScaffoldMessenger.of(context).mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar( content: Text('Erro ao excluir o chamado. Tente novamente.')),
         );
       }
    }
  }

  // Função de logout removida daqui (foi movida para ProfileScreen no exemplo anterior)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar sem botão de voltar/menu automático
      appBar: AppBar(
        title: const Text('Lista de Chamados'),
        automaticallyImplyLeading: false, // Remove o botão de voltar/menu
      ),
      // Drawer foi removido para usar BottomNavigationBar na tela principal
      // drawer: Drawer( ... ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chamados')
            .orderBy('data_criacao', descending: true)
            .snapshots(),
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          // Tratamento de erro, loading, lista vazia (mantido)
          if (snapshot.hasError) { /* ... */ return const Center(child: Text('Algo deu errado...'));}
          if (snapshot.connectionState == ConnectionState.waiting) { /* ... */ return const Center(child: CircularProgressIndicator());}
          if (snapshot.data!.docs.isEmpty) { /* ... */ return const Center(child: Text('Nenhum chamado...'));}

          // --- GridView.builder ---
          return GridView.builder(
            padding: const EdgeInsets.all(8.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8.0,
              mainAxisSpacing: 8.0,
              childAspectRatio: (1 / 0.5), // <-- AJUSTE CONFORME NECESSÁRIO
            ),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (BuildContext context, int index) {
              final DocumentSnapshot document = snapshot.data!.docs[index];
              final Map<String, dynamic> data = document.data()! as Map<String, dynamic>;

              // Extração de dados
              final String titulo = data['titulo'] as String? ?? 'S/ Título';
              final String prioridade = data['prioridade'] as String? ?? 'S/P';
              final String status = data['status'] as String? ?? 'S/S';
              // --- Extrair nome do criador ---
              final String creatorName = data['creatorName'] as String? ?? 'Anônimo'; // <--- NOVO
              // --------------------------------
              final Timestamp? dataCriacaoTimestamp = data['data_criacao'] is Timestamp
                  ? data['data_criacao'] as Timestamp : null;
              final String dataFormatada = dataCriacaoTimestamp != null
                  ? DateFormat('dd/MM', 'pt_BR').format(dataCriacaoTimestamp.toDate())
                  : '--/--';
              final Color? corDoCard = _getCorPrioridade(prioridade);

              // --- Card Menor para o Grid (com nome do criador) ---
              return Card(
                color: corDoCard,
                elevation: 2,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () { /* Navegação para detalhes */
                     Navigator.push( context, MaterialPageRoute( builder: (context) => DetalhesChamadoScreen(chamadoId: document.id),),);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0), // Padding ajustado
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Linha superior: Título e Botão Excluir
                        Row( /* ... Título e Ícone Excluir ... */
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Expanded(
                               child: Text( titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14,), maxLines: 2, overflow: TextOverflow.ellipsis, ), // Fonte ajustada
                             ),
                             InkWell(
                                onTap: () => _excluirChamado(context, document.id),
                                child: const Padding( padding: EdgeInsets.only(left: 4.0), child: Icon(Icons.delete_outline, color: Colors.redAccent, size: 19),)
                             )
                           ],
                        ),
                        const Spacer(), // Empurra para baixo
                        // Informações inferiores
                        Text('Prior: $prioridade', style: const TextStyle(fontSize: 23)), // Fonte ajustada
                        const SizedBox(height: 2),
                        Text('Status: $status', style: const TextStyle(fontSize: 23)), // Fonte ajustada
                        const SizedBox(height: 2),
                        // --- Exibir nome do criador ---
                        Text(
                          'Por: $creatorName',
                          style: TextStyle(fontSize: 23, fontStyle: FontStyle.italic, color: Colors.grey[800]), // Fonte ajustada
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // ------------------------------
                        const SizedBox(height: 2),
                        Text( dataFormatada, style: TextStyle(fontSize: 23, color: Colors.grey[700]),), // Fonte ajustada
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton( // Botão Adicionar (mantido)
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NovoChamadoScreen()),
          );
        },
        tooltip: 'Abrir Novo Chamado',
        child: const Icon(Icons.add),
      ),
    );
  }
}
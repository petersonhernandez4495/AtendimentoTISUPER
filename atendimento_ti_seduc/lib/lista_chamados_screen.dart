// lib/lista_chamados_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'detalhes_chamado_screen.dart';
import 'novo_chamado_screen.dart';

class ListaChamadosScreen extends StatelessWidget {
  const ListaChamadosScreen({super.key});

  // Função helper para cor de PRIORIDADE (Fundo do Card)
  Color? _getCorPrioridade(String prioridade) {
    switch (prioridade.toLowerCase()) {
      case 'urgente': case 'crítica': return Colors.red[100];
      case 'alta': return Colors.orange[100];
      case 'média': case 'media': return Colors.yellow[100];
      case 'baixa': return Colors.blue[50];
      default: return null;
    }
  }

  // Função helper para cor de STATUS (Barra Vertical)
  Color? _getCorStatus(String status) {
    switch (status.toLowerCase()) {
      case 'aberto': return Colors.blue[700];
      case 'em andamento': return Colors.orange[700];
      case 'pendente': return Colors.deepPurple[500];
      case 'resolvido': return Colors.green[700];
      case 'fechado': return Colors.grey[800];
      default: return Colors.grey[500];
    }
  }

  // Função de exclusão
  Future<void> _excluirChamado(BuildContext context, String chamadoId) async {
    bool confirmarExclusao = await showDialog( context: context, builder: (BuildContext context) { return AlertDialog( title: const Text('Confirmar Exclusão'), content: const Text( 'Tem certeza de que deseja excluir este chamado? Esta ação não pode ser desfeita.'), actions: <Widget>[ TextButton( child: const Text('Cancelar'), onPressed: () { Navigator.of(context).pop(false); }, ), TextButton( child: const Text('Excluir', style: TextStyle(color: Colors.red)), onPressed: () { Navigator.of(context).pop(true); }, ), ], ); } ) ?? false;
    if (!confirmarExclusao) return;
    try {
      await FirebaseFirestore.instance.collection('chamados').doc(chamadoId).delete();
       if (ScaffoldMessenger.of(context).mounted) { ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Chamado excluído com sucesso!')), ); }
    } catch (error) {
      print('Erro ao excluir chamado: $error');
       if (ScaffoldMessenger.of(context).mounted) { ScaffoldMessenger.of(context).showSnackBar( const SnackBar( content: Text('Erro ao excluir o chamado. Tente novamente.')), ); }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Se esta tela for usada dentro da MainNavigationScreen, o Scaffold/AppBar não são necessários aqui.
    // Mas mantendo por enquanto, caso contrário, remova Scaffold e AppBar.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de Chamados'),
        automaticallyImplyLeading: false, // Remove botão voltar/menu
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chamados')
            .orderBy('data_criacao', descending: true)
            .snapshots(),
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.hasError) { return const Center(child: Text('Algo deu errado...'));}
          if (snapshot.connectionState == ConnectionState.waiting) { return const Center(child: CircularProgressIndicator());}
          if (snapshot.data!.docs.isEmpty) { return const Center(child: Text('Nenhum chamado aberto.'));}

          return GridView.builder(
            padding: const EdgeInsets.all(10.0), // Aumentei um pouco o padding geral
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, // Mantém 3 colunas
              crossAxisSpacing: 10.0, // Aumentei espaçamento horizontal
              mainAxisSpacing: 10.0,  // Aumentei espaçamento vertical
              // --- childAspectRatio CORRIGIDO ---
              childAspectRatio: (1 / 0.6), // <<< CORRIGIDO: Torna o card mais alto (1 largura para 1.8 altura). AJUSTE SE NECESSÁRIO
              // ---------------------------------
            ),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (BuildContext context, int index) {
              final DocumentSnapshot document = snapshot.data!.docs[index];
              final Map<String, dynamic> data = document.data()! as Map<String, dynamic>;

              // Extração de dados
              final String titulo = data['titulo'] as String? ?? 'S/ Título';
              final String prioridade = data['prioridade'] as String? ?? 'S/P';
              final String status = data['status'] as String? ?? 'S/S';
              final String creatorName = data['creatorName'] as String? ?? 'Anônimo';
              final String creatorPhone = data['creatorPhone'] as String? ?? 'N/I'; // <<< Telefone lido
              final Timestamp? dataCriacaoTimestamp = data['data_criacao'] is Timestamp ? data['data_criacao'] as Timestamp : null;
              final String dataFormatada = dataCriacaoTimestamp != null ? DateFormat('dd/MM/yy', 'pt_BR').format(dataCriacaoTimestamp.toDate()) : '--/--'; // Formato dd/MM/yy
              final Color? corDeFundoCard = _getCorPrioridade(prioridade);
              final Color? corDaBarraStatus = _getCorStatus(status);

              // --- Card com Barra Vertical e Telefone ---
              return Card(
                color: corDeFundoCard,
                elevation: 2,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () { Navigator.push( context, MaterialPageRoute( builder: (context) => DetalhesChamadoScreen(chamadoId: document.id),),); },
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container( width: 6.0, color: corDaBarraStatus ?? Colors.transparent ), // Barra Status (largura 6)
                        const SizedBox(width: 6.0), // Espaçamento menor
                        Expanded( // Conteúdo Principal
                          child: Padding(
                             padding: const EdgeInsets.only(top: 5.0, right: 5.0, bottom: 5.0), // Padding interno menor
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // --- Título e Excluir ---
                                Row(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                     Expanded(
                                       child: Text(
                                         titulo,
                                         // --- Fontes REDUZIDAS ---
                                         style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 23), // Era 30
                                         maxLines: 2, overflow: TextOverflow.ellipsis,
                                        ),
                                     ),
                                     InkWell( onTap: () => _excluirChamado(context, document.id), child: const Padding( padding: EdgeInsets.only(left: 3.0), child: Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),)) // Ícone menor
                                   ],
                                ),
                                const Spacer(), // Empurra para baixo
                                // --- Informações Inferiores ---
                                Text('Prior: $prioridade', style: const TextStyle(fontSize: 23)), // Era 23/25
                                const SizedBox(height: 1),
                                Text('Status: $status', style: const TextStyle(fontSize: 23)), // Era 23/25
                                const SizedBox(height: 1),
                                Text( 'Por: $creatorName', style: TextStyle(fontSize: 23, fontStyle: FontStyle.italic, color: Colors.grey[800]), maxLines: 1, overflow: TextOverflow.ellipsis,), // Era 23/25
                                const SizedBox(height: 1),
                                // --- Linha do Telefone (RE-ADICIONADA) ---
                                Row(
                                  children: [
                                     Icon(Icons.phone_outlined, size: 23, color: Colors.grey[700]), // Ícone menor
                                     const SizedBox(width: 2),
                                     Expanded(
                                       child: Text(
                                         creatorPhone, // Exibe o telefone
                                         style: TextStyle(fontSize: 23, color: Colors.grey[800]), // Era 23
                                         maxLines: 1, overflow: TextOverflow.ellipsis,
                                       ),
                                     ),
                                  ],
                                ),
                                // ------------------------------------
                                const SizedBox(height: 1),
                                Text( dataFormatada, style: TextStyle(fontSize: 23, color: Colors.grey[700]),), // Era 27
                                // ------------------------------------
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () { Navigator.push( context, MaterialPageRoute(builder: (context) => const NovoChamadoScreen()), ); },
        tooltip: 'Abrir Novo Chamado',
        child: const Icon(Icons.add),
      ),
    );
  }
}
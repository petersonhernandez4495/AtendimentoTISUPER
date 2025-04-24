// lib/lista_chamados_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'detalhes_chamado_screen.dart';
// O import de NovoChamadoScreen não é necessário aqui

// --- RENOMEADO para indicar que é apenas o CONTEÚDO ---
class ListaChamadosScreen extends StatelessWidget {
  const ListaChamadosScreen({super.key});

  // --- Funções Helper (mantidas dentro da classe) ---
  Color? _getCorPrioridade(String prioridade) {
    switch (prioridade.toLowerCase()) {
      case 'urgente': case 'crítica': return Colors.red[100];
      case 'alta': return Colors.orange[100];
      case 'média': case 'media': return Colors.yellow[100];
      case 'baixa': return Colors.blue[50];
      default: return null;
    }
  }

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
  // -------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // --- REMOVIDO Scaffold e AppBar ---
    // Retorna diretamente o StreamBuilder
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chamados')
          .orderBy('data_criacao', descending: true)
          .snapshots(),
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
        // Tratamentos de erro/loading/vazio
        if (snapshot.hasError) { return const Center(child: Text('Algo deu errado...'));}
        if (snapshot.connectionState == ConnectionState.waiting) { return const Center(child: CircularProgressIndicator());}
        if (snapshot.data!.docs.isEmpty) { return const Center(child: Text('Nenhum chamado aberto.'));}

        // --- GridView com Delegate Responsivo e Layout Corrigido ---
        return GridView.builder(
          padding: const EdgeInsets.all(12.0), // Padding da grade
          // --- DELEGATE RESPONSIVO ---
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 250.0, 
            mainAxisSpacing: 12.0,
            crossAxisSpacing: 12.0,
            childAspectRatio: (1 / 0.6), // <<< Proporção L/A CORRIGIDA (Ajuste)
          ),
          // ---------------------------
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (BuildContext context, int index) {
            final DocumentSnapshot document = snapshot.data!.docs[index];
            final Map<String, dynamic> data = document.data()! as Map<String, dynamic>;

            // Extração de dados
            // !!! Verifique se a chave do título é 'titulo' ou 'Problema' no seu Firestore !!!
            final String titulo = data['titulo'] as String? ?? 'S/ Título'; // <<< Corrigido para 'titulo'
            final String prioridade = data['prioridade'] as String? ?? 'S/P';
            final String status = data['status'] as String? ?? 'S/S';
            final String creatorName = data['creatorName'] as String? ?? 'Anônimo';
            final String creatorPhone = data['creatorPhone'] as String? ?? 'N/I';
            final Timestamp? dataCriacaoTimestamp = data['data_criacao'] is Timestamp ? data['data_criacao'] as Timestamp : null;
            final String dataFormatada = dataCriacaoTimestamp != null ? DateFormat('dd/MM/yy', 'pt_BR').format(dataCriacaoTimestamp.toDate()) : '--';
            final Color? corDeFundoCard = _getCorPrioridade(prioridade);
            final Color? corDaBarraStatus = _getCorStatus(status);

            // --- Card com Barra e Fontes CORRIGIDAS ---
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
                      Container( width: 6.0, color: corDaBarraStatus ?? Colors.transparent ), // Barra Status
                      const SizedBox(width: 8.0),
                      Expanded( // Conteúdo Principal
                        child: Padding(
                           padding: const EdgeInsets.only(top: 6.0, right: 6.0, bottom: 6.0),
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
                                       style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), // <<< REDUZIDO
                                       maxLines: 3, // <<< Aumentei para 3 linhas (opcional)
                                       overflow: TextOverflow.ellipsis,
                                      ),
                                   ),
                                   InkWell( onTap: () => _excluirChamado(context, document.id), child: const Padding( padding: EdgeInsets.only(left: 3.0), child: Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),))
                                 ],
                              ),
                              const Spacer(), // Empurra para baixo
                              // --- Informações Inferiores ---
                              Text('Prior: $prioridade', style: const TextStyle(fontSize: 11)), // <<< REDUZIDO
                              const SizedBox(height: 1),
                              Text('Status: $status', style: const TextStyle(fontSize: 11)), // <<< REDUZIDO
                              const SizedBox(height: 1),
                              Text( 'Por: $creatorName', style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey[800]), maxLines: 1, overflow: TextOverflow.ellipsis,), // <<< REDUZIDO
                              const SizedBox(height: 1),
                              // --- Telefone ---
                              Row(
                                children: [
                                   Icon(Icons.phone_outlined, size: 10, color: Colors.grey[700]),
                                   const SizedBox(width: 2),
                                   Expanded(
                                     child: Text(
                                       creatorPhone,
                                       style: TextStyle(fontSize: 10, color: Colors.grey[800]), // <<< REDUZIDO
                                       maxLines: 1, overflow: TextOverflow.ellipsis,
                                     ),
                                   ),
                                ],
                              ),
                              // ----------------
                              const SizedBox(height: 1),
                              Text( dataFormatada, style: TextStyle(fontSize: 10, color: Colors.grey[700]),), // <<< REDUZIDO
                              // ------------------------------------
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ); // Fim do Card
          }, // Fim do itemBuilder
        ); // Fim do GridView.builder
      }, // Fim do builder do StreamBuilder
    ); // Fim do StreamBuilder
  } // Fim do build
} // Fim da classe
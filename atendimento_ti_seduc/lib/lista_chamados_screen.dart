// lib/lista_chamados_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'detalhes_chamado_screen.dart';
import 'novo_chamado_screen.dart';
// import 'login_screen.dart'; // Import não necessário aqui diretamente

class ListaChamadosScreen extends StatelessWidget {
  const ListaChamadosScreen({super.key});

  // --- Função helper para cor de PRIORIDADE (Fundo do Card) ---
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
        return null; // Cor padrão do tema
    }
  }

  // --- Função helper para cor de STATUS (Barra Vertical) ---
  // <<< MOVIDA PARA DENTRO DA CLASSE >>>
  Color? _getCorStatus(String status) {
    switch (status.toLowerCase()) {
      case 'aberto':
        return Colors.blue[700]; // Usando cores mais fortes para a barra
      case 'em andamento':
        return Colors.orange[700];
      case 'pendente':
        return Colors.deepPurple[500];
      case 'resolvido':
        return Colors.green[700];
      case 'fechado':
        return Colors.grey[800];
      default:
        return Colors.grey[500];
    }
  }
  // -------------------------------------------------------

  // --- Função de exclusão (mantida) ---
  Future<void> _excluirChamado(BuildContext context, String chamadoId) async {
    bool confirmarExclusao = await showDialog(
          context: context,
          builder: (BuildContext context) { /* ... diálogo ... */
             return AlertDialog( /* ... conteúdo diálogo ... */ );
          }
        ) ?? false;

    if (!confirmarExclusao) return;

    try {
      await FirebaseFirestore.instance.collection('chamados').doc(chamadoId).delete();
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
  // -------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de Chamados'),
        automaticallyImplyLeading: false, // Mantido: Remove botão voltar/menu
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chamados')
            .orderBy('data_criacao', descending: true)
            .snapshots(),
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          // Tratamentos de erro/loading/vazio (mantidos)
          if (snapshot.hasError) { return const Center(child: Text('Algo deu errado...'));}
          if (snapshot.connectionState == ConnectionState.waiting) { return const Center(child: CircularProgressIndicator());}
          if (snapshot.data!.docs.isEmpty) { return const Center(child: Text('Nenhum chamado...'));}

          // --- GridView.builder ---
          return GridView.builder(
            padding: const EdgeInsets.all(8.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8.0,
              mainAxisSpacing: 8.0,
              // --- childAspectRatio CORRIGIDO ---
              // Valor < 1.0 faz ser mais alto que largo. Ajuste se necessário.
              childAspectRatio: (1 / 0.6), // Ex: 1 de largura para 1.6 de altura
              // ----------------------------------
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
              final Timestamp? dataCriacaoTimestamp = data['data_criacao'] is Timestamp
                  ? data['data_criacao'] as Timestamp : null;
              final String dataFormatada = dataCriacaoTimestamp != null
                  ? DateFormat('dd/MM', 'pt_BR').format(dataCriacaoTimestamp.toDate())
                  : '--/--';

              // Obter cores
              final Color? corDeFundoCard = _getCorPrioridade(prioridade);
              final Color? corDaBarraStatus = _getCorStatus(status); // <<< Usa a função de status

              // --- Card com Barra Vertical de Status ---
              return Card(
                color: corDeFundoCard, // Cor de fundo (Prioridade)
                elevation: 2,
                clipBehavior: Clip.antiAlias, // Importante para a barra ficar contida
                child: InkWell(
                  onTap: () {
                     Navigator.push( context, MaterialPageRoute( builder: (context) => DetalhesChamadoScreen(chamadoId: document.id),),);
                  },
                  child: IntrinsicHeight( // <<< Adicionado
                    child: Row( // <<< Adicionado
                      crossAxisAlignment: CrossAxisAlignment.stretch, // <<< Adicionado
                      children: [
                        // --- Barra Vertical de Status ---
                        Container( // <<< Adicionado
                          width: 7.0, // Largura da barra
                          color: corDaBarraStatus ?? Colors.transparent, // Cor (Status)
                        ),
                        // ------------------------------
                        const SizedBox(width: 8.0), // Espaçamento
                        // --- Conteúdo Principal ---
                        Expanded( // <<< Adicionado
                          // Removido Padding externo, adicionado padding interno
                          child: Padding( // <<< Padding movido para cá
                             padding: const EdgeInsets.only(top: 6.0, right: 6.0, bottom: 6.0), // Sem padding esquerdo aqui
                            child: Column( // Coluna original do conteúdo
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Linha Título e Excluir
                                Row(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                     Expanded(
                                       child: Text(
                                         titulo,
                                         // --- Fontes (Ajuste se quiser maiores/menores) ---
                                         style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                         maxLines: 2, overflow: TextOverflow.ellipsis,
                                        ),
                                     ),
                                     InkWell( onTap: () => _excluirChamado(context, document.id), child: const Padding( padding: EdgeInsets.only(left: 4.0), child: Icon(Icons.delete_outline, color: Colors.redAccent, size: 19),))
                                   ],
                                ),
                                const Spacer(), // Empurra para baixo
                                // Textos inferiores
                                Text('Prior: $prioridade', style: const TextStyle(fontSize: 25)),
                                const SizedBox(height: 2),
                                Text('Status: $status', style: const TextStyle(fontSize: 25)),
                                const SizedBox(height: 2),
                                Text( 'Por: $creatorName', style: TextStyle(fontSize: 25, fontStyle: FontStyle.italic, color: Colors.grey[800]), maxLines: 1, overflow: TextOverflow.ellipsis,),
                                const SizedBox(height: 2),
                                Text( dataFormatada, style: TextStyle(fontSize: 25, color: Colors.grey[700]),),
                                // ---------------------------------------------------
                              ],
                            ),
                          ),
                        ),
                        // --------------------------
                      ],
                    ),
                  ),
                ),
              );
              // --------------------------------------
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
} // Fim da classe ListaChamadosScreen
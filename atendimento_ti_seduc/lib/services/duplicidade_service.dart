// lib/services/duplicidade_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

// Importe suas constantes, se necessário
import '../novo_chamado_screen.dart'; // Temporário para constantes

class DuplicidadeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Verifica se existe um chamado ativo (aberto ou em andamento)
  /// para o mesmo patrimônio e com o mesmo problema relatado.
  ///
  /// Retorna o ID do chamado duplicado se encontrado, caso contrário null.
  Future<String?> verificarDuplicidade({
    required String patrimonio,
    required String problemaSelecionado, // O valor do dropdown ('TELA AZUL', 'OUTRO', etc)
    required String problemaOutroDescricao, // O texto do campo 'Descreva o problema'
  }) async {
    if (patrimonio.isEmpty) {
      print("Verificação de duplicidade pulada: Patrimônio vazio.");
      return null; // Não podemos verificar sem patrimônio
    }

    // Determina qual o problema real a ser buscado
    final String problemaBusca = (problemaSelecionado == "OUTRO")
        ? problemaOutroDescricao.trim()
        : problemaSelecionado;

    if (problemaBusca.isEmpty) {
      print("Verificação de duplicidade pulada: Problema não especificado.");
      return null; // Não podemos verificar sem o problema
    }

    print("Verificando duplicidade para Patrimônio: '$patrimonio', Problema: '$problemaBusca'");

    try {
      // Query baseada no patrimônio e status ativo
       Query query = _db.collection(kCollectionChamados)
          .where('numero_patrimonio', isEqualTo: patrimonio)
          .where('status', whereIn: ['aberto', 'em_andamento']);

      // Adiciona o filtro de problema (precisa checar os dois campos possíveis)
      // Usando Filter.or para combinar as condições
      query = query.where(Filter.or(
          Filter('problema_ocorre', isEqualTo: problemaBusca),
          Filter(kFieldProblemaOutro, isEqualTo: problemaBusca) // Usa a constante
      ));

      final QuerySnapshot snapshot = await query.limit(1).get();

      if (snapshot.docs.isNotEmpty) {
        final duplicateId = snapshot.docs.first.id;
        print("DUPLICIDADE ENCONTRADA: Chamado ID $duplicateId");
        return duplicateId;
      } else {
        print("Nenhuma duplicidade encontrada.");
        return null;
      }
    } catch (e, s) {
      print('Erro ao verificar duplicidade no Firestore: $e');
      print(s);
      // Em caso de erro na consulta, optamos por permitir a criação
      // para não bloquear o usuário, mas logamos o erro.
      // Poderia lançar exceção se a verificação for crítica.
      return null;
    }
  }
}
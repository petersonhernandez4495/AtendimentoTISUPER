// lib/services/duplicidade_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chamado_service.dart'; // Importa as constantes

class DuplicidadeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<String?> verificarDuplicidade({
    required String patrimonio,
    String? problemaSelecionado,
    String? problemaOutroDescricao,
    String? equipamentoSelecionado, // <<< NOVO PARÂMETRO
    String? equipamentoOutroDescricao, // <<< NOVO PARÂMETRO
  }) async {
    if (patrimonio.trim().isEmpty) {
      print("DEBUG (Duplicidade): Verificação pulada - Patrimônio vazio.");
      return null;
    }

    // Determina o problema final para busca
    String problemaBusca;
    if (problemaSelecionado == "OUTRO") {
      problemaBusca = problemaOutroDescricao?.trim() ?? "";
    } else {
      problemaBusca = problemaSelecionado?.trim() ?? "";
    }

    if (problemaBusca.isEmpty) {
      print(
          "DEBUG (Duplicidade): Verificação pulada - Problema final para busca está vazio.");
      return null;
    }

    // Determina o equipamento final para busca
    String equipamentoBusca;
    if (equipamentoSelecionado == "OUTRO") {
      equipamentoBusca = equipamentoOutroDescricao?.trim() ?? "";
    } else {
      equipamentoBusca = equipamentoSelecionado?.trim() ?? "";
    }

    if (equipamentoBusca.isEmpty) {
      print(
          "DEBUG (Duplicidade): Verificação pulada - Equipamento final para busca está vazio.");
      return null; // Não verifica sem equipamento se ele for um critério
    }

    print(
        "DEBUG (Duplicidade): Verificando para Patrimônio: '$patrimonio', Problema: '$problemaBusca', Equipamento: '$equipamentoBusca'");

    final List<String> statusAtivosParaDuplicidade = [
      kStatusAberto,
      kStatusEmAndamento,
      kStatusPendente,
      kStatusAguardandoAprovacao,
      kStatusAguardandoPeca,
      kStatusAguardandoEquipamento,
      kStatusAtribuidoGSIOR,
      kStatusGarantiaFabricante,
    ];
    print(
        "DEBUG (Duplicidade): Status ativos para verificação: $statusAtivosParaDuplicidade");

    try {
      Query query = _db
          .collection(kCollectionChamados)
          .where(kFieldPatrimonio, isEqualTo: patrimonio.trim())
          .where(kFieldStatus, whereIn: statusAtivosParaDuplicidade);

      // Filtro para o problema
      if (problemaSelecionado == "OUTRO") {
        print(
            "DEBUG (Duplicidade): Querying for $kFieldProblemaOutro == '$problemaBusca'");
        query = query.where(kFieldProblemaOutro, isEqualTo: problemaBusca);
      } else {
        print(
            "DEBUG (Duplicidade): Querying for $kFieldProblemaOcorre == '$problemaBusca'");
        query = query.where(kFieldProblemaOcorre, isEqualTo: problemaBusca);
      }

      // Filtro para o equipamento <<< NOVO FILTRO
      if (equipamentoSelecionado == "OUTRO") {
        print(
            "DEBUG (Duplicidade): Querying for $kFieldEquipamentoOutro == '$equipamentoBusca'");
        query =
            query.where(kFieldEquipamentoOutro, isEqualTo: equipamentoBusca);
      } else {
        print(
            "DEBUG (Duplicidade): Querying for $kFieldEquipamentoSolicitacao == '$equipamentoBusca'");
        query = query.where(kFieldEquipamentoSolicitacao,
            isEqualTo: equipamentoBusca);
      }

      final QuerySnapshot snapshot = await query.limit(1).get();

      if (snapshot.docs.isNotEmpty) {
        final duplicateId = snapshot.docs.first.id;
        print(
            "DEBUG (Duplicidade): DUPLICIDADE ENCONTRADA - Chamado ID $duplicateId");
        return duplicateId;
      } else {
        print(
            "DEBUG (Duplicidade): Nenhuma duplicidade encontrada para os critérios.");
        return null;
      }
    } catch (e, s) {
      print(
          'DEBUG (Duplicidade): Erro ao verificar duplicidade no Firestore: $e');
      print(s);
      return null;
    }
  }
}

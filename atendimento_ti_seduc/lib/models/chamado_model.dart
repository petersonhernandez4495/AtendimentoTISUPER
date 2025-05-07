// models/chamado_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Importa as constantes do serviço
import '../services/chamado_service.dart'; // <<<--- AJUSTE O CAMINHO SE NECESSÁRIO

// REMOVIDAS as definições de constantes duplicadas daqui

class Chamado {
  final String id;
  final String? tipoSolicitante;
  final String? nomeSolicitante;
  final String? emailSolicitante; // Certifique-se que este campo existe no Firestore se for usar
  final String? celularContato;
  final String? cidade;
  final String? instituicao; // Pode ser o nome da escola ou "OUTRO (Ver Manual)"
  final String? instituicaoManual;
  final String? cargoSolicitante; // Mapeado de kFieldCargoFuncao
  final String? atendimentoPara;
  final String? setorSuperintendencia; // Mapeado de kFieldSetorSuper
  final String? cidadeSuperintendencia;
  final String? equipamentoSelecionado; // Mapeado de kFieldEquipamentoSolicitacao
  final String? equipamentoOutro;
  final String? internetConectada; // Mapeado de kFieldConectadoInternet
  final String? marcaModelo;
  final String? patrimonio;
  final String? problemaSelecionado; // Mapeado de kFieldProblemaOcorre
  final String? problemaOutro;
  final String status;
  final String? prioridade;
  final Timestamp dataAbertura; // Mapeado de kFieldDataCriacao
  final Timestamp? dataAtualizacao;
  final Timestamp? dataAtendimento;
  final String? solicitanteUid; // Mapeado de kFieldCreatorUid
  final String? tecnicoResponsavelNome; // Mapeado de kFieldTecnicoResponsavel
  final String? tecnicoUid;
  final String? solucao;
  final String? solucaoPorUid;
  final String? solucaoPorNome;
  final Timestamp? dataSolucao; // Mapeado de kFieldDataDaSolucao
  final bool? requerenteConfirmouSolucao; // Mapeado de kFieldRequerenteConfirmou
  final String? requerenteConfirmouUid;
  final Timestamp? requerenteConfirmouData;
  final String? nomeRequerenteConfirmador;
  final bool? adminFinalizouChamado; // Mapeado de kFieldAdminFinalizou
  final String? adminFinalizouUid;
  final String? adminFinalizouNome;
  final Timestamp? adminFinalizouData;
  final bool? adminInativo; // Mapeado de kFieldAdminInativo

  Chamado({
    required this.id,
    this.tipoSolicitante,
    this.nomeSolicitante,
    this.emailSolicitante,
    this.celularContato,
    this.cidade,
    this.instituicao,
    this.instituicaoManual,
    this.cargoSolicitante,
    this.atendimentoPara,
    this.setorSuperintendencia,
    this.cidadeSuperintendencia,
    this.equipamentoSelecionado,
    this.equipamentoOutro,
    this.internetConectada,
    this.marcaModelo,
    this.patrimonio,
    this.problemaSelecionado,
    this.problemaOutro,
    required this.status,
    this.prioridade,
    required this.dataAbertura,
    this.dataAtualizacao,
    this.dataAtendimento,
    this.solicitanteUid,
    this.tecnicoResponsavelNome,
    this.tecnicoUid,
    this.solucao,
    this.solucaoPorUid,
    this.solucaoPorNome,
    this.dataSolucao,
    this.requerenteConfirmouSolucao,
    this.requerenteConfirmouUid,
    this.requerenteConfirmouData,
    this.nomeRequerenteConfirmador,
    this.adminFinalizouChamado,
    this.adminFinalizouUid,
    this.adminFinalizouNome,
    this.adminFinalizouData,
    this.adminInativo,
  });

  factory Chamado.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw Exception("Documento ${doc.id} não contém dados!");
    }
    // Usa as constantes importadas do chamado_service.dart
    return Chamado(
      id: doc.id,
      tipoSolicitante: data[kFieldTipoSolicitante] as String?,
      nomeSolicitante: data[kFieldNomeSolicitante] as String?,
      emailSolicitante: data[kFieldEmailSolicitante] as String?,
      celularContato: data[kFieldCelularContato] as String?,
      cidade: data[kFieldCidade] as String?,
      instituicao: data[kFieldInstituicao] as String?,
      instituicaoManual: data[kFieldInstituicaoManual] as String?,
      cargoSolicitante: data[kFieldCargoFuncao] as String?, // Usando constante do service
      atendimentoPara: data[kFieldAtendimentoPara] as String?,
      setorSuperintendencia: data[kFieldSetorSuper] as String?,
      cidadeSuperintendencia: data[kFieldCidadeSuperintendencia] as String?,
      equipamentoSelecionado: data[kFieldEquipamentoSolicitacao] as String?, // Usando constante do service
      equipamentoOutro: data[kFieldEquipamentoOutro] as String?,
      internetConectada: data[kFieldConectadoInternet] as String?, // Usando constante do service
      marcaModelo: data[kFieldMarcaModelo] as String?,
      patrimonio: data[kFieldPatrimonio] as String?,
      problemaSelecionado: data[kFieldProblemaOcorre] as String?, // Usando constante do service
      problemaOutro: data[kFieldProblemaOutro] as String?,
      status: data[kFieldStatus] as String? ?? 'Desconhecido',
      prioridade: data[kFieldPrioridade] as String?,
      dataAbertura: data[kFieldDataCriacao] as Timestamp? ?? Timestamp.now(), // Usando constante do service
      dataAtualizacao: data[kFieldDataAtualizacao] as Timestamp?,
      dataAtendimento: data[kFieldDataAtendimento] as Timestamp?,
      solicitanteUid: data[kFieldCreatorUid] as String?, // Usando constante do service
      tecnicoResponsavelNome: data[kFieldTecnicoResponsavel] as String?,
      tecnicoUid: data[kFieldTecnicoUid] as String?,
      solucao: data[kFieldSolucao] as String?,
      solucaoPorUid: data[kFieldSolucaoPorUid] as String?,
      solucaoPorNome: data[kFieldSolucaoPorNome] as String?,
      dataSolucao: data[kFieldDataDaSolucao] as Timestamp?, // Usando constante do service
      requerenteConfirmouSolucao: data[kFieldRequerenteConfirmou] as bool?,
      requerenteConfirmouUid: data[kFieldRequerenteConfirmouUid] as String?,
      requerenteConfirmouData: data[kFieldRequerenteConfirmouData] as Timestamp?,
      nomeRequerenteConfirmador: data[kFieldNomeRequerenteConfirmador] as String?,
      adminFinalizouChamado: data[kFieldAdminFinalizou] as bool?,
      adminFinalizouUid: data[kFieldAdminFinalizouUid] as String?,
      adminFinalizouNome: data[kFieldAdminFinalizouNome] as String?,
      adminFinalizouData: data[kFieldAdminFinalizouData] as Timestamp?,
      adminInativo: data[kFieldAdminInativo] as bool?,
    );
  }

  bool matchesQuery(String query) {
    final queryLower = query.toLowerCase();
    bool fieldContainsQuery(String? fieldValue) {
      return fieldValue?.toLowerCase().contains(queryLower) ?? false;
    }
    // Adicione todos os campos que você quer que sejam pesquisáveis
    return id.toLowerCase().contains(queryLower) ||
           fieldContainsQuery(nomeSolicitante) ||
           fieldContainsQuery(emailSolicitante) ||
           fieldContainsQuery(patrimonio) ||
           fieldContainsQuery(instituicao) ||
           fieldContainsQuery(instituicaoManual) ||
           fieldContainsQuery(equipamentoSelecionado) ||
           fieldContainsQuery(equipamentoOutro) ||
           fieldContainsQuery(problemaSelecionado) ||
           fieldContainsQuery(problemaOutro) ||
           fieldContainsQuery(marcaModelo) ||
           fieldContainsQuery(status) || // Usa o campo status da classe
           fieldContainsQuery(tecnicoResponsavelNome) ||
           fieldContainsQuery(solucao);
  }
}

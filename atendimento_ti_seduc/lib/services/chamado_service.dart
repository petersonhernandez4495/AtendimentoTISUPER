// services/chamado_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

// --- COLEÇÕES ---
const String kCollectionChamados = 'chamados';
const String kCollectionUsers = 'users';
const String kSubCollectionComentarios = 'comentarios';
const String kCollectionConfig = 'configuracoes'; // Adicionado
const String kDocOpcoes = 'opcoesChamado'; // Adicionado
const String kDocLocalidades = 'localidades'; // Adicionado

// --- CAMPOS COMUNS DO CHAMADO ---
const String kFieldTipoSolicitante = 'tipo_solicitante';
const String kFieldNomeSolicitante = 'nome_solicitante';
const String kFieldEmailSolicitante = 'email_solicitante'; // <<<--- ADICIONADO
const String kFieldCelularContato = 'celular_contato';
const String kFieldCelularContatoUnmasked = 'celular_contato_unmasked';
const String kFieldEquipamentoSolicitacao =
    'equipamento_solicitacao'; // Renomeado de selecionado
const String kFieldEquipamentoOutro = 'equipamento_outro_descricao';
const String kFieldConectadoInternet =
    'equipamento_conectado_internet'; // Renomeado
const String kFieldMarcaModelo = 'marca_modelo_equipamento'; // Renomeado
const String kFieldPatrimonio = 'numero_patrimonio'; // Renomeado
const String kFieldProblemaOcorre =
    'problema_ocorre'; // Renomeado de selecionado
const String kFieldProblemaOutro = 'problema_outro_descricao';
const String kFieldStatus = 'status';
const String kFieldPrioridade = 'prioridade';
const String kFieldTecnicoResponsavel =
    'tecnico_responsavel'; // Renomeado de nome
const String kFieldTecnicoUid = 'tecnicoUid';
const String kFieldSolucao = 'solucao';
const String kFieldDataCriacao = 'data_criacao'; // Nome consistente com service
const String kFieldDataAtualizacao = 'data_atualizacao';
const String kFieldCreatorUid = 'creatorUid';
const String kFieldCreatorName = 'creatorName';
const String kFieldAuthUserDisplay = 'authUserDisplayName';
const String kFieldAuthUserEmail = 'authUserEmail';
const String kFieldAdminInativo = 'isAdministrativamenteInativo';

// --- CAMPOS ESPECÍFICOS ESCOLA ---
const String kFieldCidade = 'cidade';
const String kFieldInstituicao = 'instituicao';
const String kFieldInstituicaoManual = 'instituicao_manual';
const String kFieldCargoFuncao = 'cargo_funcao';
const String kFieldAtendimentoPara = 'atendimento_para';
const String kFieldObservacaoCargo = 'observacao_cargo';

// --- CAMPOS ESPECÍFICOS SUPERINTENDÊNCIA ---
const String kFieldSetorSuper = 'setor_superintendencia';
const String kFieldCidadeSuperintendencia = 'cidade_superintendencia';
const String kFieldUserSetor = 'setor_superintendencia';
// --- CAMPO UNIFICADO PARA LÓGICA DE VISUALIZAÇÃO INSTITUCIONAL ---
const String kFieldUnidadeOrganizacionalChamado =
    'unidadeOrganizacionalChamado';

// --- CAMPOS DE FINALIZAÇÃO/CONFIRMAÇÃO ---
const String kFieldDataAtendimento = 'data_atendimento';
const String kFieldRequerenteConfirmou = 'requerente_confirmou';
const String kFieldRequerenteConfirmouData = 'requerente_confirmou_data';
const String kFieldRequerenteConfirmouUid = 'requerente_confirmou_uid';
const String kFieldNomeRequerenteConfirmador = 'nomeRequerenteConfirmador';

const String kFieldAdminFinalizou = 'adminFinalizou';
const String kFieldAdminFinalizouData = 'adminFinalizouData';
const String kFieldAdminFinalizouUid = 'adminFinalizouUid';
const String kFieldAdminFinalizouNome = 'adminFinalizouNome';

const String kFieldSolucaoPorUid = 'solucaoPorUid';
const String kFieldSolucaoPorNome = 'solucaoPorNome';
const String kFieldDataDaSolucao = 'dataDaSolucao';

// --- CAMPOS DO DOCUMENTO DO USUÁRIO (na coleção 'users') ---
const String kFieldUserRole = 'role_temp';
const String kFieldUserInstituicao = 'institution';
const String kFieldUserAssinaturaUrl = 'assinatura_url';
const String kFieldPhone = 'phone'; // <<< ADICIONAR ESTA
const String kFieldJobTitle = 'jobTitle'; // <<< ADICIONAR ESTA
const String kFieldUserTipoSolicitante = 'tipo_solicitante';
const String kFieldName = 'name'; // <<< ADICIONAR ESTA (para consistência)
const String kFieldEmail = 'email'; // <<< ADICIONAR ESTA (para consistência)

// --- STATUS ---
const String kStatusAberto = 'Aberto';
const String kStatusEmAndamento = 'Em Andamento'; // <<<--- ADICIONADO
const String kStatusPendente = 'Pendente'; // <<<--- ADICIONADO
const String kStatusPadraoSolicionado = 'Solucionado';
const String kStatusFinalizado = 'Finalizado';
const String kStatusCancelado = 'Cancelado';
const String kStatusAguardandoAprovacao =
    'Aguardando Aprovação'; // <<<--- ADICIONADO
const String kStatusAguardandoPeca = 'Aguardando Peça'; // <<<--- ADICIONADO
const String kStatusChamadoDuplicado = 'Chamado Duplicado'; // <<<--- ADICIONADO
const String kStatusAguardandoEquipamento =
    'Aguardando Equipamento'; // <<<--- ADICIONADO
const String kStatusAtribuidoGSIOR =
    'Atribuido para GSIOR'; // <<<--- ADICIONADO
const String kStatusGarantiaFabricante =
    'Garantia Fabricante'; // <<<--- ADICIONADO

class ChamadoService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _phoneMaskFormatter = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  Future<String> criarChamado({
    required String? tipoSelecionado,
    required String celularContato,
    required String?
        equipamentoSelecionado, // Corresponde a kFieldEquipamentoSolicitacao
    required String? equipamentoOutro,
    required String?
        internetConectadaSelecionado, // Corresponde a kFieldConectadoInternet
    required String marcaModelo, // Corresponde a kFieldMarcaModelo
    required String patrimonio, // Corresponde a kFieldPatrimonio
    required String? problemaSelecionado, // Corresponde a kFieldProblemaOcorre
    required String? problemaOutro,
    required String? cidadeSelecionada,
    required String? instituicaoSelecionada, // Corresponde a kFieldInstituicao
    required String? instituicaoManual,
    required String? cargoSelecionado, // Corresponde a kFieldCargoFuncao
    required String?
        atendimentoParaSelecionado, // Corresponde a kFieldAtendimentoPara
    required bool isProfessorSelecionado,
    required String? setorSuperSelecionado, // Corresponde a kFieldSetorSuper
    required String cidadeSuper, // Corresponde a kFieldCidadeSuperintendencia
    required String
        tecnicoResponsavel, // Corresponde a kFieldTecnicoResponsavel
    String? tecnicoUid,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado.');

    final String nomeFinalSolicitante =
        user.displayName?.trim().isNotEmpty ?? false
            ? user.displayName!.trim()
            : (user.email ?? "User (${user.uid.substring(0, 6)})");
    final String creatorUid = user.uid;
    final String creatorPhone = celularContato.trim();
    final String unmaskedPhone = _phoneMaskFormatter.unmaskText(creatorPhone);

    String? unidadeOrganizacionalDoChamado;
    if (tipoSelecionado == 'ESCOLA') {
      if (cidadeSelecionada == "OUTRO" &&
          instituicaoManual != null &&
          instituicaoManual.trim().isNotEmpty) {
        unidadeOrganizacionalDoChamado = instituicaoManual.trim();
      } else {
        unidadeOrganizacionalDoChamado = instituicaoSelecionada;
      }
    } else if (tipoSelecionado == 'SUPERINTENDENCIA') {
      unidadeOrganizacionalDoChamado = setorSuperSelecionado;
    }

    final dadosChamado = <String, dynamic>{
      kFieldTipoSolicitante: tipoSelecionado,
      kFieldNomeSolicitante: nomeFinalSolicitante,
      kFieldCelularContato: creatorPhone,
      kFieldCelularContatoUnmasked: unmaskedPhone,
      kFieldEquipamentoSolicitacao: equipamentoSelecionado,
      kFieldEquipamentoOutro:
          equipamentoSelecionado == "OUTRO" ? equipamentoOutro?.trim() : null,
      kFieldConectadoInternet: internetConectadaSelecionado,
      kFieldMarcaModelo: marcaModelo.trim().isEmpty ? null : marcaModelo.trim(),
      kFieldPatrimonio: patrimonio.trim(),
      kFieldProblemaOcorre: problemaSelecionado,
      kFieldProblemaOutro:
          problemaSelecionado == "OUTRO" ? problemaOutro?.trim() : null,
      kFieldTecnicoResponsavel:
          tecnicoResponsavel.trim().isEmpty ? null : tecnicoResponsavel.trim(),
      if (tecnicoUid != null && tecnicoUid.trim().isNotEmpty)
        kFieldTecnicoUid: tecnicoUid.trim(),
      kFieldStatus: kStatusAberto,
      kFieldPrioridade: 'Média',
      kFieldDataCriacao: FieldValue.serverTimestamp(),
      kFieldDataAtualizacao: FieldValue.serverTimestamp(),
      kFieldCreatorUid: creatorUid,
      kFieldCreatorName:
          nomeFinalSolicitante, // Pode ser redundante se kFieldNomeSolicitante já existe
      kFieldAuthUserDisplay: user.displayName,
      kFieldAuthUserEmail: user.email,
      kFieldAdminInativo: false,
      kFieldSolucao: null,
      kFieldDataAtendimento: null,
      kFieldRequerenteConfirmou: false,
      kFieldRequerenteConfirmouData: null,
      kFieldRequerenteConfirmouUid: null,
      kFieldNomeRequerenteConfirmador: null, // Inicialmente nulo
      kFieldAdminFinalizou: false,
      kFieldAdminFinalizouData: null,
      kFieldAdminFinalizouUid: null,
      kFieldAdminFinalizouNome: null,
      kFieldSolucaoPorUid: null,
      kFieldSolucaoPorNome: null,
      kFieldDataDaSolucao: null,
      kFieldUnidadeOrganizacionalChamado: unidadeOrganizacionalDoChamado,

      if (tipoSelecionado == 'ESCOLA') ...{
        kFieldCidade: cidadeSelecionada,
        kFieldCargoFuncao: cargoSelecionado,
        kFieldAtendimentoPara: atendimentoParaSelecionado,
        if (isProfessorSelecionado)
          kFieldObservacaoCargo: 'Solicitante é Professor...',
        kFieldInstituicao: (cidadeSelecionada == "OUTRO")
            ? 'OUTRO (Ver Manual)'
            : instituicaoSelecionada,
        kFieldInstituicaoManual:
            (cidadeSelecionada == "OUTRO") ? instituicaoManual?.trim() : null,
      } else if (tipoSelecionado == 'SUPERINTENDENCIA') ...{
        kFieldSetorSuper: setorSuperSelecionado,
        kFieldCidadeSuperintendencia: cidadeSuper.trim(),
      },
    };

    try {
      final docRef =
          await _db.collection(kCollectionChamados).add(dadosChamado);
      return docRef.id;
    } catch (e) {
      print("Erro ao criar chamado: $e");
      throw Exception('Falha ao salvar chamado.');
    }
  }

  Future<void> definirInatividadeAdministrativa(
      String chamadoId, bool inativo) async {
    if (chamadoId.isEmpty)
      throw ArgumentError('ID do chamado não pode ser vazio.');
    final docRef = _db.collection(kCollectionChamados).doc(chamadoId);
    try {
      await docRef.update({
        kFieldAdminInativo: inativo,
        kFieldDataAtualizacao: FieldValue.serverTimestamp(),
      });
      await adicionarComentarioSistema(
          chamadoId,
          inativo
              ? 'Chamado INATIVO administrativamente.'
              : 'Chamado REATIVADO administrativamente.');
    } catch (e) {
      print("Erro ao definir inatividade: $e");
      throw Exception('Falha ao definir inatividade do chamado.');
    }
  }

  Future<void> atualizarDetalhesAdmin({
    required String chamadoId,
    required String status,
    required User adminUser, // Alterado para adminUser para clareza do contexto
    String? prioridade,
    String? tecnicoResponsavel,
    String? tecnicoUid,
    String? solucao,
    Timestamp? dataAtendimento,
  }) async {
    if (chamadoId.isEmpty)
      throw ArgumentError('ID do chamado não pode ser vazio.');
    final docRef = _db.collection(kCollectionChamados).doc(chamadoId);
    final Map<String, dynamic> dataToUpdate = {
      kFieldStatus: status,
      kFieldDataAtualizacao: FieldValue.serverTimestamp(),
      if (prioridade != null) kFieldPrioridade: prioridade,
      // Lógica para técnico: se nome vazio, limpar UID também. Se UID vazio, limpar nome.
      kFieldTecnicoResponsavel: tecnicoResponsavel?.trim().isEmpty ?? true
          ? null
          : tecnicoResponsavel?.trim(),
    };

    if (tecnicoUid != null && tecnicoUid.trim().isNotEmpty) {
      dataToUpdate[kFieldTecnicoUid] = tecnicoUid.trim();
    } else {
      dataToUpdate[kFieldTecnicoUid] =
          FieldValue.delete(); // Remove o campo se UID for nulo ou vazio
      if (tecnicoResponsavel == null || tecnicoResponsavel.trim().isEmpty) {
        dataToUpdate[kFieldTecnicoResponsavel] =
            null; // Garante que nome também é nulo
      }
    }

    // Se o técnico responsável for explicitamente nulo ou vazio, garantir que o UID também seja removido
    if (tecnicoResponsavel == null || tecnicoResponsavel.trim().isEmpty) {
      dataToUpdate[kFieldTecnicoUid] = FieldValue.delete();
      dataToUpdate[kFieldTecnicoResponsavel] =
          null; // Garante que o nome seja nulo se estiver vazio
    }

    dataToUpdate[kFieldSolucao] = solucao; // Pode ser null para limpar
    dataToUpdate[kFieldDataAtendimento] =
        dataAtendimento; // Pode ser null para limpar

    if (status.toLowerCase() == kStatusPadraoSolicionado.toLowerCase()) {
      final String nomeSolucionador =
          adminUser.displayName?.trim().isNotEmpty ?? false
              ? adminUser.displayName!.trim()
              : (adminUser.email ?? 'Admin (${adminUser.uid.substring(0, 6)})');
      dataToUpdate[kFieldSolucaoPorUid] = adminUser.uid;
      dataToUpdate[kFieldSolucaoPorNome] = nomeSolucionador;
      dataToUpdate[kFieldDataDaSolucao] = FieldValue.serverTimestamp();
    } else {
      // Se o status mudou de "Solucionado" para outro, limpar campos de solução
      DocumentSnapshot currentDoc = await docRef.get();
      if (currentDoc.exists) {
        final currentData = currentDoc.data() as Map<String, dynamic>;
        if (currentData[kFieldStatus]?.toString().toLowerCase() ==
            kStatusPadraoSolicionado.toLowerCase()) {
          dataToUpdate[kFieldSolucaoPorUid] = FieldValue.delete();
          dataToUpdate[kFieldSolucaoPorNome] = FieldValue.delete();
          dataToUpdate[kFieldDataDaSolucao] = FieldValue.delete();
          // Considerar se deve limpar kFieldSolucao e kFieldDataAtendimento também ao reverter de "Solucionado"
          // dataToUpdate[kFieldSolucao] = FieldValue.delete();
          // dataToUpdate[kFieldDataAtendimento] = FieldValue.delete();
        }
      }
    }

    // Resetar flags de confirmação se o status não for mais relevante para elas
    if (status.toLowerCase() != kStatusPadraoSolicionado.toLowerCase() &&
        status.toLowerCase() != kStatusFinalizado.toLowerCase()) {
      dataToUpdate[kFieldAdminFinalizou] = false;
      dataToUpdate[kFieldAdminFinalizouData] = null;
      dataToUpdate[kFieldAdminFinalizouUid] = null;
      dataToUpdate[kFieldAdminFinalizouNome] = null;
    }
    if (status.toLowerCase() != kStatusPadraoSolicionado.toLowerCase()) {
      dataToUpdate[kFieldRequerenteConfirmou] =
          false; // Requerente precisaria confirmar novamente se status voltar para solucionado
      dataToUpdate[kFieldRequerenteConfirmouData] = null;
      dataToUpdate[kFieldRequerenteConfirmouUid] = null;
      // dataToUpdate[kFieldNomeRequerenteConfirmador] = null; // Se você armazenar este
    }

    try {
      await docRef.update(dataToUpdate);
      final List<String> changes = [];
      // Construir mensagem de log de forma mais granular
      DocumentSnapshot oldSnap = await docRef
          .get(); // Pegar dados antes da atualização para comparação se necessário
      Map<String, dynamic> oldData = oldSnap.data() as Map<String, dynamic>;

      if (oldData[kFieldStatus] != status)
        changes.add('Status atualizado para: "$status".');
      if (prioridade != null && oldData[kFieldPrioridade] != prioridade)
        changes.add('Prioridade definida como: "$prioridade".');

      String? oldTecnico = oldData[kFieldTecnicoResponsavel];
      String? newTecnico = tecnicoResponsavel?.trim().isEmpty ?? true
          ? null
          : tecnicoResponsavel?.trim();
      if (oldTecnico != newTecnico) {
        changes.add(newTecnico == null
            ? 'Técnico responsável removido.'
            : 'Técnico atribuído: "$newTecnico".');
      }

      String? oldSolucao = oldData[kFieldSolucao];
      if (oldSolucao != solucao) {
        changes.add(solucao != null && solucao.isNotEmpty
            ? 'Solução/Diagnóstico registrado/alterado.'
            : 'Solução/Diagnóstico removido.');
      }

      Timestamp? oldDataAtendimento = oldData[kFieldDataAtendimento];
      if (oldDataAtendimento != dataAtendimento) {
        changes.add(dataAtendimento != null
            ? 'Data de atendimento definida para: ${DateFormat('dd/MM/yyyy HH:mm').format(dataAtendimento.toDate())}.'
            : 'Data de atendimento removida.');
      }

      if (changes.isNotEmpty) {
        await adicionarComentarioSistema(chamadoId, changes.join(' '));
      }
    } catch (e) {
      print("Erro ao atualizar detalhes do chamado: $e");
      throw Exception('Falha ao atualizar detalhes do chamado.');
    }
  }

  Future<void> adicionarComentarioSistema(
      String chamadoId, String texto) async {
    if (chamadoId.isEmpty || texto.isEmpty) return;
    try {
      await _db
          .collection(kCollectionChamados)
          .doc(chamadoId)
          .collection(kSubCollectionComentarios) // Usando constante
          .add({
        'texto': texto,
        'autorNome': 'Sistema', // Ou nome do Admin/Serviço que está logando
        'autorUid': 'sistema', // Ou UID do Admin/Serviço
        'timestamp': FieldValue.serverTimestamp(),
        'isSystemMessage': true,
      });
    } catch (e) {
      print("Erro ao adicionar comentário do sistema: $e");
      // Silently fail or log, as this is a system comment
    }
  }

  Future<void> confirmarServicoRequerente(
      String chamadoId, User currentUser) async {
    if (chamadoId.isEmpty)
      throw ArgumentError('ID do chamado não pode ser vazio.');
    final docRef = _db.collection(kCollectionChamados).doc(chamadoId);

    try {
      final chamadoDoc = await docRef.get();
      if (!chamadoDoc.exists || chamadoDoc.data() == null) {
        throw Exception('Chamado não encontrado ou dados inválidos.');
      }
      final chamadoData = chamadoDoc.data()!;
      final String? creatorUid = chamadoData[kFieldCreatorUid] as String?;

      // Somente o criador original pode confirmar
      if (creatorUid == null || creatorUid != currentUser.uid) {
        throw Exception(
            'Ação não permitida. Apenas o solicitante original pode confirmar o serviço.');
      }

      final bool jaConfirmado =
          chamadoData[kFieldRequerenteConfirmou] as bool? ?? false;
      if (jaConfirmado) {
        // Poderia lançar um erro ou apenas retornar se a intenção é ser idempotente
        // throw Exception('Este chamado já foi confirmado pelo requerente.');
        return; // Evita reconfirmar
      }

      // Verifica se o status é "Solucionado" antes de permitir a confirmação
      final String statusAtual = chamadoData[kFieldStatus] as String? ?? '';
      if (statusAtual.toLowerCase() != kStatusPadraoSolicionado.toLowerCase()) {
        throw Exception(
            'O chamado precisa estar com status "$kStatusPadraoSolicionado" para que o requerente possa confirmar a solução.');
      }

      final String nomeConfirmador =
          currentUser.displayName?.trim().isNotEmpty ?? false
              ? currentUser.displayName!.trim()
              : (currentUser.email ??
                  'Requerente (${currentUser.uid.substring(0, 6)})');

      await docRef.update({
        kFieldRequerenteConfirmou: true,
        kFieldRequerenteConfirmouData: FieldValue.serverTimestamp(),
        kFieldRequerenteConfirmouUid: currentUser.uid,
        kFieldNomeRequerenteConfirmador:
            nomeConfirmador, // Salva o nome para o PDF
        kFieldDataAtualizacao: FieldValue.serverTimestamp(),
      });

      await adicionarComentarioSistema(
        chamadoId,
        'Serviço confirmado como solucionado pelo requerente ($nomeConfirmador).',
      );
    } catch (e) {
      print("Erro ao confirmar serviço pelo requerente: $e");
      if (e.toString().contains('Ação não permitida') ||
          e.toString().contains('Este chamado já foi confirmado') ||
          e.toString().contains(
              'O chamado precisa estar com status "$kStatusPadraoSolicionado"')) {
        rethrow; // Repassa exceções específicas
      }
      throw Exception('Falha ao registrar a confirmação do serviço.');
    }
  }

  Future<void> adminConfirmarSolucaoFinal(
      String chamadoId, User adminUser) async {
    if (chamadoId.isEmpty)
      throw ArgumentError('ID do chamado não pode ser vazio.');

    final docRef = _db.collection(kCollectionChamados).doc(chamadoId);
    try {
      final chamadoDoc = await docRef.get();
      if (!chamadoDoc.exists || chamadoDoc.data() == null) {
        throw Exception('Chamado não encontrado ou dados inválidos.');
      }
      final chamadoData = chamadoDoc.data()!;

      // Verifica se o requerente já confirmou (RF010 - Ordem de Serviço)
      final bool requerenteJaConfirmou =
          chamadoData[kFieldRequerenteConfirmou] as bool? ?? false;
      if (!requerenteJaConfirmou) {
        throw Exception(
            'A confirmação do requerente é necessária antes da finalização/arquivamento pelo administrador.');
      }

      // Verifica se o status atual é "Solucionado"
      final String statusAtual = chamadoData[kFieldStatus] as String? ?? '';
      if (statusAtual.toLowerCase() != kStatusPadraoSolicionado.toLowerCase()) {
        throw Exception(
            'O chamado precisa estar com status "$kStatusPadraoSolicionado" para ser finalizado/arquivado.');
      }

      final bool adminJaFinalizou =
          chamadoData[kFieldAdminFinalizou] as bool? ?? false;
      if (adminJaFinalizou) {
        // throw Exception('Este chamado já foi finalizado/arquivado pelo administrador.');
        return; // Evita re-finalizar
      }

      final String adminNome = adminUser.displayName?.trim().isNotEmpty ?? false
          ? adminUser.displayName!.trim()
          : (adminUser.email ?? 'Admin (${adminUser.uid.substring(0, 6)})');

      await docRef.update({
        kFieldAdminFinalizou: true,
        kFieldAdminFinalizouData: FieldValue.serverTimestamp(),
        kFieldAdminFinalizouUid: adminUser.uid,
        kFieldAdminFinalizouNome: adminNome,
        kFieldStatus:
            kStatusFinalizado, // Muda o status para Finalizado/Arquivado
        kFieldDataAtualizacao: FieldValue.serverTimestamp(),
      });

      await adicionarComentarioSistema(
        chamadoId,
        'Chamado arquivado pelo administrador ($adminNome). Status alterado para "$kStatusFinalizado".',
      );
    } catch (e) {
      print("Erro ao finalizar/arquivar chamado pelo admin: $e");
      if (e.toString().contains('A confirmação do requerente é necessária') ||
          e.toString().contains('O chamado precisa estar com status') ||
          e.toString().contains('Este chamado já foi finalizado')) {
        rethrow; // Repassa exceções específicas
      }
      throw Exception('Falha ao arquivar o chamado.');
    }
  }

  Future<void> excluirChamado(String chamadoId) async {
    // Adicionar verificação de permissão se necessário (ex: só admin pode excluir)
    if (chamadoId.isEmpty) {
      throw ArgumentError('ID do chamado não pode ser vazio para exclusão.');
    }
    try {
      // Opcional: Excluir subcoleções como 'comentarios' antes de excluir o chamado.
      // Query queryComentarios = _db.collection(kCollectionChamados).doc(chamadoId).collection(kSubCollectionComentarios);
      // WriteBatch batch = _db.batch();
      // QuerySnapshot comentariosSnapshot = await queryComentarios.get();
      // for (DocumentSnapshot doc in comentariosSnapshot.docs) {
      //   batch.delete(doc.reference);
      // }
      // await batch.commit(); // Deleta comentários

      await _db.collection(kCollectionChamados).doc(chamadoId).delete();
    } catch (e) {
      print("Erro ao excluir chamado: $e");
      throw Exception('Falha ao excluir chamado: $e');
    }
  }
}

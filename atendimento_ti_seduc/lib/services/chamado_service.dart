import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

// Constantes Globais de Campos e Coleções
const String kCollectionChamados = 'chamados';
const String kFieldTipoSolicitante = 'tipo_solicitante';
const String kFieldNomeSolicitante = 'nome_solicitante';
const String kFieldCelularContato = 'celular_contato';
const String kFieldEquipamentoSolicitacao = 'equipamento_solicitacao';
const String kFieldEquipamentoOutro = 'equipamento_outro_descricao';
const String kFieldConectadoInternet = 'equipamento_conectado_internet';
const String kFieldMarcaModelo = 'marca_modelo_equipamento';
const String kFieldPatrimonio = 'numero_patrimonio';
const String kFieldProblemaOcorre = 'problema_ocorre';
const String kFieldProblemaOutro = 'problema_outro_descricao';
const String kFieldCidade = 'cidade';
const String kFieldInstituicao = 'instituicao';
const String kFieldInstituicaoManual = 'instituicao_manual';
const String kFieldCargoFuncao = 'cargo_funcao';
const String kFieldAtendimentoPara = 'atendimento_para';
const String kFieldSetorSuper = 'setor_superintendencia';
const String kFieldCidadeSuperintendencia = 'cidade_superintendencia';
const String kFieldStatus = 'status';
const String kFieldPrioridade = 'prioridade';
const String kFieldTecnicoResponsavel = 'tecnico_responsavel';
const String kFieldTecnicoUid = 'tecnicoUid'; // UID do técnico que efetivamente trabalhou/solucionou
const String kFieldSolucao = 'solucao';
const String kFieldAuthUserDisplay = 'authUserDisplayName';
const String kFieldDataCriacao = 'data_criacao';
const String kFieldDataAtualizacao = 'data_atualizacao';
const String kFieldAdminInativo = 'isAdministrativamenteInativo';
const String kFieldDataAtendimento = 'data_atendimento';
const String kFieldRequerenteConfirmou = 'requerente_confirmou';
const String kFieldRequerenteConfirmouData = 'requerente_confirmou_data';
const String kFieldRequerenteConfirmouUid = 'requerente_confirmou_uid';
const String kFieldCreatorUid = 'creatorUid';

const String kFieldAdminFinalizou = 'adminFinalizou';
const String kFieldAdminFinalizouData = 'adminFinalizouData';
const String kFieldAdminFinalizouUid = 'adminFinalizouUid';
const String kFieldAdminFinalizouNome = 'adminFinalizouNome';

// Constante padrão para o status "Solucionado"
const String kStatusPadraoSolicionado = 'Solucionado';

class ChamadoService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _phoneMaskFormatter = MaskTextInputFormatter( mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')}, );

  Future<String> criarChamado({
    required String? tipoSelecionado,
    required String celularContato,
    required String? equipamentoSelecionado, 
    required String? equipamentoOutro,
    required String? internetConectadaSelecionado,
    required String marcaModelo,
    required String patrimonio,
    required String? problemaSelecionado,
    required String? problemaOutro,
    required String? cidadeSelecionada, 
    required String? instituicaoSelecionada, 
    required String? instituicaoManual,
    required String? cargoSelecionado, 
    required String? atendimentoParaSelecionado, 
    required bool isProfessorSelecionado, 
    required String? setorSuperSelecionado, 
    required String cidadeSuper, 
    required String tecnicoResponsavel,
    String? tecnicoUid,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado.');
    final String nomeFinalSolicitante = user.displayName?.trim().isNotEmpty ?? false ? user.displayName!.trim() : (user.email ?? "User (${user.uid.substring(0, 6)})");
    final String creatorUid = user.uid;
    final String creatorPhone = celularContato.trim();
    final String unmaskedPhone = _phoneMaskFormatter.unmaskText(creatorPhone);

    final dadosChamado = <String, dynamic>{
      kFieldTipoSolicitante: tipoSelecionado,
      kFieldNomeSolicitante: nomeFinalSolicitante,
      kFieldCelularContato: creatorPhone,
      'celular_contato_unmasked': unmaskedPhone,
      kFieldEquipamentoSolicitacao: equipamentoSelecionado,
      kFieldEquipamentoOutro: equipamentoSelecionado == "OUTRO" ? equipamentoOutro?.trim() : null,
      kFieldConectadoInternet: internetConectadaSelecionado,
      kFieldMarcaModelo: marcaModelo.trim().isEmpty ? null : marcaModelo.trim(),
      kFieldPatrimonio: patrimonio.trim(),
      kFieldProblemaOcorre: problemaSelecionado,
      kFieldProblemaOutro: problemaSelecionado == "OUTRO" ? problemaOutro?.trim() : null,
      kFieldTecnicoResponsavel: tecnicoResponsavel.trim().isEmpty ? null : tecnicoResponsavel.trim(),
      if (tecnicoUid != null && tecnicoUid.trim().isNotEmpty) kFieldTecnicoUid: tecnicoUid.trim(),
      kFieldStatus: 'Aberto',
      kFieldPrioridade: 'Média',
      kFieldDataCriacao: FieldValue.serverTimestamp(),
      kFieldDataAtualizacao: FieldValue.serverTimestamp(),
      kFieldCreatorUid: creatorUid,
      'creatorName': nomeFinalSolicitante,
      kFieldAuthUserDisplay: user.displayName,
      'authUserEmail': user.email,
      kFieldAdminInativo: false,
      kFieldSolucao: null,
      kFieldDataAtendimento: null,
      kFieldRequerenteConfirmou: false,
      kFieldRequerenteConfirmouData: null,
      kFieldRequerenteConfirmouUid: null,
      kFieldAdminFinalizou: false,
      kFieldAdminFinalizouData: null,
      kFieldAdminFinalizouUid: null,
      kFieldAdminFinalizouNome: null,
      if (tipoSelecionado == 'ESCOLA') ...{
        kFieldCidade: cidadeSelecionada,
        kFieldCargoFuncao: cargoSelecionado,
        kFieldAtendimentoPara: atendimentoParaSelecionado,
        if (isProfessorSelecionado) 'observacao_cargo': 'Solicitante é Professor...',
        if (cidadeSelecionada == "OUTRO") ...{
          kFieldInstituicaoManual: instituicaoManual?.trim(),
          kFieldInstituicao: 'OUTRO (Ver $kFieldInstituicaoManual)',
        } else ...{
          kFieldInstituicao: instituicaoSelecionada,
          kFieldInstituicaoManual: null,
        },
      } else if (tipoSelecionado == 'SUPERINTENDENCIA') ...{
        kFieldSetorSuper: setorSuperSelecionado,
        kFieldCidadeSuperintendencia: cidadeSuper.trim(),
      },
    };
    try {
      final docRef = await _db.collection(kCollectionChamados).add(dadosChamado);
      return docRef.id;
    } catch (e, s) {
      print('Erro criar chamado: $e\n$s');
      throw Exception('Falha ao salvar chamado.');
    }
  }

  Future<void> definirInatividadeAdministrativa(String chamadoId, bool inativo) async {
    if (chamadoId.isEmpty) throw ArgumentError('ID vazio.'); 
    final docRef = _db.collection(kCollectionChamados).doc(chamadoId); 
    try { 
        await docRef.update({ 
            kFieldAdminInativo: inativo, 
            kFieldDataAtualizacao: FieldValue.serverTimestamp(), 
        }); 
        await adicionarComentarioSistema( chamadoId, inativo ? 'Chamado INATIVO administrativamente.' : 'Chamado REATIVADO administrativamente.' ); 
    } catch (e, s) { 
        print('Erro ao definir inatividade para $chamadoId: $e\n$s'); 
        throw Exception('Falha ao definir inatividade do chamado.'); 
    }
  }

  Future<void> atualizarDetalhesAdmin({
    required String chamadoId,
    required String status,
    String? prioridade,
    String? tecnicoResponsavel,
    String? tecnicoUid, 
    String? solucao,
    Timestamp? dataAtendimento,
  }) async {
    if (chamadoId.isEmpty) throw ArgumentError('ID do chamado não pode ser vazio.');
    final docRef = _db.collection(kCollectionChamados).doc(chamadoId);
    final Map<String, dynamic> dataToUpdate = {
      kFieldStatus: status,
      kFieldDataAtualizacao: FieldValue.serverTimestamp(),
      if (prioridade != null) kFieldPrioridade: prioridade,
      if (tecnicoResponsavel != null) kFieldTecnicoResponsavel: tecnicoResponsavel.trim().isEmpty ? null : tecnicoResponsavel.trim(),
      if (tecnicoUid != null && tecnicoUid.trim().isNotEmpty) kFieldTecnicoUid: tecnicoUid.trim() 
      else if ((tecnicoResponsavel == null || tecnicoResponsavel.trim().isEmpty) && (tecnicoUid == null || tecnicoUid.trim().isEmpty)) kFieldTecnicoUid: FieldValue.delete(), // Remove se o nome e UID do técnico forem removidos/nulos
      
      kFieldSolucao: solucao,
      kFieldDataAtendimento: dataAtendimento,
    };

    if (status.toLowerCase() != kStatusPadraoSolicionado.toLowerCase()) {
        dataToUpdate[kFieldAdminFinalizou] = false;
        dataToUpdate[kFieldAdminFinalizouData] = null;
        dataToUpdate[kFieldAdminFinalizouUid] = null;
        dataToUpdate[kFieldAdminFinalizouNome] = null;
    }

    try {
      await docRef.update(dataToUpdate);
      final List<String> changes = []; 
      changes.add('Status atualizado para: "$status".'); 
      if (prioridade != null) changes.add('Prioridade definida como: "$prioridade".'); 
      if (tecnicoResponsavel != null) changes.add(tecnicoResponsavel.trim().isEmpty ? 'Técnico responsável removido.' : 'Técnico atribuído: "$tecnicoResponsavel".'); 
      if (dataToUpdate.containsKey(kFieldSolucao)) { changes.add(solucao != null && solucao.isNotEmpty ? 'Solução/Diagnóstico registrado.' : 'Solução/Diagnóstico removido.'); } 
      if (dataToUpdate.containsKey(kFieldDataAtendimento)) { changes.add(dataAtendimento != null ? 'Data de atendimento definida para: ${DateFormat('dd/MM/yyyy').format(dataAtendimento.toDate())}.' : 'Data de atendimento removida.'); } 
      if (changes.isNotEmpty) {
        await adicionarComentarioSistema(chamadoId, changes.join(' '));
      }
    } catch (e, s) {
      print('Erro ao atualizar detalhes do chamado $chamadoId (Admin): $e\n$s');
      throw Exception('Falha ao atualizar detalhes do chamado.');
    }
  }

  Future<void> adicionarComentarioSistema(String chamadoId, String texto) async {
    if (chamadoId.isEmpty || texto.isEmpty) return; 
    try { 
        await _db.collection(kCollectionChamados).doc(chamadoId).collection('comentarios').add({ 
            'texto': texto, 
            'autorNome': 'Sistema', 
            'autorUid': 'sistema', 
            'timestamp': FieldValue.serverTimestamp(), 
            'isSystemMessage': true, 
        }); 
    } catch (e) { 
        print("Erro ao adicionar comentário do sistema para o chamado $chamadoId: $e"); 
    }
  }
  
  Future<void> confirmarServicoRequerente(String chamadoId, User currentUser) async {
    if (chamadoId.isEmpty) throw ArgumentError('ID do chamado não pode ser vazio.');
    final docRef = _db.collection(kCollectionChamados).doc(chamadoId);
    try {
      final chamadoDoc = await docRef.get();
      if (!chamadoDoc.exists || chamadoDoc.data() == null) {
        throw Exception('Chamado não encontrado ou dados inválidos.');
      }
      final chamadoData = chamadoDoc.data()!;
      final String? creatorUid = chamadoData[kFieldCreatorUid] as String?;

      if (creatorUid == null || creatorUid != currentUser.uid) {
        throw Exception('Ação não permitida. Apenas o solicitante original pode confirmar o serviço.');
      }
      
      final bool jaConfirmado = chamadoData[kFieldRequerenteConfirmou] as bool? ?? false;
      if (jaConfirmado) {
        return; 
      }

      await docRef.update({
        kFieldRequerenteConfirmou: true,
        kFieldRequerenteConfirmouData: FieldValue.serverTimestamp(),
        kFieldRequerenteConfirmouUid: currentUser.uid, 
        kFieldDataAtualizacao: FieldValue.serverTimestamp(),
      });

      final String nomeConfirmador = currentUser.displayName?.trim().isNotEmpty ?? false
          ? currentUser.displayName!.trim()
          : (currentUser.email ?? 'Requerente (${currentUser.uid.substring(0, 6)})');
      
      await adicionarComentarioSistema(
        chamadoId,
        'Serviço confirmado como solucionado pelo requerente ($nomeConfirmador).',
      );
    } catch (e) {
      print('Erro ao registrar confirmação do requerente para o chamado $chamadoId: $e');
      throw Exception('Falha ao registrar a confirmação do serviço. Detalhes: ${e.toString()}');
    }
  }

  Future<void> adminConfirmarSolucaoFinal(String chamadoId, User adminUser) async {
    if (chamadoId.isEmpty) throw ArgumentError('ID do chamado não pode ser vazio.');
    if (adminUser.uid.isEmpty) throw ArgumentError('UID do administrador não pode ser vazio.');

    final docRef = _db.collection(kCollectionChamados).doc(chamadoId);
    try {
      final chamadoDoc = await docRef.get();
      if (!chamadoDoc.exists || chamadoDoc.data() == null) {
        throw Exception('Chamado não encontrado ou dados inválidos.');
      }
      final chamadoData = chamadoDoc.data()!;

      final bool requerenteJaConfirmou = chamadoData[kFieldRequerenteConfirmou] as bool? ?? false;
      if (!requerenteJaConfirmou) {
        throw Exception('A confirmação do requerente é necessária antes da finalização pelo administrador.');
      }

      final bool adminJaFinalizou = chamadoData[kFieldAdminFinalizou] as bool? ?? false;
      if (adminJaFinalizou) {
         return; 
      }
      
      final String adminNome = adminUser.displayName?.trim().isNotEmpty ?? false
          ? adminUser.displayName!.trim()
          : (adminUser.email ?? 'Admin (${adminUser.uid.substring(0, 6)})');

      await docRef.update({
        kFieldAdminFinalizou: true,
        kFieldAdminFinalizouData: FieldValue.serverTimestamp(),
        kFieldAdminFinalizouUid: adminUser.uid,
        kFieldAdminFinalizouNome: adminNome,
        kFieldDataAtualizacao: FieldValue.serverTimestamp(),
        // kFieldStatus: 'Concluído', // Opcional: Mudar status final aqui se desejar
      });

      await adicionarComentarioSistema(
        chamadoId,
        'Chamado finalizado e confirmado pelo administrador ($adminNome).',
      );
    } catch (e) {
      print('Erro ao finalizar chamado pelo administrador $chamadoId: $e');
      throw Exception('Falha ao finalizar o chamado. Detalhes: ${e.toString()}');
    }
  }
}
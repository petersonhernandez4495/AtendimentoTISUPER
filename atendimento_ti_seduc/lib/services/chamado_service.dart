import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:intl/intl.dart';

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

class ChamadoService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _phoneMaskFormatter = MaskTextInputFormatter( mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')}, );

  Future<String> criarChamado({ required String? tipoSelecionado, required String celularContato, required String? equipamentoSelecionado, required String? internetConectadaSelecionado, required String marcaModelo, required String patrimonio, required String? problemaSelecionado, required String tecnicoResponsavel, required String? cidadeSelecionada, required String? instituicaoSelecionada, required String? cargoSelecionado, required String? atendimentoParaSelecionado, required bool isProfessorSelecionado, required String? setorSuperSelecionado, required String cidadeSuper, required String instituicaoManual, required String equipamentoOutro, required String problemaOutro, }) async { final user = _auth.currentUser; if (user == null) throw Exception('Usuário não autenticado.'); final String nomeFinalSolicitante = user.displayName?.trim().isNotEmpty ?? false ? user.displayName!.trim() : (user.email ?? "User (${user.uid.substring(0, 6)})"); final String creatorUid = user.uid; final String creatorPhone = celularContato.trim(); final String unmaskedPhone = _phoneMaskFormatter.unmaskText(creatorPhone); final dadosChamado = <String, dynamic>{ kFieldTipoSolicitante: tipoSelecionado, kFieldNomeSolicitante: nomeFinalSolicitante, kFieldCelularContato: creatorPhone, 'celular_contato_unmasked': unmaskedPhone, kFieldEquipamentoSolicitacao: equipamentoSelecionado, kFieldConectadoInternet: internetConectadaSelecionado, kFieldMarcaModelo: marcaModelo.trim().isEmpty ? null : marcaModelo.trim(), kFieldPatrimonio: patrimonio.trim(), kFieldProblemaOcorre: problemaSelecionado, kFieldTecnicoResponsavel: tecnicoResponsavel.trim().isEmpty ? null : tecnicoResponsavel.trim(), kFieldStatus: 'Aberto', kFieldPrioridade: 'Média', kFieldDataCriacao: FieldValue.serverTimestamp(), kFieldDataAtualizacao: FieldValue.serverTimestamp(), kFieldCreatorUid: creatorUid, 'creatorName': nomeFinalSolicitante, 'creatorPhone': creatorPhone, kFieldAuthUserDisplay: user.displayName, 'authUserEmail': user.email, kFieldAdminInativo: false, kFieldSolucao: null, kFieldDataAtendimento: null, kFieldRequerenteConfirmou: false, kFieldRequerenteConfirmouData: null, kFieldRequerenteConfirmouUid: null, if (tipoSelecionado == 'ESCOLA') ...{ kFieldCidade: cidadeSelecionada, kFieldCargoFuncao: cargoSelecionado, kFieldAtendimentoPara: atendimentoParaSelecionado, if (isProfessorSelecionado) 'observacao_cargo': 'Solicitante é Professor...', if (cidadeSelecionada == "OUTRO") ...{ kFieldInstituicaoManual: instituicaoManual.trim(), kFieldInstituicao: 'OUTRO (Ver $kFieldInstituicaoManual)', } else ...{ kFieldInstituicao: instituicaoSelecionada, kFieldInstituicaoManual: null, }, } else if (tipoSelecionado == 'SUPERINTENDENCIA') ...{ kFieldSetorSuper: setorSuperSelecionado, kFieldCidadeSuperintendencia: cidadeSuper.trim(), }, kFieldEquipamentoOutro: equipamentoSelecionado == "OUTRO" ? equipamentoOutro.trim() : null, kFieldProblemaOutro: problemaSelecionado == "OUTRO" ? problemaOutro.trim() : null, }; try { final docRef = await _db.collection(kCollectionChamados).add(dadosChamado); return docRef.id; } catch (e, s) { print('Erro criar chamado: $e\n$s'); throw Exception('Falha ao salvar chamado.'); } }
  Future<void> definirInatividadeAdministrativa(String chamadoId, bool inativo) async { if (chamadoId.isEmpty) throw ArgumentError('ID vazio.'); final docRef = _db.collection(kCollectionChamados).doc(chamadoId); try { await docRef.update({ kFieldAdminInativo: inativo, kFieldDataAtualizacao: FieldValue.serverTimestamp(), }); await adicionarComentarioSistema( chamadoId, inativo ? 'Chamado INATIVO adm.' : 'Chamado REATIVADO adm.' ); } catch (e, s) { print('Erro inatividade $chamadoId: $e\n$s'); throw Exception('Falha inatividade.'); } }
  Future<void> atualizarDetalhesAdmin({ required String chamadoId, required String status, String? prioridade, String? tecnicoResponsavel, String? solucao, Timestamp? dataAtendimento, }) async { if (chamadoId.isEmpty) throw ArgumentError('ID vazio.'); final docRef = _db.collection(kCollectionChamados).doc(chamadoId); final Map<String, dynamic> dataToUpdate = { kFieldStatus: status, kFieldDataAtualizacao: FieldValue.serverTimestamp(), if (prioridade != null) kFieldPrioridade: prioridade, if (tecnicoResponsavel != null) kFieldTecnicoResponsavel: tecnicoResponsavel.trim().isEmpty ? null : tecnicoResponsavel.trim(), kFieldSolucao: solucao, kFieldDataAtendimento: dataAtendimento, }; try { await docRef.update(dataToUpdate); print('Chamado $chamadoId atualizado (Admin).'); final List<String> changes = []; changes.add('St: "$status".'); if (prioridade != null) changes.add('P: "$prioridade".'); if (tecnicoResponsavel != null) changes.add(tecnicoResponsavel.trim().isEmpty ? 'Téc removido.' : 'Téc: "$tecnicoResponsavel".'); if (dataToUpdate.containsKey(kFieldSolucao)) { changes.add(solucao != null ? 'Solução reg.' : 'Solução removida.'); } if (dataToUpdate.containsKey(kFieldDataAtendimento)) { changes.add(dataAtendimento != null ? 'DtAtend: ${DateFormat('dd/MM/yyyy').format(dataAtendimento.toDate())}.' : 'DtAtend removida.'); } await adicionarComentarioSistema(chamadoId, changes.join(' ')); } catch (e, s) { print('Erro atualizar $chamadoId: $e\n$s'); throw Exception('Falha ao atualizar.'); } }
  Future<void> adicionarComentarioSistema(String chamadoId, String texto) async { if (chamadoId.isEmpty || texto.isEmpty) return; try { await _db.collection(kCollectionChamados).doc(chamadoId).collection('comentarios').add({ 'texto': texto, 'autorNome': 'Sistema', 'autorUid': 'sistema', 'timestamp': FieldValue.serverTimestamp(), 'isSystemMessage': true, }); } catch (e) { print("Erro comentário sistema $chamadoId: $e"); } }
  Future<void> confirmarServicoRequerente(String chamadoId, User currentUser) async { if (chamadoId.isEmpty) throw ArgumentError('ID vazio.'); final docRef = _db.collection(kCollectionChamados).doc(chamadoId); try { final chamadoDoc = await docRef.get(); if (!chamadoDoc.exists || chamadoDoc.data() == null) { throw Exception('Chamado não encontrado.'); } final chamadoData = chamadoDoc.data()!; final String? creatorUid = chamadoData[kFieldCreatorUid] as String?; if (creatorUid == null || creatorUid != currentUser.uid) { throw Exception('Apenas o solicitante original pode confirmar.'); } final bool jaConfirmado = chamadoData[kFieldRequerenteConfirmou] ?? false; if (jaConfirmado) { return; } await docRef.update({ kFieldRequerenteConfirmou: true, kFieldRequerenteConfirmouData: FieldValue.serverTimestamp(), kFieldRequerenteConfirmouUid: currentUser.uid, kFieldDataAtualizacao: FieldValue.serverTimestamp(), }); final String nomeConfirmador = currentUser.displayName?.isNotEmpty ?? false ? currentUser.displayName! : (currentUser.email ?? 'Req ${currentUser.uid.substring(0,6)}'); await adicionarComentarioSistema( chamadoId, 'Serviço confirmado pelo requerente ($nomeConfirmador).' ); } catch (e) { print('Erro confirmar serviço req $chamadoId: $e'); throw Exception('Falha ao registrar confirmação. $e'); } }
}
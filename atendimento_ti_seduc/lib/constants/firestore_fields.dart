// lib/constants/firestore_fields.dart

// Este arquivo centraliza os nomes das coleções e campos usados no Firestore,
// bem como valores de status comuns, para evitar erros de digitação e facilitar
// futuras refatorações.

// --- Coleções ---
const String kCollectionChamados = 'chamados';
const String kCollectionUsers = 'users';
const String kCollectionConfig = 'configuracoes';
// Adicione outras coleções se houver (ex: 'visitas_agendadas')

// --- Documentos Específicos (dentro de coleções) ---
const String kDocOpcoes = 'opcoesChamado';    // Em kCollectionConfig
const String kDocLocalidades = 'localidades'; // Em kCollectionConfig

// --- Campos Comuns (usados em múltiplos documentos/contextos) ---
const String kFieldStatus = 'status';
const String kFieldPrioridade = 'prioridade';
const String kFieldDataCriacao = 'data_abertura'; // Nome real do campo de data de criação do chamado
const String kFieldDataAtualizacao = 'data_atualizacao'; // Campo para timestamp da última atualização

// --- Campos do Documento 'Chamado' ---
const String kFieldTipoSolicitante = 'tipo_solicitante';
const String kFieldNomeSolicitante = 'nome_solicitante'; // Nome de quem abriu (pode vir do auth)
const String kFieldEmailSolicitante = 'email_solicitante'; // Email de quem abriu (pode vir do auth)
const String kFieldCreatorUid = 'solicitante_uid'; // Firebase Auth UID de quem criou
const String kFieldCelularContato = 'celular_contato';
const String kFieldCidade = 'cidade';
const String kFieldInstituicao = 'instituicao'; // Onde o chamado foi aberto / unidade organizacional
const String kFieldUnidadeOrganizacionalChamado = 'instituicao'; // Campo usado para filtro (pode ser o mesmo que kFieldInstituicao)
const String kFieldInstituicaoManual = 'instituicao_manual';
const String kFieldCargoSolicitante = 'cargo_solicitante'; // Cargo/Função de quem abriu
const String kFieldAtendimentoPara = 'atendimento_para'; // Setor dentro da escola/super
const String kFieldSetorSuper = 'setor_superintendencia'; // Setor específico da SUPER
const String kFieldCidadeSuperintendencia = 'cidade_superintendencia';

const String kFieldEquipamentoSelecionado = 'equipamento_selecionado';
const String kFieldEquipamentoOutro = 'equipamento_outro_descricao';
const String kFieldInternetConectada = 'internet_conectada';
const String kFieldMarcaModelo = 'marca_modelo';
const String kFieldPatrimonio = 'patrimonio';
const String kFieldProblemaSelecionado = 'problema_selecionado';
const String kFieldProblemaOutro = 'problema_outro_descricao';

const String kFieldTecnicoResponsavelNome = 'tecnico_responsavel_nome'; // Nome atribuído/que atendeu
const String kFieldTecnicoUid = 'tecnico_uid'; // UID do técnico atribuído/que atendeu
const String kFieldSolucao = 'solucao'; // Descrição da solução
const String kFieldSolucaoPorUid = 'solucao_por_uid'; // UID de quem registrou a solução
const String kFieldSolucaoPorNome = 'solucao_por_nome'; // Nome de quem registrou a solução
const String kFieldDataAtendimento = 'data_atendimento'; // Data em que o atendimento/solução ocorreu
const String kFieldDataSolucao = 'data_solucao'; // Timestamp de quando a solução foi registrada (pode ser o mesmo que data_atendimento)

const String kFieldRequerenteConfirmou = 'requerente_confirmou_solucao'; // bool
const String kFieldRequerenteConfirmouUid = 'requerente_confirmou_uid';
const String kFieldRequerenteConfirmouData = 'requerente_confirmou_data';
const String kFieldNomeRequerenteConfirmador = 'nome_requerente_confirmador'; // Nome de quem confirmou

const String kFieldAdminFinalizou = 'admin_finalizou_chamado'; // bool (arquivado)
const String kFieldAdminFinalizouUid = 'admin_finalizou_uid';
const String kFieldAdminFinalizouNome = 'admin_finalizou_nome';
const String kFieldAdminFinalizouData = 'admin_finalizou_data';
const String kFieldAdminInativo = 'admin_inativo'; // bool (visibilidade para requerente)

// --- Campos do Documento 'User' (na coleção kCollectionUsers) ---
const String kFieldUserRole = 'role_temp'; // Campo que define o papel (admin/user)
const String kFieldUserInstituicao = 'instituicao'; // Campo com a instituição do usuário (se aplicável)
const String kFieldUserAssinaturaUrl = 'assinatura_url'; // URL da assinatura salva
const String kFieldUserDisplayName = 'displayName'; // Se você salva o nome do Firebase Auth
const String kFieldUserPhone = 'phone'; // Se você salva o telefone do Firebase Auth

// --- Campos do Documento 'Config' (na coleção kCollectionConfig) ---
const String kFieldEscolasPorCidade = 'escolasPorCidade'; // No doc kDocLocalidades
// Adicione outros campos de configuração (ex: 'tipos', 'cargosEscola' do doc kDocOpcoes) se precisar referenciá-los

// --- Valores de Status Comuns ---
const String kStatusAberto = 'Aberto';
const String kStatusEmAndamento = 'Em Andamento'; // Adicione se usar
const String kStatusPendente = 'Pendente';       // Adicione se usar
const String kStatusPadraoSolicionado = 'Solucionado'; // Status antes da confirmação/arquivamento
const String kStatusCancelado = 'Cancelado';
const String kStatusFinalizado = 'Finalizado';     // Status após arquivamento pelo admin
// Adicione outros valores de status que você usa frequentemente
const String kStatusAguardandoAprovacao = 'Aguardando Aprovação';
const String kStatusAguardandoPeca = 'Aguardando Peça';
const String kStatusChamadoDuplicado = 'Chamado Duplicado';
const String kStatusAguardandoEquipamento = 'Aguardando Equipamento';
const String kStatusAtribuidoGSIOR = 'Atribuido para GSIOR';
const String kStatusGarantiaFabricante = 'Garantia Fabricante';


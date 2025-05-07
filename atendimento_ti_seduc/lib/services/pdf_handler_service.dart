// lib/services/pdf_handler_service.dart (CORRIGIDO - v2)

import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // Para debugPrint

// Importe seu gerador de PDF
import '../pdf_generator.dart' as pdfGen;

// REMOVIDO: Import da constante kCollectionChamados de outro arquivo

// --- DEFINIÇÃO LOCAL DA COLEÇÃO ---
// TODO: SUBSTITUA "chamados" pelo nome EXATO da sua coleção no Firestore.
const String _pdfHandlerCollectionChamados = "chamados";
// --- FIM DA DEFINIÇÃO LOCAL ---


// TODO: Confirme e ajuste estas strings para os nomes EXATOS dos campos no seu Firestore.
const String _serviceFieldRequerenteConfirmou = 'requerente_confirmou';
const String _serviceFieldRequerenteConfirmouUid = 'requerenteConfirmouUid';
const String _serviceFieldNomeRequerenteConfirmador = 'nomeRequerenteConfirmador';
const String _serviceFieldSolucaoPorUid = 'solucaoPorUid';
// Adicione outras constantes de campo que o PdfGenerator possa precisar se não forem
// passadas diretamente dentro de dadosChamadoAtuais para o generateTicketPdfBytes.

class PdfHandlerService {
  /// Busca a URL da assinatura de um usuário no Firestore.
  static Future<String?> _getSignatureUrlFromFirestore(String? userId) async {
    if (userId == null || userId.isEmpty) {
      return null;
    }
    try {
      // Assume que a coleção de usuários se chama 'users'
      DocumentSnapshot userDoc =
          await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userDoc.exists && userDoc.data() != null) {
        final userData = userDoc.data() as Map<String, dynamic>;
        // Assume que o campo da URL da assinatura se chama 'assinatura_url'
        return userData['assinatura_url'] as String?;
      }
    } catch (e) {
      debugPrint("PdfHandlerService: Erro ao buscar URL da assinatura para $userId: $e");
    }
    return null;
  }

  /// Gera os bytes do PDF para um chamado específico.
  ///
  /// Busca os dados mais recentes do chamado no Firestore,
  /// obtém as URLs das assinaturas (admin e requerente, se aplicável)
  /// e chama o PdfGenerator para criar o arquivo.
  static Future<Uint8List> gerarBytesPdfChamado({
    required String chamadoId,
  }) async {
    debugPrint("[PdfHandlerService] Iniciando geração de PDF para Chamado ID: $chamadoId");

    // 1. Buscar dados frescos do chamado
    // Usa a constante local _pdfHandlerCollectionChamados
    DocumentSnapshot chamadoDoc =
        await FirebaseFirestore.instance.collection(_pdfHandlerCollectionChamados).doc(chamadoId).get();

    if (!chamadoDoc.exists || chamadoDoc.data() == null) {
      debugPrint("[PdfHandlerService] Erro: Chamado ID $chamadoId não encontrado na coleção '$_pdfHandlerCollectionChamados' ou sem dados.");
      throw Exception("Chamado não encontrado ou dados inválidos para geração do PDF.");
    }
    final Map<String, dynamic> dadosChamadoAtuais = chamadoDoc.data() as Map<String, dynamic>;
    debugPrint("[PdfHandlerService] Dados frescos do Firestore para $chamadoId: $dadosChamadoAtuais");

    // 2. Extrair informações e buscar URLs de assinatura
    final bool requerenteConfirmou = dadosChamadoAtuais[_serviceFieldRequerenteConfirmou] as bool? ?? false;
    final String? uidRequerenteConfirmou = dadosChamadoAtuais[_serviceFieldRequerenteConfirmouUid] as String?;
    final String? adminSolucionouUid = dadosChamadoAtuais[_serviceFieldSolucaoPorUid] as String?;

    debugPrint("[PdfHandlerService] Requerente Confirmou: $requerenteConfirmou (lido do campo '$_serviceFieldRequerenteConfirmou')");
    debugPrint("[PdfHandlerService] UID Requerente Confirmou: $uidRequerenteConfirmou (lido do campo '$_serviceFieldRequerenteConfirmouUid')");
    debugPrint("[PdfHandlerService] UID Admin Solucionou: $adminSolucionouUid (lido do campo '$_serviceFieldSolucaoPorUid')");

    String? adminSignatureUrl;
    if (adminSolucionouUid != null && adminSolucionouUid.isNotEmpty) {
      adminSignatureUrl = await _getSignatureUrlFromFirestore(adminSolucionouUid);
      debugPrint("[PdfHandlerService] URL Assinatura Admin para $adminSolucionouUid: $adminSignatureUrl");
    }

    String? requesterSignatureUrl;
    if (requerenteConfirmou && uidRequerenteConfirmou != null && uidRequerenteConfirmou.isNotEmpty) {
      requesterSignatureUrl = await _getSignatureUrlFromFirestore(uidRequerenteConfirmou);
      debugPrint("[PdfHandlerService] URL Assinatura Requerente para $uidRequerenteConfirmou: $requesterSignatureUrl");
    } else {
      debugPrint("[PdfHandlerService] Não buscará assinatura do requerente. Condições: Confirmado=$requerenteConfirmou, UID=$uidRequerenteConfirmou");
    }

    // 3. Chamar o PdfGenerator
    final Uint8List pdfBytes = await pdfGen.PdfGenerator.generateTicketPdfBytes(
      chamadoId: chamadoId,
      dadosChamado: dadosChamadoAtuais,
      adminSignatureUrl: adminSignatureUrl,
      requesterSignatureUrl: requesterSignatureUrl,
    );

    debugPrint("[PdfHandlerService] PDF gerado com sucesso para Chamado ID: $chamadoId. Tamanho: ${pdfBytes.length} bytes.");
    return pdfBytes;
  }
}

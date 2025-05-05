import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:signature/signature.dart';
import 'package:firebase_storage/firebase_storage.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _jobTitleController = TextEditingController();
  final _institutionController = TextEditingController();
  final SignatureController _signatureController = SignatureController( penStrokeWidth: 2.5, penColor: Colors.black, exportBackgroundColor: Colors.white, );
  User? _currentUser;
  bool _isLoading = true;
  bool _isSavingProfile = false;
  bool _isSavingSignature = false;
  String? _errorMessage;
  String? _assinaturaUrlAtual;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser != null) { _loadInitialData(); } else { if (mounted) { setState(() { _isLoading = false; _errorMessage = "Usuário não autenticado."; }); } }
  }

  @override
  void dispose() {
    _nameController.dispose(); _phoneController.dispose(); _jobTitleController.dispose(); _institutionController.dispose(); _signatureController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return; setState(() => _isLoading = true);
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).get();
      if (userDoc.exists && mounted) {
        final data = userDoc.data() as Map<String, dynamic>? ?? {};
        _nameController.text = _currentUser!.displayName?.isNotEmpty ?? false ? _currentUser!.displayName! : (data['name'] as String? ?? '');
        _phoneController.text = data['phone'] as String? ?? ''; _jobTitleController.text = data['jobTitle'] as String? ?? ''; _institutionController.text = data['institution'] as String? ?? '';
        _assinaturaUrlAtual = data['assinatura_url'] as String?;
      } else if (mounted) { _nameController.text = _currentUser!.displayName?.isNotEmpty ?? false ? _currentUser!.displayName! : ''; }
      if (mounted) { setState(() => _isLoading = false); }
    } catch (e) { if (mounted) { setState(() { _isLoading = false; _errorMessage = "Erro ao carregar dados."; }); } }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return; if (_currentUser == null || !mounted) return; setState(() => _isSavingProfile = true);
    final n = _nameController.text.trim(); final p = _phoneController.text.trim(); final j = _jobTitleController.text.trim(); final i = _institutionController.text.trim();
    try {
      await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).set({ 'name': n, 'phone': p, 'jobTitle': j, 'institution': i, 'email': _currentUser!.email, }, SetOptions(merge: true));
      if (_currentUser!.displayName != n) { await _currentUser!.updateDisplayName(n); }
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Perfil atualizado!'), backgroundColor: Colors.green), ); }
    } catch (e) { if (mounted) { ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red), ); }
    } finally { if (mounted) { setState(() => _isSavingProfile = false); } }
  }

  Future<void> _saveSignature() async {
    if (_signatureController.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Desenhe sua assinatura.'))); return; }
    if (_currentUser == null || !mounted) return;
    setState(() { _isSavingSignature = true; });
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    Uint8List? data;
    try {
      data = await _signatureController.toPngBytes(); if (data == null) throw Exception('Exportação falhou.');
      final String filePath = 'assinaturas_usuarios/${_currentUser!.uid}/assinatura.png';
      final storageRef = FirebaseStorage.instance.ref().child(filePath);
      final metadata = SettableMetadata(contentType: 'image/png');
      final uploadTask = storageRef.putData(data, metadata);
      final snapshot = await uploadTask;
      if (snapshot.state == TaskState.success) {
        String downloadUrl;
        try { downloadUrl = await snapshot.ref.getDownloadURL(); } catch (e) { throw Exception("Falha ao obter URL pós-upload. VERIFIQUE AS REGRAS DO STORAGE!"); }
        await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).set({ 'assinatura_url': downloadUrl, 'assinatura_atualizada_em': FieldValue.serverTimestamp(), }, SetOptions(merge: true));
        if (mounted) { setState(() { _assinaturaUrlAtual = downloadUrl; _signatureController.clear(); }); scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Assinatura salva!'), backgroundColor: Colors.green)); }
      } else { throw Exception("Falha no upload (Estado: ${snapshot.state}). Verifique as regras."); }
    } catch (e) {
      if (mounted) { String errorMsg = 'Erro: $e'; if (e.toString().contains('permission-denied') || e.toString().contains('object-not-found')) { errorMsg = 'Erro: Verifique as Regras de Segurança do Storage ou conexão.'; } scaffoldMessenger.showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: Colors.red, duration: const Duration(seconds: 6),)); }
    } finally { if (mounted) { setState(() { _isSavingSignature = false; }); } }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar( title: const Text('Editar Perfil e Assinatura'), actions: [ Padding( padding: const EdgeInsets.only(right: 8.0), child: _isSavingProfile ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))) : IconButton( icon: const Icon(Icons.person_outline), onPressed: _saveProfile, tooltip: 'Salvar Dados do Perfil', ), ), ], ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) { return const Center(child: CircularProgressIndicator()); }
    if (_errorMessage != null) { return Center( child: Padding( padding: const EdgeInsets.all(16.0), child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)), ), ); }
    return Form( key: _formKey, child: ListView( padding: const EdgeInsets.all(16.0), children: [
          TextFormField( controller: _nameController, decoration: const InputDecoration( labelText: 'Nome Completo', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder(), ), validator: (v) { if (v == null || v.trim().isEmpty) return 'Informe nome.'; return null; }, textInputAction: TextInputAction.next, ),
          const SizedBox(height: 16),
          TextFormField( controller: _phoneController, decoration: const InputDecoration( labelText: 'Telefone', hintText:'(Opcional)', prefixIcon: Icon(Icons.phone_outlined), border: OutlineInputBorder(), ), keyboardType: TextInputType.phone, textInputAction: TextInputAction.next, ),
          const SizedBox(height: 16),
          TextFormField( controller: _jobTitleController, decoration: const InputDecoration( labelText: 'Cargo / Função', hintText: '(Opcional)', prefixIcon: Icon(Icons.work_outline), border: OutlineInputBorder(), ), textInputAction: TextInputAction.next, ),
          const SizedBox(height: 16),
          TextFormField( controller: _institutionController, decoration: const InputDecoration( labelText: 'Instituição / Lotação', hintText:'(Opcional)', prefixIcon: Icon(Icons.account_balance_outlined), border: OutlineInputBorder(), ), textInputAction: TextInputAction.done, ),
          const SizedBox(height: 24), const Divider(), const SizedBox(height: 16),
          const Text('Assinatura Digital', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(height: 8),
          const Text('Desenhe sua assinatura abaixo.', style: TextStyle(fontSize: 13, color: Colors.grey)), const SizedBox(height: 10),
          Container( height: 180, decoration: BoxDecoration( border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4), color: Colors.grey[100], ), child: Signature( controller: _signatureController, backgroundColor: Colors.grey[100]!, ), ),
          const SizedBox(height: 10),
          Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ TextButton.icon( icon: const Icon(Icons.clear, size: 18), label: const Text('Limpar'), onPressed: () { _signatureController.clear(); }, style: TextButton.styleFrom(foregroundColor: Colors.grey[700]), ), ElevatedButton.icon( icon: _isSavingSignature ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_alt_outlined, size: 18), label: const Text('Salvar Assinatura'), onPressed: _isSavingSignature ? null : _saveSignature, ), ], ),
          if (_assinaturaUrlAtual != null && !_isLoading) ...[
             const SizedBox(height: 20), const Divider(), const SizedBox(height: 10),
             const Text("Assinatura Salva:", style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 5),
             Container( constraints: const BoxConstraints(maxHeight: 60), alignment: Alignment.centerLeft, child: Image.network( _assinaturaUrlAtual!, fit: BoxFit.contain, loadingBuilder: (c, child, p) { return p == null ? child : const Center(child: CircularProgressIndicator()); }, errorBuilder: (c, error, s) { return const Text('Erro ao carregar.', style: TextStyle(color: Colors.red)); },), ),
             const SizedBox(height: 10), ],
          const SizedBox(height: 30),
        ], ), );
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Potencialmente importe FirebaseAuth se adicionar verificações como impedir auto-edição
// import 'package:firebase_auth/firebase_auth.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  // Referência à coleção 'users' no Firestore
  final CollectionReference _usersCollection =
      FirebaseFirestore.instance.collection('users');

  // Lista das roles disponíveis para edição
  // Atualizado para incluir 'inativo'
  final List<String> _availableRoles = ['admin', 'requester', 'inativo'];

  // Variável para guardar o estado de carregamento da atualização de uma role específica
  String?
      _updatingUserId; // Guarda o ID do usuário cuja role está sendo atualizada

  // --- Função para atualizar a role no Firestore ---
  Future<void> _updateUserRole(String userId, String newRole) async {
    // TODO: Considerar adicionar verificação para não permitir alterar a própria role
    // final currentUser = FirebaseAuth.instance.currentUser;
    // if (currentUser != null && currentUser.uid == userId) {
    //   if (mounted) {
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       const SnackBar(content: Text('Você não pode alterar seu próprio perfil aqui.'), backgroundColor: Colors.orange),
    //     );
    //   }
    //   return;
    // }

    setState(() {
      _updatingUserId = userId; // Indica que este usuário está sendo atualizado
    });

    try {
      // Atualiza apenas o campo 'role_temp' no documento do usuário especificado
      await _usersCollection.doc(userId).update({'role_temp': newRole});

      if (mounted) {
        // Verifica se o widget ainda está na árvore
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Perfil de ${userId.substring(0, 6)}... atualizado para $newRole.'), // Feedback mais claro
            backgroundColor: Colors.green,
            duration:
                const Duration(seconds: 2), // Duração mais curta para sucesso
          ),
        );
      }
    } catch (e) {
      print("Erro ao atualizar perfil $userId: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar perfil: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Garante que o estado de loading seja resetado mesmo se o widget for desmontado
      // durante o processo (embora 'mounted' já proteja setState)
      if (mounted) {
        setState(() {
          _updatingUserId = null; // Finaliza o estado de atualização
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Usuários e Perfis'),
        // Adicionar talvez uma ação de refresh manual? (Embora StreamBuilder atualize)
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.refresh),
        //     tooltip: 'Recarregar lista',
        //     onPressed: () {
        //       // Força a reconstrução (pode ser útil em alguns cenários)
        //       setState(() {});
        //     },
        //   ),
        // ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Usa StreamBuilder para ouvir atualizações em tempo real da coleção 'users'
        // Qualquer mudança no Firestore (add/edit/delete) refletirá aqui
        stream: _usersCollection
            .orderBy('name') // Ordena os usuários pelo nome alfabeticamente
            .snapshots(), // Cria o stream
        builder: (context, snapshot) {
          // --- Tratamento de Estados do Stream ---
          if (snapshot.hasError) {
            print("Erro no StreamBuilder UserManagement: ${snapshot.error}");
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Erro ao carregar usuários: ${snapshot.error}\nVerifique a conexão e as permissões do Firestore.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            );
          }

          // Mostra indicador de carregamento enquanto espera os dados iniciais
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Verifica se temos dados e se a lista de documentos não está vazia
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
                child: Text(
              'Nenhum usuário encontrado na base de dados.',
              style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
            ));
          }

          // --- Lista de Usuários ---
          // Se chegou aqui, temos dados
          final userDocs = snapshot.data!.docs;

          return ListView.separated(
            itemCount: userDocs.length,
            separatorBuilder: (context, index) => const Divider(
                height: 1,
                thickness: 0.5,
                indent: 16,
                endIndent: 16), // Linha divisória mais sutil
            itemBuilder: (context, index) {
              final userDoc = userDocs[index];
              // Pega os dados do documento como um mapa
              // Usar `as Map<String, dynamic>?` para segurança contra dados malformados
              final userData = userDoc.data() as Map<String, dynamic>? ?? {};
              final userId = userDoc.id; // UID do usuário (ID do documento)

              // Obtém os dados do usuário (com tratamento para campos ausentes/nulos)
              final String name =
                  userData['name'] as String? ?? 'Nome não disponível';
              final String email =
                  userData['email'] as String? ?? 'Email não disponível';
              final String? currentRole =
                  userData['role_temp'] as String?; // A role pode ser nula

              // Verifica se este usuário específico está sendo atualizado no momento
              final bool isUpdating = _updatingUserId == userId;

              return ListTile(
                leading: CircleAvatar(
                  // Adiciona um avatar simples
                  // Use cores baseadas no tema para consistência
                  backgroundColor:
                      Theme.of(context).colorScheme.secondaryContainer,
                  child: Text(
                    name.isNotEmpty
                        ? name[0].toUpperCase()
                        : '?', // Mostra a primeira letra do nome
                    style: TextStyle(
                        color:
                            Theme.of(context).colorScheme.onSecondaryContainer),
                  ),
                ),
                title: Text(
                  name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500), // Nome em destaque
                ),
                subtitle: Column(
                  // Usa Column para alinhar email e outras infos se necessário
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(email,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall), // Email com estilo menor
                    // Poderia adicionar mais informações aqui (descomente se necessário)
                    // if (userData.containsKey('jobTitle') && userData['jobTitle'] != null)
                    //   Padding(
                    //     padding: const EdgeInsets.only(top: 2.0),
                    //     child: Text(userData['jobTitle'], style: Theme.of(context).textTheme.labelSmall),
                    //   ),
                  ],
                ),
                trailing: SizedBox(
                  // Container para o controle da role
                  width:
                      165, // Largura ajustada para os nomes completos das roles
                  child: isUpdating // Se estiver atualizando ESTE usuário...
                      ? const Center(
                          // Mostra um indicador de progresso centralizado
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          ),
                        )
                      : DropdownButtonHideUnderline(
                          // Esconde a linha padrão do dropdown
                          child: DropdownButton<String>(
                            value:
                                currentRole, // O valor atual da role no banco
                            // Texto exibido quando o valor é nulo
                            hint: const Text('Definir Perfil',
                                style: TextStyle(
                                    fontSize: 13, color: Colors.grey)),
                            isExpanded:
                                true, // Faz o dropdown ocupar a largura do SizedBox
                            items: _availableRoles.map((role) {
                              // Cria os itens do dropdown
                              return DropdownMenuItem<String>(
                                value: role,
                                child: Text(
                                  // Melhora a legibilidade dos nomes das roles
                                  // Atualizado para incluir 'Inativo'
                                  role == 'admin'
                                      ? 'Administrador'
                                      : role == 'requester'
                                          ? 'Requisitante'
                                          : role == 'inativo'
                                              ? 'Inativo'
                                              : role, // Fallback para o nome da role
                                  style: TextStyle(
                                    fontSize:
                                        13, // Tamanho de fonte menor para caber
                                    // Destaca a opção que está selecionada atualmente
                                    fontWeight: currentRole == role
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: currentRole == role
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                  ),
                                  overflow: TextOverflow
                                      .ellipsis, // Evita quebra de texto
                                ),
                              );
                            }).toList(), // Converte o resultado do map em uma lista de itens
                            onChanged: (newRole) {
                              // Chamado quando uma nova role é selecionada
                              // Só atualiza se um valor foi selecionado e é diferente do atual
                              if (newRole != null && newRole != currentRole) {
                                _updateUserRole(userId,
                                    newRole); // Chama a função de atualização
                              }
                            },
                            // Ícone visualmente mais integrado
                            icon: Icon(Icons.edit_attributes_outlined,
                                size: 20,
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.7)),
                          ),
                        ),
                ),
                // Desabilita interações com o ListTile enquanto a role está sendo atualizada
                // Evita cliques duplos ou seleção de outro item durante a atualização
                enabled: !isUpdating,
                // Adiciona um leve efeito visual quando desabilitado para indicar o loading
                tileColor: isUpdating ? Colors.grey.withOpacity(0.05) : null,
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 8.0, horizontal: 16.0), // Ajusta padding interno
              );
            },
          );
        },
      ),
    );
  }
}

// services/chamado_search_logic.dart
import '../models/chamado_model.dart'; // <<<--- GARANTA QUE ESTE IMPORT ESTÁ CORRETO

class ChamadoSearchLogic {
  List<Chamado> _todosOsChamadosOriginal = [];
  List<Chamado> _chamadosFiltrados = [];

  void setChamadosSource(List<Chamado> todosOsChamados) {
    _todosOsChamadosOriginal = List.from(todosOsChamados);
  }

  void filterChamadosComQuery(String query) {
    final queryLower = query.trim().toLowerCase();

    if (queryLower.isEmpty) {
      _chamadosFiltrados = List.from(_todosOsChamadosOriginal);
    } else {
      _chamadosFiltrados = _todosOsChamadosOriginal.where((chamado) {
        // A checagem 'is Chamado' é redundante se a lista for bem tipada, mas segura.
        return chamado.matchesQuery(queryLower);
      }).toList();
    }
  }

  List<Chamado> get resultadosFiltrados => _chamadosFiltrados;
}

enum SymbolKind { staticKind, fieldKind, argKind, varKind, none }

class SymbolInfo {
  final String type;
  final SymbolKind kind;
  final int index;
  SymbolInfo(this.type, this.kind, this.index);
}

class SymbolTable {
  final Map<String, SymbolInfo> _classScope = {};
  final Map<String, SymbolInfo> _subroutineScope = {};
  final Map<SymbolKind, int> _indices = {
    SymbolKind.staticKind: 0, SymbolKind.fieldKind: 0,
    SymbolKind.argKind: 0, SymbolKind.varKind: 0,
  };

  void startSubroutine() {
    _subroutineScope.clear();
    _indices[SymbolKind.argKind] = 0;
    _indices[SymbolKind.varKind] = 0;
  }

  void define(String name, String type, SymbolKind kind) {
    int index = _indices[kind]!;
    if (kind == SymbolKind.staticKind || kind == SymbolKind.fieldKind) {
      _classScope[name] = SymbolInfo(type, kind, index);
    } else {
      _subroutineScope[name] = SymbolInfo(type, kind, index);
    }
    _indices[kind] = index + 1;
  }

  int varCount(SymbolKind kind) => _indices[kind]!;

  SymbolInfo? _lookup(String name) => _subroutineScope[name] ?? _classScope[name];

  SymbolKind kindOf(String name) => _lookup(name)?.kind ?? SymbolKind.none;
  String typeOf(String name) => _lookup(name)?.type ?? "";
  int indexOf(String name) => _lookup(name)?.index ?? -1;
}
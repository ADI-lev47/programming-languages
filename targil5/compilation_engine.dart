import 'jack_tokenizer.dart';
import 'symbol_table.dart';
import 'vm_writer.dart';

class CompilationEngine {
  final JackTokenizer _tk;
  final VMWriter _vm;
  final SymbolTable _st = SymbolTable();
  String _className = "";
  int _labelCounter = 0;

  CompilationEngine(this._tk, this._vm) {
    if (_tk.hasMoreTokens()) compileClass();
  }

  String _nextLabel() => "LABEL_${_labelCounter++}";

  void compileClass() {
    _tk.advance(); // 'class'
    _className = _tk.currentToken();
    _tk.advance(); // className
    _tk.advance(); // '{'
    while (_tk.currentToken() == 'static' || _tk.currentToken() == 'field') {
      compileClassVarDec();
    }
    while (['constructor', 'function', 'method'].contains(_tk.currentToken())) {
      compileSubroutine();
    }
    _tk.advance(); // '}'
  }

  void compileClassVarDec() {
    SymbolKind kind = _tk.currentToken() == 'static' ? SymbolKind.staticKind : SymbolKind.fieldKind;
    _tk.advance();
    String type = _tk.currentToken();
    _tk.advance();
    String name = _tk.currentToken();
    _st.define(name, type, kind);
    _tk.advance();
    while (_tk.currentToken() == ',') {
      _tk.advance(); // ','
      name = _tk.currentToken();
      _st.define(name, type, kind);
      _tk.advance();
    }
    _tk.advance(); // ';'
  }

  void compileSubroutine() {
    _st.startSubroutine();
    String subType = _tk.currentToken(); // constructor, function, method
    _tk.advance();
    _tk.advance(); // type or void
    String subName = _tk.currentToken();
    _tk.advance();
    
    if (subType == 'method') {
      _st.define('this', _className, SymbolKind.argKind);
    }
    
    _tk.advance(); // '('
    compileParameterList();
    _tk.advance(); // ')'
    
    _tk.advance(); // '{'
    while (_tk.currentToken() == 'var') {
      compileVarDec();
    }
    
    _vm.writeFunction("$_className.$subName", _st.varCount(SymbolKind.varKind));
    
    if (subType == 'method') {
      _vm.writePush(Segment.argSeg, 0);
      _vm.writePop(Segment.pointerSeg, 0);
    } else if (subType == 'constructor') {
      _vm.writePush(Segment.constSeg, _st.varCount(SymbolKind.fieldKind));
      _vm.writeCall("Memory.alloc", 1);
      _vm.writePop(Segment.pointerSeg, 0);
    }
    
    compileStatements();
    _tk.advance(); // '}'
  }

  void compileParameterList() {
    if (_tk.currentToken() != ')') {
      String type = _tk.currentToken();
      _tk.advance();
      String name = _tk.currentToken();
      _st.define(name, type, SymbolKind.argKind);
      _tk.advance();
      while (_tk.currentToken() == ',') {
        _tk.advance(); // ','
        type = _tk.currentToken();
        _tk.advance();
        name = _tk.currentToken();
        _st.define(name, type, SymbolKind.argKind);
        _tk.advance();
      }
    }
  }

  void compileVarDec() {
    _tk.advance(); // 'var'
    String type = _tk.currentToken();
    _tk.advance();
    String name = _tk.currentToken();
    _st.define(name, type, SymbolKind.varKind);
    _tk.advance();
    while (_tk.currentToken() == ',') {
      _tk.advance(); // ','
      name = _tk.currentToken();
      _st.define(name, type, SymbolKind.varKind);
      _tk.advance();
    }
    _tk.advance(); // ';'
  }

  void compileStatements() {
    while (['let', 'if', 'while', 'do', 'return'].contains(_tk.currentToken())) {
      switch (_tk.currentToken()) {
        case 'let': compileLet(); break;
        case 'if': compileIf(); break;
        case 'while': compileWhile(); break;
        case 'do': compileDo(); break;
        case 'return': compileReturn(); break;
      }
    }
  }

  Segment _kindToSegment(SymbolKind kind) {
    switch (kind) {
      case SymbolKind.staticKind: return Segment.staticSeg;
      case SymbolKind.fieldKind: return Segment.thisSeg;
      case SymbolKind.argKind: return Segment.argSeg;
      case SymbolKind.varKind: return Segment.localSeg;
      default: return Segment.tempSeg;
    }
  }

  void compileLet() {
    _tk.advance(); // 'let'
    String varName = _tk.currentToken();
    _tk.advance();
    
    bool isArray = false;
    if (_tk.currentToken() == '[') {
      isArray = true;
      _tk.advance(); // '['
      compileExpression();
      _tk.advance(); // ']'
      _vm.writePush(_kindToSegment(_st.kindOf(varName)), _st.indexOf(varName));
      _vm.writeArithmetic(Command.addCmd);
    }
    
    _tk.advance(); // '='
    compileExpression();
    _tk.advance(); // ';'
    
    if (isArray) {
      _vm.writePop(Segment.tempSeg, 0);
      _vm.writePop(Segment.pointerSeg, 1);
      _vm.writePush(Segment.tempSeg, 0);
      _vm.writePop(Segment.thatSeg, 0);
    } else {
      _vm.writePop(_kindToSegment(_st.kindOf(varName)), _st.indexOf(varName));
    }
  }

  void compileDo() {
    _tk.advance(); // 'do'
    compileExpression(isCall: true);
    _vm.writePop(Segment.tempSeg, 0); // Ignore return value
    _tk.advance(); // ';'
  }

  void compileIf() {
    String l1 = _nextLabel();
    String l2 = _nextLabel();
    _tk.advance(); // 'if'
    _tk.advance(); // '('
    compileExpression();
    _tk.advance(); // ')'
    _vm.writeArithmetic(Command.notCmd);
    _vm.writeIf(l1);
    _tk.advance(); // '{'
    compileStatements();
    _tk.advance(); // '}'
    _vm.writeGoto(l2);
    _vm.writeLabel(l1);
    if (_tk.currentToken() == 'else') {
      _tk.advance(); // 'else'
      _tk.advance(); // '{'
      compileStatements();
      _tk.advance(); // '}'
    }
    _vm.writeLabel(l2);
  }

  void compileWhile() {
    String l1 = _nextLabel();
    String l2 = _nextLabel();
    _vm.writeLabel(l1);
    _tk.advance(); // 'while'
    _tk.advance(); // '('
    compileExpression();
    _tk.advance(); // ')'
    _vm.writeArithmetic(Command.notCmd);
    _vm.writeIf(l2);
    _tk.advance(); // '{'
    compileStatements();
    _tk.advance(); // '}'
    _vm.writeGoto(l1);
    _vm.writeLabel(l2);
  }

  void compileReturn() {
    _tk.advance(); // 'return'
    if (_tk.currentToken() != ';') {
      compileExpression();
    } else {
      _vm.writePush(Segment.constSeg, 0); // void return
    }
    _vm.writeReturn();
    _tk.advance(); // ';'
  }

  void compileExpression({bool isCall = false}) {
    if (isCall) {
      compileTerm(isCall: true);
      return;
    }
    compileTerm();
    while (['+', '-', '*', '/', '&', '|', '<', '>', '='].contains(_tk.currentToken())) {
      String op = _tk.currentToken();
      _tk.advance();
      compileTerm();
      switch (op) {
        case '+': _vm.writeArithmetic(Command.addCmd); break;
        case '-': _vm.writeArithmetic(Command.subCmd); break;
        case '*': _vm.writeCall("Math.multiply", 2); break;
        case '/': _vm.writeCall("Math.divide", 2); break;
        case '&': _vm.writeArithmetic(Command.andCmd); break;
        case '|': _vm.writeArithmetic(Command.orCmd); break;
        case '<': _vm.writeArithmetic(Command.ltCmd); break;
        case '>': _vm.writeArithmetic(Command.gtCmd); break;
        case '=': _vm.writeArithmetic(Command.eqCmd); break;
      }
    }
  }

  void compileTerm({bool isCall = false}) {
    TokenType type = _tk.tokenType();
    if (type == TokenType.intConst) {
      _vm.writePush(Segment.constSeg, int.parse(_tk.currentToken()));
      _tk.advance();
    } else if (type == TokenType.stringConst) {
      String str = _tk.currentToken().replaceAll('"', '');
      _vm.writePush(Segment.constSeg, str.length);
      _vm.writeCall("String.new", 1);
      for (int i = 0; i < str.length; i++) {
        _vm.writePush(Segment.constSeg, str.codeUnitAt(i));
        _vm.writeCall("String.appendChar", 2);
      }
      _tk.advance();
    } else if (type == TokenType.keyword) {
      String kw = _tk.currentToken();
      if (kw == 'this') {
        _vm.writePush(Segment.pointerSeg, 0);
      } else {
        _vm.writePush(Segment.constSeg, 0);
        if (kw == 'true') _vm.writeArithmetic(Command.notCmd); // true is -1
      }
      _tk.advance();
    } else if (_tk.currentToken() == '(') {
      _tk.advance(); // '('
      compileExpression();
      _tk.advance(); // ')'
    } else if (['-', '~'].contains(_tk.currentToken())) {
      String op = _tk.currentToken();
      _tk.advance();
      compileTerm();
      _vm.writeArithmetic(op == '-' ? Command.negCmd : Command.notCmd);
    } else {
      String name = _tk.currentToken();
      _tk.advance();
      if (_tk.currentToken() == '[') {
        _tk.advance(); // '['
        compileExpression();
        _tk.advance(); // ']'
        _vm.writePush(_kindToSegment(_st.kindOf(name)), _st.indexOf(name));
        _vm.writeArithmetic(Command.addCmd);
        _vm.writePop(Segment.pointerSeg, 1);
        _vm.writePush(Segment.thatSeg, 0);
      } else if (_tk.currentToken() == '(' || _tk.currentToken() == '.') {
        // Subroutine call
        String funcName = name;
        int nArgs = 0;
        if (_tk.currentToken() == '.') {
          _tk.advance(); // '.'
          String subName = _tk.currentToken();
          _tk.advance(); // subName
          
          SymbolKind kind = _st.kindOf(name);
          if (kind != SymbolKind.none) {
            _vm.writePush(_kindToSegment(kind), _st.indexOf(name));
            funcName = "${_st.typeOf(name)}.$subName";
            nArgs = 1;
          } else {
            funcName = "$name.$subName";
          }
        } else {
          _vm.writePush(Segment.pointerSeg, 0);
          funcName = "$_className.$name";
          nArgs = 1;
        }
        _tk.advance(); // '('
        nArgs += compileExpressionList();
        _tk.advance(); // ')'
        _vm.writeCall(funcName, nArgs);
      } else {
        if (!isCall) _vm.writePush(_kindToSegment(_st.kindOf(name)), _st.indexOf(name));
      }
    }
  }

  int compileExpressionList() {
    int nArgs = 0;
    if (_tk.currentToken() != ')') {
      compileExpression();
      nArgs++;
      while (_tk.currentToken() == ',') {
        _tk.advance(); // ','
        compileExpression();
        nArgs++;
      }
    }
    return nArgs;
  }
}
// parser.dart
// Part 2 of Project 10: Parsing
// Reads the token list produced by Tokenizer and generates xxx.xml

import 'tokenizer.dart';

class Parser {
  final List<Token> _tokens;
  int _pos = 0;
  final StringBuffer _out = StringBuffer();
  int _indent = 0;

  Parser(this._tokens);

  // ─── helpers ────────────────────────────────────────────────────────────────

  Token get _current => _tokens[_pos];

  String get _currentValue => _current.value;

  Token _consume() {
    final t = _tokens[_pos];
    _pos++;
    return t;
  }

  /// Write a terminal token (keyword / symbol / identifier / constant)
  void _writeTerminal(Token t) {
    _writeLine('<${t.typeName}> ${t.xmlValue} </${t.typeName}>');
  }

  /// Consume and write the current token (must match expected value)
  void _eat(String expectedValue) {
    if (_currentValue != expectedValue) {
      throw Exception(
          'Expected "$expectedValue" but got "$_currentValue" at pos $_pos');
    }
    _writeTerminal(_consume());
  }

  /// Consume and write the current token (any token of expected type)
  void _eatType(TokenType type) {
    if (_current.type != type) {
      throw Exception(
          'Expected type ${type} but got ${_current.type} ("$_currentValue") at pos $_pos');
    }
    _writeTerminal(_consume());
  }

  void _writeLine(String line) {
    _out.writeln('${'  ' * _indent}$line');
  }

  void _openTag(String tag) {
    _writeLine('<$tag>');
    _indent++;
  }

  void _closeTag(String tag) {
    _indent--;
    _writeLine('</$tag>');
  }

  // ─── grammar rules ──────────────────────────────────────────────────────────

  /// class: 'class' className '{' classVarDec* subroutineDec* '}'
  void _compileClass() {
    _openTag('class');
    _eat('class');
    _eatType(TokenType.identifier); // className
    _eat('{');
    while (_currentValue == 'static' || _currentValue == 'field') {
      _compileClassVarDec();
    }
    while (_currentValue == 'constructor' ||
        _currentValue == 'function' ||
        _currentValue == 'method') {
      _compileSubroutineDec();
    }
    _eat('}');
    _closeTag('class');
  }

  /// classVarDec: ('static'|'field') type varName (',' varName)* ';'
  void _compileClassVarDec() {
    _openTag('classVarDec');
    _eatType(TokenType.keyword); // 'static' or 'field'
    _compileType();
    _eatType(TokenType.identifier); // varName
    while (_currentValue == ',') {
      _eat(',');
      _eatType(TokenType.identifier);
    }
    _eat(';');
    _closeTag('classVarDec');
  }

  /// type: 'int' | 'char' | 'boolean' | className
  void _compileType() {
    if (_current.type == TokenType.keyword) {
      _eatType(TokenType.keyword);
    } else {
      _eatType(TokenType.identifier); // className
    }
  }

  /// subroutineDec: ('constructor'|'function'|'method') ('void'|type)
  ///                subroutineName '(' parameterList ')' subroutineBody
  void _compileSubroutineDec() {
    _openTag('subroutineDec');
    _eatType(TokenType.keyword); // constructor / function / method
    // return type: 'void' or type
    if (_currentValue == 'void') {
      _eat('void');
    } else {
      _compileType();
    }
    _eatType(TokenType.identifier); // subroutineName
    _eat('(');
    _compileParameterList();
    _eat(')');
    _compileSubroutineBody();
    _closeTag('subroutineDec');
  }

  /// parameterList: ((type varName) (',' type varName)*)?
  /// Always opens the tag, even if empty.
  void _compileParameterList() {
    _openTag('parameterList');
    if (_currentValue != ')') {
      _compileType();
      _eatType(TokenType.identifier);
      while (_currentValue == ',') {
        _eat(',');
        _compileType();
        _eatType(TokenType.identifier);
      }
    }
    _closeTag('parameterList');
  }

  /// subroutineBody: '{' varDec* statements '}'
  void _compileSubroutineBody() {
    _openTag('subroutineBody');
    _eat('{');
    while (_currentValue == 'var') {
      _compileVarDec();
    }
    _compileStatements();
    _eat('}');
    _closeTag('subroutineBody');
  }

  /// varDec: 'var' type varName (',' varName)* ';'
  void _compileVarDec() {
    _openTag('varDec');
    _eat('var');
    _compileType();
    _eatType(TokenType.identifier);
    while (_currentValue == ',') {
      _eat(',');
      _eatType(TokenType.identifier);
    }
    _eat(';');
    _closeTag('varDec');
  }

  /// statements: statement*
  void _compileStatements() {
    _openTag('statements');
    while (true) {
      if (_currentValue == 'let') {
        _compileLet();
      } else if (_currentValue == 'if') {
        _compileIf();
      } else if (_currentValue == 'while') {
        _compileWhile();
      } else if (_currentValue == 'do') {
        _compileDo();
      } else if (_currentValue == 'return') {
        _compileReturn();
      } else {
        break;
      }
    }
    _closeTag('statements');
  }

  /// letStatement: 'let' varName ('[' expression ']')? '=' expression ';'
  void _compileLet() {
    _openTag('letStatement');
    _eat('let');
    _eatType(TokenType.identifier); // varName
    if (_currentValue == '[') {
      _eat('[');
      _compileExpression();
      _eat(']');
    }
    _eat('=');
    _compileExpression();
    _eat(';');
    _closeTag('letStatement');
  }

  /// ifStatement: 'if' '(' expression ')' '{' statements '}'
  ///              ('else' '{' statements '}')?
  void _compileIf() {
    _openTag('ifStatement');
    _eat('if');
    _eat('(');
    _compileExpression();
    _eat(')');
    _eat('{');
    _compileStatements();
    _eat('}');
    if (_currentValue == 'else') {
      _eat('else');
      _eat('{');
      _compileStatements();
      _eat('}');
    }
    _closeTag('ifStatement');
  }

  /// whileStatement: 'while' '(' expression ')' '{' statements '}'
  void _compileWhile() {
    _openTag('whileStatement');
    _eat('while');
    _eat('(');
    _compileExpression();
    _eat(')');
    _eat('{');
    _compileStatements();
    _eat('}');
    _closeTag('whileStatement');
  }

  /// doStatement: 'do' subroutineCall ';'
  /// subroutineCall is NOT wrapped in its own tag — terminals go directly here.
  void _compileDo() {
    _openTag('doStatement');
    _eat('do');
    _compileSubroutineCall();
    _eat(';');
    _closeTag('doStatement');
  }

  /// returnStatement: 'return' expression? ';'
  void _compileReturn() {
    _openTag('returnStatement');
    _eat('return');
    if (_currentValue != ';') {
      _compileExpression();
    }
    _eat(';');
    _closeTag('returnStatement');
  }

  // ─── expressions ─────────────────────────────────────────────────────────

  static const _ops = {'+', '-', '*', '/', '&', '|', '<', '>', '='};

  /// expression: term (op term)*
  void _compileExpression() {
    _openTag('expression');
    _compileTerm();
    while (_ops.contains(_currentValue)) {
      _eatType(TokenType.symbol); // op
      _compileTerm();
    }
    _closeTag('expression');
  }

  /// term: integerConstant | stringConstant | keywordConstant |
  ///       varName | varName '[' expression ']' |
  ///       subroutineCall | '(' expression ')' | unaryOp term
  void _compileTerm() {
    _openTag('term');

    if (_current.type == TokenType.integerConstant) {
      _eatType(TokenType.integerConstant);
    } else if (_current.type == TokenType.stringConstant) {
      _eatType(TokenType.stringConstant);
    } else if (_currentValue == 'true' ||
        _currentValue == 'false' ||
        _currentValue == 'null' ||
        _currentValue == 'this') {
      _eatType(TokenType.keyword); // keywordConstant
    } else if (_currentValue == '(') {
      _eat('(');
      _compileExpression();
      _eat(')');
    } else if (_currentValue == '-' || _currentValue == '~') {
      _eatType(TokenType.symbol); // unaryOp
      _compileTerm();
    } else if (_current.type == TokenType.identifier) {
      // Look ahead to decide: varName, varName[expr], or subroutineCall
      final nextValue = _pos + 1 < _tokens.length ? _tokens[_pos + 1].value : '';
      if (nextValue == '[') {
        // varName '[' expression ']'
        _eatType(TokenType.identifier);
        _eat('[');
        _compileExpression();
        _eat(']');
      } else if (nextValue == '(' || nextValue == '.') {
        // subroutineCall
        _compileSubroutineCall();
      } else {
        // plain varName
        _eatType(TokenType.identifier);
      }
    }

    _closeTag('term');
  }

  /// subroutineCall (no wrapper tag — called from doStatement or term):
  ///   subroutineName '(' expressionList ')' |
  ///   (className | varName) '.' subroutineName '(' expressionList ')'
  void _compileSubroutineCall() {
    _eatType(TokenType.identifier); // subroutineName or className/varName
    if (_currentValue == '.') {
      _eat('.');
      _eatType(TokenType.identifier); // subroutineName
    }
    _eat('(');
    _compileExpressionList();
    _eat(')');
  }

  /// expressionList: (expression (',' expression)*)? 
  /// Always opens the tag, even if empty.
  void _compileExpressionList() {
    _openTag('expressionList');
    if (_currentValue != ')') {
      _compileExpression();
      while (_currentValue == ',') {
        _eat(',');
        _compileExpression();
      }
    }
    _closeTag('expressionList');
  }

  // ─── public API ─────────────────────────────────────────────────────────────

  /// Generate the full xxx.xml content
  String toXml() {
    _compileClass();
    return _out.toString();
  }
}

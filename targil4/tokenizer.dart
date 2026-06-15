// tokenizer.dart
// Part 1 of Project 10: Tokenizing
// Reads a .jack source file and splits it into tokens, outputting xxxT.xml

enum TokenType { keyword, symbol, identifier, integerConstant, stringConstant }

class Token {
  final TokenType type;
  final String value;

  Token(this.type, this.value);

  String get typeName {
    switch (type) {
      case TokenType.keyword:
        return 'keyword';
      case TokenType.symbol:
        return 'symbol';
      case TokenType.identifier:
        return 'identifier';
      case TokenType.integerConstant:
        return 'integerConstant';
      case TokenType.stringConstant:
        return 'stringConstant';
    }
  }

  // Escape special XML characters in symbol values
  String get xmlValue {
    switch (value) {
      case '<':
        return '&lt;';
      case '>':
        return '&gt;';
      case '&':
        return '&amp;';
      case '"':
        return '&quot;';
      default:
        return value;
    }
  }

  @override
  String toString() => '<${typeName}> ${xmlValue} </${typeName}>';
}

class Tokenizer {
  static const _keywords = {
    'class', 'constructor', 'function', 'method', 'field', 'static',
    'var', 'int', 'char', 'boolean', 'void', 'true', 'false', 'null',
    'this', 'let', 'do', 'if', 'else', 'while', 'return'
  };

  static const _symbols = {
    '{', '}', '(', ')', '[', ']', '.', ',', ';',
    '+', '-', '*', '/', '&', '|', '<', '>', '=', '~'
  };

  final List<Token> tokens = [];

  Tokenizer(String source) {
    _tokenize(_removeComments(source));
  }

  /// Remove all comments from source code:
  /// - single-line: // ... \n
  /// - multi-line:  /* ... */  and  /** ... */
  String _removeComments(String source) {
    final buf = StringBuffer();
    int i = 0;

    while (i < source.length) {
      // Check for string literal — don't remove comments inside strings
      if (source[i] == '"') {
        buf.write(source[i]);
        i++;
        while (i < source.length && source[i] != '"') {
          buf.write(source[i]);
          i++;
        }
        if (i < source.length) {
          buf.write(source[i]); // closing "
          i++;
        }
        continue;
      }

      // Check for // comment
      if (i + 1 < source.length && source[i] == '/' && source[i + 1] == '/') {
        // Skip until end of line
        while (i < source.length && source[i] != '\n') {
          i++;
        }
        continue;
      }

      // Check for /* or /** comment
      if (i + 1 < source.length && source[i] == '/' && source[i + 1] == '*') {
        i += 2;
        // Skip until */
        while (i + 1 < source.length &&
            !(source[i] == '*' && source[i + 1] == '/')) {
          i++;
        }
        i += 2; // skip */
        continue;
      }

      buf.write(source[i]);
      i++;
    }

    return buf.toString();
  }

  void _tokenize(String source) {
    int i = 0;

    while (i < source.length) {
      final ch = source[i];

      // Skip whitespace
      if (ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n') {
        i++;
        continue;
      }

      // String constant: starts and ends with "
      if (ch == '"') {
        i++; // skip opening "
        final buf = StringBuffer();
        while (i < source.length && source[i] != '"') {
          buf.write(source[i]);
          i++;
        }
        i++; // skip closing "
        tokens.add(Token(TokenType.stringConstant, buf.toString()));
        continue;
      }

      // Integer constant: sequence of digits
      if (_isDigit(ch)) {
        final buf = StringBuffer();
        while (i < source.length && _isDigit(source[i])) {
          buf.write(source[i]);
          i++;
        }
        tokens.add(Token(TokenType.integerConstant, buf.toString()));
        continue;
      }

      // Symbol: single character
      if (_symbols.contains(ch)) {
        tokens.add(Token(TokenType.symbol, ch));
        i++;
        continue;
      }

      // Keyword or identifier: starts with letter or underscore
      if (_isLetter(ch) || ch == '_') {
        final buf = StringBuffer();
        while (i < source.length &&
            (_isLetter(source[i]) || _isDigit(source[i]) || source[i] == '_')) {
          buf.write(source[i]);
          i++;
        }
        final word = buf.toString();
        if (_keywords.contains(word)) {
          tokens.add(Token(TokenType.keyword, word));
        } else {
          tokens.add(Token(TokenType.identifier, word));
        }
        continue;
      }

      // Unknown character — skip
      i++;
    }
  }

  bool _isDigit(String ch) => ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57;
  bool _isLetter(String ch) =>
      (ch.codeUnitAt(0) >= 65 && ch.codeUnitAt(0) <= 90) ||
      (ch.codeUnitAt(0) >= 97 && ch.codeUnitAt(0) <= 122);

  /// Generate xxxT.xml content
  String toXml() {
    final buf = StringBuffer();
    buf.writeln('<tokens>');
    for (final token in tokens) {
      buf.writeln(token.toString());
    }
    buf.writeln('</tokens>');
    return buf.toString();
  }
}

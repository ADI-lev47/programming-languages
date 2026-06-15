import 'dart:io';

enum TokenType { keyword, symbol, identifier, intConst, stringConst, none }

class JackTokenizer {
  final List<String> _tokens = [];
  int _pointer = 0;

  JackTokenizer(File file) {
    String content = file.readAsStringSync();
    // הסרת הערות
    content = content.replaceAll(RegExp(r'//.*', multiLine: true), '');
    content = content.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
    
    RegExp tokenPattern = RegExp(r'"[^"]*"|[a-zA-Z_]\w*|\d+|[{}()\[\].,;+\-*/&|<>=~]');
    for (var match in tokenPattern.allMatches(content)) {
      _tokens.add(match.group(0)!);
    }
  }

  bool hasMoreTokens() => _pointer < _tokens.length;
  void advance() => _pointer++;
  String currentToken() => _tokens[_pointer];
  String peek() => _pointer + 1 < _tokens.length ? _tokens[_pointer + 1] : "";

  TokenType tokenType() {
    String t = currentToken();
    if (RegExp(r'^{|}|\[|\]|\(|\)|\.|,|;|\+|-|\*|/|&|\||<|>|=|~$').hasMatch(t)) return TokenType.symbol;
    if (RegExp(r'^\d+$').hasMatch(t)) return TokenType.intConst;
    if (t.startsWith('"')) return TokenType.stringConst;
    const keywords = ['class','constructor','function','method','field','static','var','int','char','boolean','void','true','false','null','this','let','do','if','else','while','return'];
    if (keywords.contains(t)) return TokenType.keyword;
    return TokenType.identifier;
  }
}
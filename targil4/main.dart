import 'dart:io';
import 'tokenizer.dart';
import 'parser.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    print('Usage: dart main.dart <directory>');
    exit(1);
  }

  final inputPath = args[0];
  final dir = Directory(inputPath);

  if (!dir.existsSync()) {
    print('Error: Directory not found: $inputPath');
    exit(1);
  }

  final jackFiles = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.jack'))
      .toList();

  if (jackFiles.isEmpty) {
    print('No .jack files found in $inputPath');
    exit(1);
  }

  for (final jackFile in jackFiles) {
    final basePath = jackFile.path.replaceAll(RegExp(r'\.jack$'), '');

    // Part 1: Tokenizer → xxxT.xml
    final tokenizer = Tokenizer(jackFile.readAsStringSync());
    final tokensOutput = tokenizer.toXml();
    File('${basePath}T.xml').writeAsStringSync(tokensOutput);
    print('Created: ${basePath}T.xml');

    // Part 2: Parser → xxx.xml
    final parser = Parser(tokenizer.tokens);
    final parseOutput = parser.toXml();
    File('${basePath}.xml').writeAsStringSync(parseOutput);
    print('Created: ${basePath}.xml');
  }
}

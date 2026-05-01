// מגישות- אפרת סנדומירסקי 327609582 ועדי טוקר 327739397
import 'dart:io';

String currentFileName = "";
int labelCounter = 0;

void main() async {
  print("Please enter the directory path:");
  String? input = stdin.readLineSync();
  if (input == null || input.isEmpty) return;

  String path = input.trim().replaceAll('"', '');
  var dir = Directory(path);

  if (!dir.existsSync()) {
    print("Error: Directory not found at: $path");
    return;
  }

  String dirName = dir.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
  File outputFile = File('${dir.path}${Platform.pathSeparator}$dirName.asm');
  var sink = outputFile.openWrite();

  var entities = dir.listSync();
  for (var entity in entities) {
    if (entity is File && entity.path.toLowerCase().endsWith('.vm')) {
      processFile(entity, sink);
    }
  }

  await sink.flush();
  await sink.close();
  print("Output file is ready: ${outputFile.path}");
}

void processFile(File inputFile, IOSink output) {
  currentFileName = inputFile.uri.pathSegments.last.replaceAll('.vm', '').replaceAll('.VM', '');
  labelCounter = 0;

  List<String> lines = inputFile.readAsLinesSync();

  for (var line in lines) {
    line = line.trim();
    if (line.isEmpty || line.startsWith('//')) continue;
    int commentIdx = line.indexOf('//');
    if (commentIdx != -1) line = line.substring(0, commentIdx).trim();
    if (line.isEmpty) continue;

    List<String> parts = line.split(RegExp(r'\s+'));
    String command = parts[0];

    output.writeln("// $line");

    if (command == 'push') {
      output.writeln(translatePush(parts[1], int.parse(parts[2])));
    } else if (command == 'pop') {
      output.writeln(translatePop(parts[1], int.parse(parts[2])));
    } else if (command == 'add') {
      output.writeln(translateAdd());
    } else if (command == 'sub') {
      output.writeln(translateSub());
    } else if (command == 'neg') {
      output.writeln(translateNeg());
    } else if (command == 'and') {
      output.writeln(translateAnd());
    } else if (command == 'or') {
      output.writeln(translateOr());
    } else if (command == 'not') {
      output.writeln(translateNot());
    } else if (command == 'eq') {
      labelCounter++;
      output.writeln(translateEq(labelCounter));
    } else if (command == 'gt') {
      labelCounter++;
      output.writeln(translateGt(labelCounter));
    } else if (command == 'lt') {
      labelCounter++;
      output.writeln(translateLt(labelCounter));
    }
  }
  print("End of input file: $currentFileName");
}

String translatePush(String segment, int index) {
  switch (segment) {
    case 'constant':
      return '@$index\nD=A\n@SP\nA=M\nM=D\n@SP\nM=M+1';
    case 'local':
      return _pushFromSegment('LCL', index);
    case 'argument':
      return _pushFromSegment('ARG', index);
    case 'this':
      return _pushFromSegment('THIS', index);
    case 'that':
      return _pushFromSegment('THAT', index);
    case 'temp':
      return '@${5 + index}\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1';
    case 'pointer':
      String reg = (index == 0) ? 'THIS' : 'THAT';
      return '@$reg\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1';
    case 'static':
      return '@$currentFileName.$index\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1';
    default:
      return '// ERROR: unknown segment $segment';
  }
}

String _pushFromSegment(String baseReg, int index) {
  return '@$baseReg\nD=M\n@$index\nA=D+A\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1';
}

String translatePop(String segment, int index) {
  switch (segment) {
    case 'local':
      return _popToSegment('LCL', index);
    case 'argument':
      return _popToSegment('ARG', index);
    case 'this':
      return _popToSegment('THIS', index);
    case 'that':
      return _popToSegment('THAT', index);
    case 'temp':
      return '@SP\nAM=M-1\nD=M\n@${5 + index}\nM=D';
    case 'pointer':
      String reg = (index == 0) ? 'THIS' : 'THAT';
      return '@SP\nAM=M-1\nD=M\n@$reg\nM=D';
    case 'static':
      return '@SP\nAM=M-1\nD=M\n@$currentFileName.$index\nM=D';
    default:
      return '// ERROR: unknown segment $segment';
  }
}

String _popToSegment(String baseReg, int index) {
  return '@$baseReg\nD=M\n@$index\nD=D+A\n@R13\nM=D\n@SP\nAM=M-1\nD=M\n@R13\nA=M\nM=D';
}

String translateAdd() => '@SP\nAM=M-1\nD=M\nA=A-1\nM=D+M';
String translateSub() => '@SP\nAM=M-1\nD=M\nA=A-1\nM=M-D';
String translateNeg() => '@SP\nA=M-1\nM=-M';
String translateAnd() => '@SP\nAM=M-1\nD=M\nA=A-1\nM=D&M';
String translateOr()  => '@SP\nAM=M-1\nD=M\nA=A-1\nM=D|M';
String translateNot() => '@SP\nA=M-1\nM=!M';

String translateEq(int counter) =>
  '@SP\nAM=M-1\nD=M\nA=A-1\nD=M-D\nM=-1\n@EQ_TRUE_$counter\nD;JEQ\n@SP\nA=M-1\nM=0\n(EQ_TRUE_$counter)';

String translateGt(int counter) =>
  '@SP\nAM=M-1\nD=M\nA=A-1\nD=M-D\nM=-1\n@GT_TRUE_$counter\nD;JGT\n@SP\nA=M-1\nM=0\n(GT_TRUE_$counter)';

String translateLt(int counter) =>
  '@SP\nAM=M-1\nD=M\nA=A-1\nD=M-D\nM=-1\n@LT_TRUE_$counter\nD;JLT\n@SP\nA=M-1\nM=0\n(LT_TRUE_$counter)';
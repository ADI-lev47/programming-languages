// מגישות- אפרת סנדומירסקי 327609582 ועדי טוקר 327739397
import 'dart:io';

String currentFileName = "";
String currentFunctionName = "";
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

  // סריקת הקבצים בתיקייה
  var entities = dir.listSync();

  // Bootstrapping - הוספה רק אם קיים קובץ Sys.vm בתיקייה
  bool hasSysVm = entities.any((e) => e is File && e.path.toLowerCase().endsWith('sys.vm'));
  if (hasSysVm) {
    sink.writeln('@256\nD=A\n@SP\nM=D');
    sink.writeln(translateCall('Sys.init', 0));
  }

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
    } else if (command == 'label') {
      output.writeln(translateLabel(parts[1]));
    } else if (command == 'goto') {
      output.writeln(translateGoto(parts[1]));
    } else if (command == 'if-goto') {
      output.writeln(translateIfGoto(parts[1]));
    } else if (command == 'function') {
      currentFunctionName = parts[1];
      output.writeln(translateFunction(parts[1], int.parse(parts[2])));
    } else if (command == 'return') {
      output.writeln(translateReturn());
    } else if (command == 'call') {
      output.writeln(translateCall(parts[1], int.parse(parts[2])));
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

String translateLabel(String label) {
  String prefix = currentFunctionName.isEmpty ? currentFileName : currentFunctionName;
  return '($prefix\$$label)';
}

String translateGoto(String label) {
  String prefix = currentFunctionName.isEmpty ? currentFileName : currentFunctionName;
  return '@$prefix\$$label\n0;JMP';
}

String translateIfGoto(String label) {
  String prefix = currentFunctionName.isEmpty ? currentFileName : currentFunctionName;
  return '@SP\nAM=M-1\nD=M\n@$prefix\$$label\nD;JNE';
}

String translateFunction(String functionName, int numLocals) {
  StringBuffer sb = StringBuffer();
  sb.writeln('($functionName)');
  for (int i = 0; i < numLocals; i++) {
    sb.writeln('@SP\nA=M\nM=0\n@SP\nM=M+1');
  }
  return sb.toString().trimRight();
}

String translateReturn() =>
  '@LCL\nD=M\n@R14\nM=D\n'
  '@5\nA=D-A\nD=M\n@R15\nM=D\n'
  '@SP\nAM=M-1\nD=M\n@ARG\nA=M\nM=D\n'
  '@ARG\nD=M+1\n@SP\nM=D\n'
  '@R14\nAM=M-1\nD=M\n@THAT\nM=D\n'
  '@R14\nAM=M-1\nD=M\n@THIS\nM=D\n'
  '@R14\nAM=M-1\nD=M\n@ARG\nM=D\n'
  '@R14\nAM=M-1\nD=M\n@LCL\nM=D\n'
  '@R15\nA=M\n0;JMP';

String translateCall(String functionName, int numArgs) {
  labelCounter++;
  String returnLabel = currentFunctionName.isEmpty 
    ? 'ret.$labelCounter' 
    : '$currentFunctionName\$ret.$labelCounter';
  return '@$returnLabel\nD=A\n@SP\nA=M\nM=D\n@SP\nM=M+1\n'
    '@LCL\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1\n'
    '@ARG\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1\n'
    '@THIS\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1\n'
    '@THAT\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1\n'
    '@SP\nD=M\n@${numArgs + 5}\nD=D-A\n@ARG\nM=D\n'
    '@SP\nD=M\n@LCL\nM=D\n'
    '@$functionName\n0;JMP\n'
    '($returnLabel)';
}
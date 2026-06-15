import 'dart:io';
import 'jack_tokenizer.dart';
import 'vm_writer.dart';
import 'compilation_engine.dart';

void compileFile(File input) {
  String outPath = input.path.replaceAll('.jack', '.vm');
  File output = File(outPath);
  
  JackTokenizer tokenizer = JackTokenizer(input);
  VMWriter writer = VMWriter(output);
  
  CompilationEngine(tokenizer, writer);
  writer.close();
  print("Compiled: ${input.path} -> $outPath");
}

void main(List<String> args) {
  if (args.isEmpty) {
    print("Usage: dart run main.dart <file.jack or directory>");
    return;
  }

  String path = args[0];
  if (FileSystemEntity.isDirectorySync(path)) {
    Directory dir = Directory(path);
    List<FileSystemEntity> files = dir.listSync();
    for (var file in files) {
      if (file is File && file.path.endsWith('.jack')) {
        compileFile(file);
      }
    }
  } else if (FileSystemEntity.isFileSync(path) && path.endsWith('.jack')) {
    compileFile(File(path));
  } else {
    print("Invalid input. Provide a .jack file or a directory containing .jack files.");
  }
}
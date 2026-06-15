import 'dart:io';

enum Segment { constSeg, argSeg, localSeg, staticSeg, thisSeg, thatSeg, pointerSeg, tempSeg }
enum Command { addCmd, subCmd, negCmd, eqCmd, gtCmd, ltCmd, andCmd, orCmd, notCmd }

class VMWriter {
  final IOSink _sink;
  VMWriter(File file) : _sink = file.openWrite();

  String _segStr(Segment seg) {
    const map = {
      Segment.constSeg: "constant", Segment.argSeg: "argument",
      Segment.localSeg: "local", Segment.staticSeg: "static",
      Segment.thisSeg: "this", Segment.thatSeg: "that",
      Segment.pointerSeg: "pointer", Segment.tempSeg: "temp"
    };
    return map[seg]!;
  }

  void writePush(Segment seg, int index) => _sink.writeln("push ${_segStr(seg)} $index");
  void writePop(Segment seg, int index) => _sink.writeln("pop ${_segStr(seg)} $index");
  void writeArithmetic(Command cmd) {
    String c = cmd.toString().split('.')[1].replaceAll('Cmd', '');
    _sink.writeln(c);
  }
  void writeLabel(String label) => _sink.writeln("label $label");
  void writeGoto(String label) => _sink.writeln("goto $label");
  void writeIf(String label) => _sink.writeln("if-goto $label");
  void writeCall(String name, int nArgs) => _sink.writeln("call $name $nArgs");
  void writeFunction(String name, int nLocals) => _sink.writeln("function $name $nLocals");
  void writeReturn() => _sink.writeln("return");
  void close() => _sink.close();
}
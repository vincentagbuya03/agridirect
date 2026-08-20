import 'dart:convert';
import 'dart:io';

void main() {
  final nickFile = File('assets/developer/nick_vincent_agbuya.jpg');
  final johnFile = File('assets/developer/john_carlo_banaag.jpg');

  final nickBytes = nickFile.readAsBytesSync();
  final johnBytes = johnFile.readAsBytesSync();

  final nickB64 = base64Encode(nickBytes);
  final johnB64 = base64Encode(johnBytes);

  final buffer = StringBuffer();
  buffer.writeln("import 'dart:convert';");
  buffer.writeln("import 'dart:typed_data';");
  buffer.writeln();
  buffer.writeln("/// Embedded base64 byte arrays for developer portraits.");
  buffer.writeln("/// Guarantees 100% immediate rendering on Flutter Web across all browsers.");
  buffer.writeln("class DeveloperAssets {");
  buffer.writeln("  static final Uint8List nickVincentBytes = base64Decode('$nickB64');");
  buffer.writeln("  static final Uint8List johnCarloBytes = base64Decode('$johnB64');");
  buffer.writeln("}");

  final target = File('lib/web/constants/developer_assets.dart');
  target.parent.createSync(recursive: true);
  target.writeAsStringSync(buffer.toString());

  print('Successfully generated ${target.path}');
}

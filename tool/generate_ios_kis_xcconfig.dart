import 'dart:convert';
import 'dart:io';

void main() {
  final projectRoot = Directory.current;
  final sourceFile = File('${projectRoot.path}/env/kis.local.json');
  final targetFile = File('${projectRoot.path}/ios/Flutter/Kis.local.xcconfig');

  if (!sourceFile.existsSync()) {
    stderr.writeln('env/kis.local.json 파일이 없어 iOS 로컬 xcconfig를 생성할 수 없습니다.');
    exitCode = 1;
    return;
  }

  final raw = sourceFile.readAsStringSync();
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) {
    stderr.writeln('env/kis.local.json 형식이 올바르지 않습니다.');
    exitCode = 1;
    return;
  }

  final keys = decoded.keys.where((key) => key.startsWith('KIS_')).toList()..sort();
  final encodedDefines = keys
      .map((key) => '$key=${_stringifyValue(decoded[key])}')
      .map((entry) => base64.encode(utf8.encode(entry)))
      .join(',');

  final buffer = StringBuffer()
    ..writeln('// Generated from env/kis.local.json. Do not commit this file.')
    ..writeln('DART_DEFINES=\$(inherited)${
        encodedDefines.isEmpty ? '' : ',$encodedDefines'
      }');

  targetFile.writeAsStringSync(buffer.toString());
  stdout.writeln('Generated ${targetFile.path}');
}

String _stringifyValue(Object? value) {
  if (value == null) {
    return '';
  }
  if (value is bool || value is num) {
    return value.toString();
  }
  return value.toString();
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Every language must have the same interface keys.
/// `plants` and `plant_associations` are excluded : French comes from the database,
/// only the other languages need them in their JSON file.
void main() {
  const languages = ['fr', 'en'];
  const dataGroups = ['plants', 'plant_associations'];

  String read(String lang) => File('assets/translations/$lang.json').readAsStringSync();

  Set<String> flattenKeys(Map<String, dynamic> map, [String prefix = '']) {
    return {
      for (final entry in map.entries)
        if (!(prefix.isEmpty && dataGroups.contains(entry.key)))
          ...(entry.value is Map<String, dynamic>
              ? flattenKeys(entry.value as Map<String, dynamic>, '$prefix${entry.key}.')
              : {'$prefix${entry.key}'}),
    };
  }

  test('all languages have the same interface keys', () {
    final reference = flattenKeys(json.decode(read('fr')) as Map<String, dynamic>);

    for (final lang in languages.skip(1)) {
      final keys = flattenKeys(json.decode(read(lang)) as Map<String, dynamic>);
      expect(reference.difference(keys), isEmpty, reason: 'keys missing in $lang.json');
      expect(keys.difference(reference), isEmpty, reason: 'keys missing in fr.json');
    }
  });

  test('no duplicate key in a JSON object (the last one would silently win)', () {
    for (final lang in languages) {
      final stack = <Set<String>>[{}];
      final duplicates = <String>[];

      for (final line in read(lang).split('\n')) {
        final key = RegExp(r'^\s*"([^"]+)"\s*:').firstMatch(line)?.group(1);
        if (key != null && !stack.last.add(key)) duplicates.add(key);
        if (RegExp(r'\{\s*$').hasMatch(line)) stack.add({});
        if (RegExp(r'^\s*\},?\s*$').hasMatch(line)) stack.removeLast();
      }

      expect(duplicates, isEmpty, reason: 'duplicate keys in $lang.json');
    }
  });

  test('every translation key used in lib/ exists', () {
    final fr = json.decode(read('fr')) as Map<String, dynamic>;
    dynamic lookup(String key) => key.split('.').fold<dynamic>(fr, (node, part) => node is Map ? node[part] : null);

    final missing = <String>[];
    final usage = RegExp(r"'([a-z_]+(?:\.[A-Za-z_]+)*)'\.(?:tr|plural)\(");
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      for (final match in usage.allMatches(file.readAsStringSync())) {
        if (lookup(match.group(1)!) == null) missing.add('${match.group(1)} (${file.path})');
      }
    }
    expect(missing, isEmpty);
  });
}

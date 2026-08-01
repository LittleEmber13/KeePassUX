import 'package:flutter_autofill_service/flutter_autofill_service.dart';

import '../model/db_entry.dart';
import '../model/db_group.dart';

class AutofillMatcher {
  static List<DbEntry> allEntries(DbGroup root) {
    final result = <DbEntry>[];
    void walk(DbGroup g) {
      result.addAll(g.entries);
      for (final sub in g.groups) {
        if (sub.isRecycleBin) continue;
        walk(sub);
      }
    }

    walk(root);
    return result;
  }

  static List<DbEntry> match(List<DbEntry> entries, AutofillMetadata? meta) {
    if (meta == null) return const [];

    final domains = meta.webDomains
        .map((d) => normalizeHost(d.domain))
        .where((d) => d.isNotEmpty)
        .toSet();
    final packages = meta.packageNames
        .map((p) => p.toLowerCase())
        .where((p) => p.isNotEmpty && p != 'android')
        .toSet();
    final allDomains = {...domains, ...domainsFromPackages(packages)};

    return entries
        .where((e) => _matchesEntry(e, allDomains, packages))
        .toList(growable: false);
  }

  static Set<String> domainsFromPackages(Set<String> packages) {
    final result = <String>{};
    for (final pkg in packages) {
      final parts = pkg.split('.').where((p) => p.isNotEmpty).toList();
      if (parts.length < 2) continue;
      final host = normalizeHost('${parts[1]}.${parts[0]}');
      if (host.isNotEmpty) result.add(host);
    }
    return result;
  }

  static String normalizeHost(String input) {
    var s = input.trim().toLowerCase();
    if (s.isEmpty) return '';
    final uri = Uri.tryParse(s.contains('://') ? s : 'https://$s');
    var host = (uri != null && uri.host.isNotEmpty) ? uri.host : s;
    if (host.startsWith('www.')) host = host.substring(4);
    return host;
  }

  static bool _matchesEntry(
    DbEntry e,
    Set<String> domains,
    Set<String> packages,
  ) {
    final urls = <String>[e.url, ...e.additionalUrls];

    if (domains.isNotEmpty) {
      for (final raw in urls) {
        final host = normalizeHost(raw);
        if (host.isEmpty) continue;
        for (final d in domains) {
          if (_hostMatches(host, d)) return true;
        }
      }
    }

    if (packages.isNotEmpty) {
      final lowerUrls = urls.map((u) => u.toLowerCase());
      final haystack = '${lowerUrls.join(' ')} ${e.label.toLowerCase()}';
      for (final p in packages) {
        if (haystack.contains('androidapp://$p')) return true;
        if (haystack.contains(p)) return true;
      }
    }
    return false;
  }

  static bool _hostMatches(String a, String b) {
    if (a == b) return true;
    if (a.endsWith('.$b')) return true;
    if (b.endsWith('.$a')) return true;
    return false;
  }
}

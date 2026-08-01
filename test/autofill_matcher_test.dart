import 'package:flutter_autofill_service/flutter_autofill_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keepassux/autofill/autofill_matcher.dart';
import 'package:keepassux/model/db_entry.dart';

DbEntry _entry({
  String uuid = 'u',
  String label = '',
  String url = '',
  List<String> additionalUrls = const [],
}) {
  return DbEntry(
    uuid: uuid,
    label: label,
    userName: '',
    password: '',
    url: url,
    notes: '',
    icon: 0,
    additionalUrls: additionalUrls,
  );
}

AutofillMetadata _meta({
  Set<String> packages = const {},
  Set<String> domains = const {},
}) {
  return AutofillMetadata(
    packageNames: packages,
    webDomains: domains.map((d) => AutofillWebDomain(domain: d)).toSet(),
    saveInfo: null,
  );
}

void main() {
  group('domainsFromPackages', () {
    test('derives the registrable domain from the package', () {
      expect(
        AutofillMatcher.domainsFromPackages({'com.spotify.music'}),
        contains('spotify.com'),
      );
      expect(
        AutofillMatcher.domainsFromPackages({'org.mozilla.firefox'}),
        contains('mozilla.org'),
      );
    });

    test('ignores packages with fewer than two segments', () {
      expect(AutofillMatcher.domainsFromPackages({'android'}), isEmpty);
      expect(AutofillMatcher.domainsFromPackages({''}), isEmpty);
    });
  });

  group('match', () {
    test('matches a website entry to a native app via the heuristic', () {
      final entries = [_entry(uuid: 'a', url: 'https://spotify.com/login')];
      final result = AutofillMatcher.match(
        entries,
        _meta(packages: {'com.spotify.music'}),
      );
      expect(result.map((e) => e.uuid), ['a']);
    });

    test('matches by explicit androidapp:// association', () {
      final entries = [
        _entry(uuid: 'a', additionalUrls: ['androidapp://com.acme.app']),
      ];
      final result = AutofillMatcher.match(
        entries,
        _meta(packages: {'com.acme.app'}),
      );
      expect(result.map((e) => e.uuid), ['a']);
    });

    test('returns nothing for an unrelated app', () {
      final entries = [_entry(uuid: 'a', url: 'https://github.com')];
      final result = AutofillMatcher.match(
        entries,
        _meta(packages: {'com.spotify.music'}),
      );
      expect(result, isEmpty);
    });

    test('still matches web contexts by domain', () {
      final entries = [_entry(uuid: 'a', url: 'https://accounts.github.com')];
      final result = AutofillMatcher.match(
        entries,
        _meta(domains: {'github.com'}),
      );
      expect(result.map((e) => e.uuid), ['a']);
    });
  });
}

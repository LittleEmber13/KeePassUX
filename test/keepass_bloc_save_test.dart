import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kdbx/kdbx.dart';
import 'package:keepassux/bloc/entries/keepass_bloc.dart';
import 'package:keepassux/bloc/entries/keepass_events.dart';
import 'package:keepassux/bloc/entries/keepass_states.dart';
import 'package:keepassux/services/vault_storage_service.dart';
import 'package:keepassux/utils/kdbx_isolate.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _uri = 'content://test/vault';
const String _password = 'correct horse battery staple';

Future<Uint8List> _cheapVault() async {
  final format = KdbxFormat();
  final file = format.create(
    Credentials(ProtectedValue.fromString(_password)),
    'bloc-test',
  );
  file.header.writeKdfParameters(
    argon2KdfParams(
      file.header.readKdfParameters,
      memoryBytes: 1024 * 1024,
      iterations: 1,
      parallelism: 1,
    ),
  );
  return file.save();
}

class _SlowDocument {
  _SlowDocument(this.content);

  Uint8List content;
  final List<Duration> writeDelays = <Duration>[];
  final List<Uint8List> completedWrites = <Uint8List>[];
  int _writeCount = 0;

  Future<void> write(String uri, Uint8List bytes) async {
    final index = _writeCount++;
    final delay = index < writeDelays.length
        ? writeDelays[index]
        : Duration.zero;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    content = Uint8List.fromList(bytes);
    completedWrites.add(content);
  }

  Future<Uint8List> read(String uri) async => content;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Uint8List initialBytes;
  late _SlowDocument document;
  late KeePassBloc bloc;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{'kdbx_uri': _uri});
    initialBytes = await _cheapVault();
    document = _SlowDocument(initialBytes);
    bloc = KeePassBloc(
      storage: VaultStorageService(
        writeBytes: document.write,
        readBytes: document.read,
      ),
    );
  });

  tearDown(() async {
    await bloc.close();
  });

  Future<void> unlock() async {
    final loaded = bloc.stream.firstWhere((s) => s is KeePassLoaded);
    bloc.add(LoadDatabase(bytes: initialBytes, password: _password));
    await loaded;
  }

  test('a slow write cannot be overtaken by the next mutation', () async {
    await unlock();

    document.writeDelays.addAll(const [
      Duration(milliseconds: 200),
      Duration.zero,
    ]);

    final settled = bloc.stream
        .where((s) => s is KeePassAddGroupSuccess)
        .first;

    bloc.add(AddEntry(title: 'first', password: 'a'));
    bloc.add(AddGroup(title: 'second'));
    await settled;

    expect(document.completedWrites, hasLength(2));
    expect(
      document.content,
      document.completedWrites.last,
      reason: 'the newest state must be the one left on disk',
    );

    final reopened = await KdbxFormat().read(
      document.content,
      Credentials(ProtectedValue.fromString(_password)),
    );
    expect(reopened.body.rootGroup.entries, hasLength(1));
    expect(reopened.body.rootGroup.groups.map((g) => g.name.get()),
        contains('second'));
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('a failed write leaves disk and in-memory state in agreement', () async {
    await unlock();

    final storage = VaultStorageService(
      writeBytes: (uri, bytes) async => throw Exception('provider is gone'),
      readBytes: document.read,
    );
    storage.rememberBaseline(_uri, initialBytes);

    final failing = KeePassBloc(storage: storage);
    addTearDown(failing.close);

    final loaded = failing.stream.firstWhere((s) => s is KeePassLoaded);
    failing.add(LoadDatabase(bytes: initialBytes, password: _password));
    await loaded;

    final errored = failing.stream.firstWhere((s) => s is KeePassError);
    failing.add(AddEntry(title: 'never persisted', password: 'a'));
    await errored;

    expect(failing.currentRoot, isNotNull);
    expect(
      failing.currentRoot!.entries,
      isEmpty,
      reason: 'the UI must not show an entry that never reached disk',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}

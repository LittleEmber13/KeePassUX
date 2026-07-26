import 'package:content_resolver/content_resolver.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keepassux/ui/bloc/entries/keepass_events.dart';
import 'package:keepassux/ui/bloc/entries/keepass_states.dart';
import 'package:keepassux/ui/utils/kdbx_isolate.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uri_content/uri_content.dart';

import '../../model/db_group.dart';
import '../../model/db_root.dart';
import '../../model/kdbx_action_result.dart';
import '../../model/kdf_info.dart';
import '../../utils/kdbx_command.dart';

class KeePassBloc extends Bloc<KeePassEvent, KeePassState> {
  KeePassBloc() : super(KeePassInitial()) {
    on<LoadDatabase>(_onLoadDatabase);
    on<ReloadDatabase>(_onReloadDatabase);
    on<AddEntry>(_onAddEntry);
    on<AddGroup>(_onAddGroup);
    on<GetRootGroup>(_onGetRootGroup);
    on<CreateDatabase>(_onCreateDatabase);
    on<UpdateEntry>(_onUpdateEntry);
    on<MoveEntry>(_onMoveEntry);
    on<MoveGroup>(_onMoveGroup);
    on<MoveItems>(_onMoveItems);
    on<CopyItems>(_onCopyItems);
    on<DeleteItems>(_onDeleteItems);
    on<UpdateGroup>(_onUpdateGroup);
    on<DeleteEntry>(_onDeleteEntry);
    on<DeleteGroup>(_onDeleteGroup);
    on<DeleteEntryPermanently>(_onDeleteEntryPermanently);
    on<DeleteGroupPermanently>(_onDeleteGroupPermanently);
    on<ChangeMasterPassword>(_onChangeMasterPassword);
    on<GetKdfParameters>(_onGetKdfParameters);
    on<ChangeKdfParameters>(_onChangeKdfParameters);
    _initIsolate();
  }

  final KdbxIsolate _kdbxIsolate = KdbxIsolate();
  SharedPreferences? preferences;
  DbGroup? _currentRoot;

  DbGroup? get currentRoot => _currentRoot;

  Logger logger = Logger();

  Future<void> _initIsolate() async {
    await _kdbxIsolate.init();
  }

  Future<void> _onLoadDatabase(
    LoadDatabase event,
    Emitter<KeePassState> emit,
  ) async {
    try {
      emit(KeePassLoading());

      preferences = await SharedPreferences.getInstance();

      final root = await _kdbxIsolate.send<DbRoot>(
        LoadDatabaseCmd(bytes: event.bytes, password: event.password),
      );
      _currentRoot = root.rootGroup;

      emit(KeePassLoaded());
    } catch (e) {
      logger.e(e);
      if (e.toString().contains('Invalid key') ||
          e.toString().contains('decrypt')) {
        emit(KeePassError(tr("exception.invalid_password")));
      } else {
        emit(KeePassError(tr("exception.unknown")));
      }
    }
  }

  Future<void> _onReloadDatabase(
    ReloadDatabase event,
    Emitter<KeePassState> emit,
  ) async {
    if (_currentRoot == null) return;
    try {
      preferences ??= await SharedPreferences.getInstance();
      final uri = preferences?.getString('kdbx_uri');
      if (uri == null || uri.isEmpty) return;
      final bytes = await UriContent().from(Uri.parse(uri));
      final root = await _kdbxIsolate.send<DbRoot>(
        ReloadDatabaseCmd(bytes: bytes),
      );
      _currentRoot = root.rootGroup;
      emit(KeePassRootGroup(_currentRoot!));
    } catch (e) {
      logger.e(e);
    }
  }

  Future<void> _onCreateDatabase(
    CreateDatabase event,
    Emitter<KeePassState> emit,
  ) async {
    try {
      emit(KeePassLoading());

      if (event.uri.isEmpty) {
        throw Exception("URI is null");
      }

      preferences = await SharedPreferences.getInstance();

      final result = await _kdbxIsolate.send<KdbxActionResult>(
        CreateDatabaseCmd(password: event.password),
      );
      _currentRoot = result.root.rootGroup;

      await ContentResolver.writeContent(event.uri, result.savedBytes);
      await preferences!.setString('kdbx_uri', event.uri);

      emit(KeePassCreated());
    } catch (e) {
      logger.e(e);
      emit(KeePassError(tr("exception.unknown")));
    }
  }

  void _onGetRootGroup(
    GetRootGroup event,
    Emitter<KeePassState> emit,
  ) {
    if (_currentRoot != null) {
      emit(KeePassRootGroup(_currentRoot!));
    }
  }

  Future<void> _onAddEntry(AddEntry event, Emitter<KeePassState> emit) async {
    try {
      emit(KeePassLoading());

      final result = await _kdbxIsolate.send<KdbxActionResult>(
        AddEntryCmd(
          groupUuid: event.uuidGroup ?? _currentRoot!.uuid,
          title: event.title,
          userName: event.userName ?? '',
          url: event.url ?? '',
          notes: event.notes ?? '',
          password: event.password,
          icon: event.icon ?? 0,
          customIconData: event.customIconData,
        ),
      );
      _currentRoot = result.root.rootGroup;

      await _saveBytes(result.savedBytes);

      emit(KeePassRootGroup(_currentRoot!));
      emit(KeePassAddEntrySuccess());
    } catch (e) {
      logger.e(e);
      emit(KeePassError(tr("exception.unknown")));
    }
  }

  Future<void> _onAddGroup(AddGroup event, Emitter<KeePassState> emit) async {
    try {
      emit(KeePassLoading());

      final result = await _kdbxIsolate.send<KdbxActionResult>(
        AddGroupCmd(
          parentUuid: event.uuidGroup ?? _currentRoot!.uuid,
          name: event.title,
        ),
      );
      _currentRoot = result.root.rootGroup;

      await _saveBytes(result.savedBytes);

      emit(KeePassRootGroup(_currentRoot!));
      emit(KeePassAddGroupSuccess());
    } catch (e) {
      logger.e(e);
      emit(KeePassError(tr("exception.unknown")));
    }
  }

  Future<void> _onUpdateEntry(
    UpdateEntry event,
    Emitter<KeePassState> emit,
  ) async {
    try {
      emit(KeePassLoading());

      final result = await _kdbxIsolate.send<KdbxActionResult>(
        UpdateEntryCmd(
          entryUuid: event.entryUuid,
          title: event.title,
          userName: event.userName ?? '',
          url: event.url ?? '',
          notes: event.notes ?? '',
          password: event.password,
          icon: event.icon ?? 0,
          customIconData: event.customIconData,
        ),
      );
      _currentRoot = result.root.rootGroup;

      await _saveBytes(result.savedBytes);

      emit(KeePassRootGroup(_currentRoot!));
      emit(KeePassUpdateEntrySuccess());
    } catch (e) {
      logger.e(e);
      emit(KeePassError(tr("exception.unknown")));
    }
  }

  Future<void> _onMoveEntry(MoveEntry event, Emitter<KeePassState> emit) async {
    try {
      emit(KeePassLoading());

      final result = await _kdbxIsolate.send<KdbxActionResult>(
        MoveEntryCmd(
          entryUuid: event.entryUuid,
          fromGroupUuid: event.fromGroupUuid,
          toGroupUuid: event.toGroupUuid,
        ),
      );
      _currentRoot = result.root.rootGroup;

      await _saveBytes(result.savedBytes);

      emit(KeePassRootGroup(_currentRoot!));
      emit(KeePassMoveSuccess());
    } catch (e) {
      logger.e(e);
      emit(KeePassError(tr("exception.unknown")));
    }
  }

  Future<void> _onMoveGroup(MoveGroup event, Emitter<KeePassState> emit) async {
    try {
      emit(KeePassLoading());

      final result = await _kdbxIsolate.send<KdbxActionResult>(
        MoveGroupCmd(
          groupUuid: event.groupUuid,
          fromGroupUuid: event.fromGroupUuid,
          toGroupUuid: event.toGroupUuid,
        ),
      );
      _currentRoot = result.root.rootGroup;

      await _saveBytes(result.savedBytes);

      emit(KeePassRootGroup(_currentRoot!));
      emit(KeePassMoveSuccess());
    } catch (e) {
      logger.e(e);
      emit(KeePassError(tr("exception.unknown")));
    }
  }

  Future<void> _onMoveItems(MoveItems event, Emitter<KeePassState> emit) async {
    try {
      emit(KeePassLoading());

      final result = await _kdbxIsolate.send<KdbxActionResult>(
        MoveItemsCmd(
          entryUuids: event.entryUuids,
          groupUuids: event.groupUuids,
          toGroupUuid: event.toGroupUuid,
        ),
      );
      _currentRoot = result.root.rootGroup;

      await _saveBytes(result.savedBytes);

      emit(KeePassRootGroup(_currentRoot!));
      emit(KeePassMoveSuccess());
    } catch (e) {
      logger.e(e);
      emit(KeePassError(tr("exception.unknown")));
    }
  }

  Future<void> _onCopyItems(CopyItems event, Emitter<KeePassState> emit) async {
    try {
      emit(KeePassLoading());

      final result = await _kdbxIsolate.send<KdbxActionResult>(
        CopyItemsCmd(
          entryUuids: event.entryUuids,
          groupUuids: event.groupUuids,
          toGroupUuid: event.toGroupUuid,
        ),
      );
      _currentRoot = result.root.rootGroup;

      await _saveBytes(result.savedBytes);

      emit(KeePassRootGroup(_currentRoot!));
      emit(KeePassMoveSuccess());
    } catch (e) {
      logger.e(e);
      emit(KeePassError(tr("exception.unknown")));
    }
  }

  Future<void> _onDeleteItems(
    DeleteItems event,
    Emitter<KeePassState> emit,
  ) async {
    try {
      emit(KeePassLoading());

      final result = await _kdbxIsolate.send<KdbxActionResult>(
        DeleteItemsCmd(
          entryUuids: event.entryUuids,
          groupUuids: event.groupUuids,
        ),
      );
      _currentRoot = result.root.rootGroup;

      await _saveBytes(result.savedBytes);

      emit(KeePassRootGroup(_currentRoot!));
      emit(KeePassDeleteEntrySuccess());
    } catch (e) {
      logger.e(e);
      emit(KeePassError(tr("exception.unknown")));
    }
  }

  Future<void> _onUpdateGroup(UpdateGroup event, Emitter<KeePassState> emit) async {
    try {
      emit(KeePassLoading());

      final result = await _kdbxIsolate.send<KdbxActionResult>(
        UpdateGroupCmd(
          groupUuid: event.groupUuid,
          name: event.name,
        ),
      );
      _currentRoot = result.root.rootGroup;

      await _saveBytes(result.savedBytes);

      emit(KeePassRootGroup(_currentRoot!));
      emit(KeePassUpdateGroupSuccess());
    } catch (e) {
      logger.e(e);
      emit(KeePassError(tr("exception.unknown")));
    }
  }

  Future<void> _onDeleteEntry(DeleteEntry event, Emitter<KeePassState> emit) async {
    try {
      emit(KeePassLoading());

      final result = await _kdbxIsolate.send<KdbxActionResult>(
        DeleteEntryCmd(entryUuid: event.entryUuid),
      );
      _currentRoot = result.root.rootGroup;

      await _saveBytes(result.savedBytes);

      emit(KeePassRootGroup(_currentRoot!));
      emit(KeePassDeleteEntrySuccess());
    } catch (e) {
      logger.e(e);
      emit(KeePassError(tr("exception.unknown")));
    }
  }

  Future<void> _onDeleteGroup(DeleteGroup event, Emitter<KeePassState> emit) async {
    try {
      emit(KeePassLoading());

      final result = await _kdbxIsolate.send<KdbxActionResult>(
        DeleteGroupCmd(groupUuid: event.groupUuid),
      );
      _currentRoot = result.root.rootGroup;

      await _saveBytes(result.savedBytes);

      emit(KeePassRootGroup(_currentRoot!));
      emit(KeePassDeleteGroupSuccess());
    } catch (e) {
      logger.e(e);
      emit(KeePassError(tr("exception.unknown")));
    }
  }

  Future<void> _onDeleteEntryPermanently(DeleteEntryPermanently event, Emitter<KeePassState> emit) async {
    try {
      emit(KeePassLoading());

      final result = await _kdbxIsolate.send<KdbxActionResult>(
        DeleteEntryPermanentlyCmd(entryUuid: event.entryUuid),
      );
      _currentRoot = result.root.rootGroup;

      await _saveBytes(result.savedBytes);

      emit(KeePassRootGroup(_currentRoot!));
      emit(KeePassDeleteEntrySuccess());
    } catch (e) {
      logger.e(e);
      emit(KeePassError(tr("exception.unknown")));
    }
  }

  Future<void> _onDeleteGroupPermanently(DeleteGroupPermanently event, Emitter<KeePassState> emit) async {
    try {
      emit(KeePassLoading());

      final result = await _kdbxIsolate.send<KdbxActionResult>(
        DeleteGroupPermanentlyCmd(groupUuid: event.groupUuid),
      );
      _currentRoot = result.root.rootGroup;

      await _saveBytes(result.savedBytes);

      emit(KeePassRootGroup(_currentRoot!));
      emit(KeePassDeleteGroupSuccess());
    } catch (e) {
      logger.e(e);
      emit(KeePassError(tr("exception.unknown")));
    }
  }

  Future<void> _onChangeMasterPassword(
    ChangeMasterPassword event,
    Emitter<KeePassState> emit,
  ) async {
    try {
      emit(KeePassLoading());

      final result = await _kdbxIsolate.send<KdbxActionResult>(
        ChangeMasterPasswordCmd(
          oldPassword: event.oldPassword,
          newPassword: event.newPassword,
        ),
      );
      _currentRoot = result.root.rootGroup;

      await _saveBytes(result.savedBytes);

      emit(KeePassChangeMasterPasswordSuccess());
    } catch (e) {
      logger.e(e);
      if (e.toString().contains('Invalid current password')) {
        emit(KeePassError(tr("change_password_page.error_wrong_current")));
      } else {
        emit(KeePassError(tr("exception.unknown")));
      }
    }
  }

  Future<void> _onGetKdfParameters(
    GetKdfParameters event,
    Emitter<KeePassState> emit,
  ) async {
    try {
      emit(KeePassLoading());

      final info = await _kdbxIsolate.send<KdfInfo>(GetKdfParametersCmd());

      emit(KeePassKdfParameters(info));
    } catch (e) {
      logger.e(e);
      emit(KeePassError(tr("exception.unknown")));
    }
  }

  Future<void> _onChangeKdfParameters(
    ChangeKdfParameters event,
    Emitter<KeePassState> emit,
  ) async {
    try {
      emit(KeePassLoading());

      final result = await _kdbxIsolate.send<KdbxActionResult>(
        ChangeKdfParametersCmd(
          memoryBytes: event.memoryBytes,
          iterations: event.iterations,
          parallelism: event.parallelism,
        ),
      );
      _currentRoot = result.root.rootGroup;

      await _saveBytes(result.savedBytes);

      emit(KeePassChangeKdfParametersSuccess());
    } catch (e) {
      logger.e(e);
      if (e.toString().contains('Unsupported KDF type')) {
        emit(KeePassError(tr("kdf_settings_page.error_unsupported_aes")));
      } else {
        emit(KeePassError(tr("exception.unknown")));
      }
    }
  }

  Future<void> _saveBytes(dynamic bytes) async {
    String? uri = preferences?.getString('kdbx_uri');
    if (uri != null) {
      await ContentResolver.writeContent(uri, bytes);
    } else {
      throw Exception('No URI saved');
    }
  }
}

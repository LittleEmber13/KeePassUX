import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keepassux/bloc/entries/keepass_events.dart';
import 'package:keepassux/bloc/entries/keepass_states.dart';
import 'package:keepassux/error/vault_write_exception.dart';
import 'package:keepassux/services/auto_lock_controller.dart';
import 'package:keepassux/services/vault_storage_service.dart';
import 'package:keepassux/utils/kdbx_isolate.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';
import 'package:uri_content/uri_content.dart';

import '../../model/db_group.dart';
import '../../model/db_root.dart';
import '../../model/kdbx_action_result.dart';
import '../../model/kdf_info.dart';
import '../../utils/kdbx_command.dart';

class KeePassBloc extends Bloc<KeePassEvent, KeePassState> {
  KeePassBloc({VaultStorageService? storage})
    : _vaultStorage = storage ?? vaultStorage,
      super(KeePassInitial()) {
    on<LoadDatabase>(_onLoadDatabase);
    on<ReloadDatabase>(_onReloadDatabase);
    on<LockDatabase>(_onLockDatabase);
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
    on<RestoreEntry>(_onRestoreEntry);
    on<RestoreGroup>(_onRestoreGroup);
    on<ChangeMasterPassword>(_onChangeMasterPassword);
    on<GetKdfParameters>(_onGetKdfParameters);
    on<ChangeKdfParameters>(_onChangeKdfParameters);
    _initIsolate();
  }

  final KdbxIsolate _kdbxIsolate = KdbxIsolate();
  final VaultStorageService _vaultStorage;
  final Lock _lock = Lock();
  SharedPreferences? preferences;
  DbGroup? _currentRoot;
  String? _sessionPassword;

  DbGroup? get currentRoot => _currentRoot;

  String? get sessionPassword => _sessionPassword;

  Logger logger = Logger();

  Future<void> _initIsolate() async {
    await _kdbxIsolate.init();
  }

  @override
  Future<void> close() {
    _kdbxIsolate.dispose();
    _vaultStorage.forgetBaseline();
    _sessionPassword = null;
    autoLock.disarm();
    return super.close();
  }

  Future<void> _mutate(KdbxCommand command, {String? rollbackPassword}) async {
    await _lock.synchronized(() async {
      final result = await _kdbxIsolate.send<KdbxActionResult>(command);
      try {
        await _saveBytes(result.savedBytes);
      } catch (_) {
        await _restoreIsolate(rollbackPassword);
        rethrow;
      }
      _currentRoot = result.root.rootGroup;
    });
  }

  Future<void> _restoreIsolate(String? password) async {
    final previous = _vaultStorage.baseline;
    if (previous == null) return;
    try {
      final root = await _kdbxIsolate.send<DbRoot>(
        RollbackCmd(bytes: previous, password: password),
      );
      _currentRoot = root.rootGroup;
    } catch (e) {
      logger.e(e);
    }
  }

  Future<void> _saveBytes(Uint8List bytes) async {
    String? uri = preferences?.getString('kdbx_uri');
    if (uri != null) {
      await _vaultStorage.save(uri, bytes);
    } else {
      throw Exception('No URI saved');
    }
  }

  KeePassError _errorFor(Object error) {
    if (error is VaultWriteException) {
      return KeePassError(
        error.rolledBack
            ? tr("exception.save_failed")
            : tr("exception.save_failed_unrecoverable"),
      );
    }
    return KeePassError(tr("exception.unknown"));
  }

  Future<void> _onLoadDatabase(
    LoadDatabase event,
    Emitter<KeePassState> emit,
  ) async {
    try {
      emit(KeePassLoading());

      preferences = await SharedPreferences.getInstance();

      await _lock.synchronized(() async {
        final root = await _kdbxIsolate.send<DbRoot>(
          LoadDatabaseCmd(bytes: event.bytes, password: event.password),
        );
        _currentRoot = root.rootGroup;

        final uri = preferences?.getString('kdbx_uri');
        if (uri != null) _vaultStorage.rememberBaseline(uri, event.bytes);
      });

      _sessionPassword = event.password;
      autoLock.arm();

      emit(KeePassLoaded());
    } catch (e) {
      logger.e(e);
      if (e.toString().contains('Invalid key') ||
          e.toString().contains('decrypt')) {
        emit(KeePassError(tr("exception.invalid_password")));
      } else {
        emit(_errorFor(e));
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

      await _lock.synchronized(() async {
        final bytes = await UriContent().from(Uri.parse(uri));
        final root = await _kdbxIsolate.send<DbRoot>(
          ReloadDatabaseCmd(bytes: bytes),
        );
        _currentRoot = root.rootGroup;
        _vaultStorage.rememberBaseline(uri, bytes);
      });

      emit(KeePassRootGroup(_currentRoot!));
    } catch (e) {
      logger.e(e);
    }
  }

  Future<void> _onLockDatabase(
    LockDatabase event,
    Emitter<KeePassState> emit,
  ) async {
    await _lock.synchronized(() async {
      try {
        await _kdbxIsolate.send<bool>(LockDatabaseCmd());
      } catch (e) {
        logger.e(e);
      }
      _currentRoot = null;
      _sessionPassword = null;
      _vaultStorage.forgetBaseline();
    });

    autoLock.disarm();

    emit(KeePassLocked());
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

      await _lock.synchronized(() async {
        final result = await _kdbxIsolate.send<KdbxActionResult>(
          CreateDatabaseCmd(password: event.password),
        );

        _vaultStorage.forgetBaseline();
        await _vaultStorage.save(event.uri, result.savedBytes);
        await preferences!.setString('kdbx_uri', event.uri);
        _currentRoot = result.root.rootGroup;
      });

      _sessionPassword = event.password;
      autoLock.arm();

      emit(KeePassCreated());
    } catch (e) {
      logger.e(e);
      emit(_errorFor(e));
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

      await _mutate(
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

      emit(KeePassRootGroup(_currentRoot!));
      emit(KeePassAddEntrySuccess());
    } catch (e) {
      logger.e(e);
      emit(_errorFor(e));
    }
  }

  Future<void> _onAddGroup(AddGroup event, Emitter<KeePassState> emit) async {
    try {
      emit(KeePassLoading());

      await _mutate(
        AddGroupCmd(
          parentUuid: event.uuidGroup ?? _currentRoot!.uuid,
          name: event.title,
        ),
      );

      emit(KeePassRootGroup(_currentRoot!));
      emit(KeePassAddGroupSuccess());
    } catch (e) {
      logger.e(e);
      emit(_errorFor(e));
    }
  }

  Future<void> _onUpdateEntry(
    UpdateEntry event,
    Emitter<KeePassState> emit,
  ) async {
    try {
      emit(KeePassLoading());

      await _mutate(
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

      emit(KeePassRootGroup(_currentRoot!));
      emit(KeePassUpdateEntrySuccess());
    } catch (e) {
      logger.e(e);
      emit(_errorFor(e));
    }
  }

  Future<void> _onMoveEntry(MoveEntry event, Emitter<KeePassState> emit) async {
    try {
      emit(KeePassLoading());

      await _mutate(
        MoveEntryCmd(
          entryUuid: event.entryUuid,
          fromGroupUuid: event.fromGroupUuid,
          toGroupUuid: event.toGroupUuid,
        ),
      );

      emit(KeePassRootGroup(_currentRoot!));
      emit(KeePassMoveSuccess());
    } catch (e) {
      logger.e(e);
      emit(_errorFor(e));
    }
  }

  Future<void> _onMoveGroup(MoveGroup event, Emitter<KeePassState> emit) async {
    try {
      emit(KeePassLoading());

      await _mutate(
        MoveGroupCmd(
          groupUuid: event.groupUuid,
          fromGroupUuid: event.fromGroupUuid,
          toGroupUuid: event.toGroupUuid,
        ),
      );

      emit(KeePassRootGroup(_currentRoot!));
      emit(KeePassMoveSuccess());
    } catch (e) {
      logger.e(e);
      emit(_errorFor(e));
    }
  }

  Future<void> _onMoveItems(MoveItems event, Emitter<KeePassState> emit) async {
    try {
      emit(KeePassLoading());

      await _mutate(
        MoveItemsCmd(
          entryUuids: event.entryUuids,
          groupUuids: event.groupUuids,
          toGroupUuid: event.toGroupUuid,
        ),
      );

      emit(KeePassRootGroup(_currentRoot!));
      emit(KeePassMoveSuccess());
    } catch (e) {
      logger.e(e);
      emit(_errorFor(e));
    }
  }

  Future<void> _onCopyItems(CopyItems event, Emitter<KeePassState> emit) async {
    try {
      emit(KeePassLoading());

      await _mutate(
        CopyItemsCmd(
          entryUuids: event.entryUuids,
          groupUuids: event.groupUuids,
          toGroupUuid: event.toGroupUuid,
        ),
      );

      emit(KeePassRootGroup(_currentRoot!));
      emit(KeePassMoveSuccess());
    } catch (e) {
      logger.e(e);
      emit(_errorFor(e));
    }
  }

  Future<void> _onDeleteItems(
    DeleteItems event,
    Emitter<KeePassState> emit,
  ) async {
    try {
      emit(KeePassLoading());

      await _mutate(
        DeleteItemsCmd(
          entryUuids: event.entryUuids,
          groupUuids: event.groupUuids,
        ),
      );

      emit(KeePassRootGroup(_currentRoot!));
      emit(KeePassDeleteEntrySuccess());
    } catch (e) {
      logger.e(e);
      emit(_errorFor(e));
    }
  }

  Future<void> _onUpdateGroup(UpdateGroup event, Emitter<KeePassState> emit) async {
    try {
      emit(KeePassLoading());

      await _mutate(
        UpdateGroupCmd(
          groupUuid: event.groupUuid,
          name: event.name,
        ),
      );

      emit(KeePassRootGroup(_currentRoot!));
      emit(KeePassUpdateGroupSuccess());
    } catch (e) {
      logger.e(e);
      emit(_errorFor(e));
    }
  }

  Future<void> _onDeleteEntry(DeleteEntry event, Emitter<KeePassState> emit) async {
    try {
      emit(KeePassLoading());

      await _mutate(DeleteEntryCmd(entryUuid: event.entryUuid));

      emit(KeePassRootGroup(_currentRoot!));
      emit(KeePassDeleteEntrySuccess());
    } catch (e) {
      logger.e(e);
      emit(_errorFor(e));
    }
  }

  Future<void> _onDeleteGroup(DeleteGroup event, Emitter<KeePassState> emit) async {
    try {
      emit(KeePassLoading());

      await _mutate(DeleteGroupCmd(groupUuid: event.groupUuid));

      emit(KeePassRootGroup(_currentRoot!));
      emit(KeePassDeleteGroupSuccess());
    } catch (e) {
      logger.e(e);
      emit(_errorFor(e));
    }
  }

  Future<void> _onDeleteEntryPermanently(DeleteEntryPermanently event, Emitter<KeePassState> emit) async {
    try {
      emit(KeePassLoading());

      await _mutate(DeleteEntryPermanentlyCmd(entryUuid: event.entryUuid));

      emit(KeePassRootGroup(_currentRoot!));
      emit(KeePassDeleteEntrySuccess());
    } catch (e) {
      logger.e(e);
      emit(_errorFor(e));
    }
  }

  Future<void> _onDeleteGroupPermanently(DeleteGroupPermanently event, Emitter<KeePassState> emit) async {
    try {
      emit(KeePassLoading());

      await _mutate(DeleteGroupPermanentlyCmd(groupUuid: event.groupUuid));

      emit(KeePassRootGroup(_currentRoot!));
      emit(KeePassDeleteGroupSuccess());
    } catch (e) {
      logger.e(e);
      emit(_errorFor(e));
    }
  }

  Future<void> _onRestoreEntry(RestoreEntry event, Emitter<KeePassState> emit) async {
    try {
      emit(KeePassLoading());

      await _mutate(RestoreEntryCmd(entryUuid: event.entryUuid));

      emit(KeePassRootGroup(_currentRoot!));
      emit(KeePassMoveSuccess());
    } catch (e) {
      logger.e(e);
      emit(_errorFor(e));
    }
  }

  Future<void> _onRestoreGroup(RestoreGroup event, Emitter<KeePassState> emit) async {
    try {
      emit(KeePassLoading());

      await _mutate(RestoreGroupCmd(groupUuid: event.groupUuid));

      emit(KeePassRootGroup(_currentRoot!));
      emit(KeePassMoveSuccess());
    } catch (e) {
      logger.e(e);
      emit(_errorFor(e));
    }
  }

  Future<void> _onChangeMasterPassword(
    ChangeMasterPassword event,
    Emitter<KeePassState> emit,
  ) async {
    try {
      emit(KeePassLoading());

      await _mutate(
        ChangeMasterPasswordCmd(
          oldPassword: event.oldPassword,
          newPassword: event.newPassword,
        ),
        rollbackPassword: event.oldPassword,
      );

      _sessionPassword = event.newPassword;

      emit(KeePassChangeMasterPasswordSuccess());
    } catch (e) {
      logger.e(e);
      if (e.toString().contains('Invalid current password')) {
        emit(KeePassError(tr("change_password_page.error_wrong_current")));
      } else {
        emit(_errorFor(e));
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
      emit(_errorFor(e));
    }
  }

  Future<void> _onChangeKdfParameters(
    ChangeKdfParameters event,
    Emitter<KeePassState> emit,
  ) async {
    try {
      emit(KeePassLoading());

      await _mutate(
        ChangeKdfParametersCmd(
          memoryBytes: event.memoryBytes,
          iterations: event.iterations,
          parallelism: event.parallelism,
        ),
      );

      emit(KeePassChangeKdfParametersSuccess());
    } catch (e) {
      logger.e(e);
      if (e.toString().contains('Unsupported KDF type')) {
        emit(KeePassError(tr("kdf_settings_page.error_unsupported_aes")));
      } else {
        emit(_errorFor(e));
      }
    }
  }
}

import '../../model/db_group.dart';
import '../../model/kdf_info.dart';

abstract class KeePassState {}

class KeePassInitial extends KeePassState {}

class KeePassLoading extends KeePassState {}

class KeePassLoaded extends KeePassState {}

class KeePassCreated extends KeePassState {}

class KeePassRootGroup extends KeePassState {
  final DbGroup? rootGroup;
  KeePassRootGroup(this.rootGroup);
}

class KeePassError extends KeePassState {
  final String message;
  KeePassError(this.message);
}

class KeePassAddEntrySuccess extends KeePassState {
  KeePassAddEntrySuccess();
}

class KeePassAddGroupSuccess extends KeePassState {
  KeePassAddGroupSuccess();
}

class KeePassUpdateEntrySuccess extends KeePassState {
  KeePassUpdateEntrySuccess();
}

class KeePassMoveSuccess extends KeePassState {
  KeePassMoveSuccess();
}

class KeePassUpdateGroupSuccess extends KeePassState {
  KeePassUpdateGroupSuccess();
}

class KeePassDeleteEntrySuccess extends KeePassState {
  KeePassDeleteEntrySuccess();
}

class KeePassDeleteGroupSuccess extends KeePassState {
  KeePassDeleteGroupSuccess();
}

class KeePassChangeMasterPasswordSuccess extends KeePassState {
  KeePassChangeMasterPasswordSuccess();
}

class KeePassKdfParameters extends KeePassState {
  final KdfInfo info;
  KeePassKdfParameters(this.info);
}

class KeePassChangeKdfParametersSuccess extends KeePassState {
  KeePassChangeKdfParametersSuccess();
}

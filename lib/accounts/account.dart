import 'management_mode.dart';

class Account {
  final String id;
  final String name;
  final bool isShared;
  final ManagementMode managementMode;

  const Account({
    required this.id,
    required this.name,
    required this.isShared,
    required this.managementMode,
  });
}

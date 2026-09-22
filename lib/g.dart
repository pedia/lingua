import 'package:hive_ce/hive_ce.dart';

/// stupid global instance
late final Box gbox;

late int gid;
int nextId() {
  gid++;
  gbox.put('gid', gid);
  return gid;
}

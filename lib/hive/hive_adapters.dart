import 'package:hive_ce/hive_ce.dart';
import '../data/model.dart';
import '../ui/book.dart';
import '../ui/chapter_list.dart';

@GenerateAdapters([
  AdapterSpec<Item>(),
  AdapterSpec<ItemType>(),
  AdapterSpec<Shop>(),
  AdapterSpec<Note>(),
  AdapterSpec<Shelf>(),
  AdapterSpec<ItemState>(),
  AdapterSpec<Progress>(),
])
part 'hive_adapters.g.dart';

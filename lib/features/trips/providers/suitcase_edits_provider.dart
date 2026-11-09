import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/daos/suitcase_edits_dao.dart';
import '../../../core/database/database_provider.dart';

part 'suitcase_edits_provider.g.dart';

/// La coda locale delle modifiche alla valigia proposta.
@Riverpod(keepAlive: true)
SuitcaseEditsDao suitcaseEditsDao(Ref ref) =>
    ref.read(appDatabaseProvider).suitcaseEditsDao;

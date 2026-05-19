import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/items/providers/item_selection_provider.dart';

/// Unit tests per [ItemSelectionNotifier] e [ItemSelectionState].
///
/// ## Strategia di test
///
/// Ogni test crea un [ProviderContainer] isolato: lo stato è AutoDispose,
/// quindi viene resettato automaticamente tra i test senza bisogno di tearDown
/// espliciti.
///
/// Non c'è dipendenza da repository, database o plugin nativi: il provider è
/// puro Dart e può essere testato senza flutter_test widget pumps.
void main() {
  ProviderContainer makeContainer() => ProviderContainer();

  // ---------------------------------------------------------------------------
  // ItemSelectionState
  // ---------------------------------------------------------------------------
  group('ItemSelectionState', () {
    test('valori default: isActive=false, selectedIds vuoto', () {
      const state = ItemSelectionState();
      expect(state.isActive, isFalse);
      expect(state.selectedIds, isEmpty);
      expect(state.selectionCount, 0);
      expect(state.hasSelection, isFalse);
    });

    test('copyWith sovrascrive solo i campi forniti', () {
      const initial = ItemSelectionState();
      final withActive = initial.copyWith(isActive: true);

      expect(withActive.isActive, isTrue);
      expect(withActive.selectedIds, isEmpty);
    });

    test('copyWith con selectedIds crea una nuova istanza', () {
      const initial = ItemSelectionState();
      final ids = {'a', 'b'};
      final updated = initial.copyWith(selectedIds: ids);

      expect(updated.selectedIds, containsAll(['a', 'b']));
      expect(updated.selectionCount, 2);
      expect(updated.hasSelection, isTrue);
    });

    test('equality: due stati uguali sono ==', () {
      final s1 = ItemSelectionState(isActive: true, selectedIds: {'x', 'y'});
      final s2 = ItemSelectionState(
        isActive: true,
        selectedIds: {'y', 'x'}, // ordine diverso, stesso contenuto
      );
      expect(s1, equals(s2));
    });

    test('equality: stati diversi non sono ==', () {
      final s1 = const ItemSelectionState(isActive: true);
      final s2 = const ItemSelectionState(isActive: false);
      expect(s1, isNot(equals(s2)));
    });

    test('hashCode è coerente con equality', () {
      final s1 = ItemSelectionState(selectedIds: {'a'});
      final s2 = ItemSelectionState(selectedIds: {'a'});
      expect(s1.hashCode, equals(s2.hashCode));
    });

    test('toString contiene isActive e count', () {
      const state = ItemSelectionState(isActive: true);
      expect(state.toString(), contains('isActive: true'));
      expect(state.toString(), contains('count: 0'));
    });
  });

  // ---------------------------------------------------------------------------
  // ItemSelectionNotifier — stato iniziale
  // ---------------------------------------------------------------------------
  group('ItemSelectionNotifier — stato iniziale', () {
    test('stato iniziale: isActive=false, selectedIds vuoto', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      final state = container.read(itemSelectionNotifierProvider);
      expect(state.isActive, isFalse);
      expect(state.selectedIds, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // toggleMode
  // ---------------------------------------------------------------------------
  group('toggleMode()', () {
    test('attiva la selezione (false → true)', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      container.read(itemSelectionNotifierProvider.notifier).toggleMode();
      expect(container.read(itemSelectionNotifierProvider).isActive, isTrue);
    });

    test('disattiva la selezione (true → false) e svuota selectedIds', () {
      final container = makeContainer();
      addTearDown(container.dispose);
      final notifier = container.read(itemSelectionNotifierProvider.notifier);

      notifier.toggleMode(); // attiva
      notifier.toggleItem('id-1');
      notifier.toggleItem('id-2');

      notifier.toggleMode(); // disattiva

      final state = container.read(itemSelectionNotifierProvider);
      expect(state.isActive, isFalse);
      expect(state.selectedIds, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // toggleItem
  // ---------------------------------------------------------------------------
  group('toggleItem()', () {
    test('aggiunge un ID non presente', () {
      final container = makeContainer();
      addTearDown(container.dispose);
      final notifier = container.read(itemSelectionNotifierProvider.notifier);

      notifier.toggleMode();
      notifier.toggleItem('item-1');

      expect(
        container.read(itemSelectionNotifierProvider).selectedIds,
        contains('item-1'),
      );
    });

    test('rimuove un ID già presente', () {
      final container = makeContainer();
      addTearDown(container.dispose);
      final notifier = container.read(itemSelectionNotifierProvider.notifier);

      notifier.toggleMode();
      notifier.toggleItem('item-1');
      notifier.toggleItem('item-1'); // secondo tap: deseleziona

      expect(
        container.read(itemSelectionNotifierProvider).selectedIds,
        isNot(contains('item-1')),
      );
    });

    test(
      'genera un nuovo Set ad ogni chiamata (contratto reattività Riverpod)',
      () {
        final container = makeContainer();
        addTearDown(container.dispose);
        final notifier = container.read(itemSelectionNotifierProvider.notifier);

        notifier.toggleMode();
        notifier.toggleItem('a');
        final setAfterFirst = container
            .read(itemSelectionNotifierProvider)
            .selectedIds;

        notifier.toggleItem('b');
        final setAfterSecond = container
            .read(itemSelectionNotifierProvider)
            .selectedIds;

        // Istanze diverse: il Set non deve essere mutato in place.
        expect(identical(setAfterFirst, setAfterSecond), isFalse);
      },
    );

    test('selezionare più item accumula correttamente', () {
      final container = makeContainer();
      addTearDown(container.dispose);
      final notifier = container.read(itemSelectionNotifierProvider.notifier);

      notifier.toggleMode();
      notifier.toggleItem('a');
      notifier.toggleItem('b');
      notifier.toggleItem('c');

      final state = container.read(itemSelectionNotifierProvider);
      expect(state.selectionCount, 3);
      expect(state.selectedIds, containsAll(['a', 'b', 'c']));
    });
  });

  // ---------------------------------------------------------------------------
  // clear
  // ---------------------------------------------------------------------------
  group('clear()', () {
    test('disattiva la selezione e svuota il Set', () {
      final container = makeContainer();
      addTearDown(container.dispose);
      final notifier = container.read(itemSelectionNotifierProvider.notifier);

      notifier.toggleMode();
      notifier.toggleItem('x');
      notifier.clear();

      final state = container.read(itemSelectionNotifierProvider);
      expect(state.isActive, isFalse);
      expect(state.selectedIds, isEmpty);
    });

    test('chiamare clear su stato già inattivo non genera errori', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      expect(
        () => container.read(itemSelectionNotifierProvider.notifier).clear(),
        returnsNormally,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // selectAll
  // ---------------------------------------------------------------------------
  group('selectAll()', () {
    test('aggiunge tutti gli ID forniti', () {
      final container = makeContainer();
      addTearDown(container.dispose);
      final notifier = container.read(itemSelectionNotifierProvider.notifier);

      notifier.toggleMode();
      notifier.selectAll(['a', 'b', 'c']);

      final state = container.read(itemSelectionNotifierProvider);
      expect(state.selectionCount, 3);
      expect(state.selectedIds, containsAll(['a', 'b', 'c']));
    });

    test('non duplica ID già presenti (Set semantics)', () {
      final container = makeContainer();
      addTearDown(container.dispose);
      final notifier = container.read(itemSelectionNotifierProvider.notifier);

      notifier.toggleMode();
      notifier.toggleItem('a');
      notifier.selectAll(['a', 'b']); // 'a' già presente

      expect(
        container.read(itemSelectionNotifierProvider).selectionCount,
        2, // non 3
      );
    });

    test('selectAll con lista vuota non modifica il Set', () {
      final container = makeContainer();
      addTearDown(container.dispose);
      final notifier = container.read(itemSelectionNotifierProvider.notifier);

      notifier.toggleMode();
      notifier.toggleItem('x');
      notifier.selectAll([]);

      expect(container.read(itemSelectionNotifierProvider).selectionCount, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // deselectAll
  // ---------------------------------------------------------------------------
  group('deselectAll()', () {
    test('svuota selectedIds mantenendo isActive=true', () {
      final container = makeContainer();
      addTearDown(container.dispose);
      final notifier = container.read(itemSelectionNotifierProvider.notifier);

      notifier.toggleMode();
      notifier.selectAll(['a', 'b', 'c']);
      notifier.deselectAll();

      final state = container.read(itemSelectionNotifierProvider);
      expect(state.isActive, isTrue);
      expect(state.selectedIds, isEmpty);
      expect(state.hasSelection, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Scenario end-to-end
  // ---------------------------------------------------------------------------
  group('Scenario end-to-end: long press → select → deselect → cancel', () {
    test('flusso completo senza errori', () {
      final container = makeContainer();
      addTearDown(container.dispose);
      final notifier = container.read(itemSelectionNotifierProvider.notifier);

      // 1. Long press: attiva + seleziona primo item
      notifier.toggleMode();
      notifier.toggleItem('item-A');

      var state = container.read(itemSelectionNotifierProvider);
      expect(state.isActive, isTrue);
      expect(state.selectedIds, contains('item-A'));

      // 2. Tap su altri item per aggiungere
      notifier.toggleItem('item-B');
      notifier.toggleItem('item-C');
      expect(container.read(itemSelectionNotifierProvider).selectionCount, 3);

      // 3. Tap su item già selezionato → deseleziona
      notifier.toggleItem('item-B');
      expect(container.read(itemSelectionNotifierProvider).selectionCount, 2);

      // 4. Utente annulla la selezione (tasto X o back)
      notifier.clear();

      state = container.read(itemSelectionNotifierProvider);
      expect(state.isActive, isFalse);
      expect(state.selectedIds, isEmpty);
    });
  });
}

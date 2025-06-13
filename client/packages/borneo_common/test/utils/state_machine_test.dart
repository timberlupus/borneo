import 'package:test/test.dart';
import 'package:borneo_common/utils/state_machine.dart';

void main() {
  group('StateMachine Tests', () {
    StateMachine<String>? fsm; // 使用可空类型

    setUp(() {
      fsm = StateMachine<String>('idle');

      fsm!.addState(
        'idle',
        onEnter: () async => print('Entering idle state...'),
        onExit: () async => print('Exiting idle state...'),
      );

      fsm!.addState(
        'working',
        onEnter: () async => print('Entering working state...'),
        onExit: () async => print('Exiting working state...'),
      );

      fsm!.addTransition('idle', 'start', 'working', () async {
        await Future.delayed(Duration(milliseconds: 100));
        print('Work started.');
      });

      fsm!.addTransition('working', 'finish', 'idle', () async {
        await Future.delayed(Duration(milliseconds: 100));
        print('Work finished.');
      }, guard: () => true);
    });

    test('Initial state should be idle', () {
      expect(fsm!.currentState, 'idle'); // 使用非空断言
    });

    test('Transition from idle to working', () async {
      await fsm!.trigger('start');
      expect(fsm!.currentState, 'working');
    });

    test('Transition from working to idle', () async {
      await fsm!.trigger('start'); // First transition to working
      await fsm!.trigger('finish'); // Then transition back to idle
      expect(fsm!.currentState, 'idle');
    });

    test('Guard condition prevents transition', () async {
      fsm!.addTransition('working', 'guardedFinish', 'idle', () async {
        await Future.delayed(Duration(milliseconds: 100));
      }, guard: () => false); // Guard always fails

      await fsm!.trigger('start'); // Transition to working
      expect(
        () async => await fsm!.trigger('guardedFinish'),
        throwsA(isA<ArgumentError>()),
      ); // Attempt to use guarded transition

      expect(fsm!.currentState, 'working'); // Should still be in working state
    });
  });
}

class StateMachine<T> {
  T _currentState;
  final Map<T, State<T>> _states = {};

  StateMachine(this._currentState);

  void addState(T state,
      {Future Function()? onEnter, Future Function()? onExit}) {
    _states[state] = State(state, onEnter: onEnter, onExit: onExit);
  }

  void addTransition(T from, String event, T to, Future Function() action,
      {bool Function()? guard}) {
    if (_states[from] != null) {
      _states[from]!.transitions[event] = Transition(to, action, guard);
    }
  }

  Future<void> trigger(String event) async {
    final currentState = _states[_currentState];
    if (currentState != null && currentState.transitions.containsKey(event)) {
      final transition = currentState.transitions[event];
      if (transition != null) {
        // check guard
        if (transition.guard == null ||
            (transition.guard != null && transition.guard!())) {
          if (currentState.onExit != null) {
            await currentState.onExit!();
          }

          await transition.action();
          if (currentState.onEnter != null) {
            await currentState.onEnter!();
          }

          _currentState = transition.to;
        } else {
          throw ArgumentError(
              'Guard condition failed for event $event on state $_currentState',
              'event');
        }
      }
    } else {
      throw ArgumentError(
          'No transition for $_currentState on event $event', 'event');
    }
  }

  T get currentState => _currentState;
}

class State<T> {
  final T name;
  final Future Function()? onEnter;
  final Future Function()? onExit;
  final Map<String, Transition<T>> transitions = {};

  State(this.name, {this.onEnter, this.onExit});
}

class Transition<T> {
  final T to;
  final Future Function() action;
  final bool Function()? guard;

  Transition(this.to, this.action, this.guard);
}

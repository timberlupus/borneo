class AppErrorEvent {
  final String message;
  final StackTrace? stackTrace;
  final Object? error;
  const AppErrorEvent(this.message, {this.error, this.stackTrace});
}

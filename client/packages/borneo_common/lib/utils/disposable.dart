abstract class IDisposable {
  void dispose();
}

R using<T extends IDisposable, R>(T resource, R Function(T) action) {
  try {
    return action(resource);
  } finally {
    resource.dispose();
  }
}

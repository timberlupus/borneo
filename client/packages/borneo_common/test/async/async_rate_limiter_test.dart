import 'package:test/test.dart';
import 'dart:async';

import 'package:borneo_common/async/async_rate_limiter.dart';

void main() {
  group('AsyncRateLimiter', () {
    test('should execute a single task', () async {
      final rateLimiter = AsyncRateLimiter<Future Function()>(
          interval: Duration(milliseconds: 100));
      var executed = false;

      rateLimiter.add(() async {
        executed = true;
      });

      await Future.delayed(Duration(milliseconds: 200));
      expect(executed, isTrue);
      rateLimiter.dispose();
    });

    test('should execute tasks with the specified interval', () async {
      final rateLimiter = AsyncRateLimiter<Future Function()>(
          interval: Duration(milliseconds: 100));
      var executionTimes = <DateTime>[];

      rateLimiter.add(() async {
        executionTimes.add(DateTime.now());
      });

      rateLimiter.add(() async {
        executionTimes.add(DateTime.now());
      });

      await Future.delayed(Duration(milliseconds: 300));
      expect(executionTimes.length, 2);
      expect(executionTimes[1].difference(executionTimes[0]).inMilliseconds,
          greaterThanOrEqualTo(100));
      rateLimiter.dispose();
    });

    test('should execute tasks in the order they were added', () async {
      final rateLimiter = AsyncRateLimiter<Future Function()>(
          interval: Duration(milliseconds: 100));
      var executionOrder = <int>[];

      rateLimiter.add(() async {
        executionOrder.add(1);
      });

      rateLimiter.add(() async {
        executionOrder.add(2);
      });

      await Future.delayed(Duration(milliseconds: 300));
      expect(executionOrder, [1, 2]);
      rateLimiter.dispose();
    });

    test('should execute the last pending task when stream is closed',
        () async {
      final rateLimiter = AsyncRateLimiter<Future Function()>(
          interval: Duration(milliseconds: 100));
      var executed = false;

      rateLimiter.add(() async {
        executed = true;
      });

      rateLimiter.dispose();
      await Future.delayed(Duration(milliseconds: 200));
      expect(executed, isTrue);
    });
  });
}

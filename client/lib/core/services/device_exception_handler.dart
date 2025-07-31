import 'dart:async';
import 'dart:io';

import 'package:borneo_common/io/net/coap_client.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:coap/coap.dart';
import 'package:logging/logging.dart';

/// Centralized exception handler for device API calls
/// Provides consistent error handling, logging, and user feedback
class DeviceExceptionHandler {
  static final Logger _logger = Logger('DeviceExceptionHandler');

  /// Wraps a device API call with comprehensive exception handling
  static Future<T> handleDeviceCall<T>(
    Future<T> Function() apiCall, {
    required String deviceName,
    required String operation,
    T? fallbackValue,
    void Function(Object error, StackTrace stack)? onError,
    CancellationToken? cancelToken,
  }) async {
    try {
      if (cancelToken?.isCancelled ?? false) {
        throw Exception('Operation cancelled');
      }

      return await apiCall();
    } on CoapException catch (e, stack) {
      _logger.warning('CoAP error during $operation on $deviceName: ${e.message}', e, stack);
      _handleCoapException(e, deviceName, operation);
      if (onError != null) {
        onError(e, stack);
      }
      if (fallbackValue != null) return fallbackValue;
      rethrow;
    } on SocketException catch (e, stack) {
      _logger.warning('Network error during $operation on $deviceName: ${e.message}', e, stack);
      _handleNetworkException(e, deviceName, operation);
      if (onError != null) {
        onError(e, stack);
      }
      if (fallbackValue != null) return fallbackValue;
      rethrow;
    } on TimeoutException catch (e, stack) {
      _logger.warning('Timeout during $operation on $deviceName: ${e.message}', e, stack);
      _handleTimeoutException(e, deviceName, operation);
      if (onError != null) {
        onError(e, stack);
      }
      if (fallbackValue != null) return fallbackValue;
      rethrow;
    } catch (e, stack) {
      _logger.severe('Unexpected error during $operation on $deviceName: $e', e, stack);
      _handleGenericException(e, deviceName, operation);
      if (onError != null) {
        onError(e, stack);
      }
      if (fallbackValue != null) return fallbackValue;
      rethrow;
    }
  }

  /// Handles device status refresh with safe defaults
  static Future<void> handleDeviceRefresh({
    required String deviceName,
    required Future<void> Function() refreshCall,
    void Function(Object error)? onError,
    bool silent = false,
  }) async {
    try {
      await handleDeviceCall(
        refreshCall,
        deviceName: deviceName,
        operation: 'status refresh',
        fallbackValue: null,
        onError: onError != null ? (error, _) => onError(error) : null,
      );
    } catch (e) {
      if (!silent) {
        _logger.info('Device refresh failed for $deviceName but continuing gracefully');
      }
    }
  }

  /// Handles CoAP-specific exceptions with appropriate user messages
  static void _handleCoapException(CoapException e, String deviceName, String operation) {
    final statusCode = ResponseCode.decode(e.response.code.code);
    String message;

    switch (statusCode) {
      case ResponseCode.notFound:
        message = 'Device $deviceName not found';
        break;
      case ResponseCode.unauthorized:
        message = 'Authentication failed for $deviceName';
        break;
      case ResponseCode.forbidden:
        message = 'Access denied for $deviceName';
        break;
      case ResponseCode.gatewayTimeout:
        message = 'Request timeout for $deviceName';
        break;
      case ResponseCode.internalServerError:
        message = 'Internal server error on $deviceName';
        break;
      case ResponseCode.serviceUnavailable:
        message = 'Device $deviceName temporarily unavailable';
        break;
      default:
        message = 'Communication error with $deviceName (Code: $statusCode)';
    }

    _logger.info('CoAP $operation error: $message');
  }

  /// Handles network-related exceptions
  static void _handleNetworkException(SocketException e, String deviceName, String operation) {
    String message;
    if (e.message.contains('refused')) {
      message = 'Connection refused by $deviceName';
    } else if (e.message.contains('unreachable')) {
      message = 'Device $deviceName is unreachable';
    } else if (e.message.contains('timeout')) {
      message = 'Network timeout for $deviceName';
    } else {
      message = 'Network error connecting to $deviceName';
    }

    _logger.info('Network $operation error: $message');
  }

  /// Handles timeout exceptions
  static void _handleTimeoutException(TimeoutException e, String deviceName, String operation) {
    _logger.info('Timeout during $operation on $deviceName: ${e.duration}');
  }

  /// Handles generic exceptions
  static void _handleGenericException(Object e, String deviceName, String operation) {
    _logger.info('Unexpected error during $operation on $deviceName: $e');
  }

  /// Provides a human-readable error message for display to users
  static String getUserFriendlyMessage(Object error, {String? deviceName}) {
    if (error is CoapException) {
      switch (ResponseCode.decode(error.response.code.code)) {
        case ResponseCode.notFound:
          return 'Device not found';
        case ResponseCode.unauthorized:
          return 'Authentication failed';
        case ResponseCode.forbidden:
          return 'Access denied';
        case ResponseCode.gatewayTimeout:
          return 'Request timed out';
        case ResponseCode.internalServerError:
          return 'Internal server error';
        case ResponseCode.serviceUnavailable:
          return 'Device temporarily unavailable';
        default:
          return 'Communication error (${error.response.code})';
      }
    } else if (error is SocketException) {
      if (error.message.contains('refused')) {
        return 'Connection refused';
      } else if (error.message.contains('unreachable')) {
        return 'Device unreachable';
      } else if (error.message.contains('timeout')) {
        return 'Network timeout';
      } else {
        return 'Network connection error';
      }
    } else if (error is TimeoutException) {
      return 'Request timed out';
    } else if (error is CoapRequestCancellationException) {
      return 'Operation cancelled';
    } else {
      return 'Unknown error occurred';
    }
  }
}

/// Extension methods for convenient exception handling
extension DeviceApiExtensions on Future Function() {
  /// Safely executes a device API call with exception handling
  Future<T> safeDeviceCall<T>({
    required String deviceName,
    required String operation,
    T? fallbackValue,
    void Function(Object error, StackTrace stack)? onError,
  }) {
    return DeviceExceptionHandler.handleDeviceCall(
      this as Future<T> Function(),
      deviceName: deviceName,
      operation: operation,
      fallbackValue: fallbackValue,
      onError: onError,
    );
  }

  /// Safely refreshes device status
  Future<void> safeDeviceRefresh({
    required String deviceName,
    void Function(Object error)? onError,
    bool silent = false,
  }) {
    return DeviceExceptionHandler.handleDeviceRefresh(
      deviceName: deviceName,
      refreshCall: this as Future<void> Function(),
      onError: onError,
      silent: silent,
    );
  }
}

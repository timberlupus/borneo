import 'package:flutter/material.dart';
import 'package:flutter_gettext/flutter_gettext.dart';

class ConfirmationSheet extends StatelessWidget {
  final String message;
  final VoidCallback okPressed;
  final VoidCallback? cancelPressed;

  const ConfirmationSheet({super.key, required this.message, required this.okPressed, this.cancelPressed});

  static void show(
    BuildContext context, {
    required String message,
    required VoidCallback okPressed,
    VoidCallback? cancelPressed,
  }) {
    showModalBottomSheet(
      context: context,
      elevation: 1,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      builder: (BuildContext context) {
        return ConfirmationSheet(message: message, okPressed: okPressed, cancelPressed: cancelPressed);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _ConfirmationBody(
      message: message,
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            if (cancelPressed != null) {
              cancelPressed!();
            }
          },
          child: Text(context.translate('Cancel')),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            okPressed();
          },
          child: Text(context.translate('OK')),
        ),
      ],
    );
  }
}

class AsyncConfirmationSheet extends StatelessWidget {
  final String message;

  const AsyncConfirmationSheet({super.key, required this.message});

  static Future<bool> show(BuildContext context, {required String message}) async {
    return await showModalBottomSheet(
          context: context,
          elevation: 1,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
          builder: (BuildContext context) {
            return AsyncConfirmationSheet(message: message);
          },
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return _ConfirmationBody(
      message: message,
      actions: [
        TextButton(
          child: Text(context.translate('Cancel')),
          onPressed: () {
            Navigator.of(context).pop(false);
          },
        ),
        TextButton(
          child: Text(context.translate('OK')),
          onPressed: () {
            Navigator.of(context).pop(true);
          },
        ),
      ],
    );
  }
}

/// Shared body used by both [ConfirmationSheet] and
/// [AsyncConfirmationSheet] to avoid duplicating the layout logic.
class _ConfirmationBody extends StatelessWidget {
  final String message;
  final List<Widget> actions;

  const _ConfirmationBody({required this.message, required this.actions});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(message),
            SizedBox(height: 16.0),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
          ],
        ),
      ),
    );
  }
}

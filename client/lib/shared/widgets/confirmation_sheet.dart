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
      builder: (BuildContext context) {
        return ConfirmationSheet(message: message, okPressed: okPressed, cancelPressed: cancelPressed);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(message),
            SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
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
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    okPressed();
                  },
                  child: Text(context.translate('Ok')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AsyncConfirmationSheet extends StatelessWidget {
  final String message;

  const AsyncConfirmationSheet({super.key, required this.message});

  static Future<bool> show(BuildContext context, {required String message}) async {
    return await showModalBottomSheet(
          context: context,
          builder: (BuildContext context) {
            return AsyncConfirmationSheet(message: message);
          },
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(message),
            SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                ),
                TextButton(
                  child: Text('Ok'),
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

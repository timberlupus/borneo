import 'package:flutter/material.dart';

/// An entry used by [GenericBottomSheetPicker].
///
/// This mirrors the lightweight API of [DropdownMenuEntry], providing a
/// value and a human-readable label.  The picker is generic over the value
/// type so it can be reused in a variety of settings.
class GenericBottomSheetPickerEntry<T> {
  /// The underlying value represented by this entry.
  final T value;

  /// Text shown to the user for this option.
  final String label;

  const GenericBottomSheetPickerEntry({required this.value, required this.label});
}

/// A bottom sheet that allows the caller to pick one item from a list of
/// generic entries.
///
/// The API is intentionally similar to [DropdownMenu] so that callers can
/// supply a list of ``GenericBottomSheetPickerEntry`` objects.  A static
/// ``show`` helper is provided so the picker can be invoked without needing to
/// construct the widget manually.
class GenericBottomSheetPicker<T> extends StatelessWidget {
  final String title;
  final List<GenericBottomSheetPickerEntry<T>> entries;
  final T? selectedValue;
  final ValueChanged<T> onValueSelected;

  const GenericBottomSheetPicker({
    super.key,
    required this.title,
    required this.entries,
    required this.selectedValue,
    required this.onValueSelected,
  });

  /// Shows the picker from a bottom sheet.
  ///
  /// ``selectedValue`` is optional; if it is null or not contained in
  /// ``entries`` the first entry in the list will be treated as the
  /// selected item.
  static Future<void> show<T>({
    required BuildContext context,
    required String title,
    required List<GenericBottomSheetPickerEntry<T>> entries,
    required T? selectedValue,
    required ValueChanged<T> onValueSelected,
  }) {
    // figure out an effective selection that definitely exists in
    // ``entries`` so the widget build logic can rely on it.
    T? effective = selectedValue;
    if (effective == null || !entries.any((e) => e.value == effective)) {
      if (entries.isNotEmpty) {
        effective = entries.first.value;
      }
    }

    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GenericBottomSheetPicker<T>(
        title: title,
        entries: entries,
        selectedValue: effective,
        onValueSelected: (val) {
          onValueSelected(val);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final T? effective = (selectedValue != null && entries.any((e) => e.value == selectedValue))
        ? selectedValue
        : (entries.isNotEmpty ? entries.first.value : null);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: colorScheme.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                ),
              ],
            ),
          ),

          // items
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: entries.length,
              separatorBuilder: (context, index) => Divider(height: 1, indent: 20, endIndent: 20),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final isSelected = entry.value == effective;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onValueSelected(entry.value),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.label,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                                fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (isSelected) Icon(Icons.check, color: colorScheme.primary, size: 20),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

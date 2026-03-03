import 'package:flutter/material.dart';

// expose the generic picker alongside the legacy implementation
export 'generic_bottom_sheet_picker.dart';

import 'generic_bottom_sheet_picker.dart';

/// A custom bottom sheet picker that provides a clean, native iOS/Android experience
/// for selecting from a list of **string** options.
///
/// The legacy API remains available for backwards compatibility, but
/// internally it now delegates to [GenericBottomSheetPicker] so the two
/// implementations share the same behaviour and styling.
class BottomSheetPicker extends StatelessWidget {
  final String title;
  final List<String> items;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const BottomSheetPicker({
    super.key,
    required this.title,
    required this.items,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    required List<String> items,
    required int selectedIndex,
    required ValueChanged<int> onItemSelected,
  }) {
    // convert to generic entries
    final entries = items.map((s) => GenericBottomSheetPickerEntry<String>(value: s, label: s)).toList();

    final selectedValue = (selectedIndex >= 0 && selectedIndex < items.length)
        ? items[selectedIndex]
        : (items.isNotEmpty ? items.first : null);

    return GenericBottomSheetPicker.show<String>(
      context: context,
      title: title,
      entries: entries,
      selectedValue: selectedValue,
      onValueSelected: (val) {
        final idx = items.indexOf(val);
        if (idx != -1) {
          onItemSelected(idx);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with title and close button
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

          // Items list
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: items.length,
              separatorBuilder: (context, index) => const Divider(height: 1, thickness: 1, indent: 20, endIndent: 20),
              itemBuilder: (context, index) {
                final isSelected = index == selectedIndex;
                return ListTile(
                  dense: true,
                  onTap: () => onItemSelected(index),
                  title: Text(
                    items[index],
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                      fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                  //      if (isSelected) Icon(Icons.check, color: colorScheme.primary, size: 20),
                );
              },
            ),
          ),

          // Bottom padding
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

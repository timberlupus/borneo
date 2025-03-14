import 'package:flutter/material.dart';

import 'package:borneo_app/views/common/hex_color.dart';
import '../view_models/ieditor.dart';
import 'brightness_slider_list_tile.dart';

class BrightnessSliderList<TEditor extends IEditor> extends StatelessWidget {
  final TEditor editor;
  final bool disabled;
  const BrightnessSliderList(this.editor, {required this.disabled, super.key});

  @override
  Widget build(BuildContext context) {
    final sliders = <Widget>[];
    for (int index = 0; index < editor.availableChannelCount; index++) {
      final channelInfo = editor.deviceInfo.channels.elementAt(index);
      final slider = ValueListenableBuilder<int>(
        valueListenable: editor.channels[index],
        builder:
            (context, channelValue, child) => BrightnessSliderListTile(
              channelName: channelInfo.name,
              max: 100,
              min: 0,
              value: channelValue,
              color: HexColor.fromHex(channelInfo.color),
              disabled: this.disabled,
              trailing: Text(
                '${channelValue.toString().padLeft(3, '\u2007')}%',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(fontFeatures: [FontFeature.tabularFigures()]),
              ),
              onChanged: (newValue) {
                editor.updateChannelValue(index, newValue);
              },
            ),
      );
      sliders.add(slider);
    }
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: editor.availableChannelCount,
        itemBuilder: (context, index) => sliders[index],
        separatorBuilder: (context, index) => Divider(height: 1, color: Theme.of(context).colorScheme.surface),
      ),
    );
  }
}

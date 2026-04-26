import 'package:flutter/material.dart';

class HomeScreenBody extends StatelessWidget {
  final bool isWide;
  final Widget? filterPanel;
  final Widget topSectionWithTabs;
  final Widget sessionPanel;
  final Widget articlesList;
  final double topPanelWidth;
  final double filterPanelWidth;
  final ValueChanged<double> onTopPanelWidthChanged;
  final ValueChanged<double> onFilterPanelWidthChanged;

  const HomeScreenBody({
    super.key,
    required this.isWide,
    required this.filterPanel,
    required this.topSectionWithTabs,
    required this.sessionPanel,
    required this.articlesList,
    required this.topPanelWidth,
    required this.filterPanelWidth,
    required this.onTopPanelWidthChanged,
    required this.onFilterPanelWidthChanged,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: topPanelWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: topSectionWithTabs),
                sessionPanel,
              ],
            ),
          ),
          _ResizeHandle(
            onDragDelta: (delta) {
              onTopPanelWidthChanged(
                (topPanelWidth + delta).clamp(180.0, 500.0).toDouble(),
              );
            },
          ),
          const SizedBox(width: 8),
          Expanded(child: articlesList),
        ],
      ),
    );

    if (!isWide) return content;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (filterPanel != null) filterPanel!,
        _ResizeHandle(
          onDragDelta: (delta) {
            onFilterPanelWidthChanged(
              (filterPanelWidth + delta).clamp(180.0, 420.0).toDouble(),
            );
          },
        ),
        Expanded(child: content),
      ],
    );
  }
}

class _ResizeHandle extends StatelessWidget {
  final ValueChanged<double> onDragDelta;

  const _ResizeHandle({required this.onDragDelta});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) {
          onDragDelta(details.delta.dx);
        },
        child: Container(
          width: 10,
          height: double.infinity,
          alignment: Alignment.center,
          child: Container(width: 2, color: Colors.grey.shade400),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../services/token/token_usage_models.dart';

class TokenUsageTable extends StatelessWidget {
  final TokenUsageSummary summary;

  const TokenUsageTable({
    super.key,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <ProviderTokenSummary>[
      summary.allProviders,
      ...summary.byProvider,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Usage is grouped by provider service. "Last model" and "Last use case" show the most recent run recorded for each row.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Provider')),
              DataColumn(label: Text('Last Run')),
              DataColumn(label: Text('Today')),
              DataColumn(label: Text('Week')),
              DataColumn(label: Text('Month')),
              DataColumn(label: Text('Last Model')),
              DataColumn(label: Text('Last Use Case')),
            ],
            rows: rows.map(_buildRow).toList(),
          ),
        ),
      ],
    );
  }

  DataRow _buildRow(ProviderTokenSummary summary) {
    final isAllProviders = summary.providerType == 'all';
    final style = TextStyle(
      fontWeight: isAllProviders ? FontWeight.w700 : FontWeight.w500,
    );

    return DataRow(
      cells: [
        DataCell(Text(summary.providerLabel, style: style)),
        DataCell(Text('${summary.lastRun}', style: style)),
        DataCell(Text('${summary.today}', style: style)),
        DataCell(Text('${summary.week}', style: style)),
        DataCell(Text('${summary.month}', style: style)),
        DataCell(
          Tooltip(
            message: summary.lastModelUsed.isEmpty
                ? 'Model not recorded yet'
                : summary.lastModelUsed,
            child: Text(
              summary.lastModelUsed.isEmpty ? '-' : summary.lastModelUsed,
              style: style,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        DataCell(
          Tooltip(
            message: _prettyUseCase(summary.lastUseCase),
            child: Text(
              _prettyUseCase(summary.lastUseCase),
              style: style,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  String _prettyUseCase(String useCase) {
    switch (useCase) {
      case 'review':
        return 'Review';
      case 'teaching':
        return 'Teaching';
      case 'laymanQuick':
        return 'Layman Quick';
      case 'laymanDetailed':
        return 'Layman Detailed';
      case 'laymanPpt':
        return 'Layman PPT';
      case '':
        return '-';
      default:
        return useCase;
    }
  }
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../core/utils/browser_files.dart';
import '../providers/overview_provider.dart';
import '../theme/theme.dart';

/// One printable report the API can make.
class _PdfReport {
  const _PdfReport(this.kind, this.title, this.forWho, this.icon, {this.maxDays, this.ignoresPeriod = false});

  final String kind;
  final String title;
  final String forWho;
  final IconData icon;

  /// Longest period the report accepts; the entry/exit log lists every car.
  final int? maxDays;

  /// A snapshot "as of now" rather than a period.
  final bool ignoresPeriod;
}

const _reports = [
  _PdfReport('summary', 'Parking summary', 'For school administration', Icons.insights_outlined),
  _PdfReport('collections', 'Collection report', 'For accounting', Icons.payments_outlined),
  _PdfReport('violations', 'Violations report', 'For the security or discipline office', Icons.gavel_outlined),
  _PdfReport('entry-exit', 'Entry and exit log', 'For security · 7 days at most', Icons.swap_horiz,
      maxDays: 7),
  _PdfReport('incidents', 'Incident report', 'For security', Icons.report_outlined),
  _PdfReport('vehicles', 'Registered vehicles', 'For the admin office · as of today', Icons.directions_car_outlined,
      ignoresPeriod: true),
];

/// Download the printable PDF reports for the period the page has picked.
///
/// The PDF is made on the server, not here, so its figures come straight from
/// the database and it carries a report number and a QR code that checks the
/// printed copy against what the system recorded. A file built in the browser
/// could carry neither honestly.
class ReportPdfMenu extends ConsumerStatefulWidget {
  const ReportPdfMenu({super.key, required this.period});

  final StateProvider<OverviewPeriod> period;

  @override
  ConsumerState<ReportPdfMenu> createState() => _ReportPdfMenuState();
}

class _ReportPdfMenuState extends ConsumerState<ReportPdfMenu> {
  String? _busy;

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(widget.period);

    return MenuAnchor(
      menuChildren: [
        for (final r in _reports)
          MenuItemButton(
            leadingIcon: Icon(r.icon, size: AppSizes.iconSm),
            onPressed: _busy != null ? null : () => _download(r, period),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.x1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(r.title),
                  Text(
                    r.forWho,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),
      ],
      builder: (context, controller, _) => OutlinedButton.icon(
        icon: _busy == null
            ? const Icon(Icons.picture_as_pdf_outlined, size: AppSizes.iconSm)
            : const SizedBox.square(
                dimension: AppSizes.iconSm,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
        label: Text(_busy == null ? 'Download PDF' : 'Preparing…'),
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }

  Future<void> _download(_PdfReport report, OverviewPeriod period) async {
    final messenger = ScaffoldMessenger.of(context);

    // Said here rather than after a round trip; the server refuses it too.
    final days = period.days;
    final max = report.maxDays;
    if (max != null && (days == null || days.to.difference(days.from).inDays + 1 > max)) {
      messenger.showSnackBar(SnackBar(
        content: Text('The ${report.title.toLowerCase()} covers $max days at most. '
            'Pick a day or a shorter range first.'),
      ));
      return;
    }

    setState(() => _busy = report.kind);
    try {
      final response = await ref.read(dioProvider).get<List<int>>(
            ApiEndpoints.reportPdf(report.kind),
            queryParameters: report.ignoresPeriod ? null : period.query,
            options: Options(responseType: ResponseType.bytes),
          );

      final name = _fileName(response.headers) ?? 'aimpark-${report.kind}.pdf';
      BrowserFiles.download(
        name,
        Uint8List.fromList(response.data ?? const []),
        mimeType: 'application/pdf',
      );

      final number = response.headers.value('x-report-number');
      messenger.showSnackBar(SnackBar(
        content: Text(number == null ? '${report.title} downloaded.' : '${report.title} $number downloaded.'),
      ));
    } on DioException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_message(e, report))));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  /// The bytes of an error are still the server's JSON `{ message }`.
  static String _message(DioException e, _PdfReport report) {
    final data = e.response?.data;
    if (data is List<int> && data.isNotEmpty) {
      try {
        final body = jsonDecode(utf8.decode(data));
        if (body is Map && body['message'] is String) return body['message'] as String;
      } catch (_) {/* not JSON; fall through */}
    }
    return "Couldn't make the ${report.title.toLowerCase()}. Try again.";
  }

  static String? _fileName(Headers headers) {
    final header = headers.value('content-disposition');
    if (header == null) return null;
    final match = RegExp(r"""filename\*?=(?:UTF-8'')?"?([^";]+)"?""").firstMatch(header);
    return match == null ? null : Uri.decodeComponent(match.group(1)!);
  }
}

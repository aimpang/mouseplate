import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:mouseplate/models/party_member.dart';
import 'package:mouseplate/models/planned_meal.dart';
import 'package:mouseplate/models/trip.dart';
import 'package:mouseplate/models/usage_entry.dart';

abstract final class ExportService {
  static Future<void> generateAndSharePdf({
    required Trip trip,
    required List<UsageEntry> usage,
  }) async {
    final doc = pw.Document(title: 'Enchanted Credits — Trip Summary');

    final usedQS = usage.where((e) => e.type == UsageType.quickService).length;
    final usedTS = usage.where((e) => e.type == UsageType.tableService).length;
    final usedSnack = usage.where((e) => e.type == UsageType.snack).length;

    final remainQS = (trip.totalQuickServiceCredits - usedQS).clamp(0, 999999);
    final remainTS = (trip.totalTableServiceCredits - usedTS).clamp(0, 999999);
    final remainSnack = (trip.totalSnackCredits - usedSnack).clamp(0, 999999);

    final loggedValue = usage.fold<double>(0.0, (s, e) => s + (e.value ?? 0.0));
    final delta = trip.estimatedOutOfPocketCost - trip.estimatedTotalCost;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 48),
        header: (_) => _pageHeader(trip),
        footer: (_) => _pageFooter(),
        build: (context) => [
          _sectionTitle('Trip Summary'),
          _tripSummaryTable(trip),
          pw.SizedBox(height: 20),

          if (trip.partyMembers.isNotEmpty) ...[
            _sectionTitle('Party Members'),
            _partyMembersTable(trip.partyMembers),
            pw.SizedBox(height: 20),
          ],

          _sectionTitle('Credit Totals'),
          _creditTable(
            trip: trip,
            usedQS: usedQS, usedTS: usedTS, usedSnack: usedSnack,
            remainQS: remainQS, remainTS: remainTS, remainSnack: remainSnack,
          ),
          pw.SizedBox(height: 20),

          _sectionTitle('Worth It? Breakdown'),
          _worthItTable(trip: trip, loggedValue: loggedValue, delta: delta),
          pw.SizedBox(height: 20),

          if (trip.plannedMeals.isNotEmpty) ...[
            _sectionTitle('Planned Meals'),
            _plannedMealsTable(trip.plannedMeals),
            pw.SizedBox(height: 20),
          ],

          _sectionTitle('Usage Log'),
          if (usage.isEmpty)
            _emptyNote('No meals or snacks have been logged yet.')
          else
            _usageLogTable(usage),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'enchanted-credits-trip-summary.pdf',
    );
  }

  // ── Header / Footer ──────────────────────────────────────────────────────

  static pw.Widget _pageHeader(Trip trip) {
    final checkIn = _fmtDate(trip.startDate);
    final checkOut = _fmtDate(trip.checkoutDay);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Enchanted Credits', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo700)),
            pw.Text('Trip Summary', style: pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
          ],
        ),
        pw.SizedBox(height: 3),
        pw.Text('$checkIn – $checkOut  •  ${trip.planType.label}', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
        pw.Divider(height: 14, thickness: 0.5, color: PdfColors.grey300),
      ],
    );
  }

  static pw.Widget _pageFooter() {
    final now = _fmtDate(DateTime.now());
    return pw.Column(
      children: [
        pw.Divider(height: 14, thickness: 0.5, color: PdfColors.grey300),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Not affiliated with The Walt Disney Company.', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
            pw.Text('Exported $now', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
          ],
        ),
      ],
    );
  }

  // ── Section helpers ───────────────────────────────────────────────────────

  static pw.Widget _sectionTitle(String title) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo800)),
      pw.SizedBox(height: 6),
    ],
  );

  static pw.Widget _emptyNote(String msg) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 8),
    child: pw.Text(msg, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic)),
  );

  // ── Trip summary ──────────────────────────────────────────────────────────

  static pw.Widget _tripSummaryTable(Trip trip) {
    final bevLabel = switch (trip.beveragePreference) {
      BeveragePreference.waterOnly => 'Water only',
      BeveragePreference.fountainOrNonAlcoholic => 'Fountain / non-alcoholic',
      BeveragePreference.includesAlcohol => 'Includes alcohol',
    };
    final styleLabel = switch (trip.diningStyle) {
      DiningStyle.budget => 'Budget',
      DiningStyle.average => 'Average',
      DiningStyle.splurge => 'Splurge',
    };

    final rows = [
      ['Plan type', trip.planType.label],
      ['Check-in', _fmtDate(trip.startDate)],
      ['Check-out', _fmtDate(trip.checkoutDay)],
      ['Nights', '${trip.nights}'],
      ['Adults', '${trip.adults}'],
      ['Children', '${trip.children}'],
      ['Dining style', styleLabel],
      ['Beverage preference', bevLabel],
      if (trip.snacksPerPersonPerDay > 0) ['Snacks / person / day', '${trip.snacksPerPersonPerDay}'],
      if (trip.dessertAtTableService) ['Dessert at table service', 'Yes'],
      if (trip.resortRefillableMugs) ['Resort refillable mugs', 'Yes'],
      if (trip.annualPassholder) ['Annual Passholder', 'Yes'],
      if (trip.dvcMember) ['DVC Member', 'Yes'],
    ];

    return _keyValueTable(rows);
  }

  // ── Party members ─────────────────────────────────────────────────────────

  static pw.Widget _partyMembersTable(List<PartyMember> members) {
    final headers = ['Name', 'Type', 'Eating style', 'Snacks/day', 'Dessert at TS', 'Alcohol'];
    final rows = members.map((m) => [
      m.name,
      m.isAdult ? 'Adult' : 'Child',
      m.eatingStyle.label,
      '${m.snacksPerDay}',
      m.dessertAtTableService ? 'Yes' : 'No',
      m.isAdult ? (m.enjoysAlcohol ? 'Yes' : 'No') : '—',
    ]).toList();

    final headerStyle = pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white);
    final cellStyle = const pw.TextStyle(fontSize: 9);
    const headerBg = PdfColors.blueGrey700;
    const evenBg = PdfColors.grey100;

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.5),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(2.5),
        3: const pw.FlexColumnWidth(1.5),
        4: const pw.FlexColumnWidth(1.8),
        5: const pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: headerBg),
          children: headers.map((h) => pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: pw.Text(h, style: headerStyle),
          )).toList(),
        ),
        ...rows.asMap().entries.map((entry) {
          final bg = entry.key.isEven ? evenBg : PdfColors.white;
          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bg),
            children: entry.value.map((cell) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              child: pw.Text(cell, style: cellStyle),
            )).toList(),
          );
        }),
      ],
    );
  }

  // ── Credits ───────────────────────────────────────────────────────────────

  static pw.Widget _creditTable({
    required Trip trip,
    required int usedQS, required int usedTS, required int usedSnack,
    required int remainQS, required int remainTS, required int remainSnack,
  }) {
    final headers = ['Credit type', 'Total', 'Used', 'Remaining'];
    final rows = <List<String>>[
      ['Quick-Service', '${trip.totalQuickServiceCredits}', '$usedQS', '$remainQS'],
      if (trip.totalTableServiceCredits > 0)
        ['Table-Service', '${trip.totalTableServiceCredits}', '$usedTS', '$remainTS'],
      if (trip.totalSnackCredits > 0)
        ['Snack', '${trip.totalSnackCredits}', '$usedSnack', '$remainSnack'],
      ['Total', '${trip.totalAllCredits}', '${usedQS + usedTS + usedSnack}', '${remainQS + remainTS + remainSnack}'],
    ];
    return _dataTable(headers: headers, rows: rows, boldLastRow: true);
  }

  // ── Worth-it ──────────────────────────────────────────────────────────────

  static pw.Widget _worthItTable({
    required Trip trip,
    required double loggedValue,
    required double delta,
  }) {
    final rows = [
      ['Plan cost (estimated)', _money(trip.estimatedTotalCost)],
      ['Cash value if buying same items', _money(trip.estimatedOutOfPocketCost)],
      ['Estimated net ${delta >= 0 ? 'savings' : 'extra cost'}', _money(delta.abs())],
      ['Value logged so far', _money(loggedValue)],
    ];
    return _keyValueTable(rows);
  }

  // ── Planned meals ─────────────────────────────────────────────────────────

  static pw.Widget _plannedMealsTable(List<PlannedMeal> meals) {
    final sorted = [...meals]..sort((a, b) {
      final dayDiff = a.day.compareTo(b.day);
      if (dayDiff != 0) return dayDiff;
      return a.slot.index.compareTo(b.slot.index);
    });

    final headers = ['Date', 'Slot', 'Restaurant', 'Type', 'Est. value'];
    final rows = sorted.map((m) => [
      _fmtDate(m.day),
      m.slot.label,
      m.restaurant,
      m.type.shortLabel,
      m.estimatedValue != null ? _money(m.estimatedValue!) : '—',
    ]).toList();

    return _dataTable(headers: headers, rows: rows);
  }

  // ── Usage log ─────────────────────────────────────────────────────────────

  static pw.Widget _usageLogTable(List<UsageEntry> usage) {
    final sorted = [...usage]..sort((a, b) => a.usedAt.compareTo(b.usedAt));

    final headers = ['Date & time', 'Type', 'Note', 'Value'];
    final rows = sorted.map((e) => [
      _fmtDateTime(e.usedAt),
      e.type.label,
      e.note ?? '—',
      e.value != null ? _money(e.value!) : '—',
    ]).toList();

    return _dataTable(headers: headers, rows: rows);
  }

  // ── Table primitives ──────────────────────────────────────────────────────

  static pw.Widget _keyValueTable(List<List<String>> rows) {
    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(3),
      },
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: rows.asMap().entries.map((entry) {
        final isEven = entry.key.isEven;
        final row = entry.value;
        return pw.TableRow(
          decoration: pw.BoxDecoration(color: isEven ? PdfColors.grey50 : PdfColors.white),
          children: [
            _cell(row[0], bold: true),
            _cell(row[1]),
          ],
        );
      }).toList(),
    );
  }

  static pw.Widget _dataTable({required List<String> headers, required List<List<String>> rows, bool boldLastRow = false}) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.indigo50),
          children: headers.map((h) => _cell(h, bold: true)).toList(),
        ),
        ...rows.asMap().entries.map((entry) {
          final isLast = boldLastRow && entry.key == rows.length - 1;
          final isEven = entry.key.isEven;
          return pw.TableRow(
            decoration: pw.BoxDecoration(color: isEven ? PdfColors.white : PdfColors.grey50),
            children: entry.value.map((v) => _cell(v, bold: isLast)).toList(),
          );
        }),
      ],
    );
  }

  static pw.Widget _cell(String text, {bool bold = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    child: pw.Text(
      text,
      style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
    ),
  );

  // ── Formatters ────────────────────────────────────────────────────────────

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  static String _fmtDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

  static String _fmtDateTime(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    return '${_months[d.month - 1]} ${d.day}  $h:$m $ampm';
  }

  static String _money(double v) => '\$${v.toStringAsFixed(2)}';
}

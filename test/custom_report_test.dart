import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cosecha_app/logic/providers/custom_report_provider.dart';
import 'package:cosecha_app/ui/screens/reports/custom_report_screen.dart';

Widget _createTestWidget(CustomReportProvider provider) {
  return MaterialApp(
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [
      Locale('es', 'ES'),
      Locale('es', 'BO'),
    ],
    home: ChangeNotifierProvider<CustomReportProvider>.value(
      value: provider,
      child: const CustomReportScreen(),
    ),
  );
}

void main() {
  group('CustomReportProvider Tests', () {
    test('Valores iniciales correctos en CustomReportProvider', () {
      final provider = CustomReportProvider();

      expect(provider.startDate, isNull);
      expect(provider.endDate, isNull);
      expect(provider.selectedMetric, 'C.PROC');
      expect(provider.selectedMetricLabel, 'Volumen Procesado');
      expect(provider.selectedDimension, 'Zonas');
      expect(provider.isLoading, isFalse);
      expect(provider.isFilterExpanded, isTrue);
      expect(provider.reportData, isNull);
    });

    test('toggleFilters alterna correctamente el estado de visibilidad', () {
      final provider = CustomReportProvider();
      expect(provider.isFilterExpanded, isTrue);

      provider.toggleFilters();
      expect(provider.isFilterExpanded, isFalse);

      provider.toggleFilters();
      expect(provider.isFilterExpanded, isTrue);
    });

    test('setDates actualiza las fechas y notifica listeners', () {
      final provider = CustomReportProvider();
      bool notified = false;
      provider.addListener(() => notified = true);

      final start = DateTime(2026, 1, 1);
      final end = DateTime(2026, 1, 15);

      provider.setDates(start, end);

      expect(provider.startDate, start);
      expect(provider.endDate, end);
      expect(provider.formattedDateRange, '01/01/2026 - 15/01/2026');
      expect(notified, isTrue);
    });

    test('setMetric actualiza con código técnico o etiqueta de negocio', () {
      final provider = CustomReportProvider();

      // Con etiqueta de negocio
      provider.setMetric('Volumen Recepcionado');
      expect(provider.selectedMetric, 'C.RECEP');
      expect(provider.selectedMetricLabel, 'Volumen Recepcionado');

      // Con código técnico
      provider.setMetric('C.RECH');
      expect(provider.selectedMetric, 'C.RECH');
      expect(provider.selectedMetricLabel, 'Cantidad Rechazada');
    });

    test('setDimension actualiza la dimensión', () {
      final provider = CustomReportProvider();
      provider.setDimension('Programadores');
      expect(provider.selectedDimension, 'Programadores');

      provider.setDimension('Evolución Mensual');
      expect(provider.selectedDimension, 'Evolución Mensual');
    });

    test('generateReport valida fechas nulas sin llamar a Supabase', () async {
      final provider = CustomReportProvider();
      expect(provider.startDate, isNull);

      await provider.generateReport();
      expect(provider.errorMessage, isNotNull);
      expect(provider.isLoading, isFalse);
    });

    test('reportData helpers parsean listas y total global', () {
      final provider = CustomReportProvider();
      provider.reportData = {
        'global_total': 12500,
        'by_zone': [
          {'name': 'ZONA_ALFA', 'total': 7500},
          {'name': 'ZONA_BETA', 'total': 5000},
        ],
        'by_programmer': [
          {'name': 'EXT_01', 'total': 8000},
          {'name': 'EXT_02', 'total': 4500},
        ],
        'monthly_trend': [
          {'name': 'Enero', 'total': 12500},
        ],
      };

      expect(provider.globalTotal, 12500);

      provider.setDimension('Zonas');
      expect(provider.currentDimensionList.length, 2);
      expect(provider.currentDimensionList.first['name'], 'ZONA_ALFA');

      provider.setDimension('Programadores');
      expect(provider.currentDimensionList.length, 2);
      expect(provider.currentDimensionList.first['name'], 'EXT_01');

      provider.setDimension('Evolución Mensual');
      expect(provider.currentDimensionList.length, 1);
      expect(provider.currentDimensionList.first['name'], 'Enero');
    });
  });

  group('CustomReportScreen Widget Tests', () {
    testWidgets('Renderiza elementos principales del Scaffold y filtros', (WidgetTester tester) async {
      final provider = CustomReportProvider();

      await tester.pumpWidget(_createTestWidget(provider));

      // AppBar y título
      expect(find.text('Generador Personalizado'), findsOneWidget);

      // Selector de período de análisis (Fecha Desde y Fecha Hasta)
      expect(find.text('Período de Análisis'), findsOneWidget);
      expect(find.text('Fecha Desde'), findsOneWidget);
      expect(find.text('Fecha Hasta'), findsOneWidget);

      // Dropdowns
      expect(find.text('Métrica a Evaluar'), findsOneWidget);
      expect(find.text('Agrupar por'), findsOneWidget);
      expect(find.text('Volumen Procesado'), findsWidgets);
      expect(find.text('Zonas'), findsWidgets);

      // Botón Generar Reporte
      expect(find.text('Generar Reporte'), findsOneWidget);
    });

    testWidgets('Abre showDatePicker con localización en español y se puede cancelar', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final provider = CustomReportProvider();
      await tester.pumpWidget(_createTestWidget(provider));

      // Presionar el campo "Fecha Desde"
      await tester.tap(find.text('Fecha Desde'));
      await tester.pumpAndSettle();

      // Verificar que el diálogo de selección de fecha individual está abierto
      expect(find.byType(DatePickerDialog), findsOneWidget);

      // Cerrar mediante botón "Cancelar"
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      // El diálogo debe haberse cerrado
      expect(find.byType(DatePickerDialog), findsNothing);
    });

    testWidgets('Muestra barra colapsada cuando isFilterExpanded es false', (WidgetTester tester) async {
      final provider = CustomReportProvider();
      provider.setFilterExpanded(false);

      await tester.pumpWidget(_createTestWidget(provider));

      // Debe aparecer el texto minimalista colapsado
      expect(find.text('Filtros aplicados (Tocar para editar)'), findsOneWidget);
    });

    testWidgets('Muestra Resultados: Tarjeta Verde Oscuro, BarChart y DataTable con cogollos', (WidgetTester tester) async {
      final provider = CustomReportProvider();
      provider.setDates(DateTime(2026, 1, 1), DateTime(2026, 1, 31));
      provider.reportData = {
        'global_total': 15200,
        'by_zone': [
          {'name': 'ZONA_ALFA', 'total': 9200},
          {'name': 'ZONA_BETA', 'total': 6000},
        ],
      };
      provider.setFilterExpanded(false); // Colapsado automáticamente al generar

      await tester.pumpWidget(_createTestWidget(provider));
      await tester.pumpAndSettle();

      // 1. Tarjeta Oscura con total en cogollos
      expect(find.text('Total: 15,200 cogollos'), findsOneWidget);

      // 2. Gráfica BarChart de fl_chart
      expect(find.byType(BarChart), findsOneWidget);

      // 3. DataTable con los datos y encabezados (sin palabra Tabular, con fila TOTAL)
      expect(find.text('Detalles - Zonas'), findsOneWidget);
      expect(find.textContaining('Tabular'), findsNothing);
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.text('TOTAL'), findsOneWidget);
      expect(find.text('Cantidad de cogollos'), findsOneWidget);
      expect(find.text('ZONA_ALFA'), findsWidgets);
      expect(find.text('9,200'), findsOneWidget);
      expect(find.text('6,000'), findsOneWidget);
    });
  });
}

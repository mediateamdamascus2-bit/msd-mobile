import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Arabic Material strings and month names, with Latin digits (0-9).
///
/// `Locale('ar')` would otherwise format numbers with Eastern Arabic digits.
/// `ar_DZ` keeps Arabic date symbols and a Latin numbering system, matching the site.
class ArabicLatinMaterialLocalizationsDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const ArabicLatinMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ar';

  @override
  Future<MaterialLocalizations> load(Locale locale) async {
    const symbols = 'ar_DZ';
    await initializeDateFormatting(symbols);
    return MaterialLocalizationAr(
      localeName: 'ar',
      fullYearFormat: DateFormat.y(symbols),
      compactDateFormat: DateFormat.yMd(symbols),
      shortDateFormat: DateFormat.yMMMd(symbols),
      mediumDateFormat: DateFormat.MMMEd(symbols),
      longDateFormat: DateFormat.yMMMMEEEEd(symbols),
      yearMonthFormat: DateFormat.yMMMM(symbols),
      shortMonthDayFormat: DateFormat.MMMd(symbols),
      decimalFormat: NumberFormat.decimalPattern('en'),
      twoDigitZeroPaddedFormat: NumberFormat('00', 'en'),
    );
  }

  @override
  bool shouldReload(covariant ArabicLatinMaterialLocalizationsDelegate old) => false;
}

const msdLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  ArabicLatinMaterialLocalizationsDelegate(),
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

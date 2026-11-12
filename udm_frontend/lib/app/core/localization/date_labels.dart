// Dates and clocks the app prints itself. Server-authored copy arrives ready
// to read; these are the timestamps a recording row or page adds beside it,
// so they follow the language the student reads the interface in.

import 'package:get/get.dart';

const _monthsEn = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

const _monthsFr = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

/// "October 21, 2026", or "21 octobre 2026" — French puts the day first and
/// does not capitalize the month.
String publicationDate(DateTime moment) => _isFrench
    ? '${moment.day} ${_monthsFr[moment.month - 1]} ${moment.year}'
    : '${_monthsEn[moment.month - 1]} ${moment.day}, ${moment.year}';

/// Where a student has got to in a recording: `12:34`, or `1:04:30` once it
/// runs past the hour.
String elapsed(int seconds) {
  final minutes = seconds ~/ 60;
  final rest = (seconds % 60).toString().padLeft(2, '0');
  if (minutes < 60) return '$minutes:$rest';
  return '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}:$rest';
}

bool get _isFrench => (Get.locale?.languageCode ?? 'en') == 'fr';

// Dates and clocks the app prints itself. Server-authored copy arrives ready
// to read; these are the timestamps a recording row or page adds beside it.

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// "October 21, 2026".
String publicationDate(DateTime moment) => '${_months[moment.month - 1]} ${moment.day}, ${moment.year}';

/// Where a student has got to in a recording: `12:34`, or `1:04:30` once it
/// runs past the hour.
String elapsed(int seconds) {
  final minutes = seconds ~/ 60;
  final rest = (seconds % 60).toString().padLeft(2, '0');
  if (minutes < 60) return '$minutes:$rest';
  return '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}:$rest';
}

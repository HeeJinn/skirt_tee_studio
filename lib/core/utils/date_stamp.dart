/// `YYYYMMDD`, for filenames (exports, backups) that sort chronologically.
String dateStamp(DateTime date) =>
    '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';

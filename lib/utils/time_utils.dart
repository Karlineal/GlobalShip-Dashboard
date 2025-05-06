import 'package:intl/intl.dart';

/// 将 UTC 时间转换为指定时区并格式化为字符串。
///
/// [utcTime]：UTC 时间（必须）
/// [timezoneOffset]：目标时区偏移（单位：小时）
/// 返回格式为 "yyyy-MM-dd HH:mm:ss"
String formatLocalTime(DateTime utcTime, int timezoneOffset) {
  final localTime = utcTime.add(Duration(hours: timezoneOffset));
  return DateFormat('yyyy-MM-dd HH:mm:ss').format(localTime);
}

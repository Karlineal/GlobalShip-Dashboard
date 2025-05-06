import '../models/customer.dart';

Customer? getCustomer(
  String code,
  int defaultTz,
  String defaultLang,
  Map<String, Customer> customerDB,
) {
  final c = customerDB[code];
  if (c == null) return null;

  // 不重复构造对象，仅做字段回退
  final language = (c.language.isNotEmpty) ? c.language : defaultLang;
  final timezone = c.timezone;

  // 仅当需要变更才复制，否则返回原对象（性能优化）
  if (language == c.language && timezone == c.timezone) {
    return c;
  }

  return Customer(
    code: c.code,
    name: c.name,
    contact: c.contact,
    country: c.country,
    language: language,
    timezone: timezone,
  );
}

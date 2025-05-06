class Customer {
  String code; // 唯一客户代码
  String name;
  String contact;
  String country;
  String language; // 如 "en", "ar"
  int timezone; // 时区偏移（单位：小时），如 +3 表示 UTC+3

  Customer({
    required this.code,
    required this.name,
    required this.contact,
    required this.country,
    required this.language,
    required this.timezone,
  });

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'contact': contact,
    'country': country,
    'language': language,
    'timezone': timezone,
  };

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
    code: json['code'],
    name: json['name'],
    contact: json['contact'],
    country: json['country'],
    language: json['language'],
    timezone: json['timezone'],
  );
}

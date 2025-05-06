class Shipment {
  String trackingNumber;
  String customerCode;
  String cargoShortName;
  String cargoDetails;
  int packageCount;
  String transportType; // "Sea" 或 "Air"
  int estimatedDays;
  String status; // "未发货" / "已发货" / "已到达" / "已提货"
  DateTime createdTime; // UTC时间
  DateTime? shipDate; // UTC
  DateTime? arriveDate; // UTC
  DateTime? pickupDate; // UTC

  Shipment({
    required this.customerCode,
    required this.cargoShortName,
    required this.cargoDetails,
    required this.packageCount,
    required this.transportType,
    required this.estimatedDays,
  }) : createdTime = DateTime.now().toUtc(),
       status = "未发货",
       trackingNumber = _generateTrackingNumber(
         customerCode,
         cargoShortName,
         packageCount,
       );

  static String _generateTrackingNumber(
    String code,
    String shortName,
    int count,
  ) {
    String timestamp = DateTime.now().toUtc().toIso8601String().replaceAll(
      RegExp(r'[:-]|\.\d+'),
      '',
    );
    return '${code}_${shortName}_${count}_$timestamp';
  }

  Map<String, dynamic> toJson() => {
    'trackingNumber': trackingNumber,
    'customerCode': customerCode,
    'cargoShortName': cargoShortName,
    'cargoDetails': cargoDetails,
    'packageCount': packageCount,
    'transportType': transportType,
    'status': status,
    'estimatedDays': estimatedDays,
    'createdTime': createdTime.toIso8601String(),
    'shipDate': shipDate?.toIso8601String(),
    'arriveDate': arriveDate?.toIso8601String(),
    'pickupDate': pickupDate?.toIso8601String(),
  };

  factory Shipment.fromJson(Map<String, dynamic> json) =>
      Shipment(
          customerCode: json['customerCode'],
          cargoShortName: json['cargoShortName'],
          cargoDetails: json['cargoDetails'],
          packageCount: json['packageCount'],
          transportType: json['transportType'],
          estimatedDays: json['estimatedDays'],
        )
        ..trackingNumber = json['trackingNumber']
        ..status = json['status']
        ..createdTime = DateTime.parse(json['createdTime'])
        ..shipDate =
            json['shipDate'] != null ? DateTime.parse(json['shipDate']) : null
        ..arriveDate =
            json['arriveDate'] != null
                ? DateTime.parse(json['arriveDate'])
                : null
        ..pickupDate =
            json['pickupDate'] != null
                ? DateTime.parse(json['pickupDate'])
                : null;
}

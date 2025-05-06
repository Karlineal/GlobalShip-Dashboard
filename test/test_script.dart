// test/test_script.dart
import 'dart:io';
import 'dart:convert';
import 'package:globalship_dashboard/models/customer.dart';
import 'package:globalship_dashboard/models/shipment.dart';
import 'package:globalship_dashboard/shared/shared_data.dart';
import 'package:globalship_dashboard/utils/time_utils.dart';

Future<void> main() async {
  print('🔄 初始化客户数据...');
  _initializeMockCustomers();

  print('📦 创建运单...');
  final shipment1 = Shipment(
    customerCode: 'C001',
    cargoShortName: 'iPad',
    cargoDetails: 'Apple iPad 10th Gen',
    packageCount: 2,
    transportType: 'Air',
    estimatedDays: 7,
  );
  final shipment2 = Shipment(
    customerCode: 'C002',
    cargoShortName: 'Laptop',
    cargoDetails: 'Dell XPS 13',
    packageCount: 1,
    transportType: 'Sea',
    estimatedDays: 15,
  );
  shipmentList.addAll([shipment1, shipment2]);

  print('✅ 运单已创建:');
  print('   - ${shipment1.trackingNumber}');
  print('   - ${shipment2.trackingNumber}');

  print('💾 模拟保存到文件...');
  await _saveToFile();

  print('🧹 清空内存...');
  shipmentList.clear();
  customerDB.clear();

  print('📂 模拟重新加载...');
  await _loadFromFile();

  print('🔍 查询客户 C001 的运单（英文显示）...');
  await _queryCustomerShipments('C001');

  print('🔍 查询客户 C002 的运单（英文显示）...');
  await _queryCustomerShipments('C002');

  print('✏️ 模拟更新运单状态为 "已发货"...');
  shipmentList[0].status = '已发货';
  await _saveToFile();

  print('📂 重载并确认状态更新...');
  shipmentList.clear();
  customerDB.clear();
  await _loadFromFile();
  await _queryCustomerShipments('C001');
}

void _initializeMockCustomers() {
  customerDB['C001'] = Customer(
    code: 'C001',
    name: 'Ali',
    contact: 'ali@example.com',
    country: 'Egypt',
    language: 'ar',
    timezone: 2,
  );
  customerDB['C002'] = Customer(
    code: 'C002',
    name: 'Bob',
    contact: 'bob@example.com',
    country: 'USA',
    language: 'en',
    timezone: -5,
  );
}

Future<void> _queryCustomerShipments(String customerCode) async {
  final customer = customerDB[customerCode];
  if (customer == null) return;
  final tz = customer.timezone;
  final result =
      shipmentList.where((s) => s.customerCode == customerCode).toList();
  if (result.isEmpty) {
    print('❌ 查询失败：客户 $customerCode 无运单');
    return;
  }
  for (final s in result) {
    final localTime = formatLocalTime(
      s.createdTime.add(Duration(days: s.estimatedDays)),
      tz,
    );
    final line =
        'Tracking: ${s.trackingNumber}  Status: ${s.status}  ETA: $localTime';
    print('🌐 $line');
  }
}

Future<void> _saveToFile() async {
  final json = {
    'shipments': shipmentList.map((s) => s.toJson()).toList(),
    'customers': customerDB.map((k, v) => MapEntry(k, v.toJson())),
  };
  await File('../data.json').writeAsString(jsonEncode(json));
  print('💾 数据保存成功');
}

Future<void> _loadFromFile() async {
  final file = File('../data.json');
  if (!await file.exists()) {
    print('❌ data.json 文件不存在');
    return;
  }
  final json = jsonDecode(await file.readAsString());
  shipmentList =
      (json['shipments'] as List).map((s) => Shipment.fromJson(s)).toList();
  customerDB = (json['customers'] as Map<String, dynamic>).map(
    (k, v) => MapEntry(k, Customer.fromJson(v)),
  );
  print('📂 数据加载成功，共 ${shipmentList.length} 条运单');
}

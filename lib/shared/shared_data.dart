// lib/shared/shared_data.dart

import '../models/shipment.dart';
import '../models/customer.dart';

/// 全局共享运单列表
List<Shipment> shipmentList = [];

/// 全局共享客户数据库
Map<String, Customer> customerDB = {};

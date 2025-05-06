// lib/handlers/shipment_handler.dart
import 'dart:io';
import 'dart:convert';
import '../models/shipment.dart';
import '../utils/time_utils.dart';
import '../utils/translate.dart';
import '../utils/customer_utils.dart';
import '../shared/shared_data.dart' as shared_data; // 用于 _queryShipment

// 获取数据文件路径
String get _dataFilePathFromHandler {
  final currentPath = Directory.current.path;
  // 如果使用 package:path (推荐)
  // import 'package:path/path.dart' as p;
  // return p.join(currentPath, 'data.json');
  return '$currentPath/data.json'; // 假设 data.json 在项目根目录
}

// 内部数据加载函数 (主要供 create 和 update 使用)
Future<Map<String, dynamic>> _loadDataInternal() async {
  final file = File(_dataFilePathFromHandler);
  if (!await file.exists()) {
    print('（处理程序内部加载）文件 $_dataFilePathFromHandler 不存在，将使用空数据结构。');
    return {'shipments': [], 'customers': {}};
  }
  try {
    final content = await file.readAsString();
    if (content.trim().isEmpty) {
      print('（处理程序内部加载）文件 $_dataFilePathFromHandler 为空，将使用空数据结构。');
      return {'shipments': [], 'customers': {}};
    }
    final decoded = jsonDecode(content);
    if (decoded is Map<String, dynamic>) {
      // 确保 shipments 和 customers 总是存在且类型正确
      // 将 List<dynamic> 安全地转换为 List<Map<String, dynamic>>
      var shipmentsList = (decoded['shipments'] as List<dynamic>?) ?? [];
      List<Map<String, dynamic>> correctlyTypedShipments = [];
      for (var item in shipmentsList) {
        if (item is Map<String, dynamic>) {
          correctlyTypedShipments.add(item);
        } else {
          // 可以选择记录错误或忽略格式不正确的条目
          print('（处理程序内部加载）shipments 列表中发现非Map条目，已忽略: $item');
        }
      }
      decoded['shipments'] = correctlyTypedShipments;
      decoded['customers'] = (decoded['customers'] as Map<String, dynamic>?) ?? {};
      return decoded;
    }
    print('（处理程序内部加载）文件 $_dataFilePathFromHandler 解析结果非Map，将使用空数据结构。');
    return {'shipments': [], 'customers': {}};
  } catch (e) {
    print('（处理程序内部加载）加载或解析文件 $_dataFilePathFromHandler 时发生错误: $e. 将使用空数据结构。');
    return {'shipments': [], 'customers': {}};
  }
}

// 内部数据保存函数 (主要供 create 和 update 使用)
Future<void> _saveDataInternal(Map<String, dynamic> dataToSave) async {
  try {
    await File(_dataFilePathFromHandler).writeAsString(jsonEncode(dataToSave));
    // 成功消息由调用函数打印
  } catch (e) {
    print('（处理程序内部保存）保存数据到文件 $_dataFilePathFromHandler 时发生错误: $e');
    // 考虑是否需要重新抛出异常，让调用者知道保存失败
    // throw;
  }
}

Future<void> _createShipment() async {
  Map<String, dynamic> currentData = await _loadDataInternal();
  // _loadDataInternal 已经确保了 shipments 是 List<Map<String, dynamic>>
  List<Map<String, dynamic>> shipmentsJsonList = currentData['shipments'] as List<Map<String, dynamic>>;
  Map<String, dynamic> customersJsonMap = currentData['customers'] as Map<String, dynamic>;

  stdout.write('客户代码: ');
  final customerCode = stdin.readLineSync()?.trim();
  if (customerCode == null || customerCode.isEmpty) {
    print('错误：客户代码不能为空。');
    return;
  }

  // 检查客户是否存在于加载的 customersJsonMap 中
  if (!customersJsonMap.containsKey(customerCode)) {
      print('错误：客户代码 "$customerCode" 不存在于客户数据库中。请先确保客户已添加。');
      // 你可能需要一个添加客户的功能，或者在创建运单时允许同时创建客户
      // 目前，我们假设客户必须已存在。
      return;
  }

  stdout.write('货物简称: ');
  final shortName = stdin.readLineSync()?.trim();
  if (shortName == null || shortName.isEmpty) {
    print('错误：货物简称不能为空。');
    return;
  }

  stdout.write('包裹数量: ');
  final countString = stdin.readLineSync()?.trim();
  final count = int.tryParse(countString ?? '');
  if (count == null || count <= 0) {
    print('错误：包裹数量必须是一个大于0的整数。');
    return;
  }

  stdout.write('运输方式 (Sea/Air): ');
  final transport = stdin.readLineSync()?.trim().toUpperCase();
  if (transport == null || !['SEA', 'AIR'].contains(transport)) {
    print('错误：运输方式必须是 "Sea" 或 "Air"。');
    return;
  }

  stdout.write('预计运输天数: ');
  final daysString = stdin.readLineSync()?.trim();
  final days = int.tryParse(daysString ?? '');
  if (days == null || days <= 0) {
    print('错误：预计运输天数必须是一个大于0的整数。');
    return;
  }

  stdout.write('货物明细: ');
  final details = stdin.readLineSync()?.trim() ?? ''; // 允许明细为空

  final newShipment = Shipment(
    customerCode: customerCode,
    cargoShortName: shortName,
    cargoDetails: details,
    packageCount: count,
    transportType: transport, // Shipment 模型应该接受大写或进行转换
    estimatedDays: days,
  );

  shipmentsJsonList.add(newShipment.toJson());

  final dataToSave = {
    'shipments': shipmentsJsonList,
    'customers': customersJsonMap // customers 部分通常在创建运单时不修改
  };

  await _saveDataInternal(dataToSave);
  print('运单创建并已自动保存，单号：${newShipment.trackingNumber}');
}

Future<void> _updateShipment() async {
  Map<String, dynamic> currentData = await _loadDataInternal();
  List<Map<String, dynamic>> shipmentsJsonList = currentData['shipments'] as List<Map<String, dynamic>>;
  Map<String, dynamic> customersJsonMap = currentData['customers'] as Map<String, dynamic>;

  stdout.write('请输入运单编号: ');
  final trackingToUpdate = stdin.readLineSync()?.trim();
  if (trackingToUpdate == null || trackingToUpdate.isEmpty) {
    print('错误：运单编号不能为空。');
    return;
  }

  int foundIndex = -1;
  for (int i = 0; i < shipmentsJsonList.length; i++) {
    if (shipmentsJsonList[i]['trackingNumber'] == trackingToUpdate) {
      foundIndex = i;
      break;
    }
  }

  if (foundIndex == -1) {
    print('找不到该运单。');
    return;
  }

  stdout.write('请输入新的运单状态（未发货/已发货/已到达/已提货）：');
  final status = stdin.readLineSync()?.trim();
  // 你可能需要一个 ShipmentStatus 枚举并在模型中使用，这里用字符串列表简单验证
  final validStatuses = ['未发货', '已发货', '已到达', '已提货'];
  if (status == null || !validStatuses.contains(status)) {
    print('错误：无效的运单状态。请输入 (${validStatuses.join('/')}) 中的一个。');
    return;
  }
  
  shipmentsJsonList[foundIndex]['status'] = status;

  final dataToSave = {
    'shipments': shipmentsJsonList,
    'customers': customersJsonMap
  };
  
  await _saveDataInternal(dataToSave);
  print('运单状态更新并已自动保存！');
}

// _queryShipment 使用 main 函数加载到全局 shared_data 中的数据
Future<void> _queryShipment(String defaultLang, int defaultTz) async {
    stdout.write('请输入客户代码: ');
    final code = stdin.readLineSync()?.trim();
    if (code == null || code.isEmpty) {
      print('错误：客户代码不能为空。');
      return;
    }

    // 使用全局加载的 customerDB
    final customer = getCustomer(code, defaultTz, defaultLang, shared_data.customerDB); 
    if (customer == null) {
        print('找不到该客户。');
        return;
    }

    final timezone = customer.timezone;
    final lang = customer.language;

    // 使用全局加载的 shipmentList
    final shipments = shared_data.shipmentList.where((s) => s.customerCode == code).toList();
    if (shipments.isEmpty) {
        print(
          lang == 'en'
              ? 'No shipments found.'
              : await translateText('No shipments found.', lang),
        );
        return;
    }

    print('\n--- 客户 $code (${customer.name}) 的运单列表 ---');
    for (final s in shipments) {
        final localArrival = s.createdTime.add(Duration(days: s.estimatedDays));
        final formattedTime = formatLocalTime(localArrival, timezone); 
        final line = '  编号: ${s.trackingNumber}\n    状态: ${s.status}\n    预计到达: $formattedTime\n    货物: ${s.cargoShortName} (数量: ${s.packageCount})\n    明细: ${s.cargoDetails}\n';
        // 为了简化，这里移除了翻译，你可以根据需要加回来
        // final translated = lang == 'en' ? line : await translateText(line, lang);
        // print(translated);
        stdout.write(line); // 使用 stdout.write 避免自动换行，因为 line 内部已有换行
    }
    print('--- 列表结束 ---\n');
}

// 主命令处理函数
Future<void> handleShipmentCommand(
  String command,
  Map<String, dynamic> args,
) async {
  final lang = args['lang'] ?? 'en';
  final tz = args['tz'] ?? 0; // 时区偏移量

  try {
    switch (command) {
      case 'create':
        await _createShipment();
        break;
      case 'update':
        await _updateShipment();
        break;
      case 'query':
        await _queryShipment(lang, tz);
        break;
      default:
        print('shipment 命令下未知的动作："$command". 可用动作: create, update, query.');
    }
  } catch (e, stackTrace) {
    print('处理 shipment 命令时发生错误: $e');
    print('堆栈跟踪: $stackTrace');
  }
}
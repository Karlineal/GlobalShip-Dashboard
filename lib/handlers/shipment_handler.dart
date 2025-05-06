// File: lib/handlers/shipment_handler.dart

import 'dart:io';
import 'dart:convert';
import '../models/shipment.dart';
import '../models/customer.dart';
import '../utils/time_utils.dart';
import '../utils/translate.dart';
import '../shared/shared_data.dart' as shared_data;

// _dataFilePathFromHandler, _loadDataInternal, _saveDataInternal, _createShipment, _updateShipment 保持不变...
// (确保这些辅助函数与您当前版本一致)
String get _dataFilePathFromHandler {
  final currentPath = Directory.current.path;
  return '$currentPath/data.json'; 
}

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
      var shipmentsList = (decoded['shipments'] as List<dynamic>?) ?? [];
      List<Map<String, dynamic>> correctlyTypedShipments = [];
      for (var item in shipmentsList) {
        if (item is Map<String, dynamic>) {
          correctlyTypedShipments.add(item);
        } else {
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

Future<void> _saveDataInternal(Map<String, dynamic> dataToSave) async {
  try {
    await File(_dataFilePathFromHandler).writeAsString(jsonEncode(dataToSave));
  } catch (e) {
    print('（处理程序内部保存）保存数据到文件 $_dataFilePathFromHandler 时发生错误: $e');
  }
}

Future<void> _createShipment() async {
  Map<String, dynamic> currentData = await _loadDataInternal();
  List<Map<String, dynamic>> shipmentsJsonList = currentData['shipments'] as List<Map<String, dynamic>>;
  Map<String, dynamic> customersJsonMap = currentData['customers'] as Map<String, dynamic>;

  stdout.write('客户代码: '); // Prompt in Chinese, as per original
  final customerCode = stdin.readLineSync(encoding: utf8)?.trim();
  if (customerCode == null || customerCode.isEmpty) {
    print('错误：客户代码不能为空。');
    return;
  }

  if (!customersJsonMap.containsKey(customerCode)) {
      print('错误：客户代码 "$customerCode" 不存在于客户数据库中。请先确保客户已添加。');
      return;
  }

  stdout.write('货物简称: '); // Prompt in Chinese
  final shortName = stdin.readLineSync(encoding: utf8)?.trim();
  if (shortName == null || shortName.isEmpty) {
    print('错误：货物简称不能为空。');
    return;
  }

  stdout.write('包裹数量: '); // Prompt in Chinese
  final countString = stdin.readLineSync(encoding: utf8)?.trim();
  final count = int.tryParse(countString ?? '');
  if (count == null || count <= 0) {
    print('错误：包裹数量必须是一个大于0的整数。');
    return;
  }

  stdout.write('运输方式 (Sea/Air): '); // Prompt in Chinese
  final transport = stdin.readLineSync(encoding: utf8)?.trim().toUpperCase();
  if (transport == null || !['SEA', 'AIR'].contains(transport)) {
    print('错误：运输方式必须是 "Sea" 或 "Air"。');
    return;
  }

  stdout.write('预计运输天数: '); // Prompt in Chinese
  final daysString = stdin.readLineSync(encoding: utf8)?.trim();
  final days = int.tryParse(daysString ?? '');
  if (days == null || days <= 0) {
    print('错误：预计运输天数必须是一个大于0的整数。');
    return;
  }

  stdout.write('货物明细: '); // Prompt in Chinese
  final details = stdin.readLineSync(encoding: utf8)?.trim() ?? '';

  final newShipment = Shipment(
    customerCode: customerCode,
    cargoShortName: shortName,
    cargoDetails: details,
    packageCount: count,
    transportType: transport,
    estimatedDays: days,
  );

  shipmentsJsonList.add(newShipment.toJson());
  shared_data.shipmentList.add(newShipment);


  final dataToSave = {
    'shipments': shipmentsJsonList,
    'customers': customersJsonMap
  };

  await _saveDataInternal(dataToSave);
  print('运单创建并已自动保存，单号：${newShipment.trackingNumber}');
}

Future<void> _updateShipment() async {
  Map<String, dynamic> currentData = await _loadDataInternal();
  List<Map<String, dynamic>> shipmentsJsonList = currentData['shipments'] as List<Map<String, dynamic>>;
  Map<String, dynamic> customersJsonMap = currentData['customers'] as Map<String, dynamic>;
  stdout.write('请输入运单编号: ');
  final trackingToUpdate = stdin.readLineSync(encoding: utf8)?.trim();
  if (trackingToUpdate == null || trackingToUpdate.isEmpty) {
    print('错误：运单编号不能为空。');
    return;
  }

  int foundIndexJson = -1;
  for (int i = 0; i < shipmentsJsonList.length; i++) {
    if (shipmentsJsonList[i]['trackingNumber'] == trackingToUpdate) {
      foundIndexJson = i;
      break;
    }
  }

  int foundIndexGlobal = -1;
   for (int i = 0; i < shared_data.shipmentList.length; i++) {
    if (shared_data.shipmentList[i].trackingNumber == trackingToUpdate) {
      foundIndexGlobal = i;
      break;
    }
  }

  if (foundIndexJson == -1) { 
    print('找不到该运单。');
    return;
  }

  stdout.write('请输入新的运单状态（未发货/已发货/已到达/已提货）：');
  final status = stdin.readLineSync(encoding: utf8)?.trim();
  
  final validStatuses = ['未发货', '已发货', '已到达', '已提货']; 
  if (status == null || !validStatuses.contains(status)) {
    print('错误：无效的运单状态。请输入 (${validStatuses.join('/')}) 中的一个。');
    return;
  }
  
  shipmentsJsonList[foundIndexJson]['status'] = status;
  if (foundIndexGlobal != -1) { 
      shared_data.shipmentList[foundIndexGlobal].status = status;
  }

  final dataToSave = {
    'shipments': shipmentsJsonList,
    'customers': customersJsonMap
  };
  
  await _saveDataInternal(dataToSave); 
  print('运单状态更新并已自动保存！');
}


Future<void> _queryShipment(String defaultLang, int tzValueFromArg, bool tzWasSpecified) async {
    stdout.write('请输入客户代码: '); // Prompt in Chinese as per original
    final code = stdin.readLineSync(encoding: utf8)?.trim();
    if (code == null || code.isEmpty) {
      print('错误：客户代码不能为空。');
      return;
    }

    final customerFromFile = shared_data.customerDB[code];
    if (customerFromFile == null) {
        print('找不到该客户。'); // Error message in Chinese
        return;
    }

    final int finalTimezone = tzWasSpecified ? tzValueFromArg : customerFromFile.timezone;
    final String finalLang = (customerFromFile.language.isNotEmpty) ? customerFromFile.language : defaultLang;

    final displayCustomer = Customer(
      code: customerFromFile.code,
      name: customerFromFile.name,
      contact: customerFromFile.contact,
      country: customerFromFile.country,
      language: finalLang,
      timezone: finalTimezone,
    );

    final shipments = shared_data.shipmentList.where((s) => s.customerCode == code).toList();

    // --- Define BASE LABELS IN ENGLISH ---
    String labelTrackingNumber = "Tracking Number";
    String labelStatus = "Status";
    String labelEstimatedArrival = "Estimated Arrival";
    String labelCargo = "Cargo";
    String labelCount = "Count";
    String labelDetails = "Details";
    String labelNoShipments = "No shipments found.";
    String headerPart1 = "--- Customer";
    String headerPart2 = "Shipment List ---";
    String footer = "--- List End ---";

    // Translate labels ONLY if the final language is NOT English
    if (displayCustomer.language.toLowerCase() != 'en') {
        try {
            // Parallel translation for efficiency
            final translations = await Future.wait([
                translateText(labelTrackingNumber, displayCustomer.language), // "Tracking Number"
                translateText(labelStatus, displayCustomer.language),         // "Status"
                translateText(labelEstimatedArrival, displayCustomer.language),// "Estimated Arrival"
                translateText(labelCargo, displayCustomer.language),          // "Cargo"
                translateText(labelCount, displayCustomer.language),          // "Count"
                translateText(labelDetails, displayCustomer.language),        // "Details"
                translateText(labelNoShipments, displayCustomer.language),    // "No shipments found."
                translateText(headerPart1, displayCustomer.language),         // "--- Customer"
                translateText(headerPart2, displayCustomer.language),         // "Shipment List ---"
                translateText(footer, displayCustomer.language),              // "--- List End ---"
            ]);
            labelTrackingNumber = translations[0];
            labelStatus = translations[1];
            labelEstimatedArrival = translations[2];
            labelCargo = translations[3];
            labelCount = translations[4];
            labelDetails = translations[5];
            labelNoShipments = translations[6];
            headerPart1 = translations[7];
            headerPart2 = translations[8];
            footer = translations[9];
        } catch (e) {
            print("Warning: One or more label translations failed. Falling back to English for some labels. Error: $e");
            // Fallback to English is implicitly handled by translateText returning original on error/timeout
        }
    }
    // --- Labels are now either English (if lang is 'en') or translated (with English fallback on error) ---

    if (shipments.isEmpty) {
        print(labelNoShipments); // Uses English or translated "No shipments found."
        return;
    }
    
    // Construct header using (potentially) translated parts or base English parts
    print('\n$headerPart1 ${displayCustomer.code} (${displayCustomer.name}) $headerPart2');

    for (final s in shipments) {
        final utcArrivalTime = s.createdTime.add(Duration(days: s.estimatedDays));
        final formattedArrivalTime = formatLocalTime(utcArrivalTime, displayCustomer.timezone);
        
        String statusValueToDisplay = s.status; 
        String cargoShortNameToDisplay = s.cargoShortName;
        String cargoDetailsToDisplay = s.cargoDetails;

        if (displayCustomer.language.toLowerCase() == 'en') {
            // If display language is English, map known Chinese statuses to English.
            // Otherwise, use the stored status as is (assuming it might already be English or a base form).
            const Map<String, String> statusToEnglish = {
                "未发货": "Unshipped",
                "已发货": "Shipped",
                "已到达": "Arrived",
                "已提货": "Picked Up",
            };
            statusValueToDisplay = statusToEnglish[s.status] ?? s.status;
            // For cargo name and details, if they are stored in Chinese and need to be English for 'en' customer,
            // a similar mapping or translation to English would be needed here.
            // For simplicity, we assume cargoShortName and cargoDetails are displayed as stored if lang is 'en'.
            // If they were meant to be translated *from* Chinese *to* English for an English customer,
            // then translateText(s.cargoShortName, 'en') would be needed, but translateText currently
            // returns original if targetLang is 'en'. So, this assumes they are stored in a way that's acceptable for English display.

        } else { // For non-English display languages
            if (s.status.isNotEmpty) {
                 statusValueToDisplay = await translateText(s.status, displayCustomer.language);
            }
            if (s.cargoShortName.isNotEmpty) {
                cargoShortNameToDisplay = await translateText(s.cargoShortName, displayCustomer.language);
            }
            if (s.cargoDetails.isNotEmpty) {
                cargoDetailsToDisplay = await translateText(s.cargoDetails, displayCustomer.language);
            }
        }

        // Output using the determined labels and (potentially) translated dynamic content
        final shipmentInfo = '  $labelTrackingNumber: ${s.trackingNumber}\n'
                           '    $labelStatus: $statusValueToDisplay\n'
                           '    $labelEstimatedArrival: $formattedArrivalTime\n'
                           '    $labelCargo: $cargoShortNameToDisplay ($labelCount: ${s.packageCount})\n'
                           '    $labelDetails: $cargoDetailsToDisplay\n';
        
        stdout.write(shipmentInfo);
    }
    
    print('$footer\n'); // Uses English or translated footer
}

Future<void> handleShipmentCommand(
  String command,
  Map<String, dynamic> args,
) async {
  final lang = args['lang'] ?? 'en'; 
  final tzValue = args['tz'] ?? 0; 
  final tzWasSpecified = args['tz_specified'] ?? false; 

  try {
    switch (command) {
      case 'create':
        await _createShipment();
        break;
      case 'update':
        await _updateShipment();
        break;
      case 'query':
        await _queryShipment(lang, tzValue, tzWasSpecified);
        break;
      default:
        print('shipment 命令下未知的动作："$command". 可用动作: create, update, query.');
    }
  } catch (e, stackTrace) {
    print('处理 shipment 命令时发生错误: $e');
    print('堆栈跟踪: $stackTrace');
  }
}

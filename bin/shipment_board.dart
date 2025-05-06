// bin/shipment_board.dart
import 'dart:io';
import 'dart:convert'; // 需要导入 dart:convert 以使用 utf8
import 'package:args/args.dart';
import 'package:globalship_dashboard/models/customer.dart';
import 'package:globalship_dashboard/models/shipment.dart';
import 'package:globalship_dashboard/handlers/shipment_handler.dart';
import 'package:globalship_dashboard/shared/shared_data.dart'; // 用于全局 shipmentList 和 customerDB

// 获取数据文件路径
String get dataFilePath {
  final currentPath = Directory.current.path;
  return '$currentPath/data.json';
}

// 将 data.json 的内容加载到全局的 shipmentList 和 customerDB
Future<void> _loadFromFile() async {
  final file = File(dataFilePath);

  if (!await file.exists()) {
    print('（全局加载）文件 $dataFilePath 不存在。全局数据将为空。');
    shipmentList.clear();
    customerDB.clear();
    print('已加载数据到全局状态，共 ${shipmentList.length} 条运单');
    return;
  }

  try {
    final fileContent = await file.readAsString();
    if (fileContent.trim().isEmpty) {
      print('（全局加载）文件 $dataFilePath 为空。全局数据将为空。');
      shipmentList.clear();
      customerDB.clear();
    } else {
      final json = jsonDecode(fileContent);
      if (json is Map<String, dynamic>) {
        final loadedShipmentsData = json['shipments'] as List?;
        shipmentList = loadedShipmentsData
                ?.map((s) => Shipment.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [];

        final loadedCustomersData = json['customers'] as Map<String, dynamic>?;
        customerDB = loadedCustomersData
                ?.map((k, v) =>
                    MapEntry(k, Customer.fromJson(v as Map<String, dynamic>))) ??
            {};
      } else {
        print('（全局加载）文件 $dataFilePath 内容格式不正确（非Map）。全局数据将为空。');
        shipmentList.clear();
        customerDB.clear();
      }
    }
  } catch (e) {
    print('（全局加载）加载或解析文件 $dataFilePath 时发生错误: $e. 全局数据将为空。');
    shipmentList.clear();
    customerDB.clear();
  }
  print('已加载数据到全局状态，共 ${shipmentList.length} 条运单');
}

// 将全局的 shipmentList 和 customerDB 保存到 data.json
Future<void> _saveToFile() async {
  print('（Save 命令）准备保存内存中的全局数据...');
  final jsonToSave = {
    'shipments': shipmentList.map((s) => s.toJson()).toList(),
    'customers': customerDB.map((k, v) => MapEntry(k, v.toJson())),
  };
  try {
    await File(dataFilePath).writeAsString(jsonEncode(jsonToSave));
    print('（Save 命令）内存中的全局数据已成功保存到 $dataFilePath');
  } catch (e) {
    print('（Save 命令）保存数据到文件 $dataFilePath 时发生错误: $e');
  }
}

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('lang', abbr: 'l', help: '设置默认语言，如 en、ar')
    ..addOption('tz', abbr: 'z', help: '设置时区偏移（小时），如 +3')
    ..addOption(
      'action',
      abbr: 'a',
      help: 'shipment 动作: create/update/query',
      defaultsTo: 'query',
    )
    ..addCommand('login')
    ..addCommand('shipment')
    ..addCommand('save')
    ..addCommand('load');

  final argResults = parser.parse(arguments);

  print('程序启动：初始化全局数据...');
  await _loadFromFile();

  final globalLang = argResults['lang'] ?? 'en';
  final globalTz = int.tryParse(argResults['tz'] ?? '0') ?? 0;

  try {
    String? commandName = argResults.command?.name;
    if (commandName == null && argResults.wasParsed('action')) {
        commandName = 'shipment';
    }

    switch (commandName) {
      case 'login':
        _handleLogin();
        break;
      case 'shipment':
        final shipmentAction = argResults['action'] as String;
        await handleShipmentCommand(shipmentAction, {
          'lang': globalLang,
          'tz': globalTz,
        });
        break;
      case 'save':
        await _saveToFile();
        break;
      case 'load':
        await _loadFromFile();
        print("（Load 命令）数据已重新加载到内存全局状态。");
        break;
      default:
        if (arguments.isEmpty) {
            print('请输入一个命令。可用命令: login, shipment, save, load.');
        } else {
            print('未知的主命令: ${arguments.firstOrNull ?? ''}');
        }
        print(parser.usage);
    }
  } catch (e, stackTrace) {
    print('运行时发生未捕获错误: $e');
    print('堆栈跟踪: $stackTrace');
  }
}

void _handleLogin() {
  stdout.write('请输入身份（trader/customer）：');
  final role = stdin.readLineSync(encoding: utf8)?.trim();
  if (role == null || role.isEmpty) {
      print("登录角色不能为空。");
      return;
  }
  stdout.write('请输入用户代码：');
  final user = stdin.readLineSync(encoding: utf8)?.trim();
    if (user == null || user.isEmpty) {
      print("用户代码不能为空。");
      return;
  }
  print('已登录为 $role（代码：$user）');
}

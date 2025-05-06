import 'dart:io';
import 'dart:convert';
import 'package:test/test.dart';
import 'package:intl/intl.dart'; // 用于日期格式化断言
import 'package:path/path.dart' as p; // 导入 path 包

// 帮助函数：运行命令行程序
Future<ProcessResult> runShipmentBoard(List<String> arguments, {String? stdinString}) async {
  final executable = Platform.isWindows ? 'dart.exe' : 'dart';
  // 使用 p.join 来构建更可靠的路径
  final scriptPath = p.join(Directory.current.path, 'bin', 'shipment_board.dart');

  final process = await Process.start(
    executable,
    [scriptPath, ...arguments],
  );

  // 为 stdin 设置 UTF-8 编码
  process.stdin.encoding = utf8;

  if (stdinString != null && stdinString.isNotEmpty) {
    // 按行分割输入，并逐行发送
    final lines = stdinString.split('\n');
    for (final line in lines) {
      process.stdin.writeln(line);
    }
  }
  await process.stdin.flush();
  await process.stdin.close(); // 关闭 stdin 非常重要

  final stdoutResult = await process.stdout.transform(utf8.decoder).join();
  final stderrResult = await process.stderr.transform(utf8.decoder).join();
  final exitCode = await process.exitCode;

  // 用于调试测试脚本:
  // print('--- CMD: $executable $scriptPath ${arguments.join(' ')} ---');
  // if (stdinString != null) print('--- STDIN: $stdinString ---');
  // print('--- STDOUT ---:\n$stdoutResult');
  // print('--- STDERR ---:\n$stderrResult');
  // print('--- EXITCODE: $exitCode ---');

  return ProcessResult(process.pid, exitCode, stdoutResult, stderrResult);
}

// 帮助函数：管理 data.json 文件
// 使用 p.join 来确保路径分隔符的正确性
final testDataFilePath = p.join(Directory.current.path, 'data.json');
File testDataFile = File(testDataFilePath);
String? originalDataContent;

Map<String, dynamic> getDefaultCustomers() => {
  "CUST001": {"code": "CUST001", "name": "Alice Wonderland", "contact": "alice@example.com", "country": "UK", "language": "en", "timezone": 0},
  "CUST002": {"code": "CUST002", "name": "Omar Sharif", "contact": "omar@example.com", "country": "Egypt", "language": "ar", "timezone": 2},
  "CUST003": {"code": "CUST003", "name": "Test User NoShip", "contact": "test@example.com", "country": "US", "language": "en", "timezone": -5}
};

Future<void> resetTestDataFile({Map<String, dynamic>? initialData}) async {
  if (initialData != null) {
    await testDataFile.writeAsString(jsonEncode(initialData));
  } else {
    await testDataFile.writeAsString(jsonEncode({
      "shipments": [],
      "customers": getDefaultCustomers(),
    }));
  }
}

void main() {
  setUpAll(() async {
    if (await testDataFile.exists()) {
      originalDataContent = await testDataFile.readAsString();
    }
  });

  tearDownAll(() async {
    if (originalDataContent != null) {
      await testDataFile.writeAsString(originalDataContent!);
    } else {
      if (await testDataFile.exists()) {
        await testDataFile.delete();
      }
    }
  });

  setUp(() async {
    await resetTestDataFile();
  });

  // 动态获取应用在日志中打印的 data.json 路径
  // bin/shipment_board.dart 使用 `'$currentPath/data.json'`
  // 在 Windows 上，Directory.current.path 会用 '\'，但 File 构造函数通常能处理混合路径
  // 为了精确匹配输出，我们模拟应用内的路径构建方式
  final appPrintedDataPath = '${Directory.current.path}/data.json'.replaceAll('\\', '/');


  group('CLI Application Tests', () {
    group('Data Management (Load/Save Commands)', () {
      test('Initial load (implicit) from non-existent file should create empty state in memory', () async {
        if (await testDataFile.exists()) await testDataFile.delete();
        var result = await runShipmentBoard(['shipment', '-a', 'query'], stdinString: 'ANYCUST');
        // 匹配应用实际打印的包含完整路径的消息
        expect(result.stdout, contains('（全局加载）文件 $appPrintedDataPath 不存在。全局数据将为空。'));
        expect(result.stdout, contains('找不到该客户。'));
      });

      test('`load` command re-loads data from file', () async {
        final specificData = {
          "shipments": [{"trackingNumber":"LOAD_CMD_001","customerCode":"CUST001","cargoShortName":"LoadCmdTest","cargoDetails":"Details","packageCount":1,"transportType":"AIR","status":"未发货","estimatedDays":1,"createdTime":"2025-01-01T00:00:00.000Z"}],
          "customers": getDefaultCustomers()
        };
        await testDataFile.writeAsString(jsonEncode(specificData));

        var result = await runShipmentBoard(['load']);
        expect(result.exitCode, 0);
        expect(result.stdout, contains('已加载数据到全局状态，共 1 条运单'));

        result = await runShipmentBoard(['shipment', '-a', 'query'], stdinString: 'CUST001');
        expect(result.stdout, contains('LOAD_CMD_001'));
      });

      test('`save` command writes current in-memory data to data.json', () async {
        await resetTestDataFile();
        await runShipmentBoard(['load']); // 确保内存中有 getDefaultCustomers()

        final createInputs = 'CUST001\nSaveTestCargo\n1\nAir\n1\nSave Details';
        await runShipmentBoard(['shipment', '-a', 'create'], stdinString: createInputs);

        var result = await runShipmentBoard(['save']);
        expect(result.exitCode, 0);
        // 匹配应用实际打印的包含完整路径的消息
        expect(result.stdout, contains('（Save 命令）内存中的全局数据已成功保存到 $appPrintedDataPath'));

        final fileContent = jsonDecode(await testDataFile.readAsString());
        expect(fileContent['shipments'], anyElement(predicate<dynamic>((s) => s['cargoShortName'] == 'SaveTestCargo')));
        expect(fileContent['customers'], getDefaultCustomers());
      });
    });

    group('Login Command', () {
      test('Login as trader', () async {
        final result = await runShipmentBoard(['login'], stdinString: 'trader\ntrader007');
        expect(result.exitCode, 0);
        expect(result.stdout, contains('已登录为 trader（代码：trader007）'));
      });
      test('Login as customer', () async {
        final result = await runShipmentBoard(['login'], stdinString: 'customer\nCUST001');
        expect(result.exitCode, 0);
        expect(result.stdout, contains('已登录为 customer（代码：CUST001）'));
      });
      test('Login with empty role fails', () async {
        final result = await runShipmentBoard(['login'], stdinString: '\nNoUser');
        expect(result.stdout, contains('登录角色不能为空。'));
      });
       test('Login with empty user code fails', () async {
        final result = await runShipmentBoard(['login'], stdinString: 'trader\n');
        expect(result.stdout, contains('用户代码不能为空。'));
      });
    });

    group('Shipment Create Command', () {
      test('Create shipment successfully', () async {
        final inputs = 'CUST001\nElectronics\n10\nAir\n3\nHigh-value electronics';
        var result = await runShipmentBoard(['shipment', '-a', 'create'], stdinString: inputs);
        expect(result.exitCode, 0);
        expect(result.stdout, contains('运单创建并已自动保存，单号：'));
        final trackingNumberMatch = RegExp(r'单号：(CUST001_Electronics_10_[\wT.-]+Z)').firstMatch(result.stdout);
        expect(trackingNumberMatch, isNotNull);
        final trackingNumber = trackingNumberMatch!.group(1);

        final fileContent = jsonDecode(await testDataFile.readAsString());
        final createdShipment = (fileContent['shipments'] as List).firstWhere((s) => s['trackingNumber'] == trackingNumber, orElse: () => null);
        expect(createdShipment, isNotNull);
        expect(createdShipment['customerCode'], 'CUST001');
      });

      test('Create shipment for non-existent customer fails', () async {
        final inputs = 'NONEXISTENT_CUST\nBooks\n5\nSea\n20\nOld books';
        var result = await runShipmentBoard(['shipment', '-a', 'create'], stdinString: inputs);
        expect(result.stdout, contains('错误：客户代码 "NONEXISTENT_CUST" 不存在于客户数据库中。'));
      });

      test('Create shipment with invalid package count (e.g., "abc") fails', () async {
        final inputs = 'CUST001\nInvalidCount\nabc\nAir\n5\nDetails';
        var result = await runShipmentBoard(['shipment', '-a', 'create'], stdinString: inputs);
        expect(result.stdout, contains('错误：包裹数量必须是一个大于0的整数。'));
      });
    });

    group('Shipment Update Command', () {
      String? existingTrackingNumber;

      setUp(() async {
        await resetTestDataFile();
        final createInputs = 'CUST002\nUpdatableGadget\n1\nSea\n25\nItem to be updated';
        var createResult = await runShipmentBoard(['shipment', '-a', 'create'], stdinString: createInputs);
        final match = RegExp(r'单号：(CUST002_UpdatableGadget_1_[\wT.-]+Z)').firstMatch(createResult.stdout);
        expect(match, isNotNull, reason: "Setup for update test failed: tracking number not found in create output.");
        existingTrackingNumber = match!.group(1)?.trim(); // Trim to be safe
      });

      test('Update shipment status successfully', () async {
        expect(existingTrackingNumber, isNotNull);
        final updateInputs = '$existingTrackingNumber\n已发货'; // Tracking number on first line, status on second
        var result = await runShipmentBoard(['shipment', '-a', 'update'], stdinString: updateInputs);
        expect(result.exitCode, 0, reason: "Process exited with error. STDOUT: ${result.stdout} STDERR: ${result.stderr}");
        expect(result.stdout, contains('运单状态更新并已自动保存！'), reason: "Success message not found. STDOUT: ${result.stdout}");

        final fileContent = jsonDecode(await testDataFile.readAsString());
        final updatedShipment = (fileContent['shipments'] as List).firstWhere((s) => s['trackingNumber'] == existingTrackingNumber, orElse: () => null);
        expect(updatedShipment, isNotNull);
        expect(updatedShipment['status'], '已发货');
      });

      test('Update non-existent shipment fails', () async {
        final updateInputs = 'FAKE_TRACKING_123\n已到达';
        var result = await runShipmentBoard(['shipment', '-a', 'update'], stdinString: updateInputs);
        expect(result.stdout, contains('找不到该运单。'));
      });

      test('Update shipment with invalid status fails', () async {
        expect(existingTrackingNumber, isNotNull);
        final updateInputs = '$existingTrackingNumber\n正在飞';
        var result = await runShipmentBoard(['shipment', '-a', 'update'], stdinString: updateInputs);
        expect(result.stdout, contains('错误：无效的运单状态。请输入 (未发货/已发货/已到达/已提货) 中的一个。'));
      });
    });

    group('Shipment Query Command', () {
      String? track1, track2;
      DateTime? createdTime1;

      setUp(() async {
        await resetTestDataFile();
        final create1Inputs = 'CUST001\nAlphaQuery\n2\nAir\n3\nQuery Details 1';
        var r1 = await runShipmentBoard(['shipment', '-a', 'create'], stdinString: create1Inputs);
        track1 = RegExp(r'单号：(CUST001_AlphaQuery_2_[\wT.-]+Z)').firstMatch(r1.stdout)?.group(1);

        final fileData = jsonDecode(await testDataFile.readAsString());
        final shipmentData1 = (fileData['shipments'] as List).firstWhere((s) => s['trackingNumber'] == track1, orElse: () => null);
        expect(shipmentData1, isNotNull);
        createdTime1 = DateTime.parse(shipmentData1['createdTime'] as String);

        final create2Inputs = 'CUST001\nBetaQuery\n5\nSea\n12\nQuery Details 2';
        var r2 = await runShipmentBoard(['shipment', '-a', 'create'], stdinString: create2Inputs);
        track2 = RegExp(r'单号：(CUST001_BetaQuery_5_[\wT.-]+Z)').firstMatch(r2.stdout)?.group(1);

        expect(track1, isNotNull);
        expect(track2, isNotNull);
        expect(createdTime1, isNotNull);
      });

      test('Query shipments for customer with shipments (default lang/tz)', () async {
        var result = await runShipmentBoard(['shipment', '-a', 'query'], stdinString: 'CUST001');
        expect(result.exitCode, 0);
        expect(result.stdout, contains('客户 CUST001 (Alice Wonderland) 的运单列表'));
        expect(result.stdout, contains(track1!));
        final expectedUtcArrival1 = createdTime1!.add(Duration(days: 3));
        final formattedExpectedUtcArrival1 = DateFormat('yyyy-MM-dd HH:mm:ss').format(expectedUtcArrival1);
        expect(result.stdout, contains('预计到达: $formattedExpectedUtcArrival1'));
      });

      test('Query shipments for customer with no shipments', () async {
        var result = await runShipmentBoard(['shipment', '-a', 'query'], stdinString: 'CUST003');
        expect(result.stdout, contains('No shipments found.'));
      });
    });

    group('Argument Parsing and Help', () {
      test('Unknown main command shows usage', () async {
        var result = await runShipmentBoard(['nonexistentcmd']);
        expect(result.stdout, contains('未知的主命令: nonexistentcmd'));
        // 检查 parser.usage 输出中的特定选项，而不是一个笼统的 "Usage:" 字符串
        expect(result.stdout, contains('--lang'));
        expect(result.stdout, contains('--action'));
      });

      test('Shipment command with unknown action shows error', () async {
        var result = await runShipmentBoard(['shipment', '-a', 'delete']);
        expect(result.stdout, contains('shipment 命令下未知的动作：\"delete\"'));
      });

      test('No command (empty arguments) shows usage', () async {
        var result = await runShipmentBoard([]);
        expect(result.stdout, contains('请输入一个命令。可用命令: login, shipment, save, load.'));
        expect(result.stdout, contains('--lang')); // 同样检查 parser.usage 的部分内容
        expect(result.stdout, contains('--action'));
      });
    });
  });
}
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

  // 打印将要执行的命令和输入 (用于演示)
  print("\n▶️ EXECUTING COMMAND: dart ${p.basename(scriptPath)} ${arguments.join(' ')}");
  if (stdinString != null && stdinString.isNotEmpty) {
    print("  ⌨️ WITH STDIN:\n---stdin---\n$stdinString\n-----------");
  }

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

  // 打印程序输出 (用于演示)
  if (stdoutResult.isNotEmpty) {
    print("  📢 STDOUT:\n---stdout---\n$stdoutResult\n------------");
  }
  if (stderrResult.isNotEmpty) {
    print("  ⚠️ STDERR:\n---stderr---\n$stderrResult\n------------");
  }
  print("  🏁 EXITCODE: $exitCode");


  return ProcessResult(process.pid, exitCode, stdoutResult, stderrResult);
}

// 帮助函数：管理 data.json 文件
// 使用 p.join 来确保路径分隔符的正确性
final testDataFilePath = p.join(Directory.current.path, 'data.json');
File testDataFile = File(testDataFilePath);
String? originalDataContent; // 仍然保留以记录初始状态，但不再用于恢复

Map<String, dynamic> getDefaultCustomers() => {
  "CUST001": {"code": "CUST001", "name": "Alice Wonderland", "contact": "alice@example.com", "country": "UK", "language": "en", "timezone": 0}, // UTC+0
  "CUST002": {"code": "CUST002", "name": "Omar Sharif", "contact": "omar@example.com", "country": "Egypt", "language": "ar", "timezone": 2},    // UTC+2
  "CUST003": {"code": "CUST003", "name": "Test User NoShip", "contact": "test@example.com", "country": "US", "language": "en", "timezone": -5}   // UTC-5
};

Future<void> resetTestDataFile({Map<String, dynamic>? initialData}) async {
  print("  🔄 Resetting data.json...");
  if (initialData != null) {
    await testDataFile.writeAsString(jsonEncode(initialData));
  } else {
    await testDataFile.writeAsString(jsonEncode({
      "shipments": [],
      "customers": getDefaultCustomers(),
    }));
  }
  print("  🔄 data.json has been reset.");
}

// 辅助函数：从 JSON 读取特定运单的创建时间 (UTC)
Future<DateTime?> getShipmentCreationTimeUtc(String trackingNumber) async {
    if (!await testDataFile.exists()) return null;
    final fileContent = await testDataFile.readAsString();
    if (fileContent.isEmpty) return null;
    try {
        final fileData = jsonDecode(fileContent);
        final shipments = fileData['shipments'] as List?;
        if (shipments == null) return null;
        final shipmentData = shipments.firstWhere(
            (s) => s is Map && s['trackingNumber'] == trackingNumber,
            orElse: () => null
        );
        if (shipmentData != null && shipmentData['createdTime'] is String) {
            // 确保解析为 UTC 时间
            return DateTime.parse(shipmentData['createdTime'] as String).toUtc();
        }
    } catch (e) {
        print("Error reading creation time for $trackingNumber: $e");
    }
    return null;
}


void main() {
  setUpAll(() async {
    print("\n--- Global Test Setup (setUpAll) ---");
    if (await testDataFile.exists()) {
      originalDataContent = await testDataFile.readAsString(); // 仍然备份，以防万一或用于比较
      print("  💾 Original data.json content backed up (but will not be restored automatically).");
    } else {
      print("  💾 No original data.json to back up.");
    }
  });

  tearDownAll(() async {
    print("\n--- Global Test Teardown (tearDownAll) ---");
    // **修改点**: 注释掉恢复和删除 data.json 的逻辑
    // if (originalDataContent != null) {
    //   await testDataFile.writeAsString(originalDataContent!);
    //   print("   restor💾 Original data.json restored.");
    // } else {
    //   if (await testDataFile.exists()) {
    //     await testDataFile.delete();
    //     print("  🗑️ Test data.json deleted (no original to restore).");
    //   }
    // }
    if (await testDataFile.exists()) {
        print("  ℹ️ data.json now reflects the state after all test operations. It has NOT been restored or deleted.");
        print("      You can inspect its content at: $testDataFilePath");
    } else {
        print("  ℹ️ data.json does not exist after tests (it might have been deleted by a test or never created if all tests failed early).");
    }
  });

  setUp(() async {
    print("\n--- Test Case Setup (setUp) ---");
    await resetTestDataFile(); // 每个测试前重置数据
  });

  final String appPrintedDataPath = Directory.current.path + "/data.json";
  final DateFormat expectedTimeFormat = DateFormat('yyyy-MM-dd HH:mm:ss'); // 统一预期的时间格式

  group('CLI Application Tests', () {
    print("\n\n--- 🧪 STARTING TEST GROUP: CLI Application Tests ---");

    group('Data Management (Load/Save Commands)', () {
      print("\n  --- 🧪 STARTING SUB-GROUP: Data Management (Load/Save Commands) ---");
      test('Initial load (implicit) from non-existent file should create empty state in memory', () async {
        print("\n    --- ▶️ TEST: Initial load from non-existent file ---");
        print("      - Purpose: Verify app handles missing data.json gracefully on first (implicit) load.");
        if (await testDataFile.exists()) {
          print("      - Action: Deleting existing data.json for this test.");
          await testDataFile.delete();
        }
        var result = await runShipmentBoard(['shipment', '-a', 'query'], stdinString: 'ANYCUST');

        print("      - Verification: Checking stdout for file not found message and customer not found message.");
        expect(result.stdout, contains('（全局加载）文件 $appPrintedDataPath 不存在。全局数据将为空。'));
        expect(result.stdout, contains('找不到该客户。'));
        print("    --- ✅ TEST PASSED: Initial load from non-existent file ---");
      });

      test('`load` command re-loads data from file', () async {
        print("\n    --- ▶️ TEST: `load` command functionality ---");
        print("      - Purpose: Verify `load` command correctly re-populates in-memory data from data.json.");
        final specificData = {
          "shipments": [{"trackingNumber":"LOAD_CMD_001","customerCode":"CUST001","cargoShortName":"LoadCmdTest","cargoDetails":"Details","packageCount":1,"transportType":"AIR","status":"未发货","estimatedDays":1,"createdTime":"2025-01-01T00:00:00.000Z"}],
          "customers": getDefaultCustomers()
        };
        print("      - Action: Writing specific test data to data.json: ${jsonEncode(specificData)}");
        await testDataFile.writeAsString(jsonEncode(specificData));

        var resultLoad = await runShipmentBoard(['load']);
        print("      - Verification: Checking `load` command output and exit code.");
        expect(resultLoad.exitCode, 0);
        // 注意：您的load命令似乎会打印两次加载信息，测试脚本需要适应这种情况
        // 如果您的程序逻辑是只打印一次，请调整下面的断言
        expect(resultLoad.stdout, contains('已加载数据到全局状态，共 1 条运单'));
        expect(resultLoad.stdout, contains('（Load 命令）数据已重新加载到内存全局状态。'));


        print("      - Action: Querying for loaded shipment to confirm.");
        var resultQuery = await runShipmentBoard(['shipment', '-a', 'query'], stdinString: 'CUST001');
        print("      - Verification: Checking query result for 'LOAD_CMD_001'.");
        expect(resultQuery.stdout, contains('LOAD_CMD_001'));
        print("    --- ✅ TEST PASSED: `load` command functionality ---");
      });

      test('`save` command writes current in-memory data to data.json', () async {
        print("\n    --- ▶️ TEST: `save` command functionality ---");
        print("      - Purpose: Verify `save` command writes in-memory changes (like a new shipment) to data.json.");
        await runShipmentBoard(['load']); // Load initial (default customers)

        final createInputs = 'CUST001\nSaveTestCargo\n1\nAir\n1\nSave Details';
        print("      - Action: Creating a new shipment in memory (via `shipment -a create`).");
        await runShipmentBoard(['shipment', '-a', 'create'], stdinString: createInputs);

        print("      - Action: Executing `save` command.");
        var resultSave = await runShipmentBoard(['save']);
        print("      - Verification: Checking `save` command output and exit code.");
        expect(resultSave.exitCode, 0);
        expect(resultSave.stdout, contains('（Save 命令）内存中的全局数据已成功保存到 $appPrintedDataPath'));

        print("      - Verification: Reading data.json to confirm saved content.");
        final fileContent = jsonDecode(await testDataFile.readAsString());
        expect(fileContent['shipments'], anyElement(predicate<dynamic>((s) => s['cargoShortName'] == 'SaveTestCargo')));
        expect(fileContent['customers'], getDefaultCustomers());
        print("    --- ✅ TEST PASSED: `save` command functionality ---");
      });
    });

    group('Login Command', () {
      print("\n  --- 🧪 STARTING SUB-GROUP: Login Command ---");
      test('Login as trader', () async {
        print("\n    --- ▶️ TEST: Login as trader ---");
        print("      - Purpose: Verify successful login for 'trader' role.");
        final result = await runShipmentBoard(['login'], stdinString: 'trader\ntrader007');
        print("      - Verification: Checking stdout for trader login success message.");
        expect(result.exitCode, 0);
        expect(result.stdout, contains('已登录为 trader（代码：trader007）'));
        print("    --- ✅ TEST PASSED: Login as trader ---");
      });

      test('Login as customer', () async {
        print("\n    --- ▶️ TEST: Login as customer ---");
        print("      - Purpose: Verify successful login for 'customer' role.");
        final result = await runShipmentBoard(['login'], stdinString: 'customer\nCUST001');
        print("      - Verification: Checking stdout for customer login success message.");
        expect(result.exitCode, 0);
        expect(result.stdout, contains('已登录为 customer（代码：CUST001）'));
        print("    --- ✅ TEST PASSED: Login as customer ---");
      });

      test('Login with empty role fails', () async {
        print("\n    --- ▶️ TEST: Login with empty role ---");
        print("      - Purpose: Verify login fails if role is not provided.");
        final result = await runShipmentBoard(['login'], stdinString: '\nNoUser');
        print("      - Verification: Checking stdout for 'role cannot be empty' message.");
        expect(result.stdout, contains('登录角色不能为空。'));
        print("    --- ✅ TEST PASSED: Login with empty role ---");
      });

       test('Login with empty user code fails', () async {
        print("\n    --- ▶️ TEST: Login with empty user code ---");
        print("      - Purpose: Verify login fails if user code is not provided.");
        final result = await runShipmentBoard(['login'], stdinString: 'trader\n');
        print("      - Verification: Checking stdout for 'user code cannot be empty' message.");
        expect(result.stdout, contains('用户代码不能为空。'));
        print("    --- ✅ TEST PASSED: Login with empty user code ---");
      });
    });

    group('Shipment Create Command', () {
      print("\n  --- 🧪 STARTING SUB-GROUP: Shipment Create Command ---");
      test('Create shipment successfully', () async {
        print("\n    --- ▶️ TEST: Create shipment successfully ---");
        print("      - Purpose: Verify a new shipment can be created and is saved to data.json.");
        final inputs = 'CUST001\nElectronics\n10\nAir\n3\nHigh-value electronics';
        var result = await runShipmentBoard(['shipment', '-a', 'create'], stdinString: inputs);

        print("      - Verification: Checking command output for success message and tracking number.");
        expect(result.exitCode, 0);
        expect(result.stdout, contains('运单创建并已自动保存，单号：'));
        final trackingNumberMatch = RegExp(r'单号：(CUST001_Electronics_10_[\wT.-]+Z)').firstMatch(result.stdout);
        expect(trackingNumberMatch, isNotNull);
        final trackingNumber = trackingNumberMatch!.group(1);

        print("      - Verification: Reading data.json to confirm new shipment details for tracking number: $trackingNumber.");
        final fileContent = jsonDecode(await testDataFile.readAsString());
        final createdShipment = (fileContent['shipments'] as List).firstWhere((s) => s['trackingNumber'] == trackingNumber, orElse: () => null);
        expect(createdShipment, isNotNull);
        expect(createdShipment['customerCode'], 'CUST001');
        expect(createdShipment['cargoShortName'], 'Electronics');
        print("    --- ✅ TEST PASSED: Create shipment successfully ---");
      });

      test('Create shipment for non-existent customer fails', () async {
        print("\n    --- ▶️ TEST: Create shipment for non-existent customer ---");
        print("      - Purpose: Verify shipment creation fails if customer code is invalid.");
        final inputs = 'NONEXISTENT_CUST\nBooks\n5\nSea\n20\nOld books';
        var result = await runShipmentBoard(['shipment', '-a', 'create'], stdinString: inputs);
        print("      - Verification: Checking stdout for 'customer not found' error message.");
        expect(result.stdout, contains('错误：客户代码 "NONEXISTENT_CUST" 不存在于客户数据库中。'));
        print("    --- ✅ TEST PASSED: Create shipment for non-existent customer ---");
      });

      test('Create shipment with invalid package count (e.g., "abc") fails', () async {
        print("\n    --- ▶️ TEST: Create shipment with invalid package count ---");
        print("      - Purpose: Verify shipment creation fails if package count is not a valid number.");
        final inputs = 'CUST001\nInvalidCount\nabc\nAir\n5\nDetails';
        var result = await runShipmentBoard(['shipment', '-a', 'create'], stdinString: inputs);
        print("      - Verification: Checking stdout for 'invalid package count' error message.");
        expect(result.stdout, contains('错误：包裹数量必须是一个大于0的整数。'));
        print("    --- ✅ TEST PASSED: Create shipment with invalid package count ---");
      });
    });

    group('Shipment Update Command', () {
      print("\n  --- 🧪 STARTING SUB-GROUP: Shipment Update Command ---");
      String? existingTrackingNumber;

      setUp(() async {
        print("    --- Group-specific setUp for Update tests: Creating a shipment to update ---");
        await resetTestDataFile();
        final createInputs = 'CUST002\nUpdatableGadget\n1\nSea\n25\nItem to be updated';
        var createResult = await runShipmentBoard(['shipment', '-a', 'create'], stdinString: createInputs);
        final match = RegExp(r'单号：(CUST002_UpdatableGadget_1_[\wT.-]+Z)').firstMatch(createResult.stdout);
        expect(match, isNotNull, reason: "Setup for update test failed: tracking number not found in create output.");
        existingTrackingNumber = match!.group(1)?.trim();
        print("      - Shipment created for update tests. Tracking number: $existingTrackingNumber");
      });

      test('Update shipment status successfully', () async {
        print("\n    --- ▶️ TEST: Update shipment status successfully ---");
        print("      - Purpose: Verify an existing shipment's status can be updated and saved.");
        expect(existingTrackingNumber, isNotNull);
        final updateInputs = '$existingTrackingNumber\n已发货';
        var result = await runShipmentBoard(['shipment', '-a', 'update'], stdinString: updateInputs);

        print("      - Verification: Checking command output for update success message.");
        expect(result.exitCode, 0, reason: "Process exited with error. STDOUT: ${result.stdout} STDERR: ${result.stderr}");
        expect(result.stdout, contains('运单状态更新并已自动保存！'), reason: "Success message not found. STDOUT: ${result.stdout}");

        print("      - Verification: Reading data.json to confirm updated status for tracking number: $existingTrackingNumber.");
        final fileContent = jsonDecode(await testDataFile.readAsString());
        final updatedShipment = (fileContent['shipments'] as List).firstWhere((s) => s['trackingNumber'] == existingTrackingNumber, orElse: () => null);
        expect(updatedShipment, isNotNull);
        expect(updatedShipment['status'], '已发货');
        print("    --- ✅ TEST PASSED: Update shipment status successfully ---");
      });

      test('Update non-existent shipment fails', () async {
        print("\n    --- ▶️ TEST: Update non-existent shipment ---");
        print("      - Purpose: Verify updating a non-existent shipment fails gracefully.");
        final updateInputs = 'FAKE_TRACKING_123\n已到达';
        var result = await runShipmentBoard(['shipment', '-a', 'update'], stdinString: updateInputs);
        print("      - Verification: Checking stdout for 'shipment not found' error message.");
        expect(result.stdout, contains('找不到该运单。'));
        print("    --- ✅ TEST PASSED: Update non-existent shipment ---");
      });

      test('Update shipment with invalid status fails', () async {
        print("\n    --- ▶️ TEST: Update shipment with invalid status ---");
        print("      - Purpose: Verify updating with an invalid status string fails.");
        expect(existingTrackingNumber, isNotNull);
        final updateInputs = '$existingTrackingNumber\n正在飞';
        var result = await runShipmentBoard(['shipment', '-a', 'update'], stdinString: updateInputs);
        print("      - Verification: Checking stdout for 'invalid status' error message.");
        expect(result.stdout, contains('错误：无效的运单状态。请输入 (未发货/已发货/已到达/已提货) 中的一个。'));
        print("    --- ✅ TEST PASSED: Update shipment with invalid status ---");
      });
    });

    group('Shipment Query Command', () {
      print("\n  --- 🧪 STARTING SUB-GROUP: Shipment Query Command ---");
      String? track1Cust1, track2Cust1, track1Cust2; // Store tracking numbers for different customers
      DateTime? createdTime1Cust1, createdTime1Cust2; // Store creation times

      setUp(() async {
        print("    --- Group-specific setUp for Query tests: Creating shipments for different customers ---");
        await resetTestDataFile();

        // Create shipment for CUST001 (UTC+0)
        final create1Inputs = 'CUST001\nAlphaQuery\n2\nAir\n3\nQuery Details 1';
        var r1 = await runShipmentBoard(['shipment', '-a', 'create'], stdinString: create1Inputs);
        track1Cust1 = RegExp(r'单号：(CUST001_AlphaQuery_2_[\wT.-]+Z)').firstMatch(r1.stdout)?.group(1);
        createdTime1Cust1 = await getShipmentCreationTimeUtc(track1Cust1!); // Get UTC time

        // Create another shipment for CUST001
        final create2Inputs = 'CUST001\nBetaQuery\n5\nSea\n12\nQuery Details 2';
        var r2 = await runShipmentBoard(['shipment', '-a', 'create'], stdinString: create2Inputs);
        track2Cust1 = RegExp(r'单号：(CUST001_BetaQuery_5_[\wT.-]+Z)').firstMatch(r2.stdout)?.group(1);

        // Create shipment for CUST002 (UTC+2)
        final create3Inputs = 'CUST002\nCairoCargo\n8\nSea\n15\nDetails for Egypt';
        var r3 = await runShipmentBoard(['shipment', '-a', 'create'], stdinString: create3Inputs);
        track1Cust2 = RegExp(r'单号：(CUST002_CairoCargo_8_[\wT.-]+Z)').firstMatch(r3.stdout)?.group(1);
        createdTime1Cust2 = await getShipmentCreationTimeUtc(track1Cust2!); // Get UTC time

        expect(track1Cust1, isNotNull);
        expect(track2Cust1, isNotNull);
        expect(track1Cust2, isNotNull);
        expect(createdTime1Cust1, isNotNull);
        expect(createdTime1Cust2, isNotNull);
        print("      - Shipments created. CUST001: $track1Cust1, $track2Cust1. CUST002: $track1Cust2");
      });

      test('Query shipments for customer with shipments (default lang/tz)', () async {
        print("\n    --- ▶️ TEST: Query shipments for customer CUST001 (UTC+0) ---");
        print("      - Purpose: Verify querying CUST001 shows correct shipments and UTC arrival time.");
        var result = await runShipmentBoard(['shipment', '-a', 'query'], stdinString: 'CUST001');

        print("      - Verification: Checking output for CUST001 name, shipments, and formatted UTC arrival time.");
        expect(result.exitCode, 0);
        expect(result.stdout, contains('客户 CUST001 (Alice Wonderland) 的运单列表'));
        expect(result.stdout, contains(track1Cust1!));
        final expectedUtcArrival1 = createdTime1Cust1!.add(Duration(days: 3)); // 3 days transit
        final formattedExpectedUtcArrival1 = expectedTimeFormat.format(expectedUtcArrival1);
        expect(result.stdout, contains('预计到达: $formattedExpectedUtcArrival1'));
        print("    --- ✅ TEST PASSED: Query shipments for customer CUST001 (UTC+0) ---");
      });

      // **NEW TEST CASE for Timezone**
      test('Query shipments for customer with non-zero timezone (CUST002, UTC+2)', () async {
        print("\n    --- ▶️ TEST: Query shipments for customer CUST002 (UTC+2) ---");
        print("      - Purpose: Verify querying CUST002 shows arrival time converted to customer's local time (UTC+2).");
        var result = await runShipmentBoard(['shipment', '-a', 'query'], stdinString: 'CUST002');

        print("      - Verification: Checking output for CUST002 name, shipment, and formatted LOCAL (UTC+2) arrival time.");
        expect(result.exitCode, 0);
        expect(result.stdout, contains('客户 CUST002 (Omar Sharif) 的运单列表'));
        expect(result.stdout, contains(track1Cust2!));
        // Calculate expected arrival time in customer's timezone (UTC+2)
        final expectedUtcArrival = createdTime1Cust2!.add(Duration(days: 15)); // 15 days transit
        final expectedLocalArrival = expectedUtcArrival.add(Duration(hours: 2)); // Add timezone offset
        final formattedExpectedLocalArrival = expectedTimeFormat.format(expectedLocalArrival);
        expect(result.stdout, contains('预计到达: $formattedExpectedLocalArrival'));
        print("    --- ✅ TEST PASSED: Query shipments for customer CUST002 (UTC+2) ---");
      });

       // **NEW TEST CASE for Timezone Override**
      test('Query shipments using --tz argument override', () async {
        print("\n    --- ▶️ TEST: Query shipments using --tz argument override ---");
        print("      - Purpose: Verify querying CUST001 with --tz=-5 shows arrival time converted to UTC-5.");
        // Use CUST001 (timezone 0) but override with tz=-5
        var result = await runShipmentBoard(['shipment', '-a', 'query', '--tz=-5'], stdinString: 'CUST001');

        print("      - Verification: Checking output for CUST001 name, shipment, and formatted OVERRIDDEN (UTC-5) arrival time.");
        expect(result.exitCode, 0);
        expect(result.stdout, contains('客户 CUST001 (Alice Wonderland) 的运单列表'));
        expect(result.stdout, contains(track1Cust1!));
        // Calculate expected arrival time in the overridden timezone (UTC-5)
        final expectedUtcArrival = createdTime1Cust1!.add(Duration(days: 3)); // 3 days transit
        final expectedOverriddenLocalArrival = expectedUtcArrival.add(Duration(hours: -5)); // Apply override offset
        final formattedExpectedOverriddenLocalArrival = expectedTimeFormat.format(expectedOverriddenLocalArrival);
        expect(result.stdout, contains('预计到达: $formattedExpectedOverriddenLocalArrival'));
        print("    --- ✅ TEST PASSED: Query shipments using --tz argument override ---");
      });


      test('Query shipments for customer with no shipments', () async {
        print("\n    --- ▶️ TEST: Query shipments for customer with no shipments ---");
        print("      - Purpose: Verify querying a customer with no shipments shows an appropriate message.");
        var result = await runShipmentBoard(['shipment', '-a', 'query'], stdinString: 'CUST003'); // CUST003 has no shipments by default
        print("      - Verification: Checking stdout for 'No shipments found' message.");
        expect(result.stdout, contains('No shipments found.'));
        print("    --- ✅ TEST PASSED: Query shipments for customer with no shipments ---");
      });
    });

    group('Argument Parsing and Help', () {
      print("\n  --- 🧪 STARTING SUB-GROUP: Argument Parsing and Help ---");
      test('Unknown main command shows usage', () async {
        print("\n    --- ▶️ TEST: Unknown main command shows usage ---");
        print("      - Purpose: Verify an unknown command triggers help/usage output.");
        var result = await runShipmentBoard(['nonexistentcmd']);
        print("      - Verification: Checking stdout for 'unknown command' message and usage info.");
        expect(result.stdout, contains('未知的主命令: nonexistentcmd'));
        expect(result.stdout, contains('--lang'));
        expect(result.stdout, contains('--action'));
        print("    --- ✅ TEST PASSED: Unknown main command shows usage ---");
      });

      test('Shipment command with unknown action shows error', () async {
        print("\n    --- ▶️ TEST: Shipment command with unknown action ---");
        print("      - Purpose: Verify an unknown action for the 'shipment' command shows an error.");
        var result = await runShipmentBoard(['shipment', '-a', 'delete']); // 'delete' is an invalid action
        print("      - Verification: Checking stdout for 'unknown action' error message.");
        expect(result.stdout, contains('shipment 命令下未知的动作：\"delete\"'));
        print("    --- ✅ TEST PASSED: Shipment command with unknown action ---");
      });

      test('No command (empty arguments) shows usage', () async {
        print("\n    --- ▶️ TEST: No command (empty arguments) shows usage ---");
        print("      - Purpose: Verify running the app with no arguments shows help/usage output.");
        var result = await runShipmentBoard([]);
        print("      - Verification: Checking stdout for 'please enter a command' message and usage info.");
        expect(result.stdout, contains('请输入一个命令。可用命令: login, shipment, save, load.'));
        expect(result.stdout, contains('--lang'));
        expect(result.stdout, contains('--action'));
        print("    --- ✅ TEST PASSED: No command (empty arguments) shows usage ---");
      });
    });
     print("\n--- 🧪 FINISHED TEST GROUP: CLI Application Tests ---");
  });
}

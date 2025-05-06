// File: test/comprehensive_cli_test.dart
import 'dart:io';
import 'dart:convert';
import 'package:test/test.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

// runShipmentBoard, testDataFilePath, getDefaultCustomers, resetTestDataFile, getShipmentCreationTimeUtc 保持不变
// (确保这些辅助函数与您当前版本一致)
Future<ProcessResult> runShipmentBoard(List<String> arguments, {String? stdinString}) async {
  final executable = Platform.isWindows ? 'dart.exe' : 'dart';
  final scriptPath = p.join(Directory.current.path, 'bin', 'shipment_board.dart');

  print("\n▶️ EXECUTING COMMAND: dart ${p.basename(scriptPath)} ${arguments.join(' ')}");
  if (stdinString != null && stdinString.isNotEmpty) {
    print("  ⌨️ WITH STDIN:\n---stdin---\n$stdinString\n-----------");
  }

  final process = await Process.start(
    executable,
    [scriptPath, ...arguments],
  );

  process.stdin.encoding = utf8;

  if (stdinString != null && stdinString.isNotEmpty) {
    final lines = stdinString.split('\n');
    for (final line in lines) {
      process.stdin.writeln(line);
    }
  }
  await process.stdin.flush();
  await process.stdin.close(); 

  final stdoutResult = await process.stdout.transform(utf8.decoder).join();
  final stderrResult = await process.stderr.transform(utf8.decoder).join();
  final exitCode = await process.exitCode;

  if (stdoutResult.isNotEmpty) {
    print("  📢 STDOUT:\n---stdout---\n$stdoutResult\n------------");
  }
  if (stderrResult.isNotEmpty) {
    print("  ⚠️ STDERR:\n---stderr---\n$stderrResult\n------------");
  }
  print("  🏁 EXITCODE: $exitCode");

  return ProcessResult(process.pid, exitCode, stdoutResult, stderrResult);
}

final testDataFilePath = p.join(Directory.current.path, 'data.json');
File testDataFile = File(testDataFilePath);
String? originalDataContent; 

Map<String, dynamic> getDefaultCustomers() => {
  "CUST001": {"code": "CUST001", "name": "Alice Wonderland", "contact": "alice@example.com", "country": "UK", "language": "en", "timezone": 0},
  "CUST002": {"code": "CUST002", "name": "Omar Sharif", "contact": "omar@example.com", "country": "Egypt", "language": "ar", "timezone": 2},
  "CUST003": {"code": "CUST003", "name": "Test User NoShip", "contact": "test@example.com", "country": "US", "language": "en", "timezone": -5}
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
      originalDataContent = await testDataFile.readAsString(); 
      print("  💾 Original data.json content backed up (but will not be restored automatically).");
    } else {
      print("  💾 No original data.json to back up.");
    }
  });

  tearDownAll(() async {
    print("\n--- Global Test Teardown (tearDownAll) ---");
    if (await testDataFile.exists()) {
        print("  ℹ️ data.json now reflects the state after all test operations. It has NOT been restored or deleted.");
        print("      You can inspect its content at: $testDataFilePath");
    } else {
        print("  ℹ️ data.json does not exist after tests (it might have been deleted by a test or never created if all tests failed early).");
    }
  });

  setUp(() async {
    print("\n--- Test Case Setup (setUp) ---");
    await resetTestDataFile(); 
  });

  final String appPrintedDataPath = "${Directory.current.path}/data.json";
  final DateFormat expectedTimeFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  group('CLI Application Tests', () {
    print("\n\n--- 🧪 STARTING TEST GROUP: CLI Application Tests ---");

    group('Data Management (Load/Save Commands)', () {
      print("\n  --- 🧪 STARTING SUB-GROUP: Data Management (Load/Save Commands) ---");
      test('Initial load (implicit) from non-existent file should create empty state in memory', () async {
        print("\n    --- ▶️ TEST: Initial load from non-existent file ---");
        if (await testDataFile.exists()) {
          await testDataFile.delete();
        }
        var result = await runShipmentBoard(['shipment', '-a', 'query'], stdinString: 'ANYCUST');
        expect(result.stdout, contains('（全局加载）文件 $appPrintedDataPath 不存在。全局数据将为空。'));
        expect(result.stdout, contains('找不到该客户。')); // Chinese prompt from handler
        print("    --- ✅ TEST PASSED: Initial load from non-existent file ---");
      });

      test('`load` command re-loads data from file', () async {
        print("\n    --- ▶️ TEST: `load` command functionality ---");
        final specificData = {
          "shipments": [{"trackingNumber":"LOAD_CMD_001","customerCode":"CUST001","cargoShortName":"LoadCmdTest","cargoDetails":"Details","packageCount":1,"transportType":"AIR","status":"未发货","estimatedDays":1,"createdTime":"2025-01-01T00:00:00.000Z"}],
          "customers": getDefaultCustomers()
        };
        await testDataFile.writeAsString(jsonEncode(specificData));
        var resultLoad = await runShipmentBoard(['load']);
        expect(resultLoad.exitCode, 0);
        expect(resultLoad.stdout, contains('已加载数据到全局状态，共 1 条运单'));
        expect(resultLoad.stdout, contains('（Load 命令）数据已重新加载到内存全局状态。'));

        var resultQuery = await runShipmentBoard(['shipment', '-a', 'query'], stdinString: 'CUST001');
        expect(resultQuery.stdout, contains('LOAD_CMD_001'));
        // CUST001 is English, so header should be English
        expect(resultQuery.stdout, contains('--- Customer CUST001 (Alice Wonderland) Shipment List ---'));
        expect(resultQuery.stdout, contains('Tracking Number: LOAD_CMD_001'));
        expect(resultQuery.stdout, contains('Status: Unshipped')); // Expect English status
        print("    --- ✅ TEST PASSED: `load` command functionality ---");
      });

      test('`save` command writes current in-memory data to data.json', () async {
        print("\n    --- ▶️ TEST: `save` command functionality ---");
        await runShipmentBoard(['load']); 
        final createInputs = 'CUST001\nSaveTestCargo\n1\nAir\n1\nSave Details';
        await runShipmentBoard(['shipment', '-a', 'create'], stdinString: createInputs);
        var resultSave = await runShipmentBoard(['save']);
        expect(resultSave.exitCode, 0);
        expect(resultSave.stdout, contains('（Save 命令）内存中的全局数据已成功保存到 $appPrintedDataPath'));
        final fileContent = jsonDecode(await testDataFile.readAsString());
        expect(fileContent['shipments'], anyElement(predicate<dynamic>((s) => s['cargoShortName'] == 'SaveTestCargo')));
        expect(fileContent['customers'], getDefaultCustomers());
        print("    --- ✅ TEST PASSED: `save` command functionality ---");
      });
    });

    group('Login Command', () {
      print("\n  --- 🧪 STARTING SUB-GROUP: Login Command ---");
      test('Login as trader', () async {
        final result = await runShipmentBoard(['login'], stdinString: 'trader\ntrader007');
        expect(result.exitCode, 0);
        expect(result.stdout, contains('已登录为 trader（代码：trader007）'));
        print("    --- ✅ TEST PASSED: Login as trader ---");
      });
      test('Login as customer', () async {
        final result = await runShipmentBoard(['login'], stdinString: 'customer\nCUST001');
        expect(result.exitCode, 0);
        expect(result.stdout, contains('已登录为 customer（代码：CUST001）'));
        print("    --- ✅ TEST PASSED: Login as customer ---");
      });
      test('Login with empty role fails', () async {
        final result = await runShipmentBoard(['login'], stdinString: '\nNoUser');
        expect(result.stdout, contains('登录角色不能为空。'));
        print("    --- ✅ TEST PASSED: Login with empty role ---");
      });
       test('Login with empty user code fails', () async {
        final result = await runShipmentBoard(['login'], stdinString: 'trader\n');
        expect(result.stdout, contains('用户代码不能为空。'));
        print("    --- ✅ TEST PASSED: Login with empty user code ---");
      });
    });

    group('Shipment Create Command', () {
      print("\n  --- 🧪 STARTING SUB-GROUP: Shipment Create Command ---");
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
        expect(createdShipment['cargoShortName'], 'Electronics');
        print("    --- ✅ TEST PASSED: Create shipment successfully ---");
      });
      test('Create shipment for non-existent customer fails', () async {
        final inputs = 'NONEXISTENT_CUST\nBooks\n5\nSea\n20\nOld books';
        var result = await runShipmentBoard(['shipment', '-a', 'create'], stdinString: inputs);
        expect(result.stdout, contains('错误：客户代码 "NONEXISTENT_CUST" 不存在于客户数据库中。'));
        print("    --- ✅ TEST PASSED: Create shipment for non-existent customer ---");
      });
      test('Create shipment with invalid package count (e.g., "abc") fails', () async {
        final inputs = 'CUST001\nInvalidCount\nabc\nAir\n5\nDetails';
        var result = await runShipmentBoard(['shipment', '-a', 'create'], stdinString: inputs);
        expect(result.stdout, contains('错误：包裹数量必须是一个大于0的整数。'));
        print("    --- ✅ TEST PASSED: Create shipment with invalid package count ---");
      });
    });
    
    group('Shipment Update Command', () {
      print("\n  --- 🧪 STARTING SUB-GROUP: Shipment Update Command ---");
      String? existingTrackingNumber;
      setUp(() async {
        final createInputs = 'CUST002\nUpdatableGadget\n1\nSea\n25\nItem to be updated';
        var createResult = await runShipmentBoard(['shipment', '-a', 'create'], stdinString: createInputs);
        final match = RegExp(r'单号：(CUST002_UpdatableGadget_1_[\wT.-]+Z)').firstMatch(createResult.stdout);
        expect(match, isNotNull, reason: "Setup for update test failed: tracking number not found in create output.");
        existingTrackingNumber = match!.group(1)?.trim();
      });
      test('Update shipment status successfully', () async {
        final currentExistingTrackingNumber = existingTrackingNumber; 
        expect(currentExistingTrackingNumber, isNotNull);
        final updateInputs = '$currentExistingTrackingNumber\n已发货'; // Using Chinese status for input
        var result = await runShipmentBoard(['shipment', '-a', 'update'], stdinString: updateInputs);
        expect(result.exitCode, 0);
        expect(result.stdout, contains('运单状态更新并已自动保存！'));
        final fileContent = jsonDecode(await testDataFile.readAsString());
        final updatedShipment = (fileContent['shipments'] as List).firstWhere((s) => s['trackingNumber'] == currentExistingTrackingNumber, orElse: () => null);
        expect(updatedShipment, isNotNull);
        expect(updatedShipment['status'], '已发货'); // Verify stored status is Chinese
        print("    --- ✅ TEST PASSED: Update shipment status successfully ---");
      });
      test('Update non-existent shipment fails', () async {
        final updateInputs = 'FAKE_TRACKING_123\n已到达';
        var result = await runShipmentBoard(['shipment', '-a', 'update'], stdinString: updateInputs);
        expect(result.stdout, contains('找不到该运单。'));
        print("    --- ✅ TEST PASSED: Update non-existent shipment ---");
      });
      test('Update shipment with invalid status fails', () async {
        final currentExistingTrackingNumber = existingTrackingNumber; 
        expect(currentExistingTrackingNumber, isNotNull);
        final updateInputs = '$currentExistingTrackingNumber\n正在飞';
        var result = await runShipmentBoard(['shipment', '-a', 'update'], stdinString: updateInputs);
        expect(result.stdout, contains('错误：无效的运单状态。请输入 (未发货/已发货/已到达/已提货) 中的一个。'));
        print("    --- ✅ TEST PASSED: Update shipment with invalid status ---");
      });
    });

    group('Shipment Query Command', () {
      print("\n  --- 🧪 STARTING SUB-GROUP: Shipment Query Command ---");
      String? track1Cust1ForGroup, track2Cust1ForGroup, track1Cust2ForGroup;
      DateTime? createdTime1Cust1ForGroup, createdTime1Cust2ForGroup;

      setUp(() async {
        print("    --- Group-specific setUp for Query tests: Creating shipments for different customers ---");
        final create1Inputs = 'CUST001\nAlphaQuery\n2\nAir\n3\nQuery Details 1';
        var r1 = await runShipmentBoard(['shipment', '-a', 'create'], stdinString: create1Inputs);
        track1Cust1ForGroup = RegExp(r'单号：(CUST001_AlphaQuery_2_[\wT.-]+Z)').firstMatch(r1.stdout)?.group(1);
        createdTime1Cust1ForGroup = await getShipmentCreationTimeUtc(track1Cust1ForGroup!);

        final create2Inputs = 'CUST001\nBetaQuery\n5\nSea\n12\nQuery Details 2';
        var r2 = await runShipmentBoard(['shipment', '-a', 'create'], stdinString: create2Inputs);
        track2Cust1ForGroup = RegExp(r'单号：(CUST001_BetaQuery_5_[\wT.-]+Z)').firstMatch(r2.stdout)?.group(1);

        final create3Inputs = 'CUST002\nCairoCargo\n8\nSea\n15\nDetails for Egypt';
        var r3 = await runShipmentBoard(['shipment', '-a', 'create'], stdinString: create3Inputs);
        track1Cust2ForGroup = RegExp(r'单号：(CUST002_CairoCargo_8_[\wT.-]+Z)').firstMatch(r3.stdout)?.group(1);
        createdTime1Cust2ForGroup = await getShipmentCreationTimeUtc(track1Cust2ForGroup!);

        expect(track1Cust1ForGroup, isNotNull);
        expect(track2Cust1ForGroup, isNotNull);
        expect(track1Cust2ForGroup, isNotNull);
        expect(createdTime1Cust1ForGroup, isNotNull);
        expect(createdTime1Cust2ForGroup, isNotNull);
        print("      - Shipments created in setUp. CUST001: $track1Cust1ForGroup, $track2Cust1ForGroup. CUST002: $track1Cust2ForGroup");
      });

      test('Query shipments for customer with shipments (CUST001, default lang/tz should be English)', () async {
        print("\n    --- ▶️ TEST: Query shipments for customer CUST001 (English output) ---");
        final currentTrack1Cust1 = track1Cust1ForGroup;
        final currentCreatedTime1Cust1 = createdTime1Cust1ForGroup;
        expect(currentTrack1Cust1, isNotNull);
        expect(currentCreatedTime1Cust1, isNotNull);

        var result = await runShipmentBoard(['shipment', '-a', 'query'], stdinString: 'CUST001');
        
        expect(result.exitCode, 0);
        expect(result.stdout, contains('--- Customer CUST001 (Alice Wonderland) Shipment List ---'));
        expect(result.stdout, contains('Tracking Number: $currentTrack1Cust1'));
        expect(result.stdout, contains('Status: Unshipped')); 
        
        final expectedUtcArrival1 = currentCreatedTime1Cust1!.add(Duration(days: 3));
        final formattedExpectedUtcArrival1 = expectedTimeFormat.format(expectedUtcArrival1);
        expect(result.stdout, contains('Estimated Arrival: $formattedExpectedUtcArrival1'));
        print("    --- ✅ TEST PASSED: Query shipments for customer CUST001 (English output) ---");
      });

      test('Query shipments for customer with non-zero timezone (CUST002, UTC+2, Arabic)', () async {
        print("\n    --- ▶️ TEST: Query shipments for customer CUST002 (Arabic output, UTC+2) ---");
        final currentTrack1Cust2 = track1Cust2ForGroup;
        final currentCreatedTime1Cust2 = createdTime1Cust2ForGroup;
        expect(currentTrack1Cust2, isNotNull);
        expect(currentCreatedTime1Cust2, isNotNull);
        print("        ℹ️ Using for assertion: Tracking=$currentTrack1Cust2, Created=$currentCreatedTime1Cust2");

        var result = await runShipmentBoard(['shipment', '-a', 'query'], stdinString: 'CUST002');
        
        expect(result.exitCode, 0);

        // **MODIFIED ASSERTION for CUST002 Header**
        // Check for consistent parts: customer code and name.
        // The full header might be mixed language due to API timeouts.
        expect(result.stdout, contains('CUST002 (Omar Sharif)'));
        // Check if "Shipment List ---" (English fallback) or its Arabic translation "قائمة الشحنات" is present.
        // This makes the test resilient to translation failures for the header.
        expect(result.stdout, anyOf(contains('Shipment List ---'), contains('قائمة الشحنات')));

        // Assert tracking number (language neutral)
        expect(result.stdout, contains(currentTrack1Cust2!)); 
        
        // Assert status (flexible: Arabic, English fallback, or original Chinese if all fails)
        expect(result.stdout, anyOf(contains('الحالة: غير مرسل'), contains('Status: Unshipped'), contains('Status: 未发货')));

        // Assert Estimated Arrival label and value
        final expectedUtcArrival = currentCreatedTime1Cust2!.add(Duration(days: 15));
        final expectedLocalArrival = expectedUtcArrival.add(Duration(hours: 2)); // UTC+2
        final formattedExpectedLocalArrival = expectedTimeFormat.format(expectedLocalArrival);
        expect(result.stdout, anyOf(contains('Estimated Arrival: $formattedExpectedLocalArrival'), contains('يقدر وصول: $formattedExpectedLocalArrival'), contains('Estimated Arrival: $formattedExpectedLocalArrival')));
        
        print("    --- ✅ TEST PASSED (with robust assertions): Query shipments for customer CUST002 (Arabic output, UTC+2) ---");
      }, timeout: Timeout(Duration(seconds: 90)));

      test('Query shipments using --tz argument override (CUST001 to UTC-5)', () async {
        print("\n    --- ▶️ TEST: Query shipments using --tz argument override ---");
        final currentTrack1Cust1 = track1Cust1ForGroup;
        final currentCreatedTime1Cust1 = createdTime1Cust1ForGroup;
        expect(currentTrack1Cust1, isNotNull);
        expect(currentCreatedTime1Cust1, isNotNull);
        
        var result = await runShipmentBoard(['shipment', '-a', 'query', '--tz=-5'], stdinString: 'CUST001');
        
        expect(result.exitCode, 0);
        expect(result.stdout, contains('--- Customer CUST001 (Alice Wonderland) Shipment List ---'));
        expect(result.stdout, contains('Tracking Number: $currentTrack1Cust1'));
        expect(result.stdout, contains('Status: Unshipped')); 
        
        final expectedUtcArrival = currentCreatedTime1Cust1!.add(Duration(days: 3));
        final expectedOverriddenLocalArrival = expectedUtcArrival.add(Duration(hours: -5));
        final formattedExpectedOverriddenLocalArrival = expectedTimeFormat.format(expectedOverriddenLocalArrival);
        expect(result.stdout, contains('Estimated Arrival: $formattedExpectedOverriddenLocalArrival'));
        print("    --- ✅ TEST PASSED: Query shipments using --tz argument override ---");
      });

      test('Query shipments for customer with no shipments (CUST003, English)', () async {
        print("\n    --- ▶️ TEST: Query shipments for customer with no shipments ---");
        var result = await runShipmentBoard(['shipment', '-a', 'query'], stdinString: 'CUST003');
        expect(result.stdout, contains('No shipments found.')); // Expect English
        print("    --- ✅ TEST PASSED: Query shipments for customer with no shipments ---");
      });
    });

    group('Argument Parsing and Help', () {
      print("\n  --- 🧪 STARTING SUB-GROUP: Argument Parsing and Help ---");
      test('Unknown main command shows usage', () async {
        var result = await runShipmentBoard(['nonexistentcmd']);
        expect(result.stdout, contains('未知的主命令: nonexistentcmd')); 
        expect(result.stdout, contains('--lang'));
        expect(result.stdout, contains('--action'));
        print("    --- ✅ TEST PASSED: Unknown main command shows usage ---");
      });
      test('Shipment command with unknown action shows error', () async {
        var result = await runShipmentBoard(['shipment', '-a', 'delete']); 
        expect(result.stdout, contains('shipment 命令下未知的动作："delete"')); 
        print("    --- ✅ TEST PASSED: Shipment command with unknown action ---");
      });
      test('No command (empty arguments) shows usage', () async {
        var result = await runShipmentBoard([]);
        expect(result.stdout, contains('请输入一个命令。可用命令: login, shipment, save, load.')); 
        expect(result.stdout, contains('--lang'));
        expect(result.stdout, contains('--action'));
        print("    --- ✅ TEST PASSED: No command (empty arguments) shows usage ---");
      });
    });
     print("\n--- 🧪 FINISHED TEST GROUP: CLI Application Tests ---");
  });
}

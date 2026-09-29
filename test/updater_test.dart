import 'package:flutter_test/flutter_test.dart';
import 'package:nexoratv/core/updater.dart';

void main() {
  test('compare les versions numériquement', () {
    expect(compareVersions('2.1.0', '2.0.9'), greaterThan(0));
    expect(compareVersions('2.10.0', '2.9.0'), greaterThan(0));
    expect(compareVersions('2.0.0', '2.0.0'), 0);
    expect(compareVersions('2.0', '2.0.0'), 0);
    expect(compareVersions('1.3.3', '2.0.0'), lessThan(0));
    expect(compareVersions('2.0.1+201', '2.0.0'), greaterThan(0));
    expect(compareVersions('v2.1.0', '2.0.0'), greaterThan(0));
  });
}

import 'package:finance_ai/core/failure/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Result routes a success to the success branch', () {
    const result = Success<int>(42);

    final value = result.when(
      success: (number) => number,
      failure: (_) => -1,
    );

    expect(value, 42);
  });
}

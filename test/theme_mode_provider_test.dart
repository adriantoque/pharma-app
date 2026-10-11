import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/core/theme/theme_mode_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to light mode and restores the saved preference', () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('darkModeEnabled', true);
    final provider = ThemeModeProvider(preferences: Future.value(preferences));
    addTearDown(provider.dispose);

    await provider.load();

    expect(provider.isDarkMode, isTrue);
  });

  test('saves dark mode changes for the next launch', () async {
    final preferences = await SharedPreferences.getInstance();
    final provider = ThemeModeProvider(preferences: Future.value(preferences));
    addTearDown(provider.dispose);

    await provider.setDarkMode(true);

    expect(provider.isDarkMode, isTrue);
    expect(preferences.getBool('darkModeEnabled'), isTrue);

    await provider.setDarkMode(false);

    expect(provider.isDarkMode, isFalse);
    expect(preferences.getBool('darkModeEnabled'), isFalse);
  });
}

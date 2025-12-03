# hardcoded_strings

A custom Dart/Flutter linter that detects hardcoded strings in Flutter widgets and encourages the use of localization or constants for better internationalization support.

## Features

- 🔍 Detects hardcoded strings passed directly to Flutter widget constructors
- 🎯 Smart filtering to avoid false positives:
  - Skips technical strings (URLs, emails, file paths, etc.)
  - Skips map keys and acceptable widget properties
  - Skips very short strings (≤ 2 characters)
  - Skips empty strings
- 🛠️ Supports ignore comments for specific cases
- ⚡ Built on `custom_lint` for fast, IDE-integrated linting

## Installation

### 1. Add the package to your `pubspec.yaml`

Add `hardcoded_strings` to your `dev_dependencies`:

```yaml
dev_dependencies:
  hardcoded_strings:
    git:
      url: https://github.com/your-username/hardcoded_strings.git
      # Or use a specific version/tag
      # ref: v0.0.1
```

Or if published to pub.dev:

```yaml
dev_dependencies:
  hardcoded_strings: ^0.0.1
```

### 2. Configure `custom_lint` in your `pubspec.yaml`

Add `custom_lint` to your `dev_dependencies`:

```yaml
dev_dependencies:
  custom_lint: ^0.8.1
  hardcoded_strings: ^0.0.1
```

### 3. Create or update `analysis_options.yaml`

Create an `analysis_options.yaml` file in your project root (if it doesn't exist) and include the plugin:

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  plugins:
    - custom_lint
```

### 4. Run the setup

After adding the dependencies, run:

```bash
flutter pub get
```

## Usage

Once installed, the linter will automatically check your code for hardcoded strings in Flutter widgets. The linter will flag strings that are:

- Passed directly to widget constructors (e.g., `Text('Hello')`)
- Not empty or very short
- Not technical identifiers (URLs, file paths, etc.)
- Not in acceptable widget properties (keys, asset paths, etc.)

### Example

The linter will flag this:

```dart
// ❌ This will be flagged
Text('Welcome to the app')
ElevatedButton(
  onPressed: () {},
  child: Text('Click me'),
)
```

Instead, use localization or constants:

```dart
// ✅ Recommended approach
Text(AppLocalizations.of(context)!.welcomeMessage)
// or
Text(AppStrings.welcomeMessage)

ElevatedButton(
  onPressed: () {},
  child: Text(AppLocalizations.of(context)!.clickMe),
)
```

### What Gets Ignored

The linter intelligently ignores:

1. **Technical strings**: URLs, emails, file paths, hex colors, etc.

   ```dart
   Image.network('https://example.com/image.png') // ✅ Ignored
   Color(0xFF000000) // ✅ Ignored
   ```

2. **Map keys**:

   ```dart
   final map = {'key': 'value'}; // ✅ 'key' is ignored
   ```

3. **Acceptable widget properties**: keys, asset paths, restoration IDs, etc.

   ```dart
   Widget(key: ValueKey('my-key')) // ✅ Ignored
   Image.asset('assets/image.png') // ✅ Ignored
   ```

4. **Very short strings** (≤ 2 characters):

   ```dart
   Text('A') // ✅ Ignored
   ```

5. **Strings in function bodies** (not direct widget arguments):

   ```dart
   onPressed: () {
     print('Debug message'); // ✅ Ignored
   }
   ```

## Ignoring Specific Cases

If you need to ignore a specific hardcoded string, you can use ignore comments:

```dart
// ignore: hardcoded_strings
Text('This string is okay for now')

// Or use the full rule name
// ignore: avoid_hardcoded_strings_in_widgets
Text('Another acceptable string')
```

To ignore for an entire file:

```dart
// ignore_for_file: hardcoded_strings
```

## Configuration

Currently, the linter uses sensible defaults. Future versions may support configuration options for:

- Custom ignore patterns
- Minimum string length threshold
- Custom acceptable widget properties
- Custom technical string patterns

## How It Works

The linter analyzes your Dart code using the `analyzer` package and:

1. Finds all string literals in your code
2. Checks if they are passed directly to Flutter widget constructors
3. Applies various filters to reduce false positives
4. Reports violations with helpful messages

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

See the [LICENSE](LICENSE) file for details.

## Additional Information

For more information about:

- Writing custom linters: [custom_lint documentation](https://pub.dev/packages/custom_lint)
- Dart analysis: [Dart analyzer documentation](https://dart.dev/tools/analysis)
- Flutter localization: [Flutter internationalization guide](https://flutter.dev/docs/development/accessibility-and-localization/internationalization)

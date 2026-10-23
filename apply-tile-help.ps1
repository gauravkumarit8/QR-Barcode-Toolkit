# Adds ONLY the "Scan from anywhere" Quick Settings help to settings_screen.dart.
# Run from the repo folder (next to pubspec.yaml). Safe to run twice.

$ErrorActionPreference = 'Stop'
$path = 'lib\screens\settings_screen.dart'
$full = (Resolve-Path $path).Path
$raw = [System.IO.File]::ReadAllText($full)

if ($raw.Contains('_showTileHelp')) {
  Write-Host "Already present in $path - nothing to do."
  exit 0
}

$crlf = $raw.Contains("`r`n")
$text = $raw.Replace("`r`n", "`n")

$edits = @(
  @{
    Old = @'
if (_showPrivacyOptions)
'@
    New = @'
ListTile(
                  leading: const Icon(Icons.qr_code_scanner),
                  title: const Text('Scan from anywhere'),
                  subtitle: const Text('Add the "Scan QR" tile to Quick Settings'),
                  onTap: _showTileHelp,
                ),
                const Divider(),
                if (_showPrivacyOptions)
'@
  },
  @{
    Old = @'
String _themeLabel(ThemeMode mode) {
'@
    New = @'
void _showTileHelp() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quick Settings tile'),
        content: const Text(
          '1. Swipe down from the top of the screen to open Quick Settings (on some '
          'phones, swipe down twice).\n\n'
          '2. Tap the pencil (edit) icon.\n\n'
          '3. Drag the "Scan QR" tile into your active tiles.\n\n'
          'One tap on the tile then opens the scanner. The steps differ a little '
          'between phone makers.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  String _themeLabel(ThemeMode mode) {
'@
  }
)

foreach ($e in $edits) {
  $old = $e.Old.TrimEnd("`r", "`n")
  $new = $e.New.TrimEnd("`r", "`n")
  $n = ([regex]::Matches($text, [regex]::Escape($old))).Count
  if ($n -ne 1) { throw "$path : expected exactly 1 match but found $n for:`n$old" }
  $text = $text.Replace($old, $new)
}

if ($crlf) { $text = $text.Replace("`n", "`r`n") }
[System.IO.File]::WriteAllText($full, $text, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "edited $path"

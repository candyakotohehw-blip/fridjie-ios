import 'dart:io';

void main() {
  final mainPath = 'lib/screens/open_fridge_setup_screen.dart';
  final fragPath = 'lib/screens/_step56_new.fragment.dart';
  var text = File(mainPath).readAsStringSync().replaceAll('\r\n', '\n');
  final frag =
      File(fragPath).readAsStringSync().replaceAll('\r\n', '\n').trimRight();
  final start = text.indexOf(
    '  Widget _buildStepFive() {\n    const primaryBlue = Color(0xFF2D7DFF);\n    final slots = _computeLayoutSlots();',
  );
  final end = text.indexOf('  Widget _recentItemTile(String name, String meta) {');
  if (start < 0 || end < 0 || start >= end) {
    stderr.writeln('patch_step56: markers not found start=$start end=$end');
    exitCode = 1;
    return;
  }
  text = '${text.substring(0, start)}$frag\n${text.substring(end)}';
  File(mainPath).writeAsStringSync(text);
  stdout.writeln('patch_step56: inserted ${frag.length} chars');
}

import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'package:tlinter/src/rules/signature_reflection.dart';

/// A plugin class used to list all the assists/lints defined by the plugin
class _TLinter extends Plugin {
  @override
  String get name => 'TLinter plugin';

  @override
  void register(PluginRegistry registry) {
    registry.registerWarningRule(FunctionSignatureReflection());
  }
}

final Plugin plugin = _TLinter();

import 'flavor_config.dart';
import 'main.dart' as app;

Future<void> main() async {
  FlavorConfig.configure(flavor: AppFlavor.prod);
  await app.main();
}

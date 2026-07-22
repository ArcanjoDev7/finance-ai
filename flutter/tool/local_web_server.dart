import 'dart:io';

Future<void> main(List<String> args) async {
  final root = Directory(args.isEmpty ? 'build/web' : args.first).absolute;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 7360);
  stdout.writeln('Serving ${root.path} at http://127.0.0.1:7360');
  await for (final request in server) {
    final path = request.uri.path == '/' ? 'index.html' : request.uri.path.substring(1);
    final target = File('${root.path}${Platform.pathSeparator}$path');
    final file = await target.exists() ? target : File('${root.path}${Platform.pathSeparator}index.html');
    final extension = file.path.split('.').last;
    request.response.headers.contentType = switch (extension) {
      'js' => ContentType('application', 'javascript', charset: 'utf-8'),
      'wasm' => ContentType('application', 'wasm'),
      'json' => ContentType.json,
      'css' => ContentType('text', 'css', charset: 'utf-8'),
      'html' => ContentType.html,
      _ => ContentType.binary,
    };
    await request.response.addStream(file.openRead());
    await request.response.close();
  }
}

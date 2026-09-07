import 'dart:convert';

import 'package:shelf/shelf.dart';

const _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
};

Middleware corsMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: _corsHeaders);
      }
      final response = await innerHandler(request);
      return response.change(headers: {..._corsHeaders, ...response.headers});
    };
  };
}

Response jsonResponse(Map<String, dynamic> body, {int status = 200}) {
  return Response(
    status,
    body: jsonEncode(body),
    headers: {'Content-Type': 'application/json'},
  );
}

Future<Map<String, dynamic>> readJsonBody(Request request) async {
  final raw = await request.readAsString();
  if (raw.trim().isEmpty) return {};
  final decoded = jsonDecode(raw);
  if (decoded is Map<String, dynamic>) return decoded;
  return {};
}

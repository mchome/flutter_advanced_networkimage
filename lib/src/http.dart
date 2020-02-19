/// http client (under development)
///
/// - [x] redirect
/// - [x] global cookie management
/// - [x] accept http proxy
/// - [ ] request hooks
/// - [ ] response hooks
/// - [ ] move redirect and cookie management to hooks
/// - [ ] resource cache
/// - [ ] full tests
/// - [ ] logger

import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:path/path.dart';
import 'package:pool/pool.dart';
import 'package:async/async.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class Fetch extends http.BaseClient {
  Fetch({
    int maxActiveRequests = 20,
    String proxy,
    bool autoUncompress = false,
    this.followRedirects = true,
    this.maxRedirects = 5,
  })  : assert(maxActiveRequests > 0),
        assert(followRedirects != null),
        _pool = Pool(maxActiveRequests),
        _client = HttpClient()
          ..findProxy = proxy != null ? ((_) => proxy) : null
          ..autoUncompress = autoUncompress;

  final bool followRedirects;
  final int maxRedirects;

  final Pool _pool;
  final HttpClient _client;
  final Cookies _cookies = Cookies();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    List<RedirectInfo> _redirects = [];

    Future<http.StreamedResponse> _send(
      http.BaseRequest request, {
      List<Cookie> cookieList,
    }) async {
      _Response res =
          await _sendRequest(request, client: _client, cookies: cookieList);
      http.StreamedResponse response = res.response;
      List<Cookie> cookies = res.cookies;
      if (cookies != null && cookies.length > 0)
        await _cookies.set(cookies
            .map((Cookie cookie) => cookie..domain ??= request.url.host)
            .toList());

      if (followRedirects &&
          (response.isRedirect ||
              response.statusCode == HttpStatus.movedPermanently ||
              response.statusCode == HttpStatus.found ||
              response.statusCode == HttpStatus.seeOther ||
              response.statusCode == HttpStatus.notModified)) {
        if (_redirects.length < maxRedirects) {
          String location = response.headers['location'];
          if (location == null)
            throw StateError('Response has no Location header for redirect');
          Uri url = Uri.parse(location);

          String method = response.statusCode == HttpStatus.seeOther
              ? 'GET'
              : request.method;
          for (RedirectInfo redirect in _redirects) {
            if (redirect.location == url)
              return Future.error(
                  RedirectException('Redirect loop detected', _redirects));
          }
          _redirects
              .add(_RedirectInfo(response.statusCode, request.method, url));
          var req = http.Request(method, request.url.resolveUri(url));
          return _send(req,
              cookieList: await _cookies.get(uri: request.url.resolveUri(url)));
        } else {
          return Future<http.StreamedResponse>.error(
              RedirectException('Redirect limit exceeded', _redirects));
        }
      } else {
        _redirects = [];
      }
      return response;
    }

    PoolResource resource = await _pool.request();
    http.StreamedResponse response;
    try {
      response = await _send(request,
          cookieList: await _cookies.get(uri: request.url));
    } catch (_) {
      resource.release();
      rethrow;
    }

    Stream<List<int>> stream = response.stream.transform(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleDone: (sink) {
          resource.release();
          sink.close();
        },
      ),
    );

    return http.StreamedResponse(
      stream,
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  void close() => _client?.close();
}

Future<_Response> _sendRequest(
  http.BaseRequest request, {
  HttpClient client,
  List<Cookie> cookies,
}) async {
  HttpClient _client = client ?? HttpClient();
  var stream = request.finalize();

  try {
    var ioRequest = await _client.openUrl(request.method, request.url);

    ioRequest
      ..followRedirects = false
      ..contentLength =
          request.contentLength == null ? -1 : request.contentLength
      ..persistentConnection = request.persistentConnection;
    request.headers.forEach((name, value) {
      ioRequest.headers.set(name, value);
    });
    if (cookies != null && cookies.length > 0)
      ioRequest.cookies.addAll(cookies);

    HttpClientResponse res =
        await stream.pipe(DelegatingStreamConsumer.typed(ioRequest));
    var headers = <String, String>{};
    res.headers.forEach((key, values) {
      headers[key] = values.join(',');
    });

    return _Response(
      http.StreamedResponse(
        DelegatingStream.typed<List<int>>(res).handleError(
            (error) => throw http.ClientException(error.message, error.uri),
            test: (error) => error is HttpException),
        res.statusCode,
        contentLength: res.contentLength == -1 ? null : res.contentLength,
        request: request,
        headers: headers,
        isRedirect: res.isRedirect,
        persistentConnection: res.persistentConnection,
        reasonPhrase: res.reasonPhrase,
      ),
      res.cookies,
    );
  } on HttpException catch (error) {
    throw http.ClientException(error.message, error.uri);
  }
}

class _RedirectInfo implements RedirectInfo {
  final int statusCode;
  final String method;
  final Uri location;
  const _RedirectInfo(this.statusCode, this.method, this.location);
}

class _Response {
  const _Response(this.response, this.cookies);

  final http.StreamedResponse response;
  final List<Cookie> cookies;
}

class Cookies {
  static final Cookies _instance = Cookies._internal();
  factory Cookies() => _instance;
  Cookies._internal();

  static const String _cookiesFilename = 'cookies.json';

  bool get saveInDisk => false;
  set saveInDisk(v) {
    assert(v != null);
    return v;
  }

  List<Cookie> _cookies;
  Map<String, List<Cookies>> _sessions;
  File path;

  Future<void> _initCookies() async {
    if (saveInDisk) {
      path ??=
          File(join((await getTemporaryDirectory()).path, _cookiesFilename));

      try {
        if (path.existsSync()) {
          _cookies = List<String>.from(json.decode(await path.readAsString()))
              .map((String value) => Cookie.fromSetCookieValue(value))
              .toList();
        } else {
          _cookies = [];
        }
      } catch (e) {
        print(e);
        _cookies = [];
      }
    } else {
      _cookies = [];
    }
  }

  Future<List<Cookie>> get({Uri uri}) async {
    if (_cookies == null) await _initCookies();

    Future(() => _cookies.removeWhere((Cookie _cookie) =>
        _cookie.expires?.isBefore(DateTime.now()) ?? false));
    return _cookies.where((Cookie _cookie) {
      return uri.host.endsWith(_cookie.domain[0] == '.'
              ? _cookie.domain.replaceFirst('.', '')
              : _cookie.domain) &&
          (uri.path.isEmpty ? '/' : uri.path).startsWith(_cookie.path) &&
          (_cookie.expires?.isAfter(DateTime.now()) ?? true);
    }).toList();
  }

  Future<void> set(List<Cookie> cookies) async {
    if (_cookies == null) await _initCookies();

    _cookies ??= [];
    cookies.forEach((Cookie newCookie) {
      _cookies.removeWhere((Cookie oldCookie) {
        try {
          bool matchDomain = newCookie.domain.endsWith(oldCookie.domain) ||
              oldCookie.domain.endsWith(newCookie.domain);
          bool matchPath = newCookie.path.startsWith(oldCookie.path) ||
              oldCookie.path.startsWith(newCookie.path);
          bool matchName = newCookie.name == oldCookie.name;

          return matchDomain && matchPath && matchName;
        } catch (e) {
          print(e);
          return true;
        }
      });
      if (newCookie.expires?.isAfter(DateTime.now()) ?? true)
        _cookies.add(newCookie);
    });

    _saveCookies();
  }

  Future<void> clear({bool sessionOnly = true, Uri uri}) async {
    assert(sessionOnly != null);

    _cookies.removeWhere((Cookie _cookie) {
      return (uri != null
                  ? uri.host.endsWith(_cookie.domain) &&
                      uri.path.startsWith(_cookie.path)
                  : true) &&
              (sessionOnly ? _cookie.expires == null : true) ||
          (_cookie.expires?.isBefore(DateTime.now()) ?? true);
    });

    _saveCookies();
  }

  Future<void> _saveCookies() async {
    Iterable<Cookie> data = _cookies.where((Cookie _cookie) =>
        _cookie.expires != null && _cookie.expires.isAfter(DateTime.now()));

    if (saveInDisk) {
      path ??=
          File(join((await getTemporaryDirectory()).path, _cookiesFilename));

      if (data.length > 0) {
        String cookiesString = json
            .encode(data.map((Cookie cookie) => cookie.toString()).toList());
        await path.writeAsString(cookiesString);
      }
    }
  }
}

Cookie cloneCookie(Cookie cookie) =>
    Cookie.fromSetCookieValue(cookie.toString());

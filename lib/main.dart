import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:easy_splash_screen/easy_splash_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:locally/locally.dart';
import 'package:just_audio/just_audio.dart';

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(
    home: MySplash(),
  ));
}

class MySplash extends StatefulWidget {
  @override
  _MySplashState createState() => _MySplashState();
}

class _MySplashState extends State<MySplash> {
  final GlobalKey splashKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return EasySplashScreen(
      logo: Image.asset("assets/trade.png", height: 100, width: 100),
      title: const Text(
        "Crypto & GiftCards",
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: Colors.white,
      showLoader: true,
      loadingText: const Text("We are Buying 24/7"),
      navigator: MyApp(),
      durationInSeconds: 5,
    );
  }
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey webViewKey = GlobalKey();
  var _loaded = false;
  var _connectionError = false;

  var _apiFetching = false;

  InAppWebViewController? webViewController;
  InAppWebViewGroupOptions options = InAppWebViewGroupOptions(
      crossPlatform: InAppWebViewOptions(
        useShouldOverrideUrlLoading: true,
        supportZoom: false,
        mediaPlaybackRequiresUserGesture: false,
      ),
      android: AndroidInAppWebViewOptions(
        allowContentAccess: true,
        allowFileAccess: true,
        useHybridComposition: true,
        domStorageEnabled: true,
        databaseEnabled: true,
      ),
      ios: IOSInAppWebViewOptions(
        allowsInlineMediaPlayback: true,
      ));

  late PullToRefreshController pullToRefreshController;
  String url = "";
  double progress = 0;
  final urlController = TextEditingController();

  late int seconds;
  late int hours;
  late String message1;
  late String message2;

  @override
  void initState() {
    super.initState();

    pullToRefreshController = PullToRefreshController(
      options: PullToRefreshOptions(
        color: Colors.blue,
      ),
      onRefresh: () async {
        if (Platform.isAndroid) {
          webViewController?.reload();
        } else if (Platform.isIOS) {
          webViewController?.loadUrl(
              urlRequest: URLRequest(
                  url: Uri.parse("https://tradepadi.com/dashboard")));
        }
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Locally locally = Locally(
      context: context,
      payload: 'TradePadi',
      pageRoute: MaterialPageRoute(builder: (context) => MyApp()),
      appIcon: 'mipmap/launcher_icon',
    );

    var myUri = Uri.parse("https://tradepadi.com/app-api");
    http.get(myUri).then((response) {
      var data = jsonDecode(utf8.decode(response.bodyBytes)) as Map;

      seconds = data['seconds'] as int;
      hours = data['hour'] as int;
      message1 = data['message1'] as String;

      locally.showPeriodically(
          title: "TradePadi",
          message: data['message2'] as String,
          repeatInterval: hours);
    });

    return MaterialApp(
      home: Scaffold(
          body: SafeArea(
              child: Column(children: <Widget>[
        if (_loaded && _connectionError)
          Container(
            child: const Text(
              "Check your Internet connection",
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            color: Colors.red[600],
            width: double.infinity,
          ),
        Expanded(
          child: Stack(
            children: [
              Visibility(
                child: InAppWebView(
                  key: webViewKey,
                  initialUrlRequest: URLRequest(
                      url: Uri.parse("https://tradepadi.com/dashboard")),
                  initialOptions: options,
                  pullToRefreshController: pullToRefreshController,
                  onWebViewCreated: (controller) {
                    webViewController = controller;
                  },
                  onLoadStart: (controller, url) {
                    setState(() {
                      _loaded = true;
                      _connectionError = false;
                      this.url = url.toString();
                      urlController.text = this.url;
                    });

                    if (!_apiFetching) {
                      setState(() {
                        _apiFetching = true;
                      });

                      Timer.periodic(Duration(seconds: seconds), (Timer t) {
                        var currentUrl = urlController.text.toLowerCase();

                        if (currentUrl.contains(
                            (RegExp(r'dashboard', caseSensitive: false)))) {
                          webViewController!.evaluateJavascript(source: """
                              (function(){
                       var userID = document.getElementById('user-id').value;
                       return userID;     
                      
                              })()
                              """).then((value) {
                            if (value != null) {
                              var completeUrl =
                                  "https://tradepadi.com/secured-notifications-count/" +
                                      value.toString();
                              var myUrl = Uri.parse(completeUrl);
                              http.get(myUrl).then((value) {
//

                                if (int.parse(value.body) >= 1) {
                                  locally.show(
                                      title: "TradePadi", message: message1);

                                  final player = AudioPlayer();
                                  player
                                      .setAsset(
                                          'assets/you-have-a-new-message.mp3')
                                      .then((value) {
                                    player.play();
                                    player.setVolume(1);
                                  });
                                }
                              });
                            }
                          });
                        }
                      });
                    }
                  },
                  androidOnPermissionRequest:
                      (controller, origin, resources) async {
                    return PermissionRequestResponse(
                        resources: resources,
                        action: PermissionRequestResponseAction.GRANT);
                  },
                  shouldOverrideUrlLoading:
                      (controller, navigationAction) async {
                    var uri = navigationAction.request.url!;

                    if (![
                      "http",
                      "https",
                      "file",
                      "chrome",
                      "data",
                      "javascript",
                      "about"
                    ].contains(uri.scheme)) {
                      if (await canLaunch(url)) {
                        // Launch the App
                        await launch(
                          url,
                        );
                        // and cancel the request
                        return NavigationActionPolicy.CANCEL;
                      }
                    }

                    return NavigationActionPolicy.ALLOW;
                  },
                  onLoadHttpError: (controller, url, code, message) {
                    //pullToRefreshController.endRefreshing();
                    setState(() {
                      _connectionError = true;
                    });
                    webViewController = controller;
                  },
                  onLoadStop: (controller, url) async {
                    //pullToRefreshController.endRefreshing();
                    setState(() {
                      this.url = url.toString();
                      urlController.text = this.url;
                    });
                    webViewController = controller;
                  },
                  onLoadError: (controller, url, code, message) {
                    //pullToRefreshController.endRefreshing();
                    setState(() {
                      _connectionError = true;
                    });
                    webViewController = controller;
                  },
                  onProgressChanged: (controller, progress) {
                    if (progress == 100) {
                      //pullToRefreshController.endRefreshing();
                    }
                    setState(() {
                      this.progress = progress / 100;
                      urlController.text = url;
                    });

                    webViewController = controller;
                  },
                  onUpdateVisitedHistory: (controller, url, androidIsReload) {
                    setState(() {
                      this.url = url.toString();
                      urlController.text = this.url;
                    });
                    webViewController = controller;
                  },
                  onConsoleMessage: (controller, consoleMessage) {},
                ),
                visible: (_connectionError) ? false : true,
              ),
              if (_connectionError)
                ButtonBar(
                  alignment: MainAxisAlignment.center,
                  children: <Widget>[
                    ElevatedButton(
                      child: Icon(Icons.refresh),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => MySplash()),
                        );
                      },
                    ),
                  ],
                ),
            ],
          ),
        ),
      ]))),
    );
  }
}

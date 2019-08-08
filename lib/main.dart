import 'package:flutter/material.dart';
import 'package:lywsd02/lywsd02.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lywsd02 Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final lywsd02 = ValueNotifier<Lywsd02Client>(null);

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      lywsd02.value = await Lywsd02Client.discoverDevice();
      // anyway, firstly sync clock with the smartphone.
      await lywsd02.value.syncClock();
      await lywsd02.value.start();
    });
  }

  @override
  void dispose() {
    lywsd02.value?.stop();
    lywsd02.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Lywsd02 Demo'),
      ),
      body: ValueListenableBuilder<Lywsd02Client>(
        valueListenable: lywsd02,
        builder: (context, client, child) {
          if (client == null) {
            return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Searching Lywsd02...', style: TextStyle(fontSize: 30.0)),
                    SizedBox(height: 10),
                    CircularProgressIndicator()
                  ]
                )
              );
          }
          return StreamBuilder<Lywsd02Data>(
            stream: client.stream,
            builder: (context, snapshot) {
              final data = snapshot.data;
              if (data == null) {
                return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Waiting for Lywsd02...', style: TextStyle(fontSize: 30.0)),
                    SizedBox(height: 10),
                    CircularProgressIndicator()
                  ]
                )
              );
              }
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${data.temperature} ${data.tempUnit == Lywsd02TempertureUnit.fahrenheit ? '℉' : '℃'}', style: TextStyle(fontSize: 40.0)),
                    SizedBox(height: 10),
                    Text('${data.humidity}%', style: TextStyle(fontSize: 40.0))
                  ]
                )
              );
            }
          );
        }
      )// This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

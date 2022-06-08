import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:earthquake_app/earthquake.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:intl/intl.dart';

Set<Marker> allMarkers = {};

Future<Earthquake> fetchEarthquake() async {
  final response = await http.get(Uri.parse(
      'https://earthquake.usgs.gov/fdsnws/event/1/query?format=geojson&jsonerror=true&eventtype=earthquake&orderby=time&minmag=4&limit=200'));

  if (response.statusCode == 200) {
    return Earthquake.fromJson(json.decode(response.body));
  } else {
    throw Exception('Failed to load earthquake data');
  }
}

var earthquakeList = <Earthquake>[];

class EarthquakesPage extends ConsumerStatefulWidget {
  const EarthquakesPage({Key? key}) : super(key: key);

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _EarthquakesPageState();
}

class _EarthquakesPageState extends ConsumerState<EarthquakesPage> {
  late Future<Earthquake> futureEarthquake;

  @override
  void initState() {
    super.initState();
    futureEarthquake = fetchEarthquake();
  }

  Color magnitudeColors(double mag) {
    if (mag < 5) {
      return Colors.green;
    } else if (mag < 5.5) {
      return Colors.yellow;
    } else if (mag < 6) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final darkModeProvider = StateProvider(
      (ref) => Theme.of(context).brightness == Brightness.dark,
    );
    final isDarkMode = ref.watch(darkModeProvider);

    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(
          color: isDarkMode ? Colors.white : Colors.black,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Earthquake List',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        actions: [
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (BuildContext context) => <PopupMenuEntry>[
              const PopupMenuItem(
                child: ListTile(
                  leading: Icon(Icons.add),
                  title: Text('Item 1'),
                ),
              ),
              const PopupMenuItem(
                child: ListTile(
                  leading: Icon(Icons.anchor),
                  title: Text('Item 2'),
                ),
              ),
              const PopupMenuItem(
                child: ListTile(
                  leading: Icon(Icons.article),
                  title: Text('Item 3'),
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              bool ascending = true;
              showModalBottomSheet(
                context: context,
                builder: (context) {
                  return Wrap(
                    children: [
                      ListTile(
                        title: const Text('Sort by Magnitude'),
                        trailing: ascending == true
                            ? const Icon(Icons.arrow_upward)
                            : const Icon(
                                Icons.arrow_downward,
                              ),
                        onTap: () {
                          setState(() {
                            ascending = !ascending;
                          });
                        },
                      ),
                      ListTile(
                        title: const Text('Sort by Date'),
                        onTap: () {
                          Navigator.pop(context);
                        },
                      ),
                      ListTile(
                        title: const Text('Sort by Location'),
                        onTap: () {
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Center(
        child: FutureBuilder<Earthquake>(
          future: futureEarthquake,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return ListView.builder(
                itemBuilder: (BuildContext context, int index) {
                  var shortPlace = 'Unknown';
                  if (snapshot.data!.features[index].properties.place != null &&
                      !snapshot.data!.features[index].properties.place!
                          .contains('?')) {
                    shortPlace = snapshot.data!.features[index].properties.place
                        .toString();

                    if (shortPlace.contains(' of ')) {
                      shortPlace = shortPlace.split(' of ')[1];
                    }
                    shortPlace =
                        shortPlace[0].toUpperCase() + shortPlace.substring(1);

                    allMarkers.clear();

                    FirebaseFirestore.instance
                        .collection('earthquakes')
                        .get()
                        .then(
                          (res) => res.docs.forEach(
                            (doc) {
                              allMarkers.add(
                                Marker(
                                  markerId: MarkerId(doc.get('id')),
                                  position: LatLng(doc.get('coordinates')[0],
                                      doc.get('coordinates')[1]),
                                  icon: BitmapDescriptor.defaultMarkerWithHue(
                                    doc.get('mag') > 5.5
                                        ? BitmapDescriptor.hueRed
                                        : doc.get('mag') > 4.5
                                            ? BitmapDescriptor.hueOrange
                                            : BitmapDescriptor.hueYellow,
                                  ),
                                ),
                              );
                            },
                          ),
                        );

                    earthquakeList.add(snapshot.data!);
                    Map<String, dynamic> firebaseData = {
                      'coordinates': [
                        snapshot.data?.features[index].geometry.coordinates[0],
                        snapshot.data?.features[index].geometry.coordinates[1],
                      ],
                      'id': snapshot.data?.features[index].id,
                      'mag': snapshot.data?.features[index].properties.mag,
                      'place': shortPlace,
                      'time': DateFormat.yMMMd().add_jms().format(
                            DateTime.fromMillisecondsSinceEpoch(
                              snapshot.data!.features[index].properties.time,
                            ),
                          ),
                    };
                    FirebaseFirestore.instance
                        .collection('earthquakes')
                        .doc(firebaseData['id'])
                        .set(firebaseData);
                        
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5.0),
                      child: ListTile(
                        title: Text(shortPlace.toString()),
                        subtitle: Text(
                          DateFormat.yMMMd().add_jms().format(
                                DateTime.fromMillisecondsSinceEpoch(
                                  snapshot
                                      .data!.features[index].properties.time,
                                ),
                              ),
                        ),
                        trailing: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: magnitudeColors(
                                snapshot.data!.features[index].properties.mag),
                          ),
                          child: SizedBox(
                            width: 50,
                            height: 50,
                            child: Center(
                              child: Text(
                                snapshot.data!.features[index].properties.mag
                                    .toString(),
                                style: const TextStyle(
                                  fontSize: 20,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  return Container();
                },
                itemCount: snapshot.data!.features.length,
                // itemCount: 100,
              );
            } else if (snapshot.hasError) {
              return Text("${snapshot.error}");
            }
            return const CircularProgressIndicator();
          },
        ),
      ),
    );
  }
}

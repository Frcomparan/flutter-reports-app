import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await openDatabase(
    join(await getDatabasesPath(), 'reports_database.db'),
    onCreate: (db, version) async {
      await db.execute(
        'CREATE TABLE reports(id INTEGER PRIMARY KEY AUTOINCREMENT, imagePath TEXT, location TEXT, description TEXT, enviado INTEGER)',
      );
    },
    version: 1,
  );

  runApp(MyApp(database: database));
}

class MyApp extends StatelessWidget {
  final Database database;

  const MyApp({required this.database});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomeScreen(database: database),
      theme: ThemeData.dark(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final Database database;

  const HomeScreen({required this.database});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late DatabaseHelper dbHelper;
  List<Report> reports = [];

  @override
  void initState() {
    super.initState();
    dbHelper = DatabaseHelper(widget.database);
    _loadReports();
  }

  void _loadReports() async {
    final reportsList = await dbHelper.getReports();
    if (mounted) {
      setState(() {
        reports = reportsList ?? [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Lista de Reportes"),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final report = reports[index];
                // Verifica el valor de la propiedad "enviado" y muestra un texto en verde o rojo
                final enviadoText =
                    report.enviado == 1 ? 'Enviado' : 'No enviado';
                final color = report.enviado == 1 ? Colors.green : Colors.red;
                return Column(
                  children: [
                    Container(
                      margin: EdgeInsets.only(
                          top:
                              8.0), // Agrega margen en la parte superior del ListTile
                      child: ListTile(
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "ID: ${report.id}\nDescripción: ${report.description.substring(0, 14)}${report.description.length > 14 ? '...' : ''}",
                            ),
                            Text(
                              enviadoText,
                              style: TextStyle(color: color),
                            ),
                          ],
                        ),
                        onTap: () {
                          _navigateToDetailsScreen(context, report);
                        },
                      ),
                    ),
                    Divider(
                      color: Colors.grey,
                      thickness: 1.0,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _navigateToFormScreen(context);
        },
        child: Icon(Icons.add),
      ),
    );
  }

  void _navigateToFormScreen(BuildContext context) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FormScreen(
          insertReport: (report) async {
            await dbHelper.insertReport(report);
            _loadReports();
          },
        ),
      ),
    );

    if (result != null) {
      _loadReports();
    }
  }

  void _navigateToDetailsScreen(BuildContext context, Report report) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportDetailsScreen(
          report: report,
          database: widget.database,
        ),
      ),
    );

    if (result != null && result) {
      _loadReports();
    }
  }
}

class ReportDetailsScreen extends StatefulWidget {
  final Report report;
  final Database database;

  ReportDetailsScreen({required this.report, required this.database});

  @override
  _ReportDetailsScreenState createState() => _ReportDetailsScreenState();
}

class _ReportDetailsScreenState extends State<ReportDetailsScreen> {
  Future<void> _sendAndMarkAsSent() async {
    try {
      final String url =
          'http://192.168.0.104:5000/upload'; // Reemplaza con la URL de tu servidor
      final Map<String, String> headers = {
        'Content-Type': 'multipart/form-data'
      };
      final Uri uri = Uri.parse(url);

      final http.MultipartRequest request = http.MultipartRequest('POST', uri)
        ..files.add(http.MultipartFile.fromBytes(
          'imageFile',
          await File(widget.report.imagePath).readAsBytes(),
          filename: widget.report.imagePath.split('/').last,
        ))
        ..fields['location'] = widget.report.location
        ..fields['description'] = widget.report.description;

      final http.Response response =
          await http.Response.fromStream(await request.send());

      if (response.statusCode == 200) {
        // Actualiza la propiedad 'sent' en la base de datos
        final Report updatedReport = widget.report.copyWith(enviado: 1);
        await DatabaseHelper(widget.database)
            .updateReportStatus(updatedReport.id, 1);
        // Puedes agregar lógica adicional aquí después de enviar el reporte
      } else {
        // Muestra un mensaje de error si la solicitud no fue exitosa
        print('Error al enviar el reporte: ${response.statusCode}');
      }
    } catch (e) {
      // Muestra un mensaje de error si ocurre alguna excepción
      print('Error al enviar el reporte: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detalles del Reporte'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ubicación: ${widget.report.location}'),
            SizedBox(height: 16.0),
            Text('Descripción: ${widget.report.description}'),
            SizedBox(height: 16.0),
            Text('Fotos:'),
            // Muestra las fotos aquí
            widget.report.imagePath.isNotEmpty
                ? Image.file(
                    File(widget.report.imagePath),
                    width: 200.0,
                    height: 200.0,
                    fit: BoxFit.cover,
                  )
                : Text('No hay fotos'),
            SizedBox(height: 16.0),
            // Agrega el botón para enviar
            if (widget.report.enviado == 0)
              ElevatedButton(
                onPressed: () async {
                  // Envía el reporte al servidor
                  await _sendAndMarkAsSent();
                  // Vuelve a la pantalla anterior
                  Navigator.pop(context, true);
                },
                child: Text('Enviar'),
              ),
          ],
        ),
      ),
    );
  }
}

class FormScreen extends StatefulWidget {
  final Function(Report) insertReport;

  FormScreen({required this.insertReport});

  @override
  _FormScreenState createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
  late TextEditingController descriptionController;
  late String location = "";
  late String imagePath = "";
  late File? imageFile;

  @override
  void initState() {
    super.initState();
    descriptionController = TextEditingController();
    imageFile = null; // Inicializa imageFile con null
  }

  // Función para obtener la ubicación del usuario
  Future<void> _getLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        location = "${position.latitude},${position.longitude}";
      });
    } catch (e) {
      print("Error al obtener la ubicación: $e");
    }
  }

  Future<void> _takePicture() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? file = await _picker.pickImage(source: ImageSource.camera);

    if (file != null) {
      setState(() {
        imageFile = File(file.path);
        imagePath = file.path;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Nuevo Reporte"),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ubicación: $location'),
              ElevatedButton(
                onPressed: () {
                  _getLocation();
                },
                child: Text('Obtener Ubicación'),
              ),
              SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: _takePicture,
                child: Text('Tomar Foto'),
              ),
              // Vista previa de la imagen
              imageFile != null
                  ? Container(
                      margin: EdgeInsets.only(top: 16.0),
                      child: Image.file(
                        imageFile!,
                        width: 100.0,
                        height: 100.0,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Container(),
              SizedBox(height: 16.0),
              TextField(
                controller: descriptionController,
                maxLines: 5,
                maxLength: 512,
                decoration: InputDecoration(
                  hintText: 'Descripción (máximo 512 caracteres)',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: () {
                  final String description = descriptionController.text;
                  if (description.isNotEmpty &&
                      description.length >=
                          20 && // Validación de longitud mínima
                      imagePath.isNotEmpty &&
                      location.isNotEmpty) {
                    final Report report = Report(
                      imagePath: imagePath,
                      location: location,
                      description: description,
                    );
                    widget.insertReport(report);
                    Navigator.pop(context);
                  } else {
                    // Mostrar un mensaje de error si algún campo está vacío.
                    // Puedes usar un AlertDialog o un SnackBar para esto.
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text("Error"),
                          content: Text(
                            "Asegúrate de completar todos los campos y que la descripción tenga al menos 14 caracteres.",
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: Text("OK"),
                            ),
                          ],
                        );
                      },
                    );
                  }
                },
                child: Text('Guardar Reporte'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Report {
  final int id;
  final String imagePath;
  final String location;
  final String description;
  int enviado;

  Report(
      {required this.imagePath,
      required this.location,
      required this.description,
      this.id = 0,
      this.enviado = 0});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'imagePath': imagePath,
      'location': location,
      'description': description,
      'enviado': enviado,
    };
  }

  factory Report.fromMap(Map<String, dynamic> map) {
    return Report(
      id: map['id'],
      imagePath: map['imagePath'],
      location: map['location'],
      description: map['description'],
      enviado: map['enviado'],
    );
  }

  Report copyWith(
      {int? id,
      String? imagePath,
      String? location,
      String? description,
      int? enviado}) {
    return Report(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      location: location ?? this.location,
      description: description ?? this.description,
      enviado: enviado ?? this.enviado,
    );
  }
}

class DatabaseHelper {
  final Database database;

  DatabaseHelper(this.database);

  Future<void> updateReportStatus(int id, int enviado) async {
    print("Actualizado");
    print(id);
    print(enviado);
    await database.update(
      'reports',
      {'enviado': enviado},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> insertReport(Report report) async {
    await database.insert(
      'reports',
      {
        'imagePath': report.imagePath,
        'location': report.location,
        'description': report.description,
        'enviado': 0, // 1 si es true, 0 si es false
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Report>?> getReports() async {
    final List<Map<String, dynamic>> maps = await database.query('reports');

    return List.generate(maps.length, (index) {
      return Report.fromMap(maps[index]);
    });
  }
}

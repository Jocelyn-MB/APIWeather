import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'dart:async';

// --- MODELO DE DATOS ---

/// Clase para representar los datos del clima.
class Weather {
  final String city;
  final double temperature;
  final String description;

  Weather({
    required this.city,
    required this.temperature,
    required this.description,
  });

  /// Método constructor que crea una instancia de Weather a partir de un mapa JSON.
  factory Weather.fromJson(Map<String, dynamic> json) {
    // La sanitización de texto aquí implica asegurar que los campos existan
    // y proveer valores por defecto seguros si es necesario.
    final main = json['main'] as Map<String, dynamic>?;
    final weatherList = json['weather'] as List<dynamic>?;

    // Obtenemos la descripción, asegurando que sea un String y no nulo.
    String description = 'Clima desconocido';
    if (weatherList != null && weatherList.isNotEmpty) {
      final weatherInfo = weatherList[0] as Map<String, dynamic>?;
      if (weatherInfo != null && weatherInfo['description'] is String) {
        // Sanitizamos la descripción mostrada.
        description = _sanitizeText(weatherInfo['description']);
      }
    }

    return Weather(
      // Sanitizamos el nombre de la ciudad
      city: _sanitizeText(json['name'] as String? ?? 'Ciudad Desconocida'),
      // La temperatura es un número, usamos ?? 0.0 para defensiva.
      temperature: (main?['temp'] as num? ?? 0.0).toDouble(),
      description: description,
    );
  }
}

/// Función simple de sanitización: capitalizar la primera letra y limpiar.
String _sanitizeText(String? text) {
  if (text == null || text.isEmpty) return '';
  // Limpieza básica de espacios
  String cleanText = text.trim();
  // Capitalización simple
  return cleanText.substring(0, 1).toUpperCase() +
      cleanText.substring(1).toLowerCase();
}

// --- SERVICIO DE API ---

/// Servicio que realiza la petición a la API.
Future<Weather> fetchWeather(String city, {int maxRetries = 3}) async {
  // 1. Obtención Segura de la Clave
  final apiKey = dotenv.env['OPEN_WEATHER_API_KEY'];
  const String baseUrl = 'api.openweathermap.org';
  const String apiPath = '/data/2.5/weather';

  if (apiKey == null || apiKey.isEmpty) {
    throw Exception(
      'Error: La clave de API no está configurada. Verifica tu archivo .env.',
    );
  }

  // 2. Validación de Entrada
  if (city.isEmpty) {
    throw Exception('Error: El nombre de la ciudad no puede estar vacío.');
  }

  // 3. Petición con Reintento Exponencial Básico
  for (int attempt = 1; attempt <= maxRetries; attempt++) {
    final Map<String, dynamic> queryParameters = {
      'q': city,
      'appid': apiKey,
      'units': 'metric', // Unidades métricas (Celsius)
    };

    final uri = Uri.https(baseUrl, apiPath, queryParameters);

    try {
      // Petición con TimeOut (8 segundos como requisito)
      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      // Manejo de Códigos de Estado
      if (response.statusCode == 200) {
        // Éxito, parseamos y retornamos
        final jsonResponse = jsonDecode(response.body);
        return Weather.fromJson(jsonResponse);
      } else if (response.statusCode == 404) {
        // Ciudad no encontrada
        throw Exception(
          'Error: Ciudad no encontrada. Código: ${response.statusCode}',
        );
      } else if (response.statusCode == 401) {
        // Clave no válida
        throw Exception(
          'Error: Clave de API no válida. Código: ${response.statusCode}',
        );
      } else if (response.statusCode == 429 || response.statusCode >= 500) {
        // Errores de Rate Limit (429) o Servidor (5xx) - Intentar de nuevo
        if (attempt == maxRetries) {
          throw Exception(
            'Error: Límite de peticiones o error del servidor. Reintentos agotados. Código: ${response.statusCode}',
          );
        }
        // Espera exponencial (1s, 2s, 4s...)
        final delay = Duration(seconds: attempt * attempt);
        print(
          'Error temporal (${response.statusCode}). Reintentando en ${delay.inSeconds}s...',
        );
        await Future.delayed(delay);
      } else {
        // Otros errores de cliente
        throw Exception(
          'Error inesperado al obtener datos: ${response.statusCode}',
        );
      }
    } on TimeoutException {
      // Manejo de Timeout
      if (attempt == maxRetries) {
        throw Exception(
          'Error de Tiempo de Espera (Timeout) después de ${maxRetries} intentos.',
        );
      }
      // Reintentar en caso de timeout
      final delay = Duration(seconds: attempt);
      print('Timeout. Reintentando en ${delay.inSeconds}s...');
      await Future.delayed(delay);
    } catch (e) {
      // Otros errores (red, parseo JSON, etc.)
      throw Exception('Error de conexión o datos: ${e.toString()}');
    }
  }

  // Esto debería ser inalcanzable si la lógica de reintento está bien hecha
  throw Exception(
    'Fallo en la petición del clima después de múltiples reintentos.',
  );
}

// --- WIDGET PRINCIPAL Y UI ---

void main() async {
  // Aseguramos que los widgets de Flutter estén inicializados
  WidgetsFlutterBinding.ensureInitialized();

  // 4. Inicialización de dotenv: Cargamos la clave del archivo .env
  try {
    await dotenv.load(fileName: ".env");
    print("Archivo .env cargado exitosamente.");
  } catch (e) {
    print(
      "Advertencia: No se pudo cargar el archivo .env. Asegúrate de que exista y esté en los assets. Error: $e",
    );
  }

  runApp(const WeatherApp());
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clima Seguro Flutter',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      home: const WeatherScreen(),
    );
  }
}

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  // La ciudad por defecto es Querétaro, como se sugirió.
  String _currentCity = 'Querétaro,MX';
  // Future para gestionar el estado de la petición
  late Future<Weather> _weatherFuture;

  @override
  void initState() {
    super.initState();
    // Inicializar la primera petición al iniciar
    _weatherFuture = fetchWeather(_currentCity);
  }

  /// Función para recargar los datos
  void _fetchNewWeather(String city) {
    // Validamos que el campo no esté vacío
    if (city.trim().isEmpty) {
      // Usamos un Snackbar en lugar de alert()
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa una ciudad válida.')),
      );
      return;
    }
    setState(() {
      _currentCity = city;
      _weatherFuture = fetchWeather(city);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Clima Seguro (OpenWeatherMap)',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            _CityInput(
              onSubmitted: _fetchNewWeather,
              initialCity: _currentCity,
            ),
            const SizedBox(height: 24),
            // Widget que maneja los 4 estados de la UI: Cargando, Error, Datos, Vacío/Inicial
            Expanded(child: _WeatherDisplay(weatherFuture: _weatherFuture)),
          ],
        ),
      ),
    );
  }
}

class _CityInput extends StatelessWidget {
  final Function(String) onSubmitted;
  final String initialCity;

  const _CityInput({required this.onSubmitted, required this.initialCity});

  @override
  Widget build(BuildContext context) {
    final TextEditingController controller = TextEditingController(
      text: initialCity,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.shade200),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: 'Buscar Ciudad (Ej: Tokyo,JP)',
          suffixIcon: IconButton(
            icon: const Icon(Icons.search, color: Colors.blueAccent),
            onPressed: () => onSubmitted(controller.text),
          ),
          border: InputBorder.none,
          labelStyle: TextStyle(color: Colors.blueGrey.shade700),
        ),
        onSubmitted: onSubmitted,
      ),
    );
  }
}

class _WeatherDisplay extends StatelessWidget {
  final Future<Weather> weatherFuture;

  const _WeatherDisplay({required this.weatherFuture});

  @override
  Widget build(BuildContext context) {
    // FutureBuilder es la herramienta clave para manejar los estados de la petición.
    return FutureBuilder<Weather>(
      future: weatherFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Estado: Cargando
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.blueAccent),
                SizedBox(height: 16),
                Text(
                  'Cargando datos del clima...',
                  style: TextStyle(fontSize: 16, color: Colors.blueGrey),
                ),
              ],
            ),
          );
        } else if (snapshot.hasError) {
          // Estado: Error
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.redAccent,
                    size: 60,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Error al cargar el clima',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    // Muestra el mensaje de error capturado (ej: Timeout, 404, clave no válida)
                    snapshot.error.toString().replaceFirst('Exception: ', ''),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blueGrey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          );
        } else if (snapshot.hasData) {
          // Estado: Éxito (Con Datos)
          final weather = snapshot.data!;
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  weather.city,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Text(
                  '${weather.temperature.toStringAsFixed(1)}°C',
                  style: const TextStyle(
                    fontSize: 80,
                    fontWeight: FontWeight.w200,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  weather.description,
                  style: const TextStyle(fontSize: 24, color: Colors.blueGrey),
                ),
                const SizedBox(height: 40),
                const Text(
                  'Datos cargados por HTTPS y clave gestionada en .env',
                  style: TextStyle(fontSize: 12, color: Colors.green),
                ),
              ],
            ),
          );
        } else {
          // Estado: Vacío (Puede ocurrir si el Future es nulo inicialmente, aunque initState lo evita aquí)
          return const Center(
            child: Text(
              'Presiona el botón de búsqueda para obtener el clima.',
              style: TextStyle(color: Colors.blueGrey),
            ),
          );
        }
      },
    );
  }
}

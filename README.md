# secure_weather_app

La aplicación consume la API de OpenWeatherMap, utilizando el endpoint de clima actual (/data/2.5/weather) para obtener la temperatura y una descripción general.

## 1. Configuración Inicial del Proyecto
Paso 1.1: Creación y Dependencias

Asegúrate de que tu pubspec.yaml contenga las siguientes dependencias:

dependencies:
  ```bash
flutter:
    sdk: flutter
  # Para peticiones HTTP
  http: ^1.1.0 
  # Para manejar el archivo .env (secretos)
  flutter_dotenv: ^6.0.0 
  # Otros paquetes necesarios
  cupertino_icons: ^1.0.2
```

Para instalar las dependencia http, corre este comando en el folder de la aplicación:
```bash
flutter pub add http
```
Despues de editar, ejecuta siempre:
```bash
flutter pub get
```
Paso 1.2: Configuración del Archivo .env
- Obtén tu Clave: Consigue tu clave de API de OpenWeatherMap.
- Crea el archivo .env: En la raíz de tu proyecto (junto a pubspec.yaml), crea un archivo llamado exactamente .env (sin extensión). Reemplaza el texto con tu clave real:
```bash
OPEN_WEATHER_API_KEY="TU_CLAVE_AQUI_REEMPLAZAME"
```
- Configurar Assets: Indica a Flutter que debe cargar este archivo. Tu sección flutter: en pubspec.yaml debe lucir así (asegúrate de que el espaciado sea correcto):
```bash
flutter:
  uses-material-design: true
  assets:
    - .env
```
- Configurar .gitignore (Manejo de Secretos): ESTO ES CRUCIAL. Asegúrate de que tu archivo .gitignore incluya la línea .env para evitar que la clave de API sea subida a repositorios públicos.
```bash
# env files
.env
```
## 2. Implementación del Código Flutter
El siguiente código [main dart](). implementa los siguientes criterios técnicos:
```diff
 ├── Consumo y Datos              Uso del endpoint de clima actual (/data/2.5/weather). El modelo de datos       │                                incluye Ciudad, Temperatura y Descripción.
 ├── HTTPS                        Todas las llamadas a la API usan Uri.https().
 ├── Timeouts                     La petición HTTP usa .timeout(const Duration(seconds: 8))
 ├── Validación de Entrada        La función _fetchNewWeather verifica que la city no esté vacía
 │── Sanitización de Texto        La función _sanitizeText() se usa para limpiar y capitalizar el nombre de la   │                                ciudad y la descripción del clima.
 ├── Retry Exponencial            La función fetchWeather usa un bucle for con Future.delayed(Duration(seconds:  │                                attempt * attempt)) para reintentar automáticamente la petición en caso de     │                                errores del servidor o timeouts.
 │── Manejo de Secretos           La clave de API se accede a través de dotenv.env['OPEN_WEATHER_API_KEY'] y     │                                está protegida por .gitignore.
```
## 3. Entregables
La interfaz de usuario implementa el FutureBuilder para manejar los estados requeridos:
- Cargando: Muestra un CircularProgressIndicator y un texto de "Cargando datos del clima...
- Error: Muestra un mensaje amigable, el error exacto y un mensaje descriptivo.
- Datos/Éxito: Muestra la Ciudad, Temperatura y Descripción en un formato legible.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

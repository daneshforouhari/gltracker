/*
 * Oct 17-24, 2026
 * This version still had issues with iOS capturing an image:
 * - Couple of differenet solution were applied between Oct 17- 20, but no luck
 * - The last cod changed is being applied on Oct 24th
 * The .apk for this source was successfully uploaded to Firenase App hosting
 * This version seems to work fully on Pixel9a. More testing should be good
 * Uses Joel's latest GLY icon/image
 * This version will become the code base for addin iOS-related changes
 * Note: This version does not handle multi-colum Nutrion Table format
 * Additional improvements in this version:
 * - Major optimized prespetive warp code: execution time reduced from 190millis to 60millis
 * Major perf improvements by using new sharpening and cylinderical warp codes
 * - Compbined grayscaling and sharpening saves at least 250 millis
 * - Sharpening: Slashed from 1,000ms to ~350ms 
 * - Cylindrical Flattening: Slashed from 212ms to 91ms
 * - Total savings so far: Over 770 millis
 * - Replacing the call to compute() with Isolate.run() shaved down 15%
 *
 * This code is all Google LLM created. The best version yet.
 * It creates a home page, uses a visual guide rectangle for taking a better picture, and displays OCR's text results
 * It outputs the results back on the homepage
 * Added the dashboard/gauge to the home page
 * Added "X" exit,  GLC logo to the home page
 * OCR still generates misspellings
 * Changed the code such
 * - serving info remains inside parenthesis
 * - not to convert sugar to s0gar
 * - gg -> 9g; bg -> 6g
 * - 334 -> 33g
 * - sservings -> servings
 * - tg -> 8g
 * - &o -> 8g 
 *
 * TODO:
 * - process the OCR output as textLines instead of using a string buffer.
 *   this should solve the problem with multi-column food labels 
 * - how to deal with OCR misspellings:  toal -> total and $3g -> 33g
 */

import 'dart:math' as math;
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

late List<CameraDescription> _cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nutrition Facts Scanner',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

// --- UPDATED HOME PAGE (Now tracks and displays the OCR result) ---
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

//typedef DisplayInfo = (String glText, Colors glTextColor, num glVal);
typedef DisplayInfo = (String , Color, double);

class _HomePageState extends State<HomePage> {

  //String _ocrDisplayResult = "No label scanned yet. Tap the button below to start.";
  DisplayInfo _ocrDisplayResult = ('Tap the button below to scan.', Colors.white, 0.0);

  Future<void> _navigateToScanner() async {
    //Open the scanner and wait for it to pass back the final text result string

    final DisplayInfo? scannedText = await Navigator.of(context).push<DisplayInfo>(
      MaterialPageRoute(builder: (context) => const CameraScannerPage()),
    );

    // If the user completed a scan successfully, update the dashboard UI
    if (scannedText != null && mounted) {
      setState(() {
        _ocrDisplayResult = scannedText;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final int dynamicMaxLines = _ocrDisplayResult.$1.split('\n').length;
    return Scaffold(
      appBar: AppBar(
        leading: CloseButton( //displays an X symbol. Clicking on the symbol causes the app to exit
           onPressed: () => SystemNavigator.pop(),
        ),
        title: Text(
          'Glycemic Load Tracker',
          style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width * 0.05,  //text size
                    fontWeight: FontWeight.bold,  //text weight
                    color: Colors.blue,          //text color
                 ),
          ),
        centerTitle: true,              //center the text in the appBar
        backgroundColor: Colors.white,  //appBar's background color
        actions: [
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Image.asset('assets/images/glt.jpg'), //update pub*.yaml, if you change the file name
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
/***Place for paid Ad?
            const Icon(Icons.analytics_outlined, size: 60, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              "Nutrition Label Analyzer",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
END***/

            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _navigateToScanner,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Scan Nutrition Label'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),

            // Displays the gauge/dashboard
            SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 300,
                  height: 300,
                  child: SfRadialGauge(
                    axes: <RadialAxis> [
                      RadialAxis(
                        minimum: 0,
                        maximum: 100,
                        ranges: <GaugeRange>[
                          GaugeRange(startValue: 0, endValue: 10, color: Colors.green),
                          GaugeRange(startValue: 11, endValue: 19, color: Colors.orange),
                          GaugeRange(startValue: 20, endValue: 100, color: Colors.red),
                        ],
                        pointers: <GaugePointer>[
                          NeedlePointer(value: _ocrDisplayResult.$3),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ), //Row

            // Displays the live OCR output block directly inside the Home screen workspace
            Expanded(
              child: Card(
                elevation: 2,
                color: Colors.grey.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  //child: SizedBox.expand(
                    child: AutoSizeText(
                      _ocrDisplayResult.$1,
                      style: TextStyle(fontSize:MediaQuery.of(context).size.width * 0.05, color:_ocrDisplayResult.$2, fontWeight:FontWeight.bold),
                      minFontSize: 10,
                      stepGranularity: 1,
                      maxLines: dynamicMaxLines,
                      overflow: TextOverflow.ellipsis, //fallback if it still won't fit at minFontSize
                    ),
                  //),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- CAMERA VIEW SCREEN ---
class CameraScannerPage extends StatefulWidget {
  const CameraScannerPage({super.key});

  @override
  State<CameraScannerPage> createState() => _CameraScannerPageState();
}

class _CameraScannerPageState extends State<CameraScannerPage> {
  CameraController? _controller;
  final NutritionScanner _scanner = NutritionScanner();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  void _initializeCamera() {
    if (_cameras.isEmpty) return;
    _controller = CameraController(_cameras[0], ResolutionPreset.high, enableAudio: false);
    _controller!.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _captureAndScan() async {
    if (_controller == null || !_controller!.value.isInitialized || _isProcessing) return;

    setState(() { _isProcessing = true; });

    try {
      final XFile rawImageFile = await _controller!.takePicture();
      Uint8List originalBytes = await rawImageFile.readAsBytes();

      final result = await _scanner.analyzeBytes(originalBytes);
      
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      setState(() { _isProcessing = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.white)));
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.previewSize?.height ?? 1080,
                height: _controller!.value.previewSize?.width ?? 1920,
                child: CameraPreview(_controller!),
              ),
            ),
          ),
          Positioned.fill(child: const CameraFramingOverlay()),
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                  child: const Text("Align Label Inside Box", style: TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.center),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                   child: FloatingActionButton(
                          onPressed: _captureAndScan,
                          backgroundColor: Colors.white,
                          child: const Icon(Icons.camera_alt, color: Colors.black),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CameraFramingOverlay extends StatelessWidget {
  const CameraFramingOverlay({super.key});
  @override
  Widget build(BuildContext context) { return CustomPaint(painter: _FramingPainter()); }
}

class _FramingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = Colors.black.withValues(alpha: 0.5);
    final boxPaint = Paint()..color = Colors.green..style = PaintingStyle.stroke..strokeWidth = 3.0;
    final double boxWidth = size.width * 0.75;
    final double boxHeight = size.height * 0.55;
    final double left = (size.width - boxWidth) / 2;
    final double top = (size.height - boxHeight) / 2;
    final RRect targetRect = RRect.fromRectAndRadius(Rect.fromLTWH(left, top, boxWidth, boxHeight), const Radius.circular(12));
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, backgroundPaint);
    canvas.drawRRect(targetRect, Paint()..blendMode = BlendMode.clear);
    canvas.restore();
    canvas.drawRRect(targetRect, boxPaint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

//PART 2
// --- CROSS-PLATFORM IN-MEMORY PIPELINE ---

num getAmount(String first_word, [bool trailing_g = true ] ) {
  /* if the amount of nutrient is less than 1, the label could have
   * some text like this:  Total Carb. less than 1g.
   * Check for misspellings for 'less', and if found, return 1.
   */
  final RegExp _LessRegex = RegExp(r'\b[l1i]e[s5\$]{1,2}(?!\w)');
  //print("XXXXXfirst_word=X${first_word}X");
  if (_LessRegex.hasMatch(first_word)) {
    return 1;
  }

  String num_str;
  num amount = -1;

  Match? token_match = RegExp(r'^\d+(?:\.\d+)?\D+').firstMatch(first_word);

  //look for a nummeric value followed by one or more non-digit chars, e.g. '0.5gx.' due to OCR
  if (token_match != null) {
    //extract the number from the beginning of the token
    Match? num_match = RegExp(r'^\d+(?:\.\d+)?').firstMatch(token_match.group(0)?? " ");
    num_str = num_match?.group(0) ?? " ";
    amount = num.parse(num_str);
  } else { //invalid token due to OCR
    Match? invalid_token = RegExp(r'^\d+(?:\.\d+)?').firstMatch(first_word);
    if (invalid_token != null) { //invalid token is a number
      num_str = invalid_token.group(0)!;
        //If the number has more than one digit and the last digit is a '9','0','6', or '8',
        //chances are the last digit was actually a 'g' which got misspelled by OCR.
      if ( num_str.length > 1 && trailing_g == true && '90684'.contains(num_str[num_str.length - 1]) ) {
        amount = num.parse(num_str.substring(0, num_str.length-1));
      } else {
        amount = num.parse(num_str);
      }
    }
  }
  return amount;
}

class NutritionScanner {
  /// Entry point to pass bytes directly to the cross-platform background processing pipeline
  Future<DisplayInfo> analyzeBytes(Uint8List originalBytes) async {
    final bool isAndroid = defaultTargetPlatform == TargetPlatform.android;

    final inputData = NutritionPipelineInput(
      originalBytes: originalBytes,
      isAndroidPlatform: isAndroid,
    );

    PlatformMemoryImageResult? imageResult = await Isolate.run(
      () => _runBackgroundEnhancements(inputData),
    );

    if (imageResult == null) throw Exception("Image processing failed.");

    // 2. Map the bytes using the precise format required by the host operating system
    final metadata = InputImageMetadata(
      size: Size(imageResult.width.toDouble(), imageResult.height.toDouble()),
      rotation: InputImageRotation.rotation0deg, 
      format: isAndroid ? InputImageFormat.nv21 : InputImageFormat.bgra8888, 
      // Use the native stride, or fallback to standard width * 4 if null
      bytesPerRow: isAndroid 
          ? imageResult.width 
          : (imageResult.iosBytesPerRow ?? imageResult.width * 4),
        );

    final inputImage = InputImage.fromBytes(
      bytes: imageResult.platformBytes,
      metadata: metadata,
    );

    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
    await textRecognizer.close();

    String glText = ""; Color glTextColor = Colors.white; double glVal = 0.0;

    if (recognizedText.text.isEmpty) {
      //DO WE NEED THIS? setState(() {
        //_isProcessing = false;
        glText = "No text dedected in the image.\nRescan Nutrition Label.";
        glTextColor = Colors.red;
        glVal = 0.0;
       //END });
       return (glText, glTextColor, glVal);
    }

    final StringBuffer combinedText = StringBuffer();
    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        combinedText.write('${line.text} ');
      }
    }

    String lowerText = combinedText.toString().replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
    print("XXXX${lowerText}XXXX\n");

    //correcting OCR mistakes
    final RegExp _sizeRegex =  RegExp(r's.?ze+');
    final RegExp _fatRegex = RegExp(r'\b[fep][a4o]t\b');

    const String standardTotal = r'[t1ilrf][o0aqc][t1ilrf][aoeik][l1it]';

    //matches the specific 4-letter compressed "ptal" variant safely
    const String compressedPtal = r'(?!pr[ou])p[t1ilrf][aoeik][l1it]';

    //combine them with an OR (|) group
    final RegExp _totalRegex = RegExp(
      r'\b(?!pr)(?:' + standardTotal + '|' + compressedPtal + r')\b',
      caseSensitive: false,
    );

    final RegExp _servingRegex = RegExp(r'\b(seving|sserving|erving)');
    final RegExp _fiberRegex = RegExp(r'[fep][i1l|t]?[bh6nvp][eco0][rni1]');
    final RegExp _carbRegex = RegExp(r'[cl0dog][a0o4e][rni1][bh6n]');
    final RegExp _gramRegex1 = RegExp(r'(cg|dg|og|ug)\b');
    final RegExp _gramRegex2 = RegExp(r'(lg|ig)\b');
    final RegExp _gramRegex3 = RegExp(r'(&g|tg|&o)\b');

    lowerText = lowerText
                .replaceFirst(_sizeRegex, 'size')
                .replaceAll(RegExp(r'\(|\)|%|,|\[|\]|{|}'), ' ')
                .replaceAll(RegExp(r'\s{2,}'), ' ')
                .replaceAll(_servingRegex, 'serving')
                .replaceAll('thsp', 'tbsp')
                .replaceAll('omg', '0mg')
                .replaceAll('oml', '0ml')
                .replaceAll('bg', '6g')
                .replaceAll('gg', '9g')
                .replaceAll(_gramRegex1, '0g')
                .replaceAll(_gramRegex2, '1g')
                .replaceAll(_gramRegex3, '8g')
                .replaceAll(_totalRegex, 'total')
                .replaceAll(_fatRegex, 'fat')
                .replaceFirst(_carbRegex, 'carb')
                .replaceFirst(_fiberRegex, 'fiber')
                ;

    print("ZZZZ${lowerText}ZZZZ");

    RegExp delimiters = RegExp(r' ');
    RegExp pat =  RegExp(r'$^'); //no match
    RegExpMatch? match = null;


    String serving_info = 'Serving size not found';
    num cals = -1; String cals_info = '';
    num fat = -1; String fat_info = '';
    num carbs = -1; String carbs_info = '';
    num fiber = -1; String fiber_info = '';
    num protein = -1; String protein_info = '';

    //process serving size
    String serving_size = "not found";
    pat = RegExp(r'serv(.*) size|tamaño de la porción');
    match = pat.firstMatch(lowerText);

    if (match != null) {
      String rest = lowerText.substring(match.end);
      /*
       split the rest of string
       extract splitted[3]
       if the last char of splitted[3] is '9|0|6|8', replace it with a 'g'
       serving_info = splitted[1]+splitted[2]+splitted[3]
      */
      List<String> splitted = rest.split(delimiters);
      //print("@@@@@@@@@@splitted[3]=X${splitted[3]}X");
      if ('90684'.contains(splitted[3][splitted[3].length-1])) {
        serving_size = splitted[3].replaceRange(splitted[3].length-1, null, "g");
      } else {
        serving_size = splitted[3];
      }
      if (RegExp(r'^\d+').firstMatch(serving_size) == null) {
        //if serving size token is missing, serving_size gets set to a non-numeric string
        serving_size = "not found";
      } else {
        //the serving sz could be in 'g' or 'mL'. We can't tell the if the  unit is missing due to OCR
        //serving_size = "${splitted[1]} ${splitted[2]} (${serving_size})";
        //splitted1 & 2 could be misspeled due to OCR
        serving_size = "${serving_size}";
      }
    }
    serving_info = "Serving size ${serving_size}";

/***DOES NOT WORK
    print("WWWWW${lowerText}WWWW");
    //process calories
    //patterns to match: calories, calones, calorles, oalories, 0alories, cal0ries, caloies
    pat = RegExp(r'\b[co0]al.{2,4}es?\b');
    match = pat.firstMatch(lowerText);
    if (match != null) {
      String rest = lowerText.substring(match.end);
      String first_word = rest.split(delimiters)[1];
      cals = getAmount(first_word, false); //no trailing g
      print("XXXXXrest=Y${rest}Y first_word=Z${first_word}Z");
    }
    cals_info = 'Calories ${cals}';
END***/

    //process carbs
    pat = RegExp(r'carb(\.|[a-z]*)|carbohidratos totales');
    match = pat.firstMatch(lowerText);
    if (match != null) {
      String rest = lowerText.substring(match.end);
      String first_word = rest.split(delimiters)[1];
      carbs = getAmount(first_word);
    }
    carbs_info = 'Carbs ${carbs}g';

    //process fat
    pat = RegExp(r'total fat|grasa total');
    match = pat.firstMatch(lowerText);
    if (match != null) {
      String rest = lowerText.substring(match.end);

      String first_word = rest.split(delimiters)[1]; //should be a number followed by 'g'
      fat = getAmount(first_word);
    }
    fat_info = 'Fat ${fat}g';

    //process protein
    pat = RegExp(r'[p1r][rni1][o0aqu][t1ilfh][eco0][i1l|t][nmht]');
    match = pat.firstMatch(lowerText);
    if (match != null) {
      String rest = lowerText.substring(match.end);

      String first_word = rest.split(delimiters)[1]; //should be a number followed by 'g'
      //firstword must start with a number &  trailed by 'g', or junk char(s) due to OCR
      protein = getAmount(first_word);
    }
    protein_info = 'Protein ${protein}g';

    //process fiber
    pat = RegExp(r'fiber|Fibra');
    match = pat.firstMatch(lowerText);
    if (match != null) {
      String rest = lowerText.substring(match.end);

      String first_word = rest.split(delimiters)[1]; //should be a number followed by 'g'
      //firstword must start with a number. The number could be trailed by 'g', or junk char(s) due to OCR
      fiber = getAmount(first_word);
    }
    fiber_info = 'Fiber ${fiber}g';

    if (protein < 0 || carbs < 0 || fat < 0 || fiber < 0) {
      List<String> invalidValues = [];
      if (protein < 0) invalidValues.add('Protein');
      if (fat < 0) invalidValues.add('Fat');
      if (carbs < 0) invalidValues.add('Carbs');
      if (fiber < 0) invalidValues.add('Fiber');

      //DO WE NEED calling setState()? setState(() {
        glText = "Failed to scan one/more nutrition values:\n$invalidValues.\nRescan the Nutrition Facts.";
        glTextColor = Colors.red;
        glVal = 00.0;
      //END });
      //FIX await FileImage(File(image.path)).evict();

    } else {
      glVal = ( (19.27 + 0.39*carbs -0.21*fat - 0.01*protein*protein - 0.01*fiber*fiber) * 10).truncateToDouble() / 10; // truncate to one decimal digit

      String status = '';
      switch (glVal) {
        case double val when val >=0.00 && val <=10.99:
          status = 'Low';
          glTextColor = Colors.green;
        case double val when val >=11.0 && val <=19.99:
          status = 'Medium';
          glTextColor = Colors.orange;
        case double val when val >=20.0:
          status = 'High';
          glTextColor = Colors.red;
       }

       glText = "${serving_info}\n${cals_info}\n${fat_info}, ${carbs_info}, ${fiber_info}, ${protein_info}\n${status} Glycemic Load ${glVal}";
       if (status == 'Medium') {
          glText = "$glText \nPair with fiber/protein food";
       }

       /***DO WE NEED THIS? setState(() {
          _isProcessing = false;
       END });***/
       //FIX await FileImage(File(image.path)).evict();
     }

    return (glText, glTextColor, glVal);
  }
}

// --- DATA STRUCTURES & ISOLATE LOGIC ---

class NutritionPipelineInput {
  final Uint8List originalBytes;
  final bool isAndroidPlatform;
  final List<math.Point<double>>? customCorners; 

  NutritionPipelineInput({
    required this.originalBytes, 
    required this.isAndroidPlatform,
    this.customCorners,
  });
}

class PlatformMemoryImageResult {
  final int width;
  final int height;
  final Uint8List platformBytes;
  final int? iosBytesPerRow; // 👈 Add this optional field

  PlatformMemoryImageResult({
    required this.width, 
    required this.height,
    required this.platformBytes, 
    this.iosBytesPerRow, // 👈 Include it in the constructor
  });
}

/// Runs entirely on a separate background thread core
Future<PlatformMemoryImageResult?> _runBackgroundEnhancements(NutritionPipelineInput input) async {
  img.Image? workingImage = img.decodeImage(input.originalBytes);
  if (workingImage == null) return null;

  // Optimizes the frame width to 1200 while scaling height automatically to keep aspect ratio
  if (workingImage.width > 1200) {
    workingImage = img.copyResize(workingImage, width: 1200);
  }

  //FIXME: Turn this into a function call?
  // STEP A+B: Grayscale + Sharpen passing through image pixels only once
  //final shsw = Stopwatch()..start();

  final int width = workingImage.width;
  final int height = workingImage.height;
  
  final sharpGrayImage = img.Image(
    width: width,
    height: height,
    numChannels: 1,
    format: img.Format.uint8,
  );
  
  for (int y = 1; y < height - 1; y++) {
    for (int x = 1; x < width - 1; x++) {
      // Fetch the raw color objects for center and neighbors
      final pCenter = workingImage.getPixel(x, y);
      final pTop    = workingImage.getPixel(x, y - 1);
      final pBottom = workingImage.getPixel(x, y + 1);
      final pLeft   = workingImage.getPixel(x - 1, y);
      final pRight  = workingImage.getPixel(x + 1, y);
  
      // Inline Grayscale Calculation using fast integer approximation:
      // (R * 77 + G * 150 + B * 29) >> 8 is a lightning-fast CPU shortcut for standard luminance
      // Force the sum to be treated as an integer so '>>' works perfectly
      final int center = (((pCenter.r as int) * 77) + ((pCenter.g as int) * 150) + ((pCenter.b as int) * 29)) >> 8;
      final int top    = (((pTop.r as int)    * 77) + ((pTop.g as int)    * 150) + ((pTop.b as int)    * 29)) >> 8;
      final int bottom = (((pBottom.r as int) * 77) + ((pBottom.g as int) * 150) + ((pBottom.b as int) * 29)) >> 8;
      final int left   = (((pLeft.r as int)   * 77) + ((pLeft.g as int)   * 150) + ((pLeft.b as int)   * 29)) >> 8;
      final int right  = (((pRight.r as int)  * 77) + ((pRight.g as int)  * 150) + ((pRight.b as int)  * 29)) >> 8;

  
      // Apply sharpening kernel math instantly
      int val = (center * 5) - top - bottom - left - right;
      
      // Clamp the values safely
      if (val < 0) val = 0;
      if (val > 255) val = 255;
  
      sharpGrayImage.setPixelRgb(x, y, val, val, val);
    }
  }

  workingImage = sharpGrayImage;

  // STEP C: Perspective Warp
  workingImage = _applyPerspectiveWarp(workingImage, input.customCorners);
  
  // STEP D: Cylindrical Flattening
  workingImage = _applyCylindricalFlattening(workingImage);

  // STEP E: Cross-Platform Conditional Allocation (100% in RAM)
  Uint8List finalBytes;
  if (input.isAndroidPlatform) {
    finalBytes = _convertToNV21InMemory(workingImage);
  } else {
    finalBytes = workingImage.toUint8List();
  }

  return PlatformMemoryImageResult(
    width: workingImage.width,
    height: workingImage.height,
    platformBytes: finalBytes,
    //BAD iosBytesPerRow: originalPlaneBytesPerRow, // 👈 Pass the native stride here
    iosBytesPerRow: workingImage.width * 4, 
  );
}

/// Converts a grayscale img.Image to NV21 bytes directly in RAM (Android Only)
Uint8List _convertToNV21InMemory(img.Image image) {
  final int w = image.width;
  final int h = image.height;
  final int ySize = w * h;
  final int uvSize = (w * h) ~/ 2;
  
  final Uint8List nv21 = Uint8List(ySize + uvSize);

  int yIndex = 0;
  for (final pixel in image) {
    nv21[yIndex++] = pixel.r.toInt();
  }

  // Neutral color values for grayscale chroma channel
  nv21.fillRange(ySize, ySize + uvSize, 128);

  return nv21;
}

/// Corrects vertical perspective skews
img.Image _applyPerspectiveWarp(img.Image inputImage, List<math.Point<double>>? corners) {
  final int targetW = inputImage.width;
  final int targetH = inputImage.height;
  
  // 1. Create a blank destination image matching your single-channel layout
  img.Image outputImage;

  // 2. Extract direct flat byte references to eliminate wrapper overhead
  final Uint8List srcBytes = inputImage.toUint8List();
  final Uint8List dstBytes = Uint8List(targetW * targetH);

  final srcTopLeft = (corners != null && corners.isNotEmpty) ? corners[0] : const math.Point(0.0, 0.0);
  final srcTopRight = (corners != null && corners.length > 1) ? corners[1] : math.Point(targetW.toDouble(), 0.0);
  final srcBottomRight = (corners != null && corners.length > 2) ? corners[2] : math.Point(targetW.toDouble(), targetH.toDouble());
  final srcBottomLeft = (corners != null && corners.length > 3) ? corners[3] : math.Point(0.0, targetH.toDouble());

  final double invTargetW = 1.0 / targetW;

  for (int y = 0; y < targetH; y++) {
    final double v = y / targetH;
    final double oneMinusV = 1.0 - v;

    final double leftX  = oneMinusV * srcTopLeft.x + v * srcBottomLeft.x;
    final double rightX = oneMinusV * srcTopRight.x + v * srcBottomRight.x;
    final double leftY  = oneMinusV * srcTopLeft.y + v * srcBottomLeft.y;
    final double rightY = oneMinusV * srcTopRight.y + v * srcBottomRight.y;

    final double deltaX = (rightX - leftX) * invTargetW;
    final double deltaY = (rightY - leftY) * invTargetW;

    double currentSrcX = leftX;
    double doubleSrcY = leftY;
    
    // Cache the exact output row offset to speed up index calculations
    final int destRowOffset = y * targetW;

    for (int x = 0; x < targetW; x++) {
      final int intX = currentSrcX.toInt();
      final int intY = doubleSrcY.toInt();

      if (intX >= 0 && intX < targetW && intY >= 0 && intY < targetH) {
        // Direct pointer-based memory lookup (No getPixel wrapper)
        final int srcIndex = (intY * targetW) + intX;
        
        // Write byte directly to the exact destination array index
        dstBytes[destRowOffset + x] = srcBytes[srcIndex];
      }
      // If out of bounds, dstBytes defaults to 0 (neutral black background)

      currentSrcX += deltaX;
      doubleSrcY += deltaY;
    }
  }

  // 3. Re-inject the optimized flat array back into the output object wrapper
  outputImage = img.Image.fromBytes(
    width: targetW,
    height: targetH,
    bytes: dstBytes.buffer,
    numChannels: 1, // Single channel for grayscale/sharpened layout
    format: img.Format.uint8,
  );
  return outputImage;
}

/// Unrolls cylindrical packaging distortion horizontally
img.Image _applyCylindricalFlattening(img.Image inputImage) {

final int width = inputImage.width;
final int height = inputImage.height;
final flattenedImage = img.Image.from(inputImage);

// 1. Precompute the Horizontal Sin Map (The Lookup Table)
// This runs only 'width' times instead of 'width * height' times!
final List<int> xLookupTable = List<int>.filled(width, 0);
final double halfWidth = width / 2.0;

// Adjust this radius value to match your current algorithm's cylinder scale
final double cylinderRadius = width * 1.5; 

for (int x = 0; x < width; x++) {
  // Translate coordinate relative to center axis
  double dx = x - halfWidth;
  
  // Calculate the cylindrical warp factor once per column
  double theta = dx / cylinderRadius;
  double warpedX = halfWidth + (cylinderRadius * math.sin(theta));
  
  // Clamp and store the source coordinate as an integer lookup
  xLookupTable[x] = warpedX.round().clamp(0, width - 1);
}

// 2. Run the Main Processing Loop (Zero Trigonometry Inside!)
for (int y = 0; y < height; y++) {
  for (int x = 0; x < width; x++) {
    // Instant array lookup replacing the heavy math loop
    final int sourceX = xLookupTable[x];
    
    // Direct, fast pixel assignments
    final img.Color sourcePixel = inputImage.getPixel(sourceX, y);
    flattenedImage.setPixel(x, y, sourcePixel);
  }
}

return flattenedImage;
}

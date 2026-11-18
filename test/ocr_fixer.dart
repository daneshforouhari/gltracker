import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    print("Expected one argument, got ${args.length}");
    exit(1);
  }
  final file = File(args[0]);

  if (await file.exists()) {
    List<String> lines = await file.readAsLines();
    for (var lowerText in lines) {
      if (lowerText.length != 0  && lowerText[0] != '#' && lowerText[0] == 'X') {
        print('lowerText: ${lowerText}\n');

        //correcting OCR mistakes
        //final sizeRegex =  RegExp(r'\b[s5z2][i1l|!][zr2s5][e3c]\b');
        final sizeRegex =  RegExp(r'\b[s5z2][i1l|!]*[zr2s5][e3c]\b');
        final fatRegex = RegExp(r'\b[fep][a4o]t\b');

        const String standardTotal = r'[t1ilrf][o0aqc][t1ilrf][aoeik][l1it]';
    
        //matches the specific 4-letter compressed "ptal" variant safely
        const String compressedPtal = r'(?!pr[ou])p[t1ilrf][aoeik][l1it]';

        //combine them with an OR (|) group
        final totalRegex = RegExp(
          r'\b(?!pr)(?:' + standardTotal + '|' + compressedPtal + r')\b',
          caseSensitive: false,
        );

        final servingRegex = RegExp(r'\b(seving|sserving|erving)');
        final caloriesRegex = RegExp(r'\b[ceog\(]?a[l1i|][o0ce](?:ri|n|m)[e3c]s?\b');
    
        final dietaryRegex = RegExp(r'\b[dcl0o][l1i|][e3c][t7f][a@o][r][yv]\b');
        final fiberRegex = RegExp(r' [fep][i1l|t]?[bh6nvp][eco0][rni1]');
        final dietaryFiberRegex = RegExp(dietaryRegex.pattern + fiberRegex.pattern);

        final carbRegex = RegExp(r'[cl0dog][a0o4e][rni1][bh6n]');

        final gramRegex1 = RegExp(r'(cg|dg|og|ug)\b');
        final gramRegex2 = RegExp(r'(lg|ig)\b');
        final gramRegex3 = RegExp(r'(&g|tg|&o)\b');
        final gramRegex4 = RegExp(r'(bg|sg)\b');

        lowerText = lowerText
                    .replaceFirst(sizeRegex, 'size')
                    .replaceAll(RegExp(r'\(|\)|%|,|\[|\]|{|}'), ' ')
                    .replaceAll(RegExp(r'\s{2,}'), ' ')
                    .replaceAll(servingRegex, 'serving')
                    .replaceAll(caloriesRegex, 'calories')
                    .replaceAll('thsp', 'tbsp')
                    .replaceAll('omg', '0mg')
                    .replaceAll('oml', '0ml')
                    .replaceAll('gg', '9g')
                    .replaceAll(gramRegex1, '0g')
                    .replaceAll(gramRegex2, '1g')
                    .replaceAll(gramRegex3, '8g')
                    .replaceAll(gramRegex4, '6g')
                    .replaceAll(totalRegex, 'total')
                    .replaceAll(fatRegex, 'fat')
                    .replaceFirst(carbRegex, 'carb')
                    .replaceFirst(dietaryFiberRegex, 'dietaryfiber')
                    ;

        print("\nZZZZ${lowerText.substring(4, lowerText.length-4)}ZZZZ");

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
        pat = RegExp(r'serv(.*) size');
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
          print("@@@@@@@@@@splitted[0]=X${splitted[0]}X");
          print("@@@@@@@@@@splitted[1]=X${splitted[1]}X");
          print("@@@@@@@@@@splitted[2]=X${splitted[2]}X");
          print("@@@@@@@@@@splitted[3]=X${splitted[3]}X");
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
        //process calories
        //patterns to match: calories, calones, calorles, oalories, 0alories, cal0ries, caloies
        pat = RegExp(r'\b[co0]al.{2,4}es?\b');
        match = pat.firstMatch(lowerText);
        if (match != null) {
          String rest = lowerText.substring(match.end);
          String first_word = rest.split(delimiters)[1];
          cals = getAmount(first_word, false); //no trailing g
          //print("XXXXXrest=Y${rest}Y first_word=Z${first_word}Z");
        }
        cals_info = 'Calories ${cals}';
    
        //process carbs
        pat = RegExp(r'total carb(\.|[a-z]*)|carbohidratos totales');
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
        pat = RegExp(r'[fp1r][rni1][o0aqu][t1ilfh][eco0][i1l|t][nmht]');
        match = pat.firstMatch(lowerText);
        if (match != null) {
          String rest = lowerText.substring(match.end);
    
          String first_word = rest.split(delimiters)[1]; //should be a number followed by 'g'
          //firstword must start with a number &  trailed by 'g', or junk char(s) due to OCR
          protein = getAmount(first_word);
        }
        protein_info = 'Protein ${protein}g';
    
        //process fiber
        pat = RegExp(r'dietaryfiber');
        match = pat.firstMatch(lowerText);
        //if (match != null || ('fiber'.allMatches(lowerText)).length == 1) {
        if (match != null) {
          String rest = lowerText.substring(match.end);
    
          String first_word = rest.split(delimiters)[1]; //should be a number followed by 'g'
          //firstword must start with a number. The number could be trailed by 'g', or junk char(s) due to OCR
          fiber = getAmount(first_word);
        } else {
          int index = lowerText.indexOf('fiber');
          if (index != -1 && ('fiber'.allMatches(lowerText)).length == 1 ) {
            String rest = lowerText.substring(index+'fiber'.length);
    
            String first_word = rest.split(delimiters)[1]; //should be a number followed by 'g'
            //firstword must start with a number. The number could be trailed by 'g', or junk char(s) due to OCR
            fiber = getAmount(first_word);
          }
        }
        fiber_info = 'Fiber ${fiber}g';

        print("\n${serving_info}\n${cals_info}\n${fat_info}, ${carbs_info}, ${fiber_info}, ${protein_info}\n");

      }
    }
  }
}

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

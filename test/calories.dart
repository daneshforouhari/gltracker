num getAmount(String first_word, [bool trailing_g = true ] ) {
  /* If the amount of nutrient is less than 1, the label could have some text like this:
   *   Total Carb. less than 1g.
   * Check for (mis)spellings for 'less', and if found, return 1.
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

void main() {
    RegExp delimiters = RegExp(r' ');
    RegExp pat =  RegExp(r'$^'); //no match
    RegExpMatch? match = null;
    num cals = -1;
    String cals_info = "";

    pat = RegExp(r'\b[co0]al.{2,4}es?\b');
    String textLine = 'Calories    150';
    String lowerText = textLine.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
    match = pat.firstMatch(lowerText);
    if (match != null) {
      String rest = lowerText.substring(match.end);
      print("rest=X${rest}X");
      String first_word = rest.split(delimiters)[1];
      print("first_word=X${first_word}X");
      cals = getAmount(first_word, false);
    }
    else {
      print("match failed");
    }
    cals_info = 'Calories ${cals}';
    print("cals_info=X${cals_info}X");
}

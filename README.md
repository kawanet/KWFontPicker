KWFontPicker
============

FKWFontPicker is a font picker control using UIPickerView.

    KWFontPicker *fontPicker = [[KWFontPicker alloc] init];
    [fontPicker setChangeHandler:^{
        NSLog(@"fontName=%@ pointSize=%.1f", fontPicker.font.fontName, fontPicker.font.pointSize);
    }];
    [self.view addSubview:fontPicker];

The following KWTextEditor would help to use the picker in most cases.

<img src="https://raw.github.com/kawanet/KWFontPicker/master/images/sample-fontpicker.jpg" width="320">&nbsp;<img src="https://raw.github.com/kawanet/KWFontPicker/master/images/sample-keyboard.jpg" width="320">

KWTextEditor
============

KWTextEditor provides a toolbar which has [Keyboard], [Font] and [Close] buttons upon KWFontPicker or iOS's software keybaord.

### BASIC USAGE

    KWTextEditor* textEditor = [[KWTextEditor alloc] initWithTextView:textView];
    [textEditor setScrollView:self.scrollView];
    [textEditor showInView:self.view];

### FONT LIST

Available font names are shown on the left side of KWFontPicker.
All fonts in iOS are listed per default.
You could specify names with NSArray:

    textEditor.fontPicker.fontList = @[ @"AmericanTypewriter", @"Baskerville",
        @"Copperplate", @"Didot", @"EuphemiaUCAS", @"Futura-Medium", @"GillSans",
        @"Helvetica", @"Marion-Regular", @"Optima-Regular", @"Palatino-Roman",
        @"TimesNewRomanPSMT", @"Verdana"];

### FONT SIZE

Available font sizes are shown on the center of KWFontPicker.
You could specify sizes by range:

    textEditor.fontPicker.minFontSize   = 10;
    textEditor.fontPicker.maxFontSize   = 30;
    textEditor.fontPicker.stepFontSize  =  4;

or by NSArray:

    textEditor.fontPicker.sizeList = @[ @9.5, @13.5, @17.5, @21.5, @25.5 ];

### FONT COLOR

Available font colors are shown on the right side of KWFontPicker.
125 colors, which means 5 levels each for RGB, are listed per default.
You could specify sizes by range:

    textEditor.fontPicker.colorVariants = KWFontPickerColorVariantsNone; // no colors. use grayscales
    textEditor.fontPicker.colorVariants = KWFontPickerColorVariants222; // 8 colors
    textEditor.fontPicker.colorVariants = KWFontPickerColorVariants333; // 27 colors
    textEditor.fontPicker.colorVariants = KWFontPickerColorVariants444; // 64 colors
    textEditor.fontPicker.colorVariants = KWFontPickerColorVariants555; // 125 colors = default
    textEditor.fontPicker.colorVariants = KWFontPickerColorVariants666; // 216 colors = web safe color

    textEditor.fontPicker.grayVariants = 2; // black and white
    textEditor.fontPicker.grayVariants = 16; // 16 gradients of grayscale

or by NSArray:

    textEditor.fontPicker.colorList = @[
        [UIColor blackColor], [UIColor grayColor],   [UIColor whiteColor],
        [UIColor redColor],   [UIColor yellowColor], [UIColor greenColor],
        [UIColor cyanColor],  [UIColor blueColor],   [UIColor purpleColor]];

### CALLBACK HANDLERS    

Following handler blocks are available.

    [textEditor setTextDidChangeHandler:^{
        NSLog(@"TextDidChangeHandler: text=%@", textView.text);
    }];
    [textEditor setFontDidChangeHandler:^{
        NSLog(@"fontDidChangeHandler: fontName=%@ pointSize=%.1f", textView.font.fontName, textView.font.pointSize);
    }];
    [textEditor setEditorDidShowHandler:^{
        NSString *mode = @"";
        if (textEditor.editorMode == KWTextEditorModeKeyboard) mode = @"keyboard";
        if (textEditor.editorMode == KWTextEditorModeFontPicker) mode = @"font picker";
        NSLog(@"editorDidShowHandler: %@", mode);
    }];
    [textEditor setEditorDidHideHandler:^{
        NSLog(@"editorDidHideHandler");
    }];
    [textEditor setCloseButtonDidTapHandler:^{
        NSLog(@"closeButtonDidTapHandler");
    }];
    
### BUTTON LABELS

    textEditor.keyboardButton.title = @"TEXT";
    textEditor.fontButton.title = @"FONT";
    textEditor.closeButton.title = @"DONE";

AUTHOR 
------

    Yusuke Kawasaki http://www.kawa.net/

COPYRIGHT 
---------
The following copyright notice applies to all the files provided in this distribution, including binary files, unless explicitly noted otherwise.

    Copyright 2012-2013 Yusuke Kawasaki

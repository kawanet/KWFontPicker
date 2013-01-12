//
//  DEMOViewController.m
//  KWFontPicker
//
//  Created by Yusuke Kawasaki on 2013/01/09.
//  Copyright (c) 2013 kawanet. All rights reserved.
//

#import "DEMOViewController.h"
#import "KWTextEditor.h"

@interface DEMOViewController ()
@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@property (weak, nonatomic) IBOutlet UITextView *textView1;
@property (weak, nonatomic) IBOutlet UITextView *textView2;
@property (weak, nonatomic) IBOutlet UITextView *textView3;
@property (weak, nonatomic) IBOutlet UITextView *textView4;

@end

@implementation DEMOViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    [self registEditor1WithTextView:self.textView1];
    [self registEditor2WithTextView:self.textView2];
    [self registEditor3WithTextView:self.textView3];
    [self registEditor4WithTextView:self.textView4];
}

- (void)registEditor1WithTextView:(UITextView*)textView
{
    KWTextEditor* textEditor = [[KWTextEditor alloc] initWithTextView:textView];
    [textEditor setScrollView:self.scrollView];
    [textEditor showInView:self.view];
}

- (void)registEditor2WithTextView:(UITextView*)textView
{
    KWTextEditor* textEditor = [[KWTextEditor alloc] initWithTextView:textView];
    
    // font names by NSArray. Find font names at http://iosfonts.com
    textEditor.fontPicker.fontList = @[ @"AmericanTypewriter", @"Baskerville",
    @"Copperplate", @"Didot", @"EuphemiaUCAS", @"Futura-Medium", @"GillSans",
    @"Helvetica", @"Marion-Regular", @"Optima-Regular", @"Palatino-Roman",
    @"TimesNewRomanPSMT", @"Verdana"];
    
    // font sizes by NSArray
    textEditor.fontPicker.sizeList = @[ @9.5, @13.5, @17.5, @21.5, @25.5 ];
    
    // font colors by NSArray
    textEditor.fontPicker.colorList = @[
    [UIColor blackColor], [UIColor grayColor],   [UIColor whiteColor],
    [UIColor redColor],   [UIColor yellowColor], [UIColor greenColor],
    [UIColor cyanColor],  [UIColor blueColor],   [UIColor purpleColor]];
    
    [textEditor setScrollView:self.scrollView];
    [textEditor showInView:self.view];
}

- (void)registEditor3WithTextView:(UITextView*)textView
{
    KWTextEditor* textEditor = [[KWTextEditor alloc] initWithTextView:textView];
    
    // font sizes by range
    textEditor.fontPicker.minFontSize   = 10;
    textEditor.fontPicker.maxFontSize   = 30;
    textEditor.fontPicker.stepFontSize  =  4;
    
    // font colors by number of variants
    textEditor.fontPicker.colorVariants = KWFontPickerColorVariants333;
    textEditor.fontPicker.grayVariants  =  4;
    
    [textEditor setScrollView:self.scrollView];
    [textEditor showInView:self.view];
}

- (void)registEditor4WithTextView:(UITextView*)textView
{
    KWTextEditor* textEditor = [[KWTextEditor alloc] initWithTextView:textView];
    
    // callback handlers
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
    
    // customize button labels
    textEditor.keyboardButton.title = @"TEXT";
    textEditor.fontButton.title = @"FONT";
    textEditor.closeButton.title = @"DONE";
    
    [textEditor setScrollView:self.scrollView];
    [textEditor showInView:self.view];
}

@end

//
//  KWFontPicker.m
//  TextTest
//
//  Created by Yusuke Kawasaki on 2013/01/02.
//  Copyright (c) 2013 Yusuke Kawasaki. All rights reserved.
//

#import "KWFontPicker.h"

typedef void(^KWFontPickerHandler)(void);

@interface KWFontPicker () <UIPickerViewDataSource, UIPickerViewDelegate>
@property NSInteger fontComponentIndex;
@property NSInteger sizeComponentIndex;
@property NSInteger colorComponentIndex;
@property (copy) KWFontPickerHandler changeHandler;
@end

static BOOL KWFontPickerStyleIOS7 = NO;

@implementation KWFontPicker {
    NSString *_fontName;
    CGFloat _fontSize;
    UIColor *_color;
}

static KWFontPickerColorVariants KWFontPickerColorVariantsDefault = KWFontPickerColorVariants555;
static NSInteger KWFontPickerGrayVariantsDefault = 5;
static CGFloat KWFontPickerMinFontSizeDefault = 8;
static CGFloat KWFontPickerMaxFontSizeDefault = 72;
static CGFloat KWFontPickerStepFontSizeDefault = 2;
static CGFloat KWFontPickerCellWitdh = 66;
static CGFloat KWFontPickerCellHeight = 30;

- (id)init
{
    self = [super init];
    if (self) {
        self.fontComponentIndex  = 0;
        self.sizeComponentIndex  = 1;
        self.colorComponentIndex = 2;
        
        self.showsSelectionIndicator = YES;
        self.dataSource = self;
        self.delegate = self;
        
        // iOS7 Style
        KWFontPickerStyleIOS7 = ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7);

        if (KWFontPickerStyleIOS7) {
            self.backgroundColor = [UIColor colorWithWhite:0.98 alpha:0.98];
        }
    }
    return self;
}

// getter
- (UIFont*)font
{
    return [UIFont fontWithName:_fontName size:_fontSize];
}

// setter
- (void)setFont:(UIFont *)font
{
    [self selectFontName:font.fontName animated:NO];
    [self selectFontSize:font.pointSize animated:NO];
}

// getter
- (UIColor*)color
{
    return _color;
}

// setter
- (void)setColor:(UIColor *)color
{
    [self selectColor:color animated:NO];
}

- (void)selectFontName:(NSString*)fontName animated:(BOOL)animated
{
    _fontName = fontName;
    NSInteger row = [self indexForFontName:fontName];
    if (row == NSNotFound) return;
    [self selectRow:row inComponent:self.fontComponentIndex animated:animated];
}
- (void)selectFontSize:(CGFloat)fontSize animated:(BOOL)animated
{
    _fontSize = fontSize;
    NSInteger row = [self indexForNearestFontSize:fontSize];
    if (row == NSNotFound) return;
    [self selectRow:row inComponent:self.sizeComponentIndex animated:animated];
}
- (void)selectColor:(UIColor*)color animated:(BOOL)animated
{
    _color = color;
    NSInteger row = [self indexForNearestColor:color];
    if (row == NSNotFound) return;
    [self selectRow:row inComponent:self.colorComponentIndex animated:animated];
}

- (NSInteger)indexForFontName:(NSString*)fontName
{
    for (int i=0; i<self.fontList.count; i++) {
        NSString *testName = self.fontList[i];
        if ([fontName isEqualToString:testName]) {
            return i;
        }
    }
    if ([fontName hasPrefix:@"."]) {
        fontName = [fontName substringFromIndex:1];
        return [self indexForFontName:fontName];
    }
    return NSNotFound;
}

- (NSInteger)indexForFontSize:(CGFloat)pointSize
{
    for (int i=0; i<self.sizeList.count; i++) {
        NSNumber *fontNumber = self.sizeList[i];
        CGFloat fontSize = fontNumber.floatValue;
        if (fontSize == pointSize) {
            return  i;
        }
    }
    return NSNotFound;
}

- (NSInteger)indexForNearestFontSize:(CGFloat)pointSize
{
    CGFloat distance = MAXFLOAT;
    NSInteger index = NSNotFound;
    for (int i=0; i<self.sizeList.count; i++) {
        NSNumber *fontNumber = self.sizeList[i];
        CGFloat fontSize = fontNumber.floatValue;
        if (fontSize == pointSize) {
            return  i;
        }
        CGFloat testDist = ABS(fontSize-pointSize);
        if (testDist < distance) {
            distance = testDist;
            index = i;
        }
    }
    return index;
}

- (NSInteger)indexForColor:(UIColor*)color
{
    if (! color) return NSNotFound;
    CGFloat r1, g1, b1, a1;
    [color getRed:&r1 green:&g1 blue:&b1 alpha:&a1];
    r1 = round(r1*255);
    g1 = round(g1*255);
    b1 = round(b1*255);
    
    for (int i=0; i<self.colorList.count; i++) {
        UIColor *testColor = self.colorList[i];
        if (! testColor) return NSNotFound;
        CGFloat r2, g2, b2, a2;
        [testColor getRed:&r2 green:&g2 blue:&b2 alpha:&a2];
        r2 = round(r2*255);
        g2 = round(g2*255);
        b2 = round(b2*255);
        
        // test RGB color code as 0-255 integer number but not float number
        if (r1 == r2 && g1 == g2 && b1 == b2) {
            return i;
        }
    }
    return NSNotFound;
}

- (NSInteger)indexForNearestColor:(UIColor*)color
{
    if (! color) return NSNotFound;
    CGFloat r1, g1, b1, a1;
    [color getRed:&r1 green:&g1 blue:&b1 alpha:&a1];
    r1 = round(r1*255);
    g1 = round(g1*255);
    b1 = round(b1*255);
    
    CGFloat distance = MAXFLOAT;
    NSInteger index = NSNotFound;
    for (int i=0; i<self.colorList.count; i++) {
        UIColor *testColor = self.colorList[i];
        if (! testColor) return NSNotFound;
        CGFloat r2, g2, b2, a2;
        [testColor getRed:&r2 green:&g2 blue:&b2 alpha:&a2];
        r2 = round(r2*255);
        g2 = round(g2*255);
        b2 = round(b2*255);
        
        // test RGB color code as 0-255 integer number but not float number
        if (r1 == r2 && g1 == g2 && b1 == b2) {
            return i;
        }
        
        CGFloat testDist = (r1-r2)*(r1-r2) + (g1-g2)*(g1-g2) + (b1-b2)*(b1-b2);
        if (testDist < distance) {
            distance = testDist;
            index = i;
        }
    }
    return index;
}

// getter (lazy initializer)
- (NSArray*)fontList
{
    if (_fontList.count) {
        return _fontList;
    }
    
    // list all font names in system
    NSArray *fonts = [[NSMutableArray alloc] init];
    NSArray *families = [UIFont familyNames];
    for (NSString *familyName in families) {
        NSArray *names = [UIFont fontNamesForFamilyName:familyName];
        fonts = [fonts arrayByAddingObjectsFromArray:names];
    }
    
    // add current font name when not found in list
    if (_fontName) {
        _fontList = fonts;
        NSInteger index = [self indexForFontName:_fontName];
        if (index == NSNotFound) {
            NSArray *temp = @[ _fontName ];
            fonts = [temp arrayByAddingObjectsFromArray:fonts];
        }
    }
    
    // sort by font name
    fonts = [fonts sortedArrayUsingComparator:^NSComparisonResult(NSString *str1, NSString *str2) {
        return [str1 localizedCaseInsensitiveCompare:str2];
    }];
    
    _fontList = fonts;
    return _fontList;
}

// getter (lazy initializer)
- (NSArray*)sizeList
{
    if (_sizeList.count) {
        return _sizeList;
    }
    
    if (!(self.minFontSize > 0)) {
        self.minFontSize = KWFontPickerMinFontSizeDefault;
    }
    if (!(self.maxFontSize > 0)) {
        self.maxFontSize = KWFontPickerMaxFontSizeDefault;
    }
    if (!(self.stepFontSize > 0)) {
        self.StepFontSize = KWFontPickerStepFontSizeDefault;
    }
    
    NSMutableArray *sizes = [[NSMutableArray alloc] init];
    for (CGFloat fsize=self.minFontSize; fsize<=self.maxFontSize; fsize+=self.stepFontSize) {
        NSNumber *nsize = [NSNumber numberWithFloat:fsize];
        [sizes addObject:nsize];
    }
    
    // add current font size when not found in list
    if (_fontSize) {
        _sizeList = sizes;
        NSInteger index = [self indexForFontSize:_fontSize];
        if (index == NSNotFound) {
            NSNumber *nsize = [NSNumber numberWithFloat:_fontSize];
            [sizes addObject:nsize];
            
            // sort by font name
            NSArray *temp = [sizes sortedArrayUsingComparator:^NSComparisonResult(NSNumber *size1, NSNumber *size2) {
                return [size1 compare:size2];
            }];
            sizes = [NSMutableArray arrayWithArray:temp];
        }
    }
    
    _sizeList = [NSArray arrayWithArray:sizes];
    return _sizeList;
}

// getter (lazy initializer)
- (NSArray*)colorList
{
    if (_colorList.count) {
        return _colorList;
    }
    NSMutableArray *colors = [[NSMutableArray alloc] init];
    
    // default variants
    if (!(self.colorVariants < 0)) {
        self.colorVariants = KWFontPickerColorVariantsDefault;
    }
    if (!(self.grayVariants < 0)) {
        self.grayVariants = KWFontPickerGrayVariantsDefault;
    }
    
    // add color variants
    if (self.colorVariants > 0) {
        int ilevel = (int)ceil(pow((double)self.colorVariants, 1.0/3.0));
        CGFloat flevel = (float)ilevel - 1;
        for (int r=0; r<ilevel; r++) {
            for (int g=0; g<ilevel; g++) {
                for (int b=ilevel-1; b>=0; b--) {
                    if (colors.count >= self.colorVariants) break;
                    if (self.grayVariants > 0 && r==g && g==b) continue;
                    UIColor *color = [UIColor colorWithRed:r/flevel green:g/flevel blue:b/flevel alpha:1.0];
                    [colors addObject:color];
                }
            }
        }
    }
    
    // add grayscale variants
    if (self.grayVariants > 0) {
        int ilevel = self.grayVariants;
        CGFloat flevel = (float)ilevel - 1;
        for (int w=0; w<ilevel; w++) {
            UIColor *color = [UIColor colorWithRed:w/flevel green:w/flevel blue:w/flevel alpha:1.0];
            [colors addObject:color];
        }
    }
    
    // add current color when not found in list
    if (_color) {
        _colorList = colors;
        NSInteger index = [self indexForColor:_color];
        if (index == NSNotFound) {
            NSArray *temp = @[ _color ];
            temp = [temp arrayByAddingObjectsFromArray:colors];
            colors = [NSMutableArray arrayWithArray:temp];
        }
    }
    
    // sort by H/B/S
    NSArray *sorted = [colors sortedArrayUsingComparator:^NSComparisonResult(UIColor *col1, UIColor *col2) {
        CGFloat h1, s1, b1, a1;
        [col1 getHue:&h1 saturation:&s1 brightness:&b1 alpha:&a1];
        
        CGFloat h2, s2, b2, a2;
        [col2 getHue:&h2 saturation:&s2 brightness:&b2 alpha:&a2];
        
        if (h1 > h2) {
            return NSOrderedAscending;
        } else if (h1 < h2) {
            return NSOrderedDescending;
        }
        if (b1 > b2) {
            return NSOrderedAscending;
        } else if (b1 < b2) {
            return NSOrderedDescending;
        }
        if (s1 > s2) {
            return NSOrderedAscending;
        } else if (s1 < s2) {
            return NSOrderedDescending;
        }
        return NSOrderedSame;
    }];
    
    _colorList = sorted;
    return _colorList;
}

// returns the number of 'columns' to display.
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 3;
}

// returns the # of rows in each component..
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    if (component == self.fontComponentIndex) {
        return self.fontList.count;
    } else if (component == self.sizeComponentIndex) {
        return self.sizeList.count;
    } else if (component == self.colorComponentIndex) {
        return self.colorList.count;
    }
    return -1; // something wrong
}

// returns width of column and height of row for each component.
- (CGFloat)pickerView:(UIPickerView *)pickerView widthForComponent:(NSInteger)component
{
    if (component == self.fontComponentIndex) {
        CGFloat width = self.frame.size.width - 30;
        width = width - KWFontPickerCellWitdh * 2;
        width = MAX(width, KWFontPickerCellWitdh);
        return width;
    } else if (component == self.sizeComponentIndex) {
        return KWFontPickerCellWitdh;
    } else if (component == self.colorComponentIndex) {
        return KWFontPickerCellWitdh;
    }
    return NAN; // something wrong
}

- (CGFloat)pickerView:(UIPickerView *)pickerView rowHeightForComponent:(NSInteger)component
{
    return KWFontPickerCellHeight;
}

- (UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view;
{
    NSString *string;
    CGFloat size = 18;
    UIFont *font = [UIFont systemFontOfSize:size];
    UILabel* label = [[UILabel alloc] init];
    label.backgroundColor = [UIColor clearColor];
    CGFloat width = KWFontPickerCellWitdh;
    
    if (component == self.fontComponentIndex) {
        if (self.fontList.count <= row) return nil;
        NSString *fontName = self.fontList[row];
        if ([fontName hasPrefix:@"Zapfino"]) size *= 0.667;
        font = [UIFont fontWithName:fontName size:size];
        string = self.text.length ? self.text : fontName;
        
        label.font = font;
        
        width = self.frame.size.width - 30;
        width = width - KWFontPickerCellWitdh * 2;
        width = MAX(width, KWFontPickerCellWitdh);
        
    } else if (component == self.sizeComponentIndex) {
        if (self.sizeList.count <= row) return nil;
        NSNumber *fontNumber = self.sizeList[row];
        CGFloat fontSize = fontNumber.floatValue;
        if (fontSize == floor(fontSize)) {
            string = [NSString stringWithFormat:@"%2.0f", fontSize];
        } else {
            string = [NSString stringWithFormat:@"%.1f", fontSize];
        }
        label.textAlignment = NSTextAlignmentCenter;
        
    } else if (component == self.colorComponentIndex) {
        if (self.colorList.count <= row) return nil;
        font = [UIFont systemFontOfSize:24];
        string = @"\u2588\u2588"; // FULL BLOCK x2
        label.textAlignment = NSTextAlignmentCenter;
        if (KWFontPickerStyleIOS7) {
            label.backgroundColor = self.colorList[row];
        }
        label.textColor = self.colorList[row];
    }
    label.text = string;
    label.frame = CGRectMake(0, 0, width - 20, KWFontPickerCellHeight-10);
    
    return label;
}
- (NSString*)selectedFontName
{
    NSString *fontName;
    if (self.fontComponentIndex > -1) {
        NSInteger fontIndex = [self selectedRowInComponent:self.fontComponentIndex];
        if (fontIndex > -1) {
            fontName = self.fontList[fontIndex];
        }
    }
    return fontName;
}

- (CGFloat)selectedFontSize
{
    CGFloat fontSize = self.minFontSize;
    
    if (self.sizeComponentIndex > -1) {
        NSInteger sizeIndex = [self selectedRowInComponent:self.sizeComponentIndex];
        if (sizeIndex > -1) {
            NSNumber *sizeNumber = self.sizeList[sizeIndex];
            fontSize = sizeNumber.floatValue;
        }
    }
    
    return fontSize;
}

- (UIColor*)selectedColor
{
    NSInteger colorIndex;
    UIColor *color;
    if (self.colorComponentIndex > -1) {
        colorIndex = [self selectedRowInComponent:self.colorComponentIndex];
        if (colorIndex > -1) {
            color = self.colorList[colorIndex];
        }
    }
    return color;
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    // cache current font and color selected
    if (component == self.fontComponentIndex) {
        _fontName = [self selectedFontName];
    } else if (component == self.sizeComponentIndex) {
        _fontSize = [self selectedFontSize];
    } else if (component == self.colorComponentIndex) {
        _color = [self selectedColor];
    }
    
    // callback handler
    if (self.changeHandler) {
        self.changeHandler();
    }
}

@end

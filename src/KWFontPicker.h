//
//  KWFontPicker.h
//  TextTest
//
//  Created by Yusuke Kawasaki on 2013/01/02.
//  Copyright (c) 2013 Yusuke Kawasaki. All rights reserved.
//

#import <UIKit/UIKit.h>

@class KWFontPicker;

typedef NS_ENUM(NSInteger, KWFontPickerColorVariants) {
    KWFontPickerColorVariantsNone = 0,
    KWFontPickerColorVariants222 = 8,
    KWFontPickerColorVariants333 = 27,
    KWFontPickerColorVariants444 = 64,
    KWFontPickerColorVariants555 = 125, // default
    KWFontPickerColorVariants666 = 216, // web safe color
};

@interface KWFontPicker : UIPickerView

@property (nonatomic) NSArray *fontList;
@property (nonatomic) NSArray *sizeList;
@property (nonatomic) NSArray *colorList;

@property NSString *text;

@property CGFloat minFontSize;
@property CGFloat maxFontSize;
@property CGFloat stepFontSize;

@property KWFontPickerColorVariants colorVariants;
@property NSInteger grayVariants;

- (void)setChangeHandler:(void(^)(void))changeHandler;

- (UIFont*)font;
- (UIColor*)color;

- (void)setFont:(UIFont *)font;
- (void)setColor:(UIColor *)color;

- (void)selectFontName:(NSString*)fontName animated:(BOOL)animated;
- (void)selectFontSize:(CGFloat)fontSize animated:(BOOL)animated;
- (void)selectColor:(UIColor*)color animated:(BOOL)animated;

- (NSString*)selectedFontName;
- (CGFloat)selectedFontSize;
- (UIColor*)selectedColor;

@end

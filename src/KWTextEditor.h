//
//  KWTextEditor.h
//  TextTest
//
//  Created by Yusuke Kawasaki on 2013/01/02.
//  Copyright (c) 2013 Yusuke Kawasaki. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "KWFontPicker.h"

@class KWTextEditor;

typedef NS_ENUM(NSInteger, KWTextEditorMode) {
    KWTextEditorModeNone = 0,
    KWTextEditorModeKeyboard,
    KWTextEditorModeFontPicker,
};

@interface KWTextEditor : UIView

@property (weak, readonly) UITextView *textView;
@property (weak) UIScrollView *scrollView;
@property (readonly) KWFontPicker *fontPicker;
@property (readonly) UIToolbar *toolbar;
@property (readonly) UIBarButtonItem *keyboardButton;
@property (readonly) UIBarButtonItem *fontButton;
@property (readonly) UIBarButtonItem *closeButton;

-(KWTextEditor*)initWithTextView:(UITextView*)textView;
-(void)showInView:(UIView*)view;
-(void)dismiss;

-(KWTextEditorMode)editorMode;
-(void)setEditorMode:(KWTextEditorMode)editorMode;

-(void)setEditorDidShowHandler:(void(^)(void))handler;
-(void)setEditorDidHideHandler:(void(^)(void))handler;

-(void)setTextDidChangeHandler:(void(^)(void))handler;
-(void)setFontDidChangeHandler:(void(^)(void))handler;

-(void)setCloseButtonDidTapHandler:(void(^)(void))handler;

// experimental
-(void)setFontPickerEnabled:(BOOL)enabled;
-(void)setKeyboardEnabled:(BOOL)enabled;

@end

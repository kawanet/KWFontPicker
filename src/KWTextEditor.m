//
//  KWTextEditor.m
//  TextTest
//
//  Created by Yusuke Kawasaki on 2013/01/02.
//  Copyright (c) 2013 Yusuke Kawasaki. All rights reserved.
//

#import "KWTextEditor.h"

typedef void(^KWTextEditorHandler)(void);

@interface KWTextEditor () <UITextViewDelegate>

@property CGPoint savedContentOffset;
@property UIEdgeInsets savedScrollInsets;
@property UIEdgeInsets savedContentInsets;
@property UIEdgeInsets ourScrollInsets;
@property UIEdgeInsets ourContentInsets;
@property BOOL hasSavedInsets;
@property BOOL isOpening;
@property BOOL isClosing;

@property (copy) KWTextEditorHandler editorDidShowHandler;
@property (copy) KWTextEditorHandler editorDidHideHandler;

@property (copy) KWTextEditorHandler textDidChangeHandler;
@property (copy) KWTextEditorHandler fontDidChangeHandler;

@property (copy) KWTextEditorHandler closeButtonDidTapHandler;

@property (nonatomic) KWTextEditorMode editorMode;
@property (nonatomic) KWTextEditorMode tapEditorMode;
@property (nonatomic) KWTextEditorMode nextEditorMode;
@property (nonatomic) BOOL keyboardEnabled;
@property (nonatomic) BOOL fontPickerEnabled;

- (BOOL) fontPickerIsOpen;
- (BOOL) keyboardIsOpen;

@end

@implementation KWTextEditor

@synthesize fontPicker = _fontPicker;
@synthesize toolbar = _toolbar;
@synthesize keyboardButton = _keyboardButton;
@synthesize fontButton = _fontButton;
@synthesize closeButton = _closeButton;

static CGFloat KWTextEditorAnimationDuration = 0.3;
static CGFloat KWTextEditorButtonWidth = 80;
static CGRect KWTextEditorLatestKeyboardRect;
static BOOL KWTextEditorStyleIOS7 = NO;

// currently those notifications are not post for outside of the class
NSString *const KWTextEditorWillShowNotification = @"KWTextEditorWillShowNotification";
NSString *const KWTextEditorDidShowNotification = @"KWTextEditorDidShowNotification";
NSString *const KWTextEditorWillHideNotification = @"KWTextEditorWillHideNotification";
NSString *const KWTextEditorDidHideNotification = @"KWTextEditorDidHideNotification";
NSString *const KWTextEditorFrameEndUserInfoKey = @"KWTextEditorFrameEndUserInfoKey";
NSString *const KWTextEditorAnimationDurationUserInfoKey = @"KWTextEditorAnimationDurationUserInfoKey";

-(KWTextEditor*)initWithTextView:(UITextView*)textView
{
    self = [self initWithFrame:CGRectZero];
    _fontPickerEnabled = YES;
    _keyboardEnabled = YES;
    _hasSavedInsets = NO;
    _isOpening = NO;
    _isClosing = NO;
    _tapEditorMode = KWTextEditorModeKeyboard; // open keyboard on a tap
    _editorMode = KWTextEditorModeNone; // don't open an editor until a tap
    _textView = textView;
    _textView.delegate = self;
    
    // device orientation detection
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    
    // iOS7 Style
    KWTextEditorStyleIOS7 = ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7);
    
    return self;
}

-(void)dismiss;
{
    [self restoreScrollViewAnimated:NO completion:nil];
    [self removeNotificationObservers];
    _toolbar = nil;
    _fontPicker = nil;
    _textView.delegate = nil;
    _textView = nil;
    _scrollView = nil;
    [self removeFromSuperview];
}

- (void) addNotificationObservers
{
    // NSLog(@"[%d] addNotificationObservers: %d (o:%d,c:%d)", self.tag, _editorMode, self.isOpening, self.isClosing);
    
    // device orientation detection
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceOrientationDidChange:) name:UIDeviceOrientationDidChangeNotification object:nil];
    
    // phonecall statusbar
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(statusBarWillChange:) name:UIApplicationWillChangeStatusBarFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(statusBarDidChange:) name:UIApplicationDidChangeStatusBarFrameNotification object:nil];
    
    // keyboard open and close
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidShow:) name:UIKeyboardDidShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidChange:) name:UIKeyboardDidChangeFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidHide:) name:UIKeyboardDidHideNotification object:nil];
    
    // other KWTextEditor instances
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textEditorWillShow:) name:KWTextEditorWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textEditorDidShow:) name:KWTextEditorDidShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textEditorWillHide:) name:KWTextEditorWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textEditorDidHide:) name:KWTextEditorDidHideNotification object:nil];
}

- (void) removeNotificationObservers
{
    // NSLog(@"[%d] removeNotificationObservers: %d (o:%d,c:%d)", self.tag, _editorMode, self.isOpening, self.isClosing);
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) statusBarWillChange:(NSNotification *)notification
{
    [self closeTextEditor];
}

- (void) statusBarDidChange:(NSNotification *)notification
{
    [self closeTextEditor];
}

- (void) deviceOrientationDidChange:(NSNotification *)notification
{
    [self closeTextEditor];
}

- (BOOL)textViewShouldBeginEditing:(UITextView *)textView
{
    // NSLog(@"[%d] textViewShouldBeginEditing: %d (o:%d,c:%d)", self.tag, _editorMode, self.isOpening, self.isClosing);
    
    // allow open keyboard if we are opening our keyboard
    if (self.isOpening) {
        return YES;
    }
    
    // hide keyboard otherwise at first, and open our editor then
    [self.superview endEditing:NO];
    [self performSelector:@selector(applyTapEditorMode) withObject:nil afterDelay:0.001];
    return NO;
}

- (void)applyTapEditorMode
{
    KWTextEditorMode newMode = (self.editorMode != KWTextEditorModeNone) ? self.editorMode : self.tapEditorMode;
    // NSLog(@"[%d] applyTapEditorMode: %d -> %d", self.tag, self.editorMode, newMode);
    self.editorMode = newMode;
}

- (void)textViewDidBeginEditing:(UITextView *)textView
{
    // NSLog(@"[%d] textViewDidBeginEditing: %d (o:%d,c:%d)", self.tag, _editorMode, self.isOpening, self.isClosing);
    
    if (! self.isOpening) {
        [self showToolbarUponKeyboard];
    }
}

- (void)textViewDidChange:(UITextView *)textView
{
    if (self.textDidChangeHandler) {
        self.textDidChangeHandler();
    }
}

- (BOOL)textViewShouldEndEditing:(UITextView *)textView
{
    // NSLog(@"[%d] textViewShouldEndEditing: %d (o:%d,c:%d)", self.tag, _editorMode, self.isOpening, self.isClosing);
    
    if (! self.isClosing) {
        [self closeTextEditor];
    }
    return YES;
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
    // NSLog(@"[%d] textViewDidEndEditing: %d (o:%d,c:%d)", self.tag, _editorMode, self.isOpening, self.isClosing);
    
    if (self.isClosing) {
        [self didCloseTextEditor];
    }
}

-(void)showInView:(UIView*)view
{
    self.hidden = YES;
    [view addSubview:self];
    [self openTextEditor];
}

- (void)setFontPickerEnabled:(BOOL)enabled
{
    _fontPickerEnabled = enabled;
    if (enabled) {
        _tapEditorMode = KWTextEditorModeFontPicker;
        return;
    }
    if (self.editorMode == KWTextEditorModeFontPicker) {
        _editorMode = KWTextEditorModeKeyboard;
    }
    if (self.tapEditorMode == KWTextEditorModeFontPicker) {
        _tapEditorMode = KWTextEditorModeKeyboard;
    }
}

- (void)setKeyboardEnabled:(BOOL)enabled
{
    _keyboardEnabled = enabled;
    if (enabled) {
        _tapEditorMode = KWTextEditorModeKeyboard;
        return;
    }
    if (self.editorMode == KWTextEditorModeKeyboard) {
        _editorMode = KWTextEditorModeFontPicker;
    }
    if (self.tapEditorMode == KWTextEditorModeKeyboard) {
        _tapEditorMode = KWTextEditorModeFontPicker;
    }
}

// getter (lazy build)
-(KWFontPicker*)fontPicker
{
    if (! _fontPicker) {
        [self renewFontPicker];
    }
    
    return _fontPicker;
}

-(void)renewFontPicker
{
    KWFontPicker *prevFontPicker = _fontPicker;
    
    if (_fontPicker) {
        [_fontPicker removeFromSuperview];
    }
    
    // initialize font picker
    _fontPicker = [[KWFontPicker alloc] init];
    _fontPicker.font  = self.textView.font;
    _fontPicker.color = self.textView.textColor;
    
    // reload previous list
    if (prevFontPicker) {
        _fontPicker.fontList = prevFontPicker.fontList;
        _fontPicker.sizeList = prevFontPicker.sizeList;
        _fontPicker.colorList = prevFontPicker.colorList;
    }
    
    // set callback handler
    __weak KWTextEditor *bself = self;
    __weak KWFontPicker *bfontPicker = _fontPicker;
    [_fontPicker setChangeHandler:^{
        bself.textView.font      = bfontPicker.font;
        bself.textView.textColor = bfontPicker.color;
        if (bself.fontDidChangeHandler) {
            bself.fontDidChangeHandler();
        }
    }];
    
    // all set
    [self addSubview:_fontPicker];
}

// getter (lazy build)
-(UIToolbar*)toolbar
{
    if (! _toolbar) {
        [self renewToolbar];
    }
    return _toolbar;
}

-(void)renewToolbar
{
    if (_toolbar) {
        [_toolbar removeFromSuperview];
    }
    
    UIBarButtonItem *flexSpacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:
                                   UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    
    // keyboard and font picker buttons are shown when both are enabled
    NSArray *barItems;
    if (self.keyboardEnabled && self.fontPickerEnabled) {
        barItems = @[ self.keyboardButton, self.fontButton, flexSpacer, self.closeButton ];
    } else {
        barItems = @[ flexSpacer, self.closeButton ];
    }
    
    // initialize toolbar
    CGRect windowRect = [self.superview convertRect:self.window.frame fromView:self.window];
    CGFloat toolbarHeight = (windowRect.size.height <= 320) ? 32 : 40; // FIXED
    CGRect frame = CGRectMake(0, 0, windowRect.size.width, toolbarHeight);
    _toolbar = [[UIToolbar alloc] initWithFrame:frame];
    _toolbar.barStyle = KWTextEditorStyleIOS7 ? UIBarStyleDefault : UIBarStyleBlackTranslucent;
    _toolbar.items = barItems;
    [self addSubview:_toolbar];
}

- (UIBarButtonItem*)keyboardButton
{
    if (_keyboardButton) return _keyboardButton;
    _keyboardButton = [[UIBarButtonItem alloc] initWithTitle:@"Keyboard"
                                                       style:UIBarButtonItemStyleBordered
                                                      target:self
                                                      action:@selector(keyboardButtonClicked:)];
    _keyboardButton.width = KWTextEditorButtonWidth;
    return _keyboardButton;
}

- (UIBarButtonItem*)fontButton
{
    if (_fontButton) return _fontButton;
    _fontButton = [[UIBarButtonItem alloc] initWithTitle:@"Font"
                                                   style:UIBarButtonItemStyleBordered
                                                  target:self
                                                  action:@selector(fontButtonClicked:)];
    _fontButton.width = KWTextEditorButtonWidth;
    return _fontButton;
}

- (UIBarButtonItem*)closeButton
{
    if (_closeButton) return _closeButton;
    _closeButton = [[UIBarButtonItem alloc] initWithTitle:@"Close"
                                                    style:UIBarButtonItemStyleBordered
                                                   target:self
                                                   action:@selector(closeButtonClicked:)];
    _closeButton.width = KWTextEditorButtonWidth;
    return _closeButton;
}

- (void)setEditorMode:(KWTextEditorMode)editorMode
{
    // keyboard is disabled
    if (editorMode == KWTextEditorModeKeyboard && ! self.keyboardEnabled) {
        editorMode = KWTextEditorModeNone;
    }
    
    // font picker is disabled
    if (editorMode == KWTextEditorModeFontPicker && ! self.fontPickerEnabled) {
        editorMode = KWTextEditorModeNone;
    }
    
    // NSLog(@"[%d] setEditorMode: ******** %d -> %d (o:%d,c:%d)", self.tag, _editorMode, editorMode, self.isOpening, self.isClosing);
    
    if (self.window) {
        if (_editorMode == KWTextEditorModeNone) {
            // open an editor
            _editorMode = editorMode;
            [self openTextEditor];
        } else {
            // close current editor at first, then open new one
            self.nextEditorMode = editorMode;
            [self closeTextEditor];
        }
    } else {
        // don't open an editor when not shown
        _editorMode = editorMode;
    }
}

- (void)openNextEditor
{
    if (! self.nextEditorMode) return;
    // NSLog(@"[%d] openNextEditor: ******** %d -> %d", self.tag, _editorMode, self.nextEditorMode);
    
    KWTextEditorMode nextMode = self.nextEditorMode;
    self.nextEditorMode = KWTextEditorModeNone;
    self.editorMode = nextMode;
}

- (void)openTextEditor
{
    // NSLog(@"[%d] openTextEditor: ======== %d (o:%d,c:%d)", self.tag, _editorMode, self.isOpening, self.isClosing);
    if (self.isOpening || self.isClosing) return;
    self.isOpening = YES;
    
    switch (self.editorMode) {
        case KWTextEditorModeKeyboard:
            [self addNotificationObservers];
            [self openKeyboard];
            break;
            
        case KWTextEditorModeFontPicker:
            [self addNotificationObservers];
            [self openFontPicker];
            break;
            
        default:
            self.isOpening = NO;
            self.hidden = YES;
            self.frame = CGRectZero;
            break;
    }

    UIColor *tintColor = KWTextEditorStyleIOS7 ? [UIColor darkTextColor] : [UIColor darkGrayColor];
    self.keyboardButton.tintColor = (self.editorMode == KWTextEditorModeKeyboard) ? tintColor : nil;
    self.fontButton.tintColor = (self.editorMode == KWTextEditorModeFontPicker) ? tintColor : nil;
}

- (void)didOpenTextEditor
{
    if (! self.isOpening) return;
    self.isOpening = NO;
    // NSLog(@"[%d] didOpenTextEditor: ======== %d (o:%d,c:%d)", self.tag, _editorMode, self.isOpening, self.isClosing);
    
    CGRect endRect = [self.window convertRect:self.frame fromView:self.superview];
    [self postNotificationWithName:KWTextEditorDidShowNotification endFrame:endRect];
    if (self.editorDidShowHandler) {
        self.editorDidShowHandler();
    }
}

- (void)closeTextEditor
{
    // NSLog(@"[%d] closeTextEditor: ======== %d -> %d (o:%d,c:%d) next=%d", self.tag, _editorMode, KWTextEditorModeNone, self.isOpening, self.isClosing, self.nextEditorMode);
    if (self.isOpening || self.isClosing) return;
    self.isClosing = YES;
    
    KWTextEditorMode currentMode = _editorMode;
    _editorMode = KWTextEditorModeNone;
    
    switch (currentMode) {
        case KWTextEditorModeKeyboard:
            [self closeKeyboard];
            break;
            
        case KWTextEditorModeFontPicker:
            [self closeFontPicker];
            break;
            
        default:
            self.isClosing = NO;
            self.hidden = YES;
            self.frame = CGRectZero;
            [self openNextEditor];
            break;
    }
}

- (void)didCloseTextEditor
{
    if (! self.isClosing) return;
    self.isClosing = NO;
    // NSLog(@"[%d] didCloseTextEditor: ======== %d (o:%d,c:%d)", self.tag, _editorMode, self.isOpening, self.isClosing);
    
    self.hidden = YES;
    self.frame = CGRectZero;
    [self restoreScrollViewAnimated:NO completion:nil];
    [self removeNotificationObservers];
    [self postNotificationWithName:KWTextEditorDidHideNotification endFrame:CGRectZero];
    if (self.editorDidHideHandler) {
        self.editorDidHideHandler();
    }
    [self performSelector:@selector(openNextEditor) withObject:nil afterDelay:0.01];
}

- (void)keyboardButtonClicked:(id)sender
{
    if (self.editorMode == KWTextEditorModeKeyboard) return;
    self.editorMode = KWTextEditorModeKeyboard;
}

- (void)fontButtonClicked:(id)sender
{
    if (self.editorMode == KWTextEditorModeFontPicker) return;
    self.editorMode = KWTextEditorModeFontPicker;
}

- (void)closeButtonClicked:(id)sender
{
    // NSLog(@"[%d] closeButtonClicked: %d", self.tag, _editorMode);
    
    // force to close
    self.isOpening = NO;
    self.isClosing = NO;
    
    self.editorMode = KWTextEditorModeNone;
    
    if (self.closeButtonDidTapHandler) {
        self.closeButtonDidTapHandler();
    }
}

- (void)openFontPicker
{
    [self.superview endEditing:NO];
    
    CGRect prevRect = [self.superview convertRect:self.frame fromView:self.superview];
    CGRect windowRect = [self.superview convertRect:self.window.frame fromView:self.window];
    
    // redraw toolbar if width changed (mostly device rotation)
    CGRect toolbarRect = [self.superview convertRect:self.toolbar.frame fromView:self];
    if (toolbarRect.size.width != windowRect.size.width) {
        [self renewToolbar];
        toolbarRect = [self.superview convertRect:self.toolbar.frame fromView:self];
    }
    
    // redraw font picker if width changed (mostly device rotation)
    CGRect pickerRect = [self.superview convertRect:self.fontPicker.frame fromView:self];
    if (pickerRect.size.width != windowRect.size.width) {
        [self renewFontPicker];
        pickerRect = [self.superview convertRect:self.fontPicker.frame fromView:self];
    }
    
    CGSize viewSize = CGSizeZero;
    viewSize.width = MAX(toolbarRect.size.width, pickerRect.size.width);
    viewSize.height = toolbarRect.size.height + pickerRect.size.height;
    
    CGRect hideRect = CGRectZero;
    hideRect.origin.x = windowRect.origin.x;
    hideRect.origin.y = windowRect.origin.y + windowRect.size.height;
    hideRect.size = viewSize;
    CGRect showRect = CGRectZero;
    showRect.origin.x = windowRect.origin.x;
    showRect.origin.y = windowRect.origin.y + windowRect.size.height - viewSize.height;
    showRect.size = viewSize;
    toolbarRect.origin = CGPointZero;
    pickerRect.origin  = CGPointMake(0, toolbarRect.size.height);
    
    BOOL animated = ! CGRectEqualToRect(prevRect, showRect);
    
    // NSLog(@"[%d] openFontPicker: -------- animated=%d", self.tag, animated);
    
    // apply new position
    self.hidden = YES;
    self.frame = hideRect;
    self.toolbar.frame = toolbarRect;
    self.fontPicker.frame = pickerRect;
    
    // apply current text attributes on font picker
    self.fontPicker.font  = self.textView.font;
    self.fontPicker.color = self.textView.textColor;
    self.fontPicker.text  = self.textView.text;
    [self.fontPicker reloadAllComponents];
    
    // post notification for other KWTextEditor instances
    CGRect endRect = [self.window convertRect:showRect fromView:self.superview];
    [self postNotificationWithName:KWTextEditorWillShowNotification endFrame:endRect];
    
    // show all
    self.toolbar.hidden = NO;
    self.fontPicker.hidden = NO;
    self.hidden = NO;
    [self.superview bringSubviewToFront:self];
    
    __weak KWTextEditor *bself = self;
    void (^completion)(void) = ^{
        [bself didOpenTextEditor];
    };
    
    void (^animations)(void) = ^{
        bself.frame = showRect;
    };
    
    __block BOOL once = NO;
    void (^afinished)(BOOL) = ^(BOOL finished){
        if (once) return;
        once = YES;
        [bself shortenScrollViewAnimated:animated completion:completion];
    };
    
    if (animated) {
        [UIView animateWithDuration:KWTextEditorAnimationDuration animations:animations completion:afinished];
    } else {
        animations();
        afinished(YES);
    }
}

- (void)closeFontPicker
{
    CGRect prevRect = [self.superview convertRect:self.frame fromView:self.superview];
    CGRect windowRect = [self.superview convertRect:self.window.frame fromView:self.window];
    
    CGRect hideRect = CGRectZero;
    hideRect.origin.x = prevRect.origin.x;
    hideRect.origin.y = windowRect.origin.y + windowRect.size.height;
    hideRect.size = prevRect.size;
    
    BOOL animated = self.fontPickerIsOpen && ! CGRectEqualToRect(prevRect, hideRect);
    
    // NSLog(@"[%d] closeFontPicker: -------- animated=%d", self.tag, animated);
    
    // post notification for other KWTextEditor instances
    CGRect endRect = [self.window convertRect:hideRect fromView:self.superview];
    [self postNotificationWithName:KWTextEditorWillHideNotification endFrame:endRect];
    
    __weak KWTextEditor *bself = self;
    void (^completion)(void) = ^{
        [bself didCloseTextEditor];
    };
    
    void (^animations)(void) = ^{
        bself.frame = hideRect;
    };
    
    __block BOOL once = NO;
    void (^afinished)(BOOL) = ^(BOOL finished){
        if (once) return;
        once = YES;
        [bself restoreScrollViewAnimated:animated completion:completion];
    };
    
    if (animated) {
        [UIView animateWithDuration:KWTextEditorAnimationDuration animations:animations completion:afinished];
    } else {
        animations();
        afinished(YES);
    }
}

- (BOOL)fontPickerIsOpen
{
    return (! self.hidden && ! _fontPicker.hidden && ! _toolbar.hidden);
}

- (void)openKeyboard
{
    if (! self.window) return;
    if (! self.textView.window) return;
    
    // NSLog(@"[%d] openKeyboard: -------- canBecomeFirstResponder=%d", self.tag, self.textView.canBecomeFirstResponder);
    
    if (self.textView.canBecomeFirstResponder) {
        [self.textView becomeFirstResponder];
    }
}

- (void)closeKeyboard
{
    if (! self.window) return;
    if (! self.textView.window) return;
    
    // NSLog(@"[%d] closeKeyboard: -------- canResignFirstResponder=%d", self.tag, self.textView.canResignFirstResponder);
    
    if (self.textView.canResignFirstResponder) {
        [self.textView resignFirstResponder];
    }
    
    if (self.isClosing) {
        [self didCloseTextEditor];
    }
}

- (BOOL)keyboardIsOpen
{
    return (! self.hidden && _fontPicker.hidden && ! _toolbar.hidden);
}

- (void)showToolbarUponKeyboard
{
    // ignore keyboard is not shown
    CGRect keyboardRect = [self.superview convertRect:KWTextEditorLatestKeyboardRect fromView:self.window];
    if (!(keyboardRect.size.height > 0)) return;
    
    // redraw toolbar if width changed (mostly device rotation)
    CGRect toolbarRect = [self.superview convertRect:self.toolbar.frame fromView:self];
    if (toolbarRect.size.width != keyboardRect.size.width) {
        [self renewToolbar];
        toolbarRect = [self.superview convertRect:self.toolbar.frame fromView:self];
    }
    
    CGRect viewRect    = CGRectZero;
    viewRect.size      = CGSizeMake(toolbarRect.size.width, toolbarRect.size.height);
    viewRect.origin    = CGPointMake(keyboardRect.origin.x, keyboardRect.origin.y - toolbarRect.size.height);
    toolbarRect.origin = CGPointZero;
    
    // no need to move toolbar if keyboard is not changed
    BOOL animated = ! (self.keyboardIsOpen && CGRectEqualToRect(self.frame, viewRect));
    
    // NSLog(@"[%d] showToolbarUponKeyboard: animated=%d", self.tag, animated);
    
    // post notification
    CGRect endRect = [self.window convertRect:viewRect fromView:self.superview];
    [self postNotificationWithName:KWTextEditorWillShowNotification endFrame:endRect];
    
    // move toolbar to new position without animation
    self.transform = CGAffineTransformIdentity;
    self.frame = viewRect;
    self.toolbar.frame = toolbarRect;
    
    // show toolbar upon keyboard when a keyboard shown
    self.toolbar.hidden = NO;
    self.fontPicker.hidden = YES;
    self.hidden = NO;
    [self.superview bringSubviewToFront:self];
    
    __weak KWTextEditor *bself = self;
    void (^completion)(void) = ^{
        [bself didOpenTextEditor];
    };
    
    [self shortenScrollViewAnimated:animated completion:completion];
}

- (void)keyboardWillShow:(NSNotification*)notification
{
    // NSLog(@"[%d] %@: isFirstResponder=%d", self.tag, notification.name, self.textView.isFirstResponder);
    
    if (self.textView.isFirstResponder) {
        // wait to show toolbar until keyboard is shown
    } else {
        [self closeTextEditor];
    }
}

- (void)keyboardDidShow:(NSNotification*)notification
{
    // NSLog(@"[%d] %@: isFirstResponder=%d", self.tag, notification.name, self.textView.isFirstResponder);
    
    // remember last keyboard size updated
    CGRect keyboardRect = [[notification.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    KWTextEditorLatestKeyboardRect = keyboardRect;
    
    if (self.textView.isFirstResponder) {
        [self showToolbarUponKeyboard];
    } else {
        [self closeTextEditor];
    }
}

- (void)keyboardDidChange:(NSNotification*)notification
{
    // NSLog(@"[%d] %@: isFirstResponder=%d", self.tag, notification.name, self.textView.isFirstResponder);
    
    // remember last keyboard size updated
    CGRect keyboardRect = [[notification.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    KWTextEditorLatestKeyboardRect = keyboardRect;
    
    if (self.textView.isFirstResponder) {
        // update toolbar position if already shown
        if (self.keyboardIsOpen) {
            [self showToolbarUponKeyboard];
        }
    }
}

- (void)keyboardWillHide:(NSNotification*)notification
{
    // NSLog(@"[%d] %@: isFirstResponder=%d", self.tag, notification.name, self.textView.isFirstResponder);
    
    if (! self.isClosing) {
        [self closeTextEditor];
    }
}

- (void)keyboardDidHide:(NSNotification*)notification
{
    // NSLog(@"[%d] %@: isFirstResponder=%d", self.tag, notification.name, self.textView.isFirstResponder);
    
    if (self.isClosing) {
        [self didCloseTextEditor];
    }
}

- (void)textEditorWillShow:(NSNotification*)notification
{
    KWTextEditor* textEditor = (KWTextEditor*) notification.object;
    BOOL noticedByMe = (self == textEditor);
    // NSLog(@"[%d] %@: noticedByMe=%@", self.tag, notification.name, noticedByMe ? @"YES" : @"NO");
    
    // close my self when another open
    if (! noticedByMe) {
        [self closeTextEditor];
    }
}

- (void)textEditorDidShow:(NSNotification*)notification
{
    KWTextEditor* textEditor = (KWTextEditor*) notification.object;
    BOOL noticedByMe = (self == textEditor);
    // NSLog(@"[%d] %@: noticedByMe=%@", self.tag, notification.name, noticedByMe ? @"YES" : @"NO");
    
    if (! noticedByMe) {
        [self closeTextEditor];
    }
}

- (void)textEditorWillHide:(NSNotification*)notification
{
}

- (void)textEditorDidHide:(NSNotification*)notification
{
}

- (void)postNotificationWithName:(NSString*)name endFrame:(CGRect)endFrame
{
    NSValue *endValue = [NSValue valueWithCGRect:endFrame];
    NSNumber *ducation = [NSNumber numberWithDouble:KWTextEditorAnimationDuration];
    NSDictionary *userInfo = @{ KWTextEditorFrameEndUserInfoKey: endValue, KWTextEditorAnimationDurationUserInfoKey: ducation };
    NSNotification *notification = [NSNotification notificationWithName:name object:self userInfo:userInfo];
    [[NSNotificationCenter defaultCenter] postNotification:notification];
}

- (void)shortenScrollViewAnimated:(BOOL)animated completion:(void(^)(void))completion
{
    if (! self.scrollView) {
        if (completion) completion();
        return;
    }
    
    // restore before shorten
    [self restoreScrollViewAnimated:NO completion:nil];
    
    // NSLog(@"[%d] shortenScrollViewAnimated: animated=%d", self.tag, animated);
    
    CGPoint textTop = CGPointMake(0, self.textView.frame.origin.y);
    CGPoint textBottom = CGPointMake(0, self.textView.frame.origin.y + self.textView.frame.size.height);
    CGPoint toolbarTop = CGPointMake(0, self.toolbar.frame.origin.y);
    CGPoint contentTop = CGPointMake(0, 0);
    CGPoint contentBottom = CGPointMake(0, self.scrollView.contentSize.height);
    CGPoint insetTop = CGPointMake(0, contentTop.y + self.scrollView.contentInset.top + self.scrollView.scrollIndicatorInsets.top);
    CGPoint insetBottom = CGPointMake(0, contentBottom.y - self.scrollView.contentInset.bottom - self.scrollView.scrollIndicatorInsets.bottom);
    
    textTop = [self.window convertPoint:textTop fromView:self.textView.superview];
    textBottom = [self.window convertPoint:textBottom fromView:self.textView.superview];
    toolbarTop = [self.window convertPoint:toolbarTop fromView:self.toolbar.superview];
    contentTop = [self.window convertPoint:contentTop fromView:self.scrollView];
    contentBottom = [self.window convertPoint:contentBottom fromView:self.scrollView];
    insetTop  = [self.window convertPoint:insetTop fromView:self.scrollView];
    insetBottom  = [self.window convertPoint:insetBottom fromView:self.scrollView];
    
    // additoinal padding for scrollView
    CGFloat paddingY = insetBottom.y - toolbarTop.y;
    
    // no need to change insets
    if (paddingY < 0)  {
        if (completion) completion();
        return;
    }
    
    // scroll to show top or bottom of TextView
    CGPoint newOffset = CGPointMake(self.scrollView.contentOffset.x, self.scrollView.contentOffset.y);
    if (textTop.y < insetTop.y) {
        newOffset.y += textTop.y - insetTop.y;
    } else if (textBottom.y > toolbarTop.y) {
        newOffset.y += textBottom.y - toolbarTop.y;
    }
    
    UIEdgeInsets ci = UIEdgeInsetsMake(self.scrollView.contentInset.top,
                                       self.scrollView.contentInset.left,
                                       self.scrollView.contentInset.bottom,
                                       self.scrollView.contentInset.right);
    UIEdgeInsets si = UIEdgeInsetsMake(self.scrollView.scrollIndicatorInsets.top,
                                       self.scrollView.scrollIndicatorInsets.left,
                                       self.scrollView.scrollIndicatorInsets.bottom,
                                       self.scrollView.scrollIndicatorInsets.right);
    CGPoint currentOffset = CGPointMake(self.scrollView.contentOffset.x,
                                        self.scrollView.contentOffset.y);
    
    // save current values to restore them later
    if (! self.hasSavedInsets) {
        self.hasSavedInsets = YES;
        self.savedContentInsets = ci;
        self.savedScrollInsets  = si;
        self.savedContentOffset = currentOffset;
    }
    
    // new padding bottom with controls' height
    self.ourContentInsets = UIEdgeInsetsMake(ci.top, ci.left, ci.bottom + paddingY, ci.right);
    self.ourScrollInsets = UIEdgeInsetsMake(si.top, si.left, si.bottom + paddingY, si.right);
    
    __weak KWTextEditor *bself = self;
    void (^animations)(void) = ^{
        bself.scrollView.contentInset = bself.ourContentInsets;
        bself.scrollView.scrollIndicatorInsets = bself.ourScrollInsets;
        bself.scrollView.contentOffset = newOffset;
    };
    
    __block BOOL once = NO;
    void (^afinished)(BOOL) = ^(BOOL finished){
        if (once) return;
        once = YES;
        if (completion) completion();
    };
    
    if (animated) {
        [UIView animateWithDuration:KWTextEditorAnimationDuration/2 animations:animations completion:afinished];
    } else {
        animations();
        afinished(YES);
    }
}

- (void)restoreScrollViewAnimated:(BOOL)animated completion:(void(^)(void))completion
{
    // NSLog(@"[%d] restoreScrollViewAnimated: hasSavedInsets=%d", self.tag, self.hasSavedInsets);
    
    if (! self.scrollView || ! self.hasSavedInsets) {
        if (completion) completion();
        return;
    }
    
    // test current insets are defined by us
    BOOL restoreContentInset = UIEdgeInsetsEqualToEdgeInsets(self.scrollView.contentInset, self.ourContentInsets);
    BOOL restoreScrollInset  = UIEdgeInsetsEqualToEdgeInsets(self.scrollView.scrollIndicatorInsets, self.ourScrollInsets);
    // NSLog(@"[%d] restoreScrollViewAnimated: restoreContentInset=%d restoreScrollInset=%d", self.tag, restoreContentInset, restoreScrollInset);
    
    // no need to restore insets when changed by someone else
    if (! restoreContentInset && ! restoreScrollInset) {
        if (completion) completion();
        return;
    }
    
    // NSLog(@"[%d] restoreScrollViewAnimated: animated=%d", self.tag, animated);
    
    self.hasSavedInsets = NO;
    
    __weak KWTextEditor *bself = self;
    void (^animations)(void) = ^{
        bself.scrollView.contentInset = bself.savedContentInsets;
        bself.scrollView.scrollIndicatorInsets = bself.savedScrollInsets;
        bself.scrollView.contentOffset = bself.savedContentOffset;
    };
    
    __block BOOL once = NO;
    void (^afinished)(BOOL) = ^(BOOL finished){
        if (once) return;
        once = YES;
        if (completion) completion();
    };
    
    if (animated) {
        [UIView animateWithDuration:KWTextEditorAnimationDuration/2 animations:animations completion:afinished];
    } else {
        animations();
        afinished(YES);
    }
}

@end

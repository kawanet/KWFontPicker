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

@property CGRect lastKeyboardRect;
@property CGPoint savedContentOffset;
@property UIEdgeInsets savedScrollInsets;
@property UIEdgeInsets savedContentInsets;
@property UIEdgeInsets ourScrollInsets;
@property UIEdgeInsets ourContentInsets;
@property BOOL hasSavedInsets;

@property (copy) KWTextEditorHandler keyboardDidShowHandler;
@property (copy) KWTextEditorHandler keyboardDidHideHandler;

@property (copy) KWTextEditorHandler fontPickerDidShowHandler;
@property (copy) KWTextEditorHandler fontPickerDidHideHandler;

@property (copy) KWTextEditorHandler textDidChangeHandler;
@property (copy) KWTextEditorHandler fontDidChangeHandler;

@property (copy) KWTextEditorHandler closeButtonDidTapHandler;

@property (nonatomic) KWTextEditorMode editorMode;
@property (nonatomic) KWTextEditorMode tapEditorMode;
@property KWTextEditorMode nextEditorMode;

- (BOOL) fontPickerIsOpen;
- (BOOL) keyboardIsOpen;

@end

@implementation KWTextEditor

@synthesize fontPicker = _fontPicker;
@synthesize toolbar = _toolbar;

static CGFloat KWTextEditorAnimationDuration = 0.3;

-(KWTextEditor*)initWithTextView:(UITextView*)textView
{
    self = [self initWithFrame:CGRectZero];
    self.keyboardEnabled = YES;
    self.fontPickerEnabled = YES;
    _editorMode = self.keyboardEnabled ? KWTextEditorModeKeyboard : KWTextEditorModeFontPicker;
    _tapEditorMode = self.keyboardEnabled ? KWTextEditorModeKeyboard : KWTextEditorModeFontPicker;
    _textView = textView;
    _textView.delegate = self;
    
    // TODO: devicec orientation detection
    // [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    
    return self;
}

-(void)dismiss;
{
    _toolbar = nil;
    _fontPicker = nil;
    _textView.delegate = nil;
    _textView = nil;
    _scrollView = nil;
    [self removeNotificationObservers];
    [self removeFromSuperview];
}

- (void) addNotificationObservers
{
    // TODO: devicec orientation detection
    // [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceOrientationDidChange:) name:UIDeviceOrientationDidChangeNotification object:nil];
    
    // phonecall statusbar
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(statusBarWillChange:) name:UIApplicationWillChangeStatusBarFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(statusBarDidChange:) name:UIApplicationDidChangeStatusBarFrameNotification object:nil];
    
    // keyboard open and close
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidShow:) name:UIKeyboardDidShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidChange:) name:UIKeyboardDidChangeFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidHide:) name:UIKeyboardDidHideNotification object:nil];
}

- (void) removeNotificationObservers
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) statusBarWillChange:(NSNotification *)notification
{
    // remove any controls once before superview changes its size
    [self hideControls];
}

- (void) statusBarDidChange:(NSNotification *)notification
{
    // compare stasubar size between pre-notification and post-notification (current)
    NSValue *rectValue = notification.userInfo[UIApplicationStatusBarFrameUserInfoKey];
    CGRect oldFrame;
    [rectValue getValue:&oldFrame];
    CGRect newFrame = [[UIApplication sharedApplication] statusBarFrame];
    
    // redraw controls when phonecall etc but not rotation
    if (oldFrame.size.height != newFrame.size.height && oldFrame.size.width == newFrame.size.width) {
        self.editorMode = self.editorMode;
    }
}

- (void) deviceOrientationDidChange:(NSNotification *)notification
{
    // reopen controls
    self.editorMode = self.editorMode;
}

- (BOOL)textViewShouldBeginEditing:(UITextView *)textView
{
    switch (self.editorMode) {
        case KWTextEditorModeKeyboard:
            // allow open keyboard
            return YES;
            
        case KWTextEditorModeFontPicker:
            // deny open keyboard
            return NO;
            
        default:
            // remove controls from outside of event chain
            [self performSelector:@selector(applyTapEditorMode) withObject:nil afterDelay:0.001];
            return NO;
    }
}

- (void)applyTapEditorMode
{
    self.editorMode = self.tapEditorMode;
}

- (void)textViewDidBeginEditing:(UITextView *)textView
{
    if (self.keyboardIsOpen) {
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
    [self closeTextEditor];
    return YES;
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
    [self closeTextEditor];
}

-(void)showInView:(UIView*)view
{
    self.hidden = YES;
    [view addSubview:self];
    [self openTextEditor];
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
    [_fontPicker setChangeHandler:^{
        bself.textView.font      = _fontPicker.font;
        bself.textView.textColor = _fontPicker.color;
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
    
    // toolbar buttons
    _keyboardButton = [[UIBarButtonItem alloc] initWithTitle:@"Keyboard"
                                                       style:UIBarButtonItemStyleBordered
                                                      target:self
                                                      action:@selector(keyboardButtonClicked:)];
    _fontButton = [[UIBarButtonItem alloc] initWithTitle:@"Font"
                                                   style:UIBarButtonItemStyleBordered
                                                  target:self
                                                  action:@selector(fontButtonClicked:)];
    _closeButton = [[UIBarButtonItem alloc] initWithTitle:@"Close"
                                                    style:UIBarButtonItemStyleBordered
                                                   target:self
                                                   action:@selector(closeButtonClicked:)];
    self.keyboardButton.width = 80;
    self.fontButton.width = 80;
    self.closeButton.width = 80;
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
    _toolbar.barStyle = UIBarStyleBlack;
    _toolbar.items = barItems;
    [self addSubview:_toolbar];
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
    
    if (self.window) {
        if (_editorMode == KWTextEditorModeNone) {
            // open an editor
            _editorMode = editorMode;
            [self openTextEditor];
        } else {
            // close current editor, at first, then open new one
            self.nextEditorMode = editorMode;
            [self closeTextEditor];
            [self performSelector:@selector(applyNextEditorMode:) withObject:[NSNumber numberWithInteger:editorMode] afterDelay:KWTextEditorAnimationDuration*2];
        }
    } else {
        // don't open an editor when not shown
        _editorMode = editorMode;
    }
}

- (void)applyNextEditorMode:(id)obj
{
    if (! self.nextEditorMode) return;
    
    KWTextEditorMode nextMode = self.nextEditorMode;
    self.nextEditorMode = KWTextEditorModeNone;
    self.editorMode = nextMode;
}

- (void)openTextEditor
{
    
    [self addNotificationObservers];
    
    switch (self.editorMode) {
        case KWTextEditorModeKeyboard:
            [self openKeyboard];
            break;
            
        case KWTextEditorModeFontPicker:
            [self openFontPicker];
            break;
            
        default:
            [self hideControls];
            break;
    }
    
    self.keyboardButton.tintColor = (self.editorMode == KWTextEditorModeKeyboard) ? [UIColor blackColor] : nil;
    self.fontButton.tintColor = (self.editorMode == KWTextEditorModeFontPicker) ? [UIColor blackColor] : nil;
}

- (void)closeTextEditor
{
    KWTextEditorMode currentMode = _editorMode;
    _editorMode = KWTextEditorModeNone;
    
    [self restoreScrollViewAnimated:YES];
    
    switch (currentMode) {
        case KWTextEditorModeKeyboard:
            [self closeKeyboard];
            break;
            
        case KWTextEditorModeFontPicker:
            [self closeFontPicker];
            break;
            
        default:
            [self hideControls];
            break;
    }
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
    [self closeTextEditor];
    
    if (self.closeButtonDidTapHandler) {
        self.closeButtonDidTapHandler();
    }
}

- (void)openFontPicker
{
    [self.superview endEditing:YES];
    
    CGRect windowRect = [self.superview convertRect:self.window.frame fromView:self.window];
    
    // redraw toolbar if width changed (mostly device rotation)
    CGRect toolbarRect = self.toolbar.frame;
    if (toolbarRect.size.width != windowRect.size.width) {
        [self renewToolbar];
        toolbarRect = self.toolbar.frame;
    }
    
    // redraw font picker if width changed (mostly device rotation)
    CGRect pickerRect = self.fontPicker.frame;
    if (pickerRect.size.width != windowRect.size.width) {
        [self renewFontPicker];
        pickerRect = self.fontPicker.frame;
    }
    
    // no need to move toolbar+picker
    CGRect viewRect    = CGRectZero;
    viewRect.size      = CGSizeMake(toolbarRect.size.width, toolbarRect.size.height + pickerRect.size.height);
    viewRect.origin    = CGPointMake(windowRect.origin.x, windowRect.origin.y + windowRect.size.height - viewRect.size.height);
    toolbarRect.origin = CGPointZero;
    pickerRect.origin  = CGPointMake(0, toolbarRect.size.height);
    if (self.fontPickerIsOpen && CGRectEqualToRect(self.frame, viewRect)) return;
    
    // apply new position
    self.frame = viewRect;
    self.toolbar.frame = toolbarRect;
    self.fontPicker.frame = pickerRect;
    self.transform = CGAffineTransformMakeTranslation(0, viewRect.size.height);
    CGAffineTransform destTransform = CGAffineTransformMakeTranslation(0, 0);
    
    // apply current text attributes on font picker
    self.fontPicker.font  = self.textView.font;
    self.fontPicker.color = self.textView.textColor;
    self.fontPicker.text  = self.textView.text;
    [self.fontPicker reloadAllComponents];
    
    // show all
    self.toolbar.hidden = NO;
    self.fontPicker.hidden = NO;
    self.hidden = NO;
    [self.superview bringSubviewToFront:self];
    
    // show up from window bottom
    __block BOOL once = NO;
    __weak KWTextEditor *bself = self;
    [UIView animateWithDuration:KWTextEditorAnimationDuration animations:^{
        bself.transform = destTransform;
    } completion:^(BOOL finished) {
        if (once) return;
        once = YES;
        [self shortenScrollViewAnimated:YES];
        if (bself.fontPickerDidShowHandler) {
            bself.fontPickerDidShowHandler();
        }
    }];
}

- (void)closeFontPicker
{
    CGRect windowRect = [self convertRect:self.window.frame fromView:self.window];
    self.transform = CGAffineTransformMakeTranslation(0, 0);
    CGFloat windowBottom = windowRect.origin.y + windowRect.size.height;
    CGAffineTransform destTransform = CGAffineTransformMakeTranslation(0, windowBottom);
    
    __block BOOL once = NO;
    __weak KWTextEditor *bself = self;
    [UIView animateWithDuration:KWTextEditorAnimationDuration animations:^{
        bself.transform = destTransform;
    } completion:^(BOOL finished) {
        if (once) return;
        once = YES;
        [bself hideControls];
    }];
}

- (BOOL)fontPickerIsOpen
{
    return (! self.hidden && ! _fontPicker.hidden && ! _toolbar.hidden);
}

- (void)openKeyboard
{
    if (! self.window) return;
    if (! self.textView.window) return;
    if (! self.textView.canBecomeFirstResponder) {
        return;
    }
    
    [self.textView becomeFirstResponder];
}

- (void)closeKeyboard
{
    if (! self.window) return;
    if (! self.textView.window) return;
    if (! self.textView.canResignFirstResponder) {
        return;
    }
    
    [self.textView resignFirstResponder];
}

- (BOOL)keyboardIsOpen
{
    return (! self.hidden && _fontPicker.hidden && ! _toolbar.hidden);
}

- (void)hideControls
{
    if (self.hidden) return;
    
    BOOL keyboardWasOpen = self.keyboardIsOpen;
    BOOL fontPickerWasOpen = self.fontPickerIsOpen;
    
    // remove any controls
    self.frame = CGRectZero;
    self.hidden = YES;
    _editorMode = KWTextEditorModeNone;
    
    [self restoreScrollViewAnimated:YES];
    [self removeNotificationObservers];
    
    if (keyboardWasOpen) {
        if (self.keyboardDidHideHandler) {
            self.keyboardDidHideHandler();
        }
    } else if (fontPickerWasOpen) {
        if (self.fontPickerDidHideHandler) {
            self.fontPickerDidHideHandler();
        }
    }
}

- (void)showToolbarUponKeyboard
{
    // ignore keyboard is not shown
    CGRect keyboardRect = [self.superview convertRect:self.lastKeyboardRect fromView:self.window];
    if (!(keyboardRect.size.height > 0)) return;
    
    // redraw toolbar if width changed (mostly device rotation)
    CGRect toolbarRect = [self.superview convertRect:self.toolbar.frame fromView:self];
    if (toolbarRect.size.width != keyboardRect.size.width) {
        [self renewToolbar];
        toolbarRect = [self.superview convertRect:self.toolbar.frame fromView:self];
    }
    
    // no need to move toolbar if keyboard is not changed
    CGRect viewRect    = CGRectZero;
    viewRect.size      = CGSizeMake(toolbarRect.size.width, toolbarRect.size.height);
    viewRect.origin    = CGPointMake(keyboardRect.origin.x, keyboardRect.origin.y - toolbarRect.size.height);
    toolbarRect.origin = CGPointZero;
    if (self.keyboardIsOpen && CGRectEqualToRect(self.frame, viewRect)) return;
    
    // move toolbar to new position without animation
    self.transform = CGAffineTransformIdentity;
    self.frame = viewRect;
    self.toolbar.frame = toolbarRect;
    
    // show toolbar upon keyboard when a keyboard shown
    self.toolbar.hidden = NO;
    self.fontPicker.hidden = YES;
    self.hidden = NO;
    [self.superview bringSubviewToFront:self];
    
    [self shortenScrollViewAnimated:YES];
    
    if (self.keyboardDidShowHandler) {
        self.keyboardDidShowHandler();
    }
}

- (void)keyboardWillShow:(NSNotification*)notification
{
    // don't hide controls here as keyboardWillShow will called before it's opened
    // [self hideControls];
}

- (void)keyboardDidShow:(NSNotification*)notification
{
    // remember last keyboard size updated
    CGRect keyboardRect = [[notification.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    self.lastKeyboardRect = keyboardRect;
    
    if (self.textView.isFirstResponder) {
        [self showToolbarUponKeyboard];
    } else {
        [self hideControls];
    }
}

- (void)keyboardDidChange:(NSNotification*)notification
{
    // remember last keyboard size updated
    CGRect keyboardRect = [[notification.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    self.lastKeyboardRect = keyboardRect;
    
    if (self.textView.isFirstResponder) {
        // update toolbar after its shown
        if (self.keyboardIsOpen) {
            [self showToolbarUponKeyboard];
        }
    } else {
        [self hideControls];
    }
}

- (void)keyboardWillHide:(NSNotification*)notification
{
    [self hideControls];
    
    // reset last keyboard size as empty because closed
    self.lastKeyboardRect = CGRectZero;
}

- (void)keyboardDidHide:(NSNotification*)notification
{
    [self hideControls];
    
    // reset last keyboard size as empty because closed
    self.lastKeyboardRect = CGRectZero;
}

- (void)shortenScrollViewAnimated:(BOOL)animated
{
    if (! self.scrollView) return;
    
    // restore before shorten
    // [self restoreScrollViewAnimated:NO];
    
    CGPoint textTop = CGPointMake(0, self.textView.frame.origin.y - 2);
    CGPoint textBottom = CGPointMake(0, self.textView.frame.origin.y + self.textView.frame.size.height + 2);
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
    if (paddingY < 0) return;
    
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
    
    if (! animated) {
        self.scrollView.contentInset = self.ourContentInsets;
        self.scrollView.scrollIndicatorInsets = self.ourScrollInsets;
        self.scrollView.contentOffset = newOffset;
        return;
    }
    
    // update scroll view insets with animation
    __block BOOL once = NO;
    __weak KWTextEditor *bself = self;
    [UIView animateWithDuration:KWTextEditorAnimationDuration/2 animations:^{
        bself.scrollView.contentInset = bself.ourContentInsets;
        bself.scrollView.scrollIndicatorInsets = bself.ourScrollInsets;
        bself.scrollView.contentOffset = newOffset;
    } completion:^(BOOL finished) {
        if (once) return;
        once = YES;
        // do nothing
    }];
}

- (void)restoreScrollViewAnimated:(BOOL)animated
{
    if (! self.scrollView) return;
    if (! self.hasSavedInsets) return;
    
    // test current insets are defined by us
    BOOL restoreContentInset = UIEdgeInsetsEqualToEdgeInsets(self.scrollView.contentInset, self.ourContentInsets);
    BOOL restoreScrollInset  = UIEdgeInsetsEqualToEdgeInsets(self.scrollView.scrollIndicatorInsets, self.ourScrollInsets);
    
    // no need to restore insets when changed by someone else
    if (! restoreContentInset && ! restoreScrollInset) return;
    
    if (! animated) {
        self.hasSavedInsets = NO;
        self.scrollView.contentInset = self.savedContentInsets;
        self.scrollView.scrollIndicatorInsets = self.savedScrollInsets;
        return;
    }
    
    // restore with animation
    __block BOOL once = NO;
    __weak KWTextEditor *bself = self;
    [UIView animateWithDuration:KWTextEditorAnimationDuration/2 animations:^{
        bself.scrollView.contentInset = bself.savedContentInsets;
        bself.scrollView.scrollIndicatorInsets = bself.savedScrollInsets;
        bself.scrollView.contentOffset = bself.savedContentOffset;
    } completion:^(BOOL finished) {
        if (once) return;
        once = YES;
        bself.hasSavedInsets = NO;
    }];
}

@end

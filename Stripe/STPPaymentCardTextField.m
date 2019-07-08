//
//  STPPaymentCardTextField.m
//  Stripe
//
//  Created by Jack Flintermann on 7/16/15.
//  Copyright (c) 2015 Stripe, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "STPPaymentCardTextField.h"

#import "NSArray+Stripe.h"
#import "NSString+Stripe.h"
#import "STPCardValidator+Private.h"
#import "STPFormTextField.h"
#import "STPImageLibrary.h"
#import "STPPaymentCardTextFieldViewModel.h"
#import "Stripe.h"
#import "STPLocalizationUtils.h"
#import "STPAnalyticsClient.h"

@interface STPPaymentCardTextField()<STPFormTextFieldDelegate>

@property (nonatomic, readwrite, weak) UIImageView *brandImageView;
@property (nonatomic, readwrite, weak) UIImageView *backgroundImageView;
@property (nonatomic, readwrite, weak) STPFormTextField *numberField;
@property (nonatomic, readwrite, weak) STPFormTextField *expirationField;
@property (nonatomic, readwrite, weak) STPFormTextField *cvcField;
@property (nonatomic, readwrite, weak) UILabel *numberLabel;
@property (nonatomic, readwrite, weak) UILabel *expirationLabel;
@property (nonatomic, readwrite, weak) UILabel *cvcLabel;
@property (nonatomic, readwrite, strong) STPPaymentCardTextFieldViewModel *viewModel;
@property (nonatomic, readwrite, strong) STPPaymentMethodCardParams *internalCardParams;
@property (nonatomic, strong) NSArray<UILabel *> *allLabels;
@property (nonatomic, strong) NSArray<STPFormTextField *> *allFields;
@property (nonatomic, readwrite, strong) STPFormTextField *sizingField;
@property (nonatomic, readwrite, strong) UILabel *sizingLabel;

/*
 These track the input parameters to the brand image setter so that we can
 later perform proper transition animations when new values are set
 */
@property (nonatomic, assign) STPCardFieldType currentBrandImageFieldType;
@property (nonatomic, assign) STPCardBrand currentBrandImageBrand;

/**
 This is a number-wrapped STPCardFieldType (or nil) that layout uses
 to determine how it should move/animate its subviews so that the chosen
 text field is fully visible.
 */
@property (nonatomic, copy) NSNumber *focusedTextFieldForLayout;

/*
 Creating and measuring the size of attributed strings is expensive so
 cache the values here.
 */
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *textToWidthCache;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *numberToWidthCache;

/**
 These bits lets us track beginEditing and endEditing for payment text field
 as a whole (instead of on a per-subview basis).
 
 DO NOT read this values directly. Use the return value from
 `getAndUpdateSubviewEditingTransitionStateFromCall:` which updates them all
 and returns you the correct current state for the method you are in.
 
 The state transitons in the should/did begin/end editing callbacks for all 
 our subfields. If we get a shouldEnd AND a shouldBegin before getting either's
 matching didEnd/didBegin, then we are transitioning focus between our subviews
 (and so we ourselves should not consider us to have begun or ended editing).
 
 But if we get a should and did called on their own without a matching opposite
 pair (shouldBegin/didBegin or shouldEnd/didEnd) then we are transitioning
 into/out of our subviews from/to outside of ourselves
 */
@property (nonatomic, assign) BOOL isMidSubviewEditingTransitionInternal;
@property (nonatomic, assign) BOOL receivedUnmatchedShouldBeginEditing;
@property (nonatomic, assign) BOOL receivedUnmatchedShouldEndEditing;

@end

NS_INLINE CGFloat stp_ceilCGFloat(CGFloat x) {
#if CGFLOAT_IS_DOUBLE
    return ceil(x);
#else
    return ceilf(x);
#endif
}


@implementation STPPaymentCardTextField

@synthesize font = _font;
@synthesize labelFont = _labelFont;
@synthesize textColor = _textColor;
@synthesize textErrorColor = _textErrorColor;
@synthesize placeholderColor = _placeholderColor;
@synthesize borderColor = _borderColor;
@synthesize borderWidth = _borderWidth;
@synthesize cornerRadius = _cornerRadius;
@dynamic enabled;

CGFloat const STPPaymentCardTextFieldTopPadding = 65;
CGFloat const STPPaymentCardTextFieldTextFieldHeight = 30;
CGFloat const STPPaymentCardTextFieldDefaultPadding = 20;
CGFloat const STPPaymentCardTextFieldDefaultInsets = 16;
CGFloat const STPPaymentCardTextFieldMinimumPadding = 14;

#pragma mark initializers

+ (void)initialize {
    [[STPAnalyticsClient sharedClient] addClassToProductUsageIfNecessary:[self class]];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    // We're using ivars here because UIAppearance tracks when setters are
    // called, and won't override properties that have already been customized
    _borderColor = UIColor.whiteColor;
    _cornerRadius = 10.0f;
    _borderWidth = 1.0f;
    
    self.layer.borderColor = [[_borderColor copy] CGColor];
    self.layer.cornerRadius = _cornerRadius;
    self.layer.borderWidth = _borderWidth;

    self.layer.shadowColor = [UIColor colorWithWhite:0 alpha:1].CGColor;
    self.layer.shadowOffset = CGSizeMake(0, 8);
    self.layer.shadowRadius = 18;
    self.layer.shadowOpacity = 0;

    self.clipsToBounds = NO;

    _internalCardParams = [STPPaymentMethodCardParams new];
    _viewModel = [STPPaymentCardTextFieldViewModel new];
    _sizingField = [self buildTextField];
    _sizingField.formDelegate = nil;
    _sizingLabel = [UILabel new];

    UIImageView *brandImageView = [[UIImageView alloc] init];
    brandImageView.translatesAutoresizingMaskIntoConstraints = NO;
    brandImageView.contentMode = UIViewContentModeScaleAspectFit;
    brandImageView.backgroundColor = [UIColor clearColor];
    brandImageView.tintColor = self.placeholderColor;
    self.brandImageView = brandImageView;

    UIImageView *backgroundImageView = [[UIImageView alloc] init];
    backgroundImageView.translatesAutoresizingMaskIntoConstraints = NO;
    backgroundImageView.backgroundColor = [UIColor clearColor];
    self.backgroundImageView = backgroundImageView;
    self.backgroundImageView.alpha = 0;

    UILabel *numberLabel = UILabel.new;
    numberLabel.translatesAutoresizingMaskIntoConstraints = NO;
    numberLabel.textAlignment = NSTextAlignmentLeft;
    numberLabel.textColor = UIColor.whiteColor;
    numberLabel.attributedText = [[NSAttributedString alloc] initWithString:STPLocalizedString(@"card number", @"accessibility label for text field").uppercaseString attributes:@{
            NSKernAttributeName: @(1.2)
    }];
    self.numberLabel = numberLabel;

    STPFormTextField *numberField = [self buildTextField];
    // This does not offer quick-type suggestions (as iOS 11.2), but does pick
    // the best keyboard (maybe other, hidden behavior?)
    numberField.textContentType = UITextContentTypeCreditCardNumber;
    numberField.autoFormattingBehavior = STPFormTextFieldAutoFormattingBehaviorCardNumbers;
    numberField.tag = STPCardFieldTypeNumber;
    numberField.textAlignment = NSTextAlignmentLeft;
    numberField.accessibilityLabel = STPLocalizedString(@"card number", @"accessibility label for text field");
    self.numberField = numberField;
    self.numberPlaceholder = [self.viewModel defaultPlaceholder];

    UILabel *expirationLabel = UILabel.new;
    expirationLabel.translatesAutoresizingMaskIntoConstraints = NO;
    expirationLabel.textColor = UIColor.whiteColor;
    expirationLabel.attributedText = [[NSAttributedString alloc] initWithString:STPLocalizedString(@"expiration date", @"accessibility label for text field").uppercaseString attributes:@{
            NSKernAttributeName: @(1.2)
    }];
    self.expirationLabel = expirationLabel;

    STPFormTextField *expirationField = [self buildTextField];
    expirationField.autoFormattingBehavior = STPFormTextFieldAutoFormattingBehaviorExpiration;
    expirationField.tag = STPCardFieldTypeExpiration;
    expirationField.isAccessibilityElement = NO;
    expirationField.accessibilityLabel = STPLocalizedString(@"expiration date", @"accessibility label for text field");
    self.expirationField = expirationField;
    self.expirationPlaceholder = @"–/–";

    UILabel *cvcLabel = UILabel.new;
    cvcLabel.translatesAutoresizingMaskIntoConstraints = NO;
    cvcLabel.textColor = UIColor.whiteColor;
    cvcLabel.textAlignment = NSTextAlignmentRight;
    cvcLabel.attributedText = [[NSAttributedString alloc] initWithString:[self defaultCVCPlaceholder].uppercaseString attributes:@{
            NSKernAttributeName: @(1.2)
    }];
    self.cvcLabel = cvcLabel;

    STPFormTextField *cvcField = [self buildTextField];
    cvcField.tag = STPCardFieldTypeCVC;
    cvcField.isAccessibilityElement = NO;
    cvcField.textAlignment = NSTextAlignmentRight;
    self.cvcField = cvcField;
    self.cvcPlaceholder = @"–";
    self.cvcField.accessibilityLabel = [self defaultCVCPlaceholder];


    self.allLabels = @[numberLabel, expirationLabel, cvcLabel];
    self.allFields = @[numberField, expirationField, cvcField];
    for (STPFormTextField *field in self.allFields) {
        [self addSubview:field];
    }
    for (UILabel *label in self.allLabels) {
        label.font = self.labelFont;
        [self addSubview:label];
    }
    [self addSubview:brandImageView];
    [self addSubview:backgroundImageView];
    [self sendSubviewToBack:backgroundImageView];

    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(offset)-[numberLabel]-(offset)-|" options:0 metrics:@{@"offset": @(STPPaymentCardTextFieldDefaultPadding)} views:NSDictionaryOfVariableBindings(numberLabel)]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(offset)-[numberField]-(offset)-|" options:0 metrics:@{@"offset": @(STPPaymentCardTextFieldDefaultPadding)} views:NSDictionaryOfVariableBindings(numberField)]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(offset)-[expirationLabel]-(offset)-|" options:0 metrics:@{@"offset": @(STPPaymentCardTextFieldDefaultPadding)} views:NSDictionaryOfVariableBindings(expirationLabel)]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(offset)-[cvcLabel]-(offset)-|" options:0 metrics:@{@"offset": @(STPPaymentCardTextFieldDefaultPadding)} views:NSDictionaryOfVariableBindings(cvcLabel)]];

    [self addConstraint:[NSLayoutConstraint constraintWithItem:expirationField attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:expirationLabel attribute:NSLayoutAttributeLeft multiplier:1 constant:0]];
    [self addConstraint:[NSLayoutConstraint constraintWithItem:expirationField attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:expirationLabel attribute:NSLayoutAttributeRight multiplier:0.5 constant:0]];

    [self addConstraint:[NSLayoutConstraint constraintWithItem:cvcField attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:expirationField attribute:NSLayoutAttributeRight multiplier:1 constant:0]];
    [self addConstraint:[NSLayoutConstraint constraintWithItem:cvcField attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:cvcLabel attribute:NSLayoutAttributeRight multiplier:1 constant:0]];

    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[numberLabel]-6-[numberField(height)]-24-[expirationLabel]-0-[expirationField(height)]-15-|" options:0 metrics:@{@"offset": @(STPPaymentCardTextFieldTopPadding), @"height": @(STPPaymentCardTextFieldTextFieldHeight)} views:NSDictionaryOfVariableBindings(numberLabel, numberField, expirationLabel, expirationField)]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[cvcLabel]-0-[cvcField(height)]-15-|" options:0 metrics:@{@"height": @(STPPaymentCardTextFieldTextFieldHeight)} views:NSDictionaryOfVariableBindings(cvcLabel, cvcField)]];

    [self addConstraint:[NSLayoutConstraint constraintWithItem:cvcLabel attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:expirationLabel attribute:NSLayoutAttributeTop multiplier:1 constant:0]];

    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[brandImageView(50)]-15-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(brandImageView)]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-15-[brandImageView(40)]" options:0 metrics:nil views:NSDictionaryOfVariableBindings(brandImageView)]];

    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[backgroundImageView]-0-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(backgroundImageView)]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[backgroundImageView]-0-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(backgroundImageView)]];

    brandImageView.userInteractionEnabled = YES;
    [brandImageView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:numberField
                                                                                 action:@selector(becomeFirstResponder)]];

    self.focusedTextFieldForLayout = nil;
    [self updateCVCPlaceholder];
    [self resetSubviewEditingTransitionState];
    
    self.viewModel.postalCodeRequested = YES;
}

- (STPPaymentCardTextFieldViewModel *)viewModel {
    if (_viewModel == nil) {
        _viewModel = [STPPaymentCardTextFieldViewModel new];
    }
    return _viewModel;
}

#pragma mark appearance properties

- (void)clearSizingCache {
    self.textToWidthCache = [NSMutableDictionary new];
    self.numberToWidthCache = [NSMutableDictionary new];
}

+ (UIColor *)placeholderGrayColor {
    #ifdef __IPHONE_13_0
        if (@available(iOS 13.0, *)) {
            return [UIColor systemGray2Color];
        }
    #endif
    
    return [UIColor lightGrayColor];
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    [super setBackgroundColor:[backgroundColor copy]];
    self.numberField.backgroundColor = self.backgroundColor;
}

- (UIColor *)backgroundColor {
    UIColor *defaultColor = [UIColor whiteColor];
    #ifdef __IPHONE_13_0
        if (@available(iOS 13.0, *)) {
            defaultColor = [UIColor systemBackgroundColor];
        }
    #endif
    
    return [super backgroundColor] ?: defaultColor;
}

- (UIFont *)labelFont {
    return _labelFont ?: [UIFont systemFontOfSize:12];
}

- (void)setLabelFont:(UIFont *)labelFont {
    _labelFont = [labelFont copy];

    for (UILabel *label in [self allLabels]) {
        label.font = _labelFont;
    }

    [self setNeedsLayout];
}

- (void)setFont:(UIFont *)font {
    _font = [font copy];

    for (UITextField *field in [self allFields]) {
        field.font = _font;
    }

    self.sizingField.font = _font;
    [self clearSizingCache];

    [self setNeedsLayout];
}

- (UIFont *)font {
    return _font ?: [UIFont systemFontOfSize:26 weight:UIFontWeightSemibold];
}

- (void)setTextColor:(UIColor *)textColor {
    _textColor = [textColor copy];

    for (STPFormTextField *field in [self allFields]) {
        field.defaultColor = _textColor;
    }
}

- (void)setContentVerticalAlignment:(UIControlContentVerticalAlignment)contentVerticalAlignment {
    [super setContentVerticalAlignment:contentVerticalAlignment];
    for (UITextField *field in [self allFields]) {
        field.contentVerticalAlignment = contentVerticalAlignment;
    }
}

- (UIColor *)textColor {
    UIColor *defaultColor = [UIColor blackColor];
    #ifdef __IPHONE_13_0
        if (@available(iOS 13.0, *)) {
            defaultColor = [UIColor labelColor];
        }
    #endif

    return _textColor ?: defaultColor;
}

- (void)setTextErrorColor:(UIColor *)textErrorColor {
    _textErrorColor = [textErrorColor copy];

    for (STPFormTextField *field in [self allFields]) {
        field.errorColor = _textErrorColor;
    }
}

- (UIColor *)textErrorColor {
    UIColor *defaultColor = [UIColor redColor];
    #ifdef __IPHONE_13_0
        if (@available(iOS 13.0, *)) {
            defaultColor = [UIColor systemRedColor];
        }
    #endif
    
    return _textErrorColor ?: defaultColor;
}

- (void)setPlaceholderColor:(UIColor *)placeholderColor {
    _placeholderColor = [placeholderColor copy];
    self.brandImageView.tintColor = placeholderColor;

    for (STPFormTextField *field in [self allFields]) {
        field.placeholderColor = _placeholderColor;
    }
}

- (UIColor *)placeholderColor {
    return _placeholderColor ?: UIColor.whiteColor;
}

- (void)setNumberPlaceholder:(NSString * __nullable)numberPlaceholder {
    _numberPlaceholder = [numberPlaceholder copy];
    self.numberField.placeholder = _numberPlaceholder;
}

- (void)setExpirationPlaceholder:(NSString * __nullable)expirationPlaceholder {
    _expirationPlaceholder = [expirationPlaceholder copy];
    self.expirationField.placeholder = _expirationPlaceholder;
}

- (void)setCvcPlaceholder:(NSString * __nullable)cvcPlaceholder {
    _cvcPlaceholder = [cvcPlaceholder copy];
    self.cvcField.placeholder = _cvcPlaceholder;
}


- (void)setCursorColor:(UIColor *)cursorColor {
    self.tintColor = cursorColor;
}

- (UIColor *)cursorColor {
    return self.tintColor;
}

- (void)setBorderColor:(UIColor * __nullable)borderColor {
    _borderColor = borderColor;
    if (borderColor) {
        self.layer.borderColor = [[borderColor copy] CGColor];
    } else {
        self.layer.borderColor = [[UIColor clearColor] CGColor];
    }
}

- (UIColor * __nullable)borderColor {
    return _borderColor;
}

- (void)setCornerRadius:(CGFloat)cornerRadius {
    _cornerRadius = cornerRadius;
    self.layer.cornerRadius = cornerRadius;
}

- (CGFloat)cornerRadius {
    return _cornerRadius;
}

- (void)setBorderWidth:(CGFloat)borderWidth {
    _borderWidth = borderWidth;
    self.layer.borderWidth = borderWidth;
}

- (CGFloat)borderWidth {
    return _borderWidth;
}

- (void)setKeyboardAppearance:(UIKeyboardAppearance)keyboardAppearance {
    _keyboardAppearance = keyboardAppearance;
    for (STPFormTextField *field in [self allFields]) {
        field.keyboardAppearance = keyboardAppearance;
    }
}

- (void)setInputView:(UIView *)inputView {
    _inputView = inputView;

    for (STPFormTextField *field in [self allFields]) {
        field.inputView = inputView;
    }
}

- (void)setInputAccessoryView:(UIView *)inputAccessoryView {
    _inputAccessoryView = inputAccessoryView;

    for (STPFormTextField *field in [self allFields]) {
        field.inputAccessoryView = inputAccessoryView;
    }
}

#pragma mark UIControl

- (void)setEnabled:(BOOL)enabled {
    [super setEnabled:enabled];
    for (STPFormTextField *textField in [self allFields]) {
        textField.enabled = enabled;
    }
    [self.numberLabel setHidden:!enabled];
    [self.cvcField setHidden:!enabled];
    [self.cvcLabel setHidden:!enabled];
    if (!enabled) {
        [self.expirationLabel setFont:[self.expirationLabel.font fontWithSize:10]];
        [self.expirationField setFont:[self.expirationField.font fontWithSize:12]];
    } else {
        [self.expirationLabel setFont:[self.expirationLabel.font fontWithSize:12]];
        [self.expirationField setFont:[self.expirationField.font fontWithSize:26]];
    }
}

#pragma mark UIResponder & related methods

- (BOOL)isFirstResponder {
    return self.currentFirstResponderField != nil;
}

- (BOOL)canBecomeFirstResponder {
    STPFormTextField *firstResponder = [self currentFirstResponderField] ?: [self nextFirstResponderField];
    return [firstResponder canBecomeFirstResponder];
}

- (BOOL)becomeFirstResponder {
    STPFormTextField *firstResponder = [self currentFirstResponderField] ?: [self nextFirstResponderField];
    return [firstResponder becomeFirstResponder];
}

/**
 Returns the next text field to be edited, in priority order:

 1. If we're currently in a text field, returns the next one (ignoring postalCodeField if postalCodeEntryEnabled == NO)
 2. Otherwise, returns the first invalid field (either cycling back from the end or as it gains 1st responder)
 3. As a final fallback, just returns the last field
 */
- (nonnull STPFormTextField *)nextFirstResponderField {
    STPFormTextField *currentFirstResponder = [self currentFirstResponderField];
    if (currentFirstResponder) {
        NSUInteger index = [self.allFields indexOfObject:currentFirstResponder];
        if (index != NSNotFound) {
            STPFormTextField *nextField = [self.allFields stp_boundSafeObjectAtIndex:index + 1];
            return nextField;
        }
    }

    return [self firstInvalidSubField] ?: [self lastSubField];
}

- (nullable STPFormTextField *)firstInvalidSubField {
    if ([self.viewModel validationStateForField:STPCardFieldTypeNumber] != STPCardValidationStateValid) {
        return self.numberField;
    } else if ([self.viewModel validationStateForField:STPCardFieldTypeExpiration] != STPCardValidationStateValid) {
        return self.expirationField;
    } else if ([self.viewModel validationStateForField:STPCardFieldTypeCVC] != STPCardValidationStateValid) {
        return self.cvcField;
    }
    else {
        return nil;
    }
}

- (nonnull STPFormTextField *)lastSubField {
    return self.cvcField;
}

- (STPFormTextField *)currentFirstResponderField {
    for (STPFormTextField *textField in [self allFields]) {
        if ([textField isFirstResponder]) {
            return textField;
        }
    }
    return nil;
}

- (BOOL)canResignFirstResponder {
    return [self.currentFirstResponderField canResignFirstResponder];
}

- (BOOL)resignFirstResponder {
    [super resignFirstResponder];
    return [self.currentFirstResponderField resignFirstResponder];
}

- (STPFormTextField *)previousField {
    STPFormTextField *currentSubResponder = self.currentFirstResponderField;
    if (currentSubResponder) {
        NSUInteger index = [self.allFields indexOfObject:currentSubResponder];
        if (index != NSNotFound
                && index > 0) {
            return self.allFields[index - 1];
        }
    }
    return nil;
}

#pragma mark public convenience methods

- (void)clear {
    for (STPFormTextField *field in [self allFields]) {
        field.text = @"";
    }
    self.viewModel = [STPPaymentCardTextFieldViewModel new];
    [self onChange];
    [self updateCVCPlaceholder];
    [self resignFirstResponder];
}

- (BOOL)isValid {
    return [self.viewModel isValid];
}

- (BOOL)valid {
    return self.isValid;
}

#pragma mark readonly variables

- (NSString *)cardNumber {
    return self.viewModel.cardNumber;
}

- (NSUInteger)expirationMonth {
    return [self.viewModel.expirationMonth integerValue];
}

- (NSUInteger)expirationYear {
    return [self.viewModel.expirationYear integerValue];
}

- (NSString *)formattedExpirationMonth {
    return self.viewModel.expirationMonth;
}

- (NSString *)formattedExpirationYear {
    return self.viewModel.expirationYear;
}

- (NSString *)cvc {
    return self.viewModel.cvc;
}


- (STPPaymentMethodCardParams *)cardParams {
    self.internalCardParams.number = self.cardNumber;
    self.internalCardParams.expMonth = @(self.expirationMonth);
    self.internalCardParams.expYear = @(self.expirationYear);
    self.internalCardParams.cvc = self.cvc;
    return [self.internalCardParams copy];
}

- (void)setCardParams:(STPPaymentMethodCardParams *)callersCardParams {
    /*
     Due to the way this class is written, programmatically setting field text
     behaves identically to user entering text (and will have the same forwarding 
     on to next responder logic).

     We have some custom logic here in the main accesible programmatic setter
     to dance around this a bit. First we save what is the current responder
     at the time this method was called. Later logic after text setting should be:
     1. If we were not first responder, we should still not be first responder
        (but layout might need updating depending on PAN validity)
     2. If original field is still not valid, it is still first responder
        (manually reset it back to first responder)
     3. Otherwise the first subfield with invalid text should now be first responder
     */
    //STPFormTextField *originalSubResponder = self.currentFirstResponderField;

    /*
     #1031 small footgun hiding here. Use copies to protect from mutations of
     `internalCardParams` in the `cardParams` property accessor and any mutations
     the app code might make to their `callersCardParams` object.
     */
    STPPaymentMethodCardParams *desiredCardParams = [callersCardParams copy];
    self.internalCardParams = [desiredCardParams copy];

    [self setText:desiredCardParams.number inField:STPCardFieldTypeNumber];
    BOOL expirationPresent = desiredCardParams.expMonth && desiredCardParams.expYear;
    if (expirationPresent) {
        NSString *text = [NSString stringWithFormat:@"%02lu%02lu",
                          (unsigned long)desiredCardParams.expMonth.integerValue,
                          (unsigned long)desiredCardParams.expYear.integerValue%100];
        [self setText:text inField:STPCardFieldTypeExpiration];
    } else {
        [self setText:@"" inField:STPCardFieldTypeExpiration];
    }
    [self setText:desiredCardParams.cvc inField:STPCardFieldTypeCVC];
}

- (void)setCardBrand:(STPCardBrand)cardBrand {
    _cardBrand = cardBrand;
    [self updateAppearanceForBrand:cardBrand];
}

- (void)setText:(NSString *)text inField:(STPCardFieldType)field {
    NSString *nonNilText = text ?: @"";
    STPFormTextField *textField = nil;
    switch (field) {
        case STPCardFieldTypeNumber:
            textField = self.numberField;
            break;
        case STPCardFieldTypeExpiration:
            textField = self.expirationField;
            break;
        case STPCardFieldTypeCVC:
            textField = self.cvcField;
            break;
    }
    textField.text = nonNilText;
}

- (CGFloat)numberFieldFullWidth {
    // Current longest possible pan is 16 digits which our standard sample fits
    if ([self.viewModel validationStateForField:STPCardFieldTypeNumber] == STPCardValidationStateValid) {
        return [self widthForCardNumber:self.viewModel.cardNumber];
    } else {
        return MAX([self widthForCardNumber:self.viewModel.cardNumber],
                [self widthForCardNumber:self.viewModel.defaultPlaceholder]);
    }
}

- (CGFloat)numberFieldCompressedWidth {

    NSString *cardNumber = self.cardNumber;
    if (cardNumber.length == 0) {
        cardNumber = self.viewModel.defaultPlaceholder;
    }

    STPCardBrand currentBrand = [STPCardValidator brandForNumber:cardNumber];
    NSArray<NSNumber *> *sortedCardNumberFormat = [[STPCardValidator cardNumberFormatForCardNumber:cardNumber] sortedArrayUsingSelector:@selector(unsignedIntegerValue)];
    NSUInteger fragmentLength = [STPCardValidator fragmentLengthForCardBrand:currentBrand];
    NSUInteger maxLength = MAX([[sortedCardNumberFormat lastObject] unsignedIntegerValue], fragmentLength);

    NSString *maxCompressedString = [@"" stringByPaddingToLength:maxLength withString:@"8" startingAtIndex:0];
    return [self widthForText:maxCompressedString];
}

- (CGFloat)cvcFieldWidth {
    if (self.focusedTextFieldForLayout == nil
            && [self.viewModel validationStateForField:STPCardFieldTypeCVC] == STPCardValidationStateValid) {
        // If we're not focused and have valid text, size exactly to what is entered
        return [self widthForText:self.viewModel.cvc];
    } else {
        // Otherwise size to fit our placeholder or what is likely to be the
        // largest possible string enterable (whichever is larger)
        NSInteger maxCvcLength = [STPCardValidator maxCVCLengthForCardBrand:self.viewModel.brand];
        NSString *longestCvc = @"888";
        if (maxCvcLength == 4) {
            longestCvc = @"8888";
        }

        return MAX([self widthForText:self.cvcField.placeholder], [self widthForText:longestCvc]);
    }
}

- (CGFloat)expirationFieldWidth {
    if (self.focusedTextFieldForLayout == nil
            && [self.viewModel validationStateForField:STPCardFieldTypeExpiration] == STPCardValidationStateValid) {
        // If we're not focused and have valid text, size exactly to what is entered
        return [self widthForText:self.viewModel.rawExpiration];
    } else {
        // Otherwise size to fit our placeholder or what is likely to be the
        // largest possible string enterable (whichever is larger)
        return MAX([self widthForText:self.expirationField.placeholder], [self widthForText:@"88/88"]);
    }
}

- (CGSize)intrinsicContentSize {

    CGSize imageSize = self.brandImage.size;

    self.sizingField.text = self.viewModel.defaultPlaceholder;
    [self.sizingField sizeToFit];
    CGFloat textHeight = CGRectGetHeight(self.sizingField.frame);
    CGFloat imageHeight = imageSize.height + (STPPaymentCardTextFieldDefaultInsets);
    CGFloat height = stp_ceilCGFloat((MAX(MAX(imageHeight, textHeight), 44)));

    CGFloat width = (STPPaymentCardTextFieldDefaultInsets
            + imageSize.width
            + STPPaymentCardTextFieldDefaultInsets
            + [self numberFieldFullWidth]
            + STPPaymentCardTextFieldDefaultInsets
    );

    width = stp_ceilCGFloat(width);

    return CGSizeMake(width, height);
}

typedef NS_ENUM(NSInteger, STPCardTextFieldState) {
    STPCardTextFieldStateVisible,
    STPCardTextFieldStateCompressed,
    STPCardTextFieldStateHidden,
};

- (CGFloat)minimumPaddingForViewsWithWidth:(CGFloat)width
                                       pan:(STPCardTextFieldState)panVisibility
                                    expiry:(STPCardTextFieldState)expiryVisibility
                                       cvc:(STPCardTextFieldState)cvcVisibility {

    CGFloat requiredWidth = 0;
    CGFloat paddingsRequired = -1;

    if (panVisibility != STPCardTextFieldStateHidden) {
        paddingsRequired += 1;
        requiredWidth += (panVisibility == STPCardTextFieldStateCompressed) ? [self numberFieldCompressedWidth] : [self numberFieldFullWidth];
    }

    if (expiryVisibility != STPCardTextFieldStateHidden) {
        paddingsRequired += 1;
        requiredWidth += [self expirationFieldWidth];
    }

    if (cvcVisibility != STPCardTextFieldStateHidden) {
        paddingsRequired += 1;
        requiredWidth += [self cvcFieldWidth];
    }

    if (paddingsRequired > 0) {
        return stp_ceilCGFloat(((width - requiredWidth) / paddingsRequired));
    } else {
        return STPPaymentCardTextFieldMinimumPadding;
    }
}


#pragma mark - private helper methods

- (STPFormTextField *)buildTextField {
    STPFormTextField *textField = [[STPFormTextField alloc] initWithFrame:CGRectZero];
    textField.translatesAutoresizingMaskIntoConstraints = NO;
    textField.backgroundColor = [UIColor clearColor];
    textField.keyboardType = UIKeyboardTypePhonePad;
    textField.textAlignment = NSTextAlignmentLeft;
    textField.font = self.font;
    textField.defaultColor = self.textColor;
    textField.errorColor = self.textErrorColor;
    textField.placeholderColor = self.placeholderColor;
    textField.formDelegate = self;
    textField.validText = true;
    return textField;
}

- (void)updateAppearanceForBrand:(STPCardBrand)cardBrand {
    if (self.currentBrandImageBrand != cardBrand || self.backgroundImageView.image == nil) {
        UIImage *brandImage = [self.class brandImageForCardBrand:cardBrand];
        UIImage *backgroundImage = [self.class backgroundImageForCardBrand:cardBrand];
        self.currentBrandImageBrand = cardBrand;
        if (cardBrand == STPCardBrandUnknown) {
            for (UILabel *label in self.allLabels) {
                label.textColor = UIColor.whiteColor;
            }
            [self setTextColor:UIColor.whiteColor];
            [self setPlaceholderColor:UIColor.whiteColor];
        } else {
            self.backgroundImageView.image = backgroundImage;
            if (cardBrand == STPCardBrandMasterCard) {
                [self setTextColor:UIColor.blackColor];
                [self setPlaceholderColor:UIColor.blackColor];
                for (UILabel *label in self.allLabels) {
                    label.textColor = [UIColor colorWithWhite:0 alpha:.6];
                }
            } else {
                [self setTextColor:UIColor.whiteColor];
                [self setPlaceholderColor:UIColor.whiteColor];
                for (UILabel *label in self.allLabels) {
                    label.textColor = [UIColor colorWithWhite:1 alpha:.6];
                }
            }
        }

        [CATransaction begin];
        [CATransaction setAnimationDuration:0.3f];
        [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];

        CABasicAnimation *borderWidth = [CABasicAnimation animationWithKeyPath:@"borderWidth"];
        borderWidth.fromValue = (cardBrand == STPCardBrandUnknown) ? @0 : @1;
        borderWidth.toValue = (cardBrand == STPCardBrandUnknown) ? @1 : @0;

        CABasicAnimation *opacity = [CABasicAnimation animationWithKeyPath:@"opacity"];
        opacity.fromValue = (cardBrand == STPCardBrandUnknown) ? @1 : @0;
        opacity.toValue = (cardBrand == STPCardBrandUnknown) ? @0 : @1;

        CABasicAnimation *shadowOpacity = [CABasicAnimation animationWithKeyPath:@"shadowOpacity"];
        [shadowOpacity setFillMode:kCAFillModeForwards];
        [shadowOpacity setRemovedOnCompletion:NO];
        shadowOpacity.fromValue = (cardBrand == STPCardBrandUnknown) ? @0 : @0.3;
        shadowOpacity.toValue = (cardBrand == STPCardBrandUnknown) ? @0.3 : @0;

        self.brandImageView.image = brandImage;
        CATransition *transition = [CATransition animation];
        transition.type = kCATransitionFade;
        [self.brandImageView.layer addAnimation:transition forKey:nil];

        self.layer.borderWidth = [borderWidth.toValue floatValue];
        self.backgroundImageView.layer.opacity = [opacity.toValue floatValue];
        self.layer.shadowOpacity = [shadowOpacity.toValue floatValue];
        [self.layer addAnimation:borderWidth forKey:@"borderWidth"];
        [self.backgroundImageView.layer addAnimation:opacity forKey:@"opacity"];
        [self.layer addAnimation:shadowOpacity forKey:@"shadowOpacity"];

        [CATransaction commit];
    }
}

typedef void (^STPLayoutAnimationCompletionBlock)(BOOL completed);
- (void)layoutViewsToFocusField:(NSNumber *)focusedField
                     completion:(STPLayoutAnimationCompletionBlock)completion {

    NSNumber *fieldtoFocus = focusedField;

    if (fieldtoFocus == nil
            && ![self.focusedTextFieldForLayout isEqualToNumber:@(STPCardFieldTypeNumber)]
            && ([self.viewModel validationStateForField:STPCardFieldTypeNumber] != STPCardValidationStateValid)) {
        fieldtoFocus = @(STPCardFieldTypeNumber);
        [self.numberField becomeFirstResponder];
    }

    if ((fieldtoFocus == nil && self.focusedTextFieldForLayout == nil)
            || (fieldtoFocus != nil && [self.focusedTextFieldForLayout isEqualToNumber:fieldtoFocus])
            ) {
        if (completion) {
            completion(YES);
        }
        return;
    }

    self.focusedTextFieldForLayout = fieldtoFocus;
}

- (CGFloat)widthForAttributedText:(NSAttributedString *)attributedText {
    // UITextField doesn't seem to size correctly here for unknown reasons
    // But UILabel reliably calculates size correctly using this method
    self.sizingLabel.attributedText = attributedText;
    [self.sizingLabel sizeToFit];
    return stp_ceilCGFloat((CGRectGetWidth(self.sizingLabel.bounds)));

}

- (CGFloat)widthForText:(NSString *)text {
    if (text.length == 0) {
        return 0;
    }

    NSNumber *cachedValue = self.textToWidthCache[text];
    if (cachedValue == nil) {
        self.sizingField.autoFormattingBehavior = STPFormTextFieldAutoFormattingBehaviorNone;
        [self.sizingField setText:STPNonLocalizedString(text)];
        cachedValue = @([self widthForAttributedText:self.sizingField.attributedText]);
        self.textToWidthCache[text] = cachedValue;
    }
    return (CGFloat)[cachedValue doubleValue];
}

- (CGFloat)widthForCardNumber:(NSString *)cardNumber {
    if (cardNumber.length == 0) {
        return 0;
    }

    NSNumber *cachedValue = self.numberToWidthCache[cardNumber];
    if (cachedValue == nil) {
        self.sizingField.autoFormattingBehavior = STPFormTextFieldAutoFormattingBehaviorCardNumbers;
        [self.sizingField setText:cardNumber];
        cachedValue = @([self widthForAttributedText:self.sizingField.attributedText]);
        self.numberToWidthCache[cardNumber] = cachedValue;
    }
    return (CGFloat)[cachedValue doubleValue];
}

#pragma mark STPFormTextFieldDelegate

- (void)formTextFieldDidBackspaceOnEmpty:(__unused STPFormTextField *)formTextField {
    STPFormTextField *previous = [self previousField];
    [previous becomeFirstResponder];
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, nil);
    if (previous.hasText) {
        [previous deleteBackward];
    }
}

- (NSAttributedString *)formTextField:(STPFormTextField *)formTextField
             modifyIncomingTextChange:(NSAttributedString *)input {
    STPCardFieldType fieldType = formTextField.tag;
    switch (fieldType) {
        case STPCardFieldTypeNumber:
            self.viewModel.cardNumber = input.string;
            [self setNeedsLayout];
            break;
        case STPCardFieldTypeExpiration:
            self.viewModel.rawExpiration = input.string;
            break;
        case STPCardFieldTypeCVC:
            self.viewModel.cvc = input.string;
            break;
    }

    switch (fieldType) {
        case STPCardFieldTypeNumber:
            return [[NSAttributedString alloc] initWithString:self.viewModel.cardNumber
                                                   attributes:self.numberField.defaultTextAttributes];
        case STPCardFieldTypeExpiration:
            return [[NSAttributedString alloc] initWithString:self.viewModel.rawExpiration
                                                   attributes:self.expirationField.defaultTextAttributes];
        case STPCardFieldTypeCVC:
            return [[NSAttributedString alloc] initWithString:self.viewModel.cvc
                                                   attributes:self.cvcField.defaultTextAttributes];
    }
}

- (void)formTextFieldTextDidChange:(STPFormTextField *)formTextField {
    STPCardFieldType fieldType = formTextField.tag;
    if (fieldType == STPCardFieldTypeNumber) {
        [self updateAppearanceForBrand:self.viewModel.brand];
        [self updateCVCPlaceholder];
        // Changing the card number field can invalidate the cvc, e.g. going from 4 digit Amex cvc to 3 digit Visa
        self.cvcField.validText = [self.viewModel validationStateForField:STPCardFieldTypeCVC] != STPCardValidationStateInvalid;
    }

    STPCardValidationState state = [self.viewModel validationStateForField:fieldType];
    formTextField.validText = YES;
    switch (state) {
        case STPCardValidationStateInvalid:
            formTextField.validText = NO;
            break;
        case STPCardValidationStateIncomplete:
            break;
        case STPCardValidationStateValid: {
            if (fieldType == STPCardFieldTypeCVC) {
                /*
                 Even though any CVC longer than the min required CVC length 
                 is valid, we don't want to forward on to the next field
                 unless it is actually >= the max cvc length (otherwise when
                 postal code is showing, you can't easily enter CVCs longer than
                 the minimum.
                 */
                NSString *sanitizedCvc = [STPCardValidator sanitizedNumericStringForString:formTextField.text];
                if (sanitizedCvc.length < [STPCardValidator maxCVCLengthForCardBrand:self.viewModel.brand]) {
                    break;
                }
            } else {
                break;
            }

            // This is a no-op if this is the last field & they're all valid
            if (self.window != nil) {
                [[self nextFirstResponderField] becomeFirstResponder];
            }
            break;
        }
    }

    [self onChange];
}

typedef NS_ENUM(NSInteger, STPFieldEditingTransitionCallSite) {
    STPFieldEditingTransitionCallSiteShouldBegin,
    STPFieldEditingTransitionCallSiteShouldEnd,
    STPFieldEditingTransitionCallSiteDidBegin,
    STPFieldEditingTransitionCallSiteDidEnd,
};

// Explanation of the logic here is with the definition of these properties
// at the top of this file
- (BOOL)getAndUpdateSubviewEditingTransitionStateFromCall:(STPFieldEditingTransitionCallSite)sendingMethod {
    BOOL stateToReturn;
    switch (sendingMethod) {
        case STPFieldEditingTransitionCallSiteShouldBegin:
            self.receivedUnmatchedShouldBeginEditing = YES;
            if (self.receivedUnmatchedShouldEndEditing) {
                self.isMidSubviewEditingTransitionInternal = YES;
            }
            stateToReturn = self.isMidSubviewEditingTransitionInternal;
            break;
        case STPFieldEditingTransitionCallSiteShouldEnd:
            self.receivedUnmatchedShouldEndEditing = YES;
            if (self.receivedUnmatchedShouldBeginEditing) {
                self.isMidSubviewEditingTransitionInternal = YES;
            }
            stateToReturn = self.isMidSubviewEditingTransitionInternal;
            break;
        case STPFieldEditingTransitionCallSiteDidBegin:
            stateToReturn = self.isMidSubviewEditingTransitionInternal;
            self.receivedUnmatchedShouldBeginEditing = NO;

            if (self.receivedUnmatchedShouldEndEditing == NO) {
                self.isMidSubviewEditingTransitionInternal = NO;
            }
            break;
        case STPFieldEditingTransitionCallSiteDidEnd:
            stateToReturn = self.isMidSubviewEditingTransitionInternal;
            self.receivedUnmatchedShouldEndEditing = NO;

            if (self.receivedUnmatchedShouldBeginEditing == NO) {
                self.isMidSubviewEditingTransitionInternal = NO;
            }
            break;
    }

    return stateToReturn;
}


- (void)resetSubviewEditingTransitionState {
    self.isMidSubviewEditingTransitionInternal = NO;
    self.receivedUnmatchedShouldBeginEditing = NO;
    self.receivedUnmatchedShouldEndEditing = NO;
}

- (BOOL)textFieldShouldBeginEditing:(__unused UITextField *)textField {
    [self getAndUpdateSubviewEditingTransitionStateFromCall:STPFieldEditingTransitionCallSiteShouldBegin];
    return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    BOOL isMidSubviewEditingTransition = [self getAndUpdateSubviewEditingTransitionStateFromCall:STPFieldEditingTransitionCallSiteDidBegin];

    [self layoutViewsToFocusField:@(textField.tag)
                       completion:nil];

    if (!isMidSubviewEditingTransition) {
        if ([self.delegate respondsToSelector:@selector(paymentCardTextFieldDidBeginEditing:)]) {
            [self.delegate paymentCardTextFieldDidBeginEditing:self];
        }
    }

    switch ((STPCardFieldType)textField.tag) {
        case STPCardFieldTypeNumber:
            ((STPFormTextField *)textField).validText = YES;
            if ([self.delegate respondsToSelector:@selector(paymentCardTextFieldDidBeginEditingNumber:)]) {
                [self.delegate paymentCardTextFieldDidBeginEditingNumber:self];
            }
            break;
        case STPCardFieldTypeCVC:
            if ([self.delegate respondsToSelector:@selector(paymentCardTextFieldDidBeginEditingCVC:)]) {
                [self.delegate paymentCardTextFieldDidBeginEditingCVC:self];
            }
            break;
        case STPCardFieldTypeExpiration:
            if ([self.delegate respondsToSelector:@selector(paymentCardTextFieldDidBeginEditingExpiration:)]) {
                [self.delegate paymentCardTextFieldDidBeginEditingExpiration:self];
            }
            break;
    }
}

- (BOOL)textFieldShouldEndEditing:(__unused UITextField *)textField {
    [self getAndUpdateSubviewEditingTransitionStateFromCall:STPFieldEditingTransitionCallSiteShouldEnd];
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    BOOL isMidSubviewEditingTransition = [self getAndUpdateSubviewEditingTransitionStateFromCall:STPFieldEditingTransitionCallSiteDidEnd];

    switch ((STPCardFieldType)textField.tag) {
        case STPCardFieldTypeNumber:
            if ([self.viewModel validationStateForField:STPCardFieldTypeNumber] == STPCardValidationStateIncomplete) {
                ((STPFormTextField *)textField).validText = NO;
            }
            if ([self.delegate respondsToSelector:@selector(paymentCardTextFieldDidEndEditingNumber:)]) {
                [self.delegate paymentCardTextFieldDidEndEditingNumber:self];
            }
            break;
        case STPCardFieldTypeCVC:
            if ([self.delegate respondsToSelector:@selector(paymentCardTextFieldDidEndEditingCVC:)]) {
                [self.delegate paymentCardTextFieldDidEndEditingCVC:self];
            }
            break;
        case STPCardFieldTypeExpiration:
            if ([self.delegate respondsToSelector:@selector(paymentCardTextFieldDidEndEditingExpiration:)]) {
                [self.delegate paymentCardTextFieldDidEndEditingExpiration:self];
            }
            break;
    }

    if (!isMidSubviewEditingTransition) {
        [self layoutViewsToFocusField:nil
                           completion:nil];
        if ([self.delegate respondsToSelector:@selector(paymentCardTextFieldDidEndEditing:)]) {
            [self.delegate paymentCardTextFieldDidEndEditing:self];
        }
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == [self lastSubField] && [self firstInvalidSubField] == nil) {
        // User pressed return in the last field, and all fields are valid
        if ([self.delegate respondsToSelector:@selector(paymentCardTextFieldWillEndEditingForReturn:)]) {
            [self.delegate paymentCardTextFieldWillEndEditingForReturn:self];
        }
        [self resignFirstResponder];
    } else {
        // otherwise, move to the next field
        [[self nextFirstResponderField] becomeFirstResponder];
        UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, nil);
    }

    return NO;
}

- (UIImage *)brandImage {
    STPCardFieldType fieldType = STPCardFieldTypeNumber;
    if (self.currentFirstResponderField) {
        fieldType = self.currentFirstResponderField.tag;
    }
    STPCardValidationState validationState = [self.viewModel validationStateForField:fieldType];
    return [self brandImageForFieldType:fieldType validationState:validationState];
}

+ (UIImage *)cvcImageForCardBrand:(STPCardBrand)cardBrand {
    return [STPImageLibrary cvcImageForCardBrand:cardBrand];
}

+ (UIImage *)brandImageForCardBrand:(STPCardBrand)cardBrand {
    return [STPImageLibrary brandImageForCardBrand:cardBrand];
}

+ (nullable UIImage *)backgroundImageForCardBrand:(STPCardBrand)brand {
    return [STPImageLibrary backgroundImageForCardBrand:brand];
}

+ (UIImage *)errorImageForCardBrand:(STPCardBrand)cardBrand {
    return [STPImageLibrary errorImageForCardBrand:cardBrand];
}

- (UIImage *)brandImageForFieldType:(STPCardFieldType)fieldType validationState:(STPCardValidationState)validationState {
    switch (fieldType) {
        case STPCardFieldTypeNumber:
            if (validationState == STPCardValidationStateInvalid) {
                return [self.class errorImageForCardBrand:self.viewModel.brand];
            } else {
                return [self.class brandImageForCardBrand:self.viewModel.brand];
            }
        case STPCardFieldTypeCVC:
            return [self.class cvcImageForCardBrand:self.viewModel.brand];
        case STPCardFieldTypeExpiration:
            return [self.class brandImageForCardBrand:self.viewModel.brand];
    }
}

- (UIViewAnimationOptions)brandImageAnimationOptionsForNewType:(STPCardFieldType)newType
                                                      newBrand:(STPCardBrand)newBrand
                                                       oldType:(STPCardFieldType)oldType
                                                      oldBrand:(STPCardBrand)oldBrand {

    if (newType == STPCardFieldTypeCVC
            && oldType != STPCardFieldTypeCVC) {
        // Transitioning to show CVC

        if (newBrand != STPCardBrandAmex) {
            // CVC is on the back
            return (UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionTransitionFlipFromRight);
        }
    } else if (newType != STPCardFieldTypeCVC
             && oldType == STPCardFieldTypeCVC) {
        // Transitioning to stop showing CVC

        if (oldBrand != STPCardBrandAmex) {
            // CVC was on the back
            return (UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionTransitionFlipFromLeft);
        }
    }

    // All other cases just cross dissolve
    return (UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionTransitionCrossDissolve);

}

- (NSString *)defaultCVCPlaceholder {
    if (self.viewModel.brand == STPCardBrandAmex) {
        return STPLocalizedString(@"CVV", @"Label for entering CVV in text field");
    } else {
        return STPLocalizedString(@"CVC", @"Label for entering CVC in text field");
    }
}

- (void)updateCVCPlaceholder {
    if (self.cvcPlaceholder) {
        self.cvcField.placeholder = self.cvcPlaceholder;
        self.cvcField.accessibilityLabel = self.cvcPlaceholder;
    } else {
        self.cvcField.placeholder = [self defaultCVCPlaceholder];
        self.cvcField.accessibilityLabel = [self defaultCVCPlaceholder];
    }
}

- (void)onChange {
    if ([self.delegate respondsToSelector:@selector(paymentCardTextFieldDidChange:)]) {
        [self.delegate paymentCardTextFieldDidChange:self];
    }
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}

#pragma mark UIKeyInput

- (BOOL)hasText {
    return self.numberField.hasText || self.expirationField.hasText || self.cvcField.hasText;
}

- (void)insertText:(NSString *)text {
    [self.currentFirstResponderField insertText:text];
}

- (void)deleteBackward {
    [self.currentFirstResponderField deleteBackward];
}

+ (NSSet<NSString *> *)keyPathsForValuesAffectingIsValid {
    return [NSSet setWithArray:@[
            [NSString stringWithFormat:@"%@.%@",
                                       NSStringFromSelector(@selector(viewModel)),
                                       NSStringFromSelector(@selector(valid))],
    ]];
}

@end

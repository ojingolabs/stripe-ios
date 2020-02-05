//
//  CardExampleViewController.m
//  Custom Integration (ObjC)
//
//  Created by Ben Guo on 2/22/17.
//  Copyright © 2017 Stripe. All rights reserved.
//

#import <Stripe/Stripe.h>
#import "CardExampleViewController.h"
#import "BrowseExamplesViewController.h"

/**
 This example demonstrates creating a payment with a credit/debit card. It creates a token
 using card information collected with STPPaymentCardTextField, and then sends the token
 to our example backend to create the charge request.
 */
@interface CardExampleViewController () <STPPaymentCardTextFieldDelegate, UIScrollViewDelegate>
@property (weak, nonatomic) STPPaymentCardTextField *paymentTextField;
@property (weak, nonatomic) UIActivityIndicatorView *activityIndicator;
@property (weak, nonatomic) UIScrollView *scrollView;
@end

@implementation CardExampleViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Card";
    self.view.backgroundColor = [UIColor darkGrayColor];

    UIBarButtonItem *buyButton = [[UIBarButtonItem alloc] initWithTitle:@"Pay" style:UIBarButtonItemStyleDone target:self action:@selector(pay)];
    buyButton.enabled = NO;
    self.navigationItem.rightBarButtonItem = buyButton;

    STPPaymentCardTextField *paymentTextField = [[STPPaymentCardTextField alloc] init];
    paymentTextField.translatesAutoresizingMaskIntoConstraints = NO;
    paymentTextField.delegate = self;
    paymentTextField.cursorColor = [UIColor whiteColor];
    /*STPCardParams *cardParams = [[STPCardParams alloc] init];
    cardParams.expMonth = 04;
    cardParams.expYear = 22;
    [paymentTextField setCardParams:cardParams];
    [paymentTextField setCardBrand:STPCardBrandMasterCard];
    [paymentTextField setNumberPlaceholder:@"•••• •••• •••• 4242"];
    [paymentTextField setExpirationPlaceholder:@"04/22"];
    [paymentTextField setEnabled:NO];*/
    self.paymentTextField = paymentTextField;
    [self.view addSubview:paymentTextField];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-15-[paymentTextField]-15-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(paymentTextField)]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-15-[paymentTextField(188)]" options:0 metrics:nil views:NSDictionaryOfVariableBindings(paymentTextField)]];


    UIActivityIndicatorView *activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    activityIndicator.hidesWhenStopped = YES;
    self.activityIndicator = activityIndicator;
    [self.view addSubview:activityIndicator];

    [self.view addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap)]];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat padding = 15;
    CGRect bounds = self.view.bounds;
    self.activityIndicator.center = CGPointMake(CGRectGetMidX(bounds),
                                                CGRectGetMaxY(self.paymentTextField.frame) + padding*2);
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)paymentCardTextFieldDidChange:(nonnull STPPaymentCardTextField *)textField {
    self.navigationItem.rightBarButtonItem.enabled = textField.isValid;
}

- (void)pay {
    if (![self.paymentTextField isValid]) {
        return;
    }
    if (![Stripe defaultPublishableKey]) {
        [self.delegate exampleViewController:self didFinishWithMessage:@"Please set a Stripe Publishable Key in Constants.m"];
        return;
    }
    [self.activityIndicator startAnimating];
    [[STPAPIClient sharedClient] createTokenWithCard:self.paymentTextField.cardParams
                                          completion:^(STPToken *token, NSError *error) {
                                              if (error) {
                                                  [self.delegate exampleViewController:self didFinishWithError:error];
                                              }
                                              [self.delegate createBackendChargeWithSource:token.tokenId completion:^(STPBackendResult result, NSError *error) {
                                                  if (error) {
                                                      [self.delegate exampleViewController:self didFinishWithError:error];
                                                      return;
                                                  }
                                                  [self.delegate exampleViewController:self didFinishWithMessage:@"Payment successfully created"];
                                              }];
                                          }];
}

- (void)onTap {
    [self.view endEditing:NO];
}

@end

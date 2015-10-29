//
//  STPAPIClient.h
//  StripeExample
//
//  Created by Jack Flintermann on 12/18/14.
//  Copyright (c) 2014 Stripe. All rights reserved.
//

#import <Foundation/Foundation.h>

static NSString *const __nonnull STPSDKVersion = @"6.0.1";

@class STPBankAccount, STPBankAccountParams, STPCard, STPCardParams, STPToken, STPProduct, STPCustomer, STPOrder, STPShippingInfos, STPOrderItem, STPSku;;

/**
 *  A callback to be run with a token response from the Stripe API.
 *
 *  @param object The Stripe object from the response. Will be nil if an error occurs. @see STPToken, STPProduct, STPOrder, STPCustomer
 *  @param error The error returned from the response, or nil in one occurs. @see StripeError.h for possible values.
 */
typedef void (^STPCompletionBlock)(id __nullable object, NSError * __nullable error);
typedef void (^STPTokenCompletionBlock)(STPToken * __nullable token, NSError * __nullable error);

/**
 A top-level class that imports the rest of the Stripe SDK. This class used to contain several methods to create Stripe tokens, but those are now deprecated in
 favor of STPAPIClient.
 */
@interface Stripe : NSObject

/**
 *  Set your Stripe API key with this method. New instances of STPAPIClient will be initialized with this value. You should call this method as early as
 *  possible in your application's lifecycle, preferably in your AppDelegate.
 *
 *  @param   publishableKey Your publishable key, obtained from https://stripe.com/account/apikeys
 *  @warning Make sure not to ship your test API keys to the App Store! This will log a warning if you use your test key in a release build.
 */
+ (void)setDefaultPublishableKey:(nonnull NSString *)publishableKey;

/// The current default publishable key.
+ (nullable NSString *)defaultPublishableKey;

+ (void)setDefaultSecretKey:(nonnull NSString *)secretKey;
+ (nullable NSString *)defaultSecretKey;
@end

/// A client for making connections to the Stripe API.
@interface STPAPIClient : NSObject

/**
 *  A shared singleton API client. Its API key will be initially equal to [Stripe defaultPublishableKey].
 */
+ (nonnull instancetype)sharedClient;
- (nonnull instancetype)initWithPublishableKey:(nonnull NSString *)publishableKey;
- (nonnull instancetype)initWithPublishableKey:(nonnull NSString *)publishableKey andSecretKey:(nonnull NSString*)secretKey NS_DESIGNATED_INITIALIZER;

/**
 *  @see [Stripe setDefaultPublishableKey:]
 */
@property (nonatomic, copy, nullable) NSString *publishableKey;

@property (nonatomic, copy, nullable) NSString *secretKey;

/**
 *  The operation queue on which to run completion blocks passed to the api client. Defaults to [NSOperationQueue mainQueue].
 */
@property (nonatomic, nonnull) NSOperationQueue *operationQueue;

@end

#pragma mark Bank Accounts

@interface STPAPIClient (BankAccounts)

/**
 *  Converts an STPBankAccount object into a Stripe token using the Stripe API.
 *
 *  @param bankAccount The user's bank account details. Cannot be nil. @see https://stripe.com/docs/api#create_bank_account_token
 *  @param completion  The callback to run with the returned Stripe token (and any errors that may have occurred).
 */
- (void)createTokenWithBankAccount:(nonnull STPBankAccountParams *)bankAccount completion:(__nullable STPTokenCompletionBlock)completion;

@end

#pragma mark Credit Cards

@interface STPAPIClient (CreditCards)

/**
 *  Converts an STPCardParams object into a Stripe token using the Stripe API.
 *
 *  @param card        The user's card details. Cannot be nil. @see https://stripe.com/docs/api#create_card_token
 *  @param completion  The callback to run with the returned Stripe token (and any errors that may have occurred).
 */
- (void)createTokenWithCard:(nonnull STPCardParams *)card completion:(nullable STPTokenCompletionBlock)completion;

- (void)listCardsForCustomer:(nonnull STPCustomer *)customer limit:(NSInteger)limit before:(nullable NSString*)beforeID after:(nullable NSString*)afterID completion:(nullable STPCompletionBlock)completion;

- (void)retrieveCard:(nonnull NSString*)cardID forCustomer:(nonnull STPCustomer*)customer completion:(nullable STPCompletionBlock)completion;

- (void)deleteCard:(nonnull NSString*)cardID forCustomer:(nonnull STPCustomer*)customer completion:(nullable STPCompletionBlock)completion;

@end

#pragma mark Products

@interface STPAPIClient (Products)

/**
 * Returns a NSArray of STPProduct*
 */
- (void)listProductsFromAccount:(nullable NSString*)stripeAccount limit:(NSInteger)limit before:(nullable NSString*)before after:(nullable NSString*)after completion:(nullable STPCompletionBlock)completion;

/**
 * Returns a STPProduct
 */
- (void)retrieveProductFromAccount:(nullable NSString*)stripeAccount product:(nonnull NSString*)productId completion:(nullable STPCompletionBlock)completion;

@end

#pragma mark Customer

@interface STPAPIClient (Customer)

/**
 * Returns a STPCustomer
 */
- (void)createCustomer:(nonnull NSString*)email shipping:(nullable STPShippingInfos *)shippingAddress source:(nullable STPToken*)source completion:(nullable STPCompletionBlock)completion;

/**
 * Returns a STPCustomer
 */
- (void)retrieveCustomer:(nonnull NSString*)customerId completion:(nullable STPCompletionBlock)completion;

/**
 *
 * Update the customer in Stripe with the infos pre-filled in the STPCustomer parameter 'customer'.
 * Returns an updated STPCustomer (same object in the good case)
 *
 */
- (void)updateCustomer:(nonnull STPCustomer*)customer completion:(nullable STPCompletionBlock)completion;

/**
 *
 * Attach a token to an existing customer
 * Returns an updated STPCustomer
 *
 */
- (void)addToken:(nonnull STPToken*)token toCustomer:(nonnull NSString*)customerId completion:(nullable STPCompletionBlock)completion;

@end

#pragma mark Orders

@interface STPAPIClient (Orders)

/**
 * Utility method
 */

+ (nonnull STPOrderItem*)createOrderItemFromSku:(nonnull STPSku*)sku andQuantity:(NSInteger)quantity;

/**
 * Returns a STPOrder object
 */
- (void)createOrderFromAccount:(nullable NSString*)stripeAccount customer:(nonnull STPCustomer*)customer currency:(nonnull NSString*)currency items:(nonnull NSArray<STPOrderItem *>*)items completion:(nullable STPCompletionBlock)completion;

/**
 * Returns a STPOrder object
 */
- (void)retrieveOrderFromAccount:(nullable NSString*)stripeAccount orderId:(nonnull NSString*)orderId completion:(nullable STPCompletionBlock)completion;

/**
 *
 * Updates the specific order by setting the values of the parameters passed.
 * Any parameters not provided will be left unchanged.
 * This request accepts only the `metadata`, `selected_shipping_method` and `status` as arguments.
 *
 * Update the order in Stripe with the infos pre-filled in the STPOrder parameter 'order'.
 * Returns an updated STPOrder
 *
 *
 */
- (void)updateOrderFromAccount:(nullable NSString*)stripeAccount order:(nonnull STPOrder*)order completion:(nullable STPCompletionBlock)completion;

/**
 * Pay an order by providing a source to create a payment.

 * Pay a giving order using the  `default_source` ID of the associated customer.
 * Returns an updated STPOrder
 */
- (void)payOrderFromAccount:(nullable NSString*)stripeAccount order:(nonnull STPOrder*)order cardId:(nullable NSString*)cardId applicationFee:(nullable NSString*)appFee completion:(nullable STPCompletionBlock)completion;

@end


// These methods are used internally and exposed here only for the sake of writing tests more easily. You should not use them in your own application.
@interface STPAPIClient (PrivateMethods)

- (void)createTokenWithData:(nonnull NSData *)data completion:(nullable STPCompletionBlock)completion;
#pragma mark - Deprecated Methods

/**
 *  A callback to be run with a token response from the Stripe API.
 *
 *  @param token The Stripe token from the response. Will be nil if an error occurs. @see STPToken
 *  @param error The error returned from the response, or nil in one occurs. @see StripeError.h for possible values.
 *  @deprecated This has been renamed to STPTokenCompletionBlock.
 */
typedef void (^STPCompletionBlock)(STPToken * __nullable token, NSError * __nullable error) __attribute__((deprecated("STPCompletionBlock has been renamed to STPTokenCompletionBlock.")));

// These methods are deprecated. You should instead use STPAPIClient to create tokens.
// Example: [Stripe createTokenWithCard:card completion:completion];
// becomes [[STPAPIClient sharedClient] createTokenWithCard:card completion:completion];
@interface Stripe (Deprecated)

/**
 *  Securely convert your user's credit card details into a Stripe token, which you can then safely store on your server and use to charge the user. The URL
 *connection will run on the main queue. Uses the value of [Stripe defaultPublishableKey] for authentication.
 *
 *  @param card    The user's card details. @see STPCard
 *  @param handler Code to run when the user's card has been turned into a Stripe token.
 *  @deprecated    Use STPAPIClient instead.
 */
+ (void)createTokenWithCard:(nonnull STPCard *)card completion:(nullable STPCompletionBlock)handler __attribute__((deprecated));

/**
 *  Securely convert your user's credit card details into a Stripe token, which you can then safely store on your server and use to charge the user. The URL
 *connection will run on the main queue.
 *
 *  @param card           The user's card details. @see STPCard
 *  @param publishableKey The API key to use to authenticate with Stripe. Get this at https://stripe.com/account/apikeys .
 *  @param handler        Code to run when the user's card has been turned into a Stripe token.
 *  @deprecated           Use STPAPIClient instead.
 */
+ (void)createTokenWithCard:(nonnull STPCard *)card publishableKey:(nonnull NSString *)publishableKey completion:(nullable STPCompletionBlock)handler __attribute__((deprecated));

/**
 *  Securely convert your user's credit card details into a Stripe token, which you can then safely store on your server and use to charge the user.
 *
 *  @param card    The user's card details. @see STPCard
 *  @param queue   The operation queue on which to run completion blocks passed to the api client. 
 *  @param handler Code to run when the user's card has been turned into a Stripe token.
 *  @deprecated    Use STPAPIClient instead.
 */
+ (void)createTokenWithCard:(nonnull STPCard *)card operationQueue:(nonnull NSOperationQueue *)queue completion:(nullable STPCompletionBlock)handler __attribute__((deprecated));

/**
 *  Securely convert your user's credit card details into a Stripe token, which you can then safely store on your server and use to charge the user.
 *
 *  @param card           The user's card details. @see STPCard
 *  @param publishableKey The API key to use to authenticate with Stripe. Get this at https://stripe.com/account/apikeys .
 *  @param queue          The operation queue on which to run completion blocks passed to the api client. 
 *  @param handler        Code to run when the user's card has been turned into a Stripe token.
 *  @deprecated           Use STPAPIClient instead.
 */
+ (void)createTokenWithCard:(nonnull STPCard *)card
             publishableKey:(nonnull NSString *)publishableKey
             operationQueue:(nonnull NSOperationQueue *)queue
                 completion:(nullable STPCompletionBlock)handler __attribute__((deprecated));

/**
 *  Securely convert your user's credit card details into a Stripe token, which you can then safely store on your server and use to charge the user. The URL
 *connection will run on the main queue. Uses the value of [Stripe defaultPublishableKey] for authentication.
 *
 *  @param bankAccount The user's bank account details. @see STPBankAccount
 *  @param handler     Code to run when the user's card has been turned into a Stripe token.
 *  @deprecated        Use STPAPIClient instead.
 */
+ (void)createTokenWithBankAccount:(nonnull STPBankAccount *)bankAccount completion:(nullable STPCompletionBlock)handler __attribute__((deprecated));

/**
 *  Securely convert your user's credit card details into a Stripe token, which you can then safely store on your server and use to charge the user. The URL
 *connection will run on the main queue. Uses the value of [Stripe defaultPublishableKey] for authentication.
 *
 *  @param bankAccount    The user's bank account details. @see STPBankAccount
 *  @param publishableKey The API key to use to authenticate with Stripe. Get this at https://stripe.com/account/apikeys .
 *  @param handler        Code to run when the user's card has been turned into a Stripe token.
 *  @deprecated           Use STPAPIClient instead.
 */
+ (void)createTokenWithBankAccount:(nonnull STPBankAccount *)bankAccount
                    publishableKey:(nonnull NSString *)publishableKey
                        completion:(nullable STPCompletionBlock)handler __attribute__((deprecated));

/**
 *  Securely convert your user's credit card details into a Stripe token, which you can then safely store on your server and use to charge the user. The URL
 *connection will run on the main queue. Uses the value of [Stripe defaultPublishableKey] for authentication.
 *
 *  @param bankAccount The user's bank account details. @see STPBankAccount
 *  @param queue       The operation queue on which to run completion blocks passed to the api client. 
 *  @param handler     Code to run when the user's card has been turned into a Stripe token.
 *  @deprecated        Use STPAPIClient instead.
 */
+ (void)createTokenWithBankAccount:(nonnull STPBankAccount *)bankAccount
                    operationQueue:(nonnull NSOperationQueue *)queue
                        completion:(nullable STPCompletionBlock)handler __attribute__((deprecated));

/**
 *  Securely convert your user's credit card details into a Stripe token, which you can then safely store on your server and use to charge the user. The URL
 *connection will run on the main queue. Uses the value of [Stripe defaultPublishableKey] for authentication.
 *
 *  @param bankAccount    The user's bank account details. @see STPBankAccount
 *  @param publishableKey The API key to use to authenticate with Stripe. Get this at https://stripe.com/account/apikeys .
 *  @param queue          The operation queue on which to run completion blocks passed to the api client. 
 *  @param handler        Code to run when the user's card has been turned into a Stripe token.
 *  @deprecated           Use STPAPIClient instead.
 */
+ (void)createTokenWithBankAccount:(nonnull STPBankAccount *)bankAccount
                    publishableKey:(nonnull NSString *)publishableKey
                    operationQueue:(nonnull NSOperationQueue *)queue
                        completion:(nullable STPCompletionBlock)handler __attribute__((deprecated));

@end

//
//  STPAPIClient.m
//  StripeExample
//
//  Created by Jack Flintermann on 12/18/14.
//  Copyright (c) 2014 Stripe. All rights reserved.
//

#import "TargetConditionals.h"
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#import <sys/utsname.h>
#endif

#import "STPAPIClient.h"
#import "STPAPIConnection.h"
#import "STPFormEncoder.h"
#import "STPBankAccount.h"
#import "STPCard.h"
#import "STPToken.h"
#import "STPProduct.h"
#import "STPCustomer.h"
#import "StripeError.h"
#import "STPShippingInfos.h"
#import "STPOrder.h"
#import "STPOrderItem.h"
#import "STPSku.h"

#define FAUXPAS_IGNORED_IN_METHOD(...)

static NSString *const apiURLBase = @"api.stripe.com";
static NSString *const apiVersion = @"v1";
static NSString *const tokenEndpoint = @"tokens";
static NSString *const productEndpoint = @"products";
static NSString *const customerEndpoint = @"customers";
static NSString *const orderEndpoint = @"orders";
static NSString *STPDefaultPublishableKey;
static NSString *STPDefaultSecretKey;

@implementation Stripe

+ (void)setDefaultPublishableKey:(NSString *)publishableKey {
    STPDefaultPublishableKey = publishableKey;
}

+ (NSString *)defaultPublishableKey {
    return STPDefaultPublishableKey;
}

+ (void)setDefaultSecretKey:(NSString *)secretKey {
    STPDefaultSecretKey = secretKey;
}

+ (NSString *)defaultSecretKey {
    return STPDefaultSecretKey;
}

@end

@interface STPAPIClient ()
@property (nonatomic, readwrite) NSURL *apiURL;
@end

@implementation STPAPIClient

+ (instancetype)sharedClient {
    static id sharedClient;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ sharedClient = [[self alloc] init]; });
    return sharedClient;
}

- (instancetype)init {
    return [self initWithPublishableKey:[Stripe defaultPublishableKey] andSecretKey:[Stripe defaultSecretKey]];
}

- (instancetype)initWithPublishableKey:(NSString *)publishableKey {
    return [self initWithPublishableKey:publishableKey andSecretKey:[Stripe defaultSecretKey]];
}

- (instancetype)initWithPublishableKey:(NSString *)publishableKey andSecretKey:(NSString*)secretKey {
    self = [super init];
    if (self) {
        [self.class validateKey:publishableKey];
        _apiURL = [[NSURL URLWithString:[NSString stringWithFormat:@"https://%@", apiURLBase]] URLByAppendingPathComponent:apiVersion];
        _publishableKey = [publishableKey copy];
        _operationQueue = [NSOperationQueue mainQueue];
        _secretKey = [secretKey copy];
    }
    return self;
}

- (void)setOperationQueue:(NSOperationQueue *)operationQueue {
    NSCAssert(operationQueue, @"Operation queue cannot be nil.");
    _operationQueue = operationQueue;
}

- (void)createTokenWithData:(NSData *)data completion:(STPCompletionBlock)completion {
    NSCAssert(data != nil, @"'data' is required to create a token");
    NSCAssert(completion != nil, @"'completion' is required to use the token that is created");
    
    NSURL *endpoint = [_apiURL URLByAppendingPathComponent:tokenEndpoint];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:endpoint];
    request.HTTPMethod = @"POST";
    request.HTTPBody = data;
    [request setValue:[self.class JSONStringForObject:[self.class stripeUserAgentDetails]] forHTTPHeaderField:@"X-Stripe-User-Agent"];
    [request setValue:[@"Bearer " stringByAppendingString:self.publishableKey] forHTTPHeaderField:@"Authorization"];
    
    STPAPIConnection *connection = [[STPAPIConnection alloc] initWithRequest:request];
    [connection runOnOperationQueue:self.operationQueue
                         completion:^(NSURLResponse *response, NSData *body, NSError *requestError) {
                             NSError *error = [self handleAPIErrors:response body:body error:requestError];
                             if (error) {
                                 completion(nil,error);
                                 return;
                             }
                             completion([[STPToken alloc] initWithAttributeDictionary:[NSJSONSerialization JSONObjectWithData:body options:0 error:NULL]], nil);

                         }];
}

#pragma mark - private helpers

- (NSError*)handleAPIErrors:(NSURLResponse *)response body:(NSData *)body error:(NSError *)requestError {
    if (requestError) {
        // If this is an error that Stripe returned, let's handle it as a StripeDomain error
        if (body) {
            NSDictionary *jsonDictionary = [NSJSONSerialization JSONObjectWithData:body options:0 error:NULL];
            if ([jsonDictionary valueForKey:@"error"] != nil) {
                return [self.class errorFromStripeResponse:jsonDictionary];
            }
        }
        return requestError;
    } else {
        NSDictionary *jsonDictionary = [NSJSONSerialization JSONObjectWithData:body options:0 error:NULL];
        if (!jsonDictionary) {
            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: STPUnexpectedError,
                                       STPErrorMessageKey: @"The response from Stripe failed to get parsed into valid JSON."
                                       };
            NSError *error = [[NSError alloc] initWithDomain:StripeDomain code:STPAPIError userInfo:userInfo];
            return error;
        } else if ([(NSHTTPURLResponse *)response statusCode] != 200) {
            return [self.class errorFromStripeResponse:jsonDictionary];
        } else {
            return nil;
        }
    }

}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-variable"
+ (void)validateKey:(NSString *)publishableKey {
    NSCAssert(publishableKey != nil && ![publishableKey isEqualToString:@""],
              @"You must use a valid publishable key to create a token. For more info, see https://stripe.com/docs/stripe.js");
    BOOL secretKey = [publishableKey hasPrefix:@"sk_"];
    NSCAssert(!secretKey,
              @"You are using a secret key to create a token, instead of the publishable one. For more info, see https://stripe.com/docs/stripe.js");
#ifndef DEBUG
    if ([publishableKey.lowercaseString hasPrefix:@"pk_test"]) {
        FAUXPAS_IGNORED_IN_METHOD(NSLogUsed);
        NSLog(@"⚠️ Warning! You're building your app in a non-debug configuration, but appear to be using your Stripe test key. Make sure not to submit to "
              @"the App Store with your test keys!⚠️");
    }
#endif
}
#pragma clang diagnostic pop

+ (NSError *)errorFromStripeResponse:(NSDictionary *)jsonDictionary {
    NSDictionary *errorDictionary = jsonDictionary[@"error"];
    NSString *type = errorDictionary[@"type"];
    NSString *devMessage = errorDictionary[@"message"];
    NSString *parameter = errorDictionary[@"param"];
    NSInteger code = 0;

    // There should always be a message and type for the error
    if (devMessage == nil || type == nil) {
        NSDictionary *userInfo = @{
            NSLocalizedDescriptionKey: STPUnexpectedError,
            STPErrorMessageKey: @"Could not interpret the error response that was returned from Stripe."
        };
        return [[NSError alloc] initWithDomain:StripeDomain code:STPAPIError userInfo:userInfo];
    }

    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    userInfo[STPErrorMessageKey] = devMessage;

    if (parameter) {
        userInfo[STPErrorParameterKey] = [STPFormEncoder stringByReplacingSnakeCaseWithCamelCase:parameter];
    }

    if ([type isEqualToString:@"api_error"]) {
        code = STPAPIError;
        userInfo[NSLocalizedDescriptionKey] = STPUnexpectedError;
    } else if ([type isEqualToString:@"invalid_request_error"]) {
        code = STPInvalidRequestError;
        userInfo[NSLocalizedDescriptionKey] = devMessage;
    } else if ([type isEqualToString:@"card_error"]) {
        code = STPCardError;
        NSDictionary *errorCodes = @{
            @"incorrect_number": @{@"code": STPIncorrectNumber, @"message": STPCardErrorInvalidNumberUserMessage},
            @"invalid_number": @{@"code": STPInvalidNumber, @"message": STPCardErrorInvalidNumberUserMessage},
            @"invalid_expiry_month": @{@"code": STPInvalidExpMonth, @"message": STPCardErrorInvalidExpMonthUserMessage},
            @"invalid_expiry_year": @{@"code": STPInvalidExpYear, @"message": STPCardErrorInvalidExpYearUserMessage},
            @"invalid_cvc": @{@"code": STPInvalidCVC, @"message": STPCardErrorInvalidCVCUserMessage},
            @"expired_card": @{@"code": STPExpiredCard, @"message": STPCardErrorExpiredCardUserMessage},
            @"incorrect_cvc": @{@"code": STPIncorrectCVC, @"message": STPCardErrorInvalidCVCUserMessage},
            @"card_declined": @{@"code": STPCardDeclined, @"message": STPCardErrorDeclinedUserMessage},
            @"processing_error": @{@"code": STPProcessingError, @"message": STPCardErrorProcessingErrorUserMessage},
        };
        NSDictionary *codeMapEntry = errorCodes[errorDictionary[@"code"]];

        if (codeMapEntry) {
            userInfo[STPCardErrorCodeKey] = codeMapEntry[@"code"];
            userInfo[NSLocalizedDescriptionKey] = codeMapEntry[@"message"];
        } else {
            userInfo[STPCardErrorCodeKey] = errorDictionary[@"code"];
            userInfo[NSLocalizedDescriptionKey] = devMessage;
        }
    }

    return [[NSError alloc] initWithDomain:StripeDomain code:code userInfo:userInfo];
}

#pragma mark Utility methods -

+ (NSDictionary *)stripeUserAgentDetails {
    NSMutableDictionary *details = [@{
        @"lang": @"objective-c",
        @"bindings_version": STPSDKVersion,
    } mutableCopy];
#if TARGET_OS_IPHONE
    NSString *version = [UIDevice currentDevice].systemVersion;
    if (version) {
        details[@"os_version"] = version;
    }
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *deviceType = @(systemInfo.machine);
    if (deviceType) {
        details[@"type"] = deviceType;
    }
    NSString *model = [UIDevice currentDevice].localizedModel;
    if (model) {
        details[@"model"] = model;
    }
    if ([[UIDevice currentDevice] respondsToSelector:@selector(identifierForVendor)]) {
        NSString *vendorIdentifier = [[[UIDevice currentDevice] performSelector:@selector(identifierForVendor)] performSelector:@selector(UUIDString)];
        if (vendorIdentifier) {
            details[@"vendor_identifier"] = vendorIdentifier;
        }
    }
#endif
    return [details copy];
}

+ (NSString *)JSONStringForObject:(id)object {
    return [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:object options:0 error:NULL] encoding:NSUTF8StringEncoding];
}

+ (NSString *)HTTPBodyForDictionary:(NSDictionary*)dict {
    NSMutableString *mutString = [NSMutableString new];
    NSMutableArray *arr = [NSMutableArray arrayWithCapacity:dict.count];
    [dict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [arr addObject:[NSString stringWithFormat:@"%@=%@",key,obj]];
        *stop = NO;
    }];
    [arr enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if (idx != arr.count - 1) {
            [mutString appendString:[NSString stringWithFormat:@"%@&",obj]];
        } else {
            [mutString appendString:obj];
        }
        *stop = NO;
    }];
    return mutString;
}

@end

#pragma mark - Bank Accounts
@implementation STPAPIClient (BankAccounts)

- (void)createTokenWithBankAccount:(STPBankAccount *)bankAccount completion:(STPCompletionBlock)completion {
    [self createTokenWithData:[STPFormEncoder formEncodedDataForBankAccount:bankAccount] completion:completion];
}

@end

#pragma mark - Credit Cards
@implementation STPAPIClient (CreditCards)

- (void)createTokenWithCard:(STPCard *)card completion:(STPCompletionBlock)completion {
    [self createTokenWithData:[STPFormEncoder formEncodedDataForCard:card] completion:completion];
}

- (void)listCardsForCustomer:(STPCustomer *)customer limit:(NSInteger)limit before:(NSString*)beforeID after:(NSString*)afterID completion:(STPCompletionBlock)completion {
    NSCAssert(customer != nil, @"'customer' is required");
    NSCAssert(completion != nil, @"'completion' is required to use retrieved products");

    NSString* params = @"object=card";
    if (limit) {
        params = [params stringByAppendingString:[NSString stringWithFormat:@"&limit=%0.ld",(long)limit]];
    }
    if (beforeID) {
        params = [params stringByAppendingString:[NSString stringWithFormat:@"&ending_before=%@",beforeID]];
    }
    if (afterID) {
        params = [params stringByAppendingString:[NSString stringWithFormat:@"&starting_after=%@",afterID]];
    }
    
    NSURL *endpoint = [NSURL URLWithString:[NSString stringWithFormat:@"%@?%@",[[[_apiURL URLByAppendingPathComponent:customerEndpoint] URLByAppendingPathComponent:customer.custId] URLByAppendingPathComponent:@"sources"] ,params]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:endpoint];
    request.HTTPMethod = @"GET";

    [request setValue:[self.class JSONStringForObject:[self.class stripeUserAgentDetails]] forHTTPHeaderField:@"X-Stripe-User-Agent"];
    [request setValue:[@"Bearer " stringByAppendingString:self.secretKey] forHTTPHeaderField:@"Authorization"];
    
    STPAPIConnection *connection = [[STPAPIConnection alloc] initWithRequest:request];
    [connection runOnOperationQueue:_operationQueue completion:^(NSURLResponse *response, NSData *body, NSError *requestError) {
        NSError *error = [self handleAPIErrors:response body:body error:requestError];
        if (error) {
            completion(nil,error);
            return;
        }
        id cardsDict = [NSJSONSerialization JSONObjectWithData:body options:0 error:NULL];
        NSMutableArray<STPCard*>* cards = [NSMutableArray arrayWithCapacity:[cardsDict[@"data"] count]];
        for (id card in cardsDict[@"data"]) {
            [cards addObject:[[STPCard alloc] initWithAttributeDictionary:card]];
        }
        completion(cards, nil);
    }];
}

- (void)retrieveCard:(NSString*)cardID forCustomer:(STPCustomer*)customer completion:(STPCompletionBlock)completion {
    NSCAssert(cardID != nil, @"'cardID' is required");
    NSCAssert(completion != nil, @"'completion' is required to use retrieved customer");
    
    NSURL *endpoint = [[[[_apiURL URLByAppendingPathComponent:customerEndpoint] URLByAppendingPathComponent:customer.custId] URLByAppendingPathComponent:@"sources"] URLByAppendingPathComponent:cardID];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:endpoint];
    request.HTTPMethod = @"GET";
    [request setValue:[self.class JSONStringForObject:[self.class stripeUserAgentDetails]] forHTTPHeaderField:@"X-Stripe-User-Agent"];
    [request setValue:[@"Bearer " stringByAppendingString:self.secretKey] forHTTPHeaderField:@"Authorization"];
    
    STPAPIConnection *connection = [[STPAPIConnection alloc] initWithRequest:request];
    [connection runOnOperationQueue:_operationQueue completion:^(NSURLResponse *response, NSData *body, NSError *requestError) {
        NSError *error = [self handleAPIErrors:response body:body error:requestError];
        if (error) {
            completion(nil,error);
            return;
        }
        completion([[STPCard alloc] initWithAttributeDictionary:[NSJSONSerialization JSONObjectWithData:body options:0 error:NULL]],nil);
    }];
}

- (void)deleteCard:(NSString*)cardID forCustomer:(STPCustomer*)customer completion:(STPCompletionBlock)completion {
    NSCAssert(cardID != nil, @"'cardID' is required");
    NSCAssert(completion != nil, @"'completion' is required to use retrieved customer");
    
    NSURL *endpoint = [[[[_apiURL URLByAppendingPathComponent:customerEndpoint] URLByAppendingPathComponent:customer.custId] URLByAppendingPathComponent:@"sources"] URLByAppendingPathComponent:cardID];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:endpoint];
    request.HTTPMethod = @"DELETE";
    [request setValue:[self.class JSONStringForObject:[self.class stripeUserAgentDetails]] forHTTPHeaderField:@"X-Stripe-User-Agent"];
    [request setValue:[@"Bearer " stringByAppendingString:self.secretKey] forHTTPHeaderField:@"Authorization"];
    
    STPAPIConnection *connection = [[STPAPIConnection alloc] initWithRequest:request];
    [connection runOnOperationQueue:_operationQueue completion:^(NSURLResponse *response, NSData *body, NSError *requestError) {
        NSError *error = [self handleAPIErrors:response body:body error:requestError];
        if (error) {
            completion(nil,error);
            return;
        }
        completion(@(YES),nil);
    }];
}

@end

#pragma mark - Products
@implementation STPAPIClient (Products)

- (void)listProductsFromAccount:(NSString*)stripeAccount limit:(NSInteger)limit before:(NSString*)before after:(NSString*)after completion:(STPCompletionBlock)completion {
    NSCAssert(completion != nil, @"'completion' is required to use retrieved products");
    
    NSString* params = @"active=true&shippable=true";
    if (limit) {
        params = [params stringByAppendingString:[NSString stringWithFormat:@"&limit=%0.ld",(long)limit]];
    }
    if (before) {
        params = [params stringByAppendingString:[NSString stringWithFormat:@"&ending_before=%@",before]];
    }
    if (after) {
        params = [params stringByAppendingString:[NSString stringWithFormat:@"&starting_after=%@",after]];
    }
    
    NSURL *endpoint = [NSURL URLWithString:[NSString stringWithFormat:@"%@?%@",[_apiURL URLByAppendingPathComponent:productEndpoint].absoluteString,params]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:endpoint];
    request.HTTPMethod = @"GET";
    
    if (stripeAccount) {
        [request setValue:stripeAccount forHTTPHeaderField:@"Stripe-Account"];
    }
    [request setValue:[self.class JSONStringForObject:[self.class stripeUserAgentDetails]] forHTTPHeaderField:@"X-Stripe-User-Agent"];
    [request setValue:[@"Bearer " stringByAppendingString:self.secretKey] forHTTPHeaderField:@"Authorization"];

    STPAPIConnection *connection = [[STPAPIConnection alloc] initWithRequest:request];
    [connection runOnOperationQueue:_operationQueue completion:^(NSURLResponse *response, NSData *body, NSError *requestError) {
        NSError *error = [self handleAPIErrors:response body:body error:requestError];
        if (error) {
            completion(nil,error);
            return;
        }
        id products = [NSJSONSerialization JSONObjectWithData:body options:0 error:NULL];
        NSMutableArray<STPProduct*>* productsList = [NSMutableArray arrayWithCapacity:[products[@"data"] count]];
        for (id product in products[@"data"]) {
            [productsList addObject:[[STPProduct alloc] initWithAttributeDictionary:product]];
        }
        completion(productsList, nil);
    }];
}

- (void)retrieveProductFromAccount:(NSString*)stripeAccount product:(NSString*)productId completion:(STPCompletionBlock)completion {
    NSCAssert(productId != nil, @"'productId' is required");
    
    NSURL *endpoint = [[_apiURL URLByAppendingPathComponent:productEndpoint] URLByAppendingPathComponent:productId];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:endpoint];
    request.HTTPMethod = @"GET";
    [request setValue:[self.class JSONStringForObject:[self.class stripeUserAgentDetails]] forHTTPHeaderField:@"X-Stripe-User-Agent"];
    [request setValue:[@"Bearer " stringByAppendingString:self.secretKey] forHTTPHeaderField:@"Authorization"];

    if (stripeAccount) {
        [request setValue:stripeAccount forHTTPHeaderField:@"Stripe-Account"];
    }
    
    STPAPIConnection *connection = [[STPAPIConnection alloc] initWithRequest:request];
    [connection runOnOperationQueue:_operationQueue completion:^(NSURLResponse *response, NSData *body, NSError *requestError) {
        NSError *error = [self handleAPIErrors:response body:body error:requestError];
        if (error) {
            completion(nil,error);
            return;
        }
        completion([[STPProduct alloc] initWithAttributeDictionary:[NSJSONSerialization JSONObjectWithData:body options:0 error:NULL]],nil);
    }];
}

@end

@implementation STPAPIClient (Customer)

- (void)createCustomer:(NSString*)email shipping:(STPShippingInfos*)shippingAddress source:(STPToken*)source completion:(STPCompletionBlock)completion {
    NSCAssert(completion != nil, @"'completion' is required to use retrieved customer");

    NSMutableDictionary *data = [NSMutableDictionary dictionaryWithDictionary:@{}];
    if (email) {
        [data addEntriesFromDictionary:@{@"email":email}];
    }
    if (shippingAddress) {
        [data addEntriesFromDictionary:[shippingAddress dictionaryOutput]];
    }
    if (source) {
        [data addEntriesFromDictionary:@{@"source":[source tokenId]}];
    }

    NSURL *endpoint = [_apiURL URLByAppendingPathComponent:customerEndpoint];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:endpoint];
    request.HTTPMethod = @"POST";
    
    NSString *postDataStr = [STPAPIClient HTTPBodyForDictionary:data];
    NSData *postData = [postDataStr dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
    request.HTTPBody = postData;
    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[postDataStr length]] forHTTPHeaderField:@"Content-Length"];
    
    [request setValue:[self.class JSONStringForObject:[self.class stripeUserAgentDetails]] forHTTPHeaderField:@"X-Stripe-User-Agent"];
    [request setValue:[@"Bearer " stringByAppendingString:self.secretKey] forHTTPHeaderField:@"Authorization"];
    
    STPAPIConnection *connection = [[STPAPIConnection alloc] initWithRequest:request];
    [connection runOnOperationQueue:_operationQueue completion:^(NSURLResponse *response, NSData *body, NSError *requestError) {
        NSError *error = [self handleAPIErrors:response body:body error:requestError];
        if (error) {
            completion(nil,error);
            return;
        }
        completion([[STPCustomer alloc] initWithAttributeDictionary:[NSJSONSerialization JSONObjectWithData:body options:0 error:NULL]], nil);
    }];
}

- (void)retrieveCustomer:(NSString*)customerId completion:(STPCompletionBlock)completion {
    NSCAssert(customerId != nil, @"'customerId' is required");
    NSCAssert(completion != nil, @"'completion' is required to use retrieved customer");

    NSURL *endpoint = [[_apiURL URLByAppendingPathComponent:customerEndpoint] URLByAppendingPathComponent:customerId];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:endpoint];
    request.HTTPMethod = @"GET";
    [request setValue:[self.class JSONStringForObject:[self.class stripeUserAgentDetails]] forHTTPHeaderField:@"X-Stripe-User-Agent"];
    [request setValue:[@"Bearer " stringByAppendingString:self.secretKey] forHTTPHeaderField:@"Authorization"];

    STPAPIConnection *connection = [[STPAPIConnection alloc] initWithRequest:request];
    [connection runOnOperationQueue:_operationQueue completion:^(NSURLResponse *response, NSData *body, NSError *requestError) {
        NSError *error = [self handleAPIErrors:response body:body error:requestError];
        if (error) {
            completion(nil,error);
            return;
        }
        completion([[STPCustomer alloc] initWithAttributeDictionary:[NSJSONSerialization JSONObjectWithData:body options:0 error:NULL]],nil);
    }];
}

- (void)updateCustomer:(STPCustomer*)customer completion:(STPCompletionBlock)completion {
    NSCAssert(customer != nil, @"'customer' is required");
    NSCAssert(completion != nil, @"'completion' is required to use the updated customer");

    NSMutableDictionary *data = [NSMutableDictionary dictionaryWithDictionary:@{}];

    if (customer.defaultSourceId) {
        [data addEntriesFromDictionary:@{@"default_source":customer.defaultSourceId}];
    }
    if (customer.email) {
        [data addEntriesFromDictionary:@{@"email":customer.email}];
    }
    if (customer.shippingInfos) {
        [data addEntriesFromDictionary:[customer.shippingInfos dictionaryOutput]];
    }

    NSURL *endpoint = [[_apiURL URLByAppendingPathComponent:customerEndpoint] URLByAppendingPathComponent:customer.custId];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:endpoint];
    request.HTTPMethod = @"POST";
    
    NSString *postDataStr = [STPAPIClient HTTPBodyForDictionary:data];
    NSData *postData = [postDataStr dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
    request.HTTPBody = postData;
    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[postDataStr length]] forHTTPHeaderField:@"Content-Length"];
    
    [request setValue:[self.class JSONStringForObject:[self.class stripeUserAgentDetails]] forHTTPHeaderField:@"X-Stripe-User-Agent"];
    [request setValue:[@"Bearer " stringByAppendingString:self.secretKey] forHTTPHeaderField:@"Authorization"];

    STPAPIConnection *connection = [[STPAPIConnection alloc] initWithRequest:request];
    [connection runOnOperationQueue:_operationQueue completion:^(NSURLResponse *response, NSData *body, NSError *requestError) {
        NSError *error = [self handleAPIErrors:response body:body error:requestError];
        if (error) {
            completion(nil,error);
            return;
        }
        completion([[STPCustomer alloc] initWithAttributeDictionary:[NSJSONSerialization JSONObjectWithData:body options:0 error:NULL]], nil);
    }];
}

- (void)addToken:(STPToken*)token toCustomer:(NSString*)customerId completion:(STPCompletionBlock)completion {
    NSCAssert(token != nil, @"'token' is required");
    NSCAssert(customerId != nil, @"'customer' is required");
    NSCAssert(completion != nil, @"'completion' is required to use the updated customer");

    NSMutableDictionary *data = [NSMutableDictionary dictionaryWithDictionary:@{}];
    [data addEntriesFromDictionary:@{@"source":token.tokenId}];

    NSURL *endpoint = [[[_apiURL URLByAppendingPathComponent:customerEndpoint] URLByAppendingPathComponent:customerId]
            URLByAppendingPathComponent:@"sources"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:endpoint];
    request.HTTPMethod = @"POST";
    NSString *postDataStr = [STPAPIClient HTTPBodyForDictionary:data];
    NSData *postData = [postDataStr dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
    request.HTTPBody = postData;
    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[postDataStr length]] forHTTPHeaderField:@"Content-Length"];
    
    [request setValue:[self.class JSONStringForObject:[self.class stripeUserAgentDetails]] forHTTPHeaderField:@"X-Stripe-User-Agent"];
    [request setValue:[@"Bearer " stringByAppendingString:self.secretKey] forHTTPHeaderField:@"Authorization"];

    STPAPIConnection *connection = [[STPAPIConnection alloc] initWithRequest:request];
    [connection runOnOperationQueue:_operationQueue completion:^(NSURLResponse *response, NSData *body, NSError *requestError) {
        NSError *error = [self handleAPIErrors:response body:body error:requestError];
        if (error) {
            completion(nil,error);
            return;
        }
        completion([[STPCard alloc] initWithAttributeDictionary:[NSJSONSerialization JSONObjectWithData:body options:0 error:NULL]], nil);
    }];
}

@end

#pragma mark Orders

@implementation STPAPIClient (Orders)


+ (STPOrderItem*)createOrderItemFromSku:(STPSku*)sku andQuantity:(NSInteger)quantity {
    STPOrderItem *orderItem = [[STPOrderItem alloc] init];
    orderItem.type = STPOrderItemTypeSku;
    orderItem.parentId = sku.skuId;
    orderItem.amount = sku.price;
    orderItem.currency = sku.currency;
    orderItem.quantity = quantity;
    return orderItem;
}

- (void)createOrderFromAccount:(NSString*)stripeAccount customer:(STPCustomer*)customer currency:(NSString*)currency items:(NSArray<STPOrderItem *>*)items completion:(STPCompletionBlock)completion {
    NSCAssert(customer != nil, @"'customer' is required");
    NSCAssert(currency != nil, @"'currency' is required");
    NSCAssert(items != nil, @"'items' is required");
    NSCAssert(completion != nil, @"'completion' is required to use the newly created order");

    NSMutableDictionary *data = [NSMutableDictionary dictionaryWithDictionary:@{}];
    [data addEntriesFromDictionary:@{@"currency":currency}];
    [data addEntriesFromDictionary:@{@"customer":[customer custId]}];

    int idx = 0;
    for (STPOrderItem *orderItem in items) {
        [data addEntriesFromDictionary:[orderItem dictionaryOutputWithIndex:idx]];
        idx++;
    }

    NSURL *endpoint = [_apiURL URLByAppendingPathComponent:orderEndpoint];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:endpoint];
    request.HTTPMethod = @"POST";
    
    NSString *postDataStr = [STPAPIClient HTTPBodyForDictionary:data];
    NSData *postData = [postDataStr dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
    request.HTTPBody = postData;
    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[postDataStr length]] forHTTPHeaderField:@"Content-Length"];
    
    [request setValue:[self.class JSONStringForObject:[self.class stripeUserAgentDetails]] forHTTPHeaderField:@"X-Stripe-User-Agent"];
    [request setValue:[@"Bearer " stringByAppendingString:self.secretKey] forHTTPHeaderField:@"Authorization"];

    if (stripeAccount) {
        [request setValue:stripeAccount forHTTPHeaderField:@"Stripe-Account"];
    }

    STPAPIConnection *connection = [[STPAPIConnection alloc] initWithRequest:request];
    [connection runOnOperationQueue:_operationQueue completion:^(NSURLResponse *response, NSData *body, NSError *requestError) {
        NSError *error = [self handleAPIErrors:response body:body error:requestError];
        if (error) {
            completion(nil,error);
            return;
        }
        completion([[STPOrder alloc] initWithAttributeDictionary:[NSJSONSerialization JSONObjectWithData:body options:0 error:NULL]], nil);
    }];
}

- (void)retrieveOrderFromAccount:(NSString*)stripeAccount orderId:(NSString*)orderId completion:(STPCompletionBlock)completion {
    NSCAssert(orderId != nil, @"'orderId' is required");
    NSCAssert(completion != nil, @"'completion' is required to use the retrieved order");

    NSURL *endpoint = [[_apiURL URLByAppendingPathComponent:orderEndpoint] URLByAppendingPathComponent:orderId];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:endpoint];
    request.HTTPMethod = @"GET";
    [request setValue:[self.class JSONStringForObject:[self.class stripeUserAgentDetails]] forHTTPHeaderField:@"X-Stripe-User-Agent"];
    [request setValue:[@"Bearer " stringByAppendingString:self.secretKey] forHTTPHeaderField:@"Authorization"];

    if (stripeAccount) {
        [request setValue:stripeAccount forHTTPHeaderField:@"Stripe-Account"];
    }

    STPAPIConnection *connection = [[STPAPIConnection alloc] initWithRequest:request];
    [connection runOnOperationQueue:_operationQueue completion:^(NSURLResponse *response, NSData *body, NSError *requestError) {
        NSError *error = [self handleAPIErrors:response body:body error:requestError];
        if (error) {
            completion(nil,error);
            return;
        }
        completion([[STPOrder alloc] initWithAttributeDictionary:[NSJSONSerialization JSONObjectWithData:body options:0 error:NULL]],nil);
    }];
}

- (void)updateOrderFromAccount:(NSString*)stripeAccount order:(STPOrder*)order completion:(STPCompletionBlock)completion {
    NSCAssert(order != nil, @"'order' is required");
    NSCAssert(completion != nil, @"'completion' is required to use the updated order");

    NSMutableDictionary *data = [NSMutableDictionary dictionaryWithDictionary:@{}];
    [data addEntriesFromDictionary:@{@"selected_shipping_method":order.selectedShippingMethodId}];
    [data addEntriesFromDictionary:@{@"status":[[STPOrder class] orderStatusToString:order.orderStatus]}];

    NSURL *endpoint = [[_apiURL URLByAppendingPathComponent:orderEndpoint] URLByAppendingPathComponent:order.orderId];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:endpoint];
    request.HTTPMethod = @"POST";
    
    NSString *postDataStr = [STPAPIClient HTTPBodyForDictionary:data];
    NSData *postData = [postDataStr dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
    request.HTTPBody = postData;
    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[postDataStr length]] forHTTPHeaderField:@"Content-Length"];
    
    [request setValue:[self.class JSONStringForObject:[self.class stripeUserAgentDetails]] forHTTPHeaderField:@"X-Stripe-User-Agent"];
    [request setValue:[@"Bearer " stringByAppendingString:self.secretKey] forHTTPHeaderField:@"Authorization"];

    if (stripeAccount) {
        [request setValue:stripeAccount forHTTPHeaderField:@"Stripe-Account"];
    }

    STPAPIConnection *connection = [[STPAPIConnection alloc] initWithRequest:request];
    [connection runOnOperationQueue:_operationQueue completion:^(NSURLResponse *response, NSData *body, NSError *requestError) {
        NSError *error = [self handleAPIErrors:response body:body error:requestError];
        if (error) {
            completion(nil,error);
            return;
        }
        completion([[STPOrder alloc] initWithAttributeDictionary:[NSJSONSerialization JSONObjectWithData:body options:0 error:NULL]], nil);
    }];
}

- (void)payOrderFromAccount:(NSString*)stripeAccount order:(STPOrder*)order cardId:(NSString*)cardId applicationFee:(NSString*)appFee completion:(STPCompletionBlock)completion {
    NSCAssert(order != nil, @"'order' is required");
    NSCAssert(appFee != nil, @"'appFee' is required");
    NSCAssert(completion != nil, @"'completion' is required to use the updated order");

    NSMutableDictionary *data = [NSMutableDictionary dictionaryWithDictionary:@{}];
    if (order.customer) {
        [data addEntriesFromDictionary:@{@"customer":order.customer.custId}];
    }
    if (cardId) {
        [data addEntriesFromDictionary:@{@"source":cardId}];
    } else if (order.customer.defaultSourceId) {
        [data addEntriesFromDictionary:@{@"source":order.customer.defaultSourceId}];
    }
    [data addEntriesFromDictionary:@{@"application_fee":appFee}];

    NSURL *endpoint = [[[_apiURL URLByAppendingPathComponent:orderEndpoint] URLByAppendingPathComponent:order.orderId]
            URLByAppendingPathComponent:@"pay"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:endpoint];
    request.HTTPMethod = @"POST";
    
    NSString *postDataStr = [STPAPIClient HTTPBodyForDictionary:data];
    NSData *postData = [postDataStr dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
    request.HTTPBody = postData;
    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[postDataStr length]] forHTTPHeaderField:@"Content-Length"];
    
    [request setValue:[self.class JSONStringForObject:[self.class stripeUserAgentDetails]] forHTTPHeaderField:@"X-Stripe-User-Agent"];
    [request setValue:[@"Bearer " stringByAppendingString:self.secretKey] forHTTPHeaderField:@"Authorization"];

    if (stripeAccount) {
        [request setValue:stripeAccount forHTTPHeaderField:@"Stripe-Account"];
    }

    STPAPIConnection *connection = [[STPAPIConnection alloc] initWithRequest:request];
    [connection runOnOperationQueue:_operationQueue completion:^(NSURLResponse *response, NSData *body, NSError *requestError) {
        NSError *error = [self handleAPIErrors:response body:body error:requestError];
        if (error) {
            completion(nil,error);
            return;
        }
        completion([[STPOrder alloc] initWithAttributeDictionary:[NSJSONSerialization JSONObjectWithData:body options:0 error:NULL]], nil);
    }];
}

@end

@implementation Stripe (Deprecated)

+ (id)alloc {
    NSCAssert(NO, @"'Stripe' is a static class and cannot be instantiated.");
    return nil;
}

+ (void)createTokenWithCard:(STPCard *)card
             publishableKey:(NSString *)publishableKey
             operationQueue:(NSOperationQueue *)queue
                 completion:(STPCompletionBlock)handler {
    NSCAssert(card != nil, @"'card' is required to create a token");
    STPAPIClient *client = [[STPAPIClient alloc] initWithPublishableKey:publishableKey];
    client.operationQueue = queue;
    [client createTokenWithCard:card completion:handler];
}

+ (void)createTokenWithBankAccount:(STPBankAccount *)bankAccount
                    publishableKey:(NSString *)publishableKey
                    operationQueue:(NSOperationQueue *)queue
                        completion:(STPCompletionBlock)handler {
    NSCAssert(bankAccount != nil, @"'bankAccount' is required to create a token");
    NSCAssert(handler != nil, @"'handler' is required to use the token that is created");
    
    STPAPIClient *client = [[STPAPIClient alloc] initWithPublishableKey:publishableKey];
    client.operationQueue = queue;
    [client createTokenWithBankAccount:bankAccount completion:handler];
}

#pragma mark Shorthand methods -

+ (void)createTokenWithCard:(STPCard *)card completion:(STPCompletionBlock)handler {
    [self createTokenWithCard:card publishableKey:[self defaultPublishableKey] completion:handler];
}

+ (void)createTokenWithCard:(STPCard *)card publishableKey:(NSString *)publishableKey completion:(STPCompletionBlock)handler {
    [self createTokenWithCard:card publishableKey:publishableKey operationQueue:[NSOperationQueue mainQueue] completion:handler];
}

+ (void)createTokenWithCard:(STPCard *)card operationQueue:(NSOperationQueue *)queue completion:(STPCompletionBlock)handler {
    [self createTokenWithCard:card publishableKey:[self defaultPublishableKey] operationQueue:queue completion:handler];
}

+ (void)createTokenWithBankAccount:(STPBankAccount *)bankAccount completion:(STPCompletionBlock)handler {
    [self createTokenWithBankAccount:bankAccount publishableKey:[self defaultPublishableKey] completion:handler];
}

+ (void)createTokenWithBankAccount:(STPBankAccount *)bankAccount publishableKey:(NSString *)publishableKey completion:(STPCompletionBlock)handler {
    [self createTokenWithBankAccount:bankAccount publishableKey:publishableKey operationQueue:[NSOperationQueue mainQueue] completion:handler];
}

+ (void)createTokenWithBankAccount:(STPBankAccount *)bankAccount operationQueue:(NSOperationQueue *)queue completion:(STPCompletionBlock)handler {
    [self createTokenWithBankAccount:bankAccount publishableKey:[self defaultPublishableKey] operationQueue:queue completion:handler];
}

@end

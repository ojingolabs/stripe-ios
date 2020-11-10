//
//  STPOrder.h
//  Stripe
//
//  Created by Antoine Lavail on 02/10/15.
//  Copyright © 2015 Stripe, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 *  The various order status.
 */
typedef NS_ENUM(NSInteger, STPOrderStatus) {
    STPOrderStatusCreated,
    STPOrderStatusPaid,
    STPOrderStatusCanceled,
    STPOrderStatusFulfilled,
    STPOrderStatusReturned,
    STPOrderStatusUnknown = NSIntegerMax
};

@class STPCustomer, STPAddress, STPShippingMethod, STPOrderItem;

@interface STPOrder : NSObject

/**
 *  The Stripe ID for the order.
 */
@property (nonatomic, readonly, nullable, copy) NSString *orderId;

/**
 *  NSDate representing the order creation time.
 */
@property (nonatomic, readonly, nonnull, copy) NSDate *created;

/**
 *  A positive integer in the smallest currency unit
 *  (that is, 100 cents for $1.00, or 1 for ¥1, Japanese Yen being a 0-decimal currency) representing the total amount for the order.
 *
 */
@property (nonatomic, readonly) NSInteger amount;

/**
 *  3-letter ISO code representing the currency in which the order was made.
 */
@property (nonatomic, copy, nullable) NSString *currency;

/**
 *  Current order status. One of created, paid, canceled, fulfilled, or returned.
 */
@property (nonatomic) STPOrderStatus orderStatus;

/**
 *  A fee in cents that will be applied to the order and transferred to the application owner's Stripe account.
 *  To use an application fee, the request must be made on behalf of another account,
 *  using the Stripe-Account header or OAuth key.
 *
 */
@property (nonatomic) NSInteger applicationFee;

/**
 *  The ID of the payment used to pay for the order. Present if the order status is paid, fulfilled, or refunded.
 */
@property (nonatomic, readonly, copy, nullable) NSString *chargeId;

/**
 *  The customer used for the order.
 */
@property (nonatomic, nullable) STPCustomer *customer;

/**
 *  The customerId used for the order.
 */
@property (nonatomic, copy, nullable) NSString *customerId;

/**
 * A list of supported shipping methods for this order.
 * The desired shipping method can be specified either by updating the order, or when paying it.
 */
@property (nonatomic, nullable) NSArray<STPShippingMethod*> *shippingMethods;

/**
 *  The shipping method that is currently selected for this order, if any.
 *  If present, it is equal to one of the ids of shipping methods in the shipping_methods array.
 *  At order creation time, if there are multiple shipping methods, Stripe will automatically selected the first method.
 */
@property (nonatomic, copy, nullable) NSString *selectedShippingMethodId;

/**
 * The shipping address for the order. Present if the order is for goods to be shipped.
 */
@property (nonatomic, nullable) STPAddress *shippingAddress;

/**
 * List of items constituting the order.
 *
 */
@property (nonatomic, copy, nullable) NSArray<STPOrderItem*> *items;

/**
 * A set of key/value pairs that you can attach to an order object.
 * It can be useful for storing additional information about the order in a structured format.
 *
 */
@property (nonatomic, nullable) NSDictionary *metadata;

/**
 * The email address of the customer placing the order.
 *
 */
@property (nonatomic, nullable) NSString *email;

+ (nonnull NSString*)orderStatusToString:(STPOrderStatus)orderStatus;

@end

// This method is used internally by Stripe to deserialize API responses and exposed here for convenience and testing purposes only. You should not use it in
// your own code.
@interface STPOrder (PrivateMethods)
- (nonnull instancetype)initWithAttributeDictionary:(nonnull NSDictionary *)attributeDictionary;
@end


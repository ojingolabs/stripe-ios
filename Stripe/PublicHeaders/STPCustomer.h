//
//  STPCustomer.h
//  Stripe
//
//  Created by Antoine Lavail on 02/10/15.
//  Copyright © 2015 Stripe, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class STPCard, STPShippingInfos;

@interface STPCustomer : NSObject


/**
 *  The Stripe ID for the customer.
 */
@property (nonatomic, readonly, nullable) NSString *custId;

/**
 *  The customer's email address.
 */
@property (nonatomic, copy, nullable) NSString *email;

/**
 *  Whether or not the latest charge for the customer’s latest invoice has failed.
 */
@property (nonatomic, readonly) BOOL delinquent;

/**
 *  The currency the customer can be charged in for recurring billing purposes
 */
@property (nonatomic, copy, nullable) NSString *currency;

/**
 * The customer’s payment sources, if any
 */
@property (nonatomic, copy, nullable) NSArray<STPCard*> *sources;

/**
 * ID of the default source attached to this customer.
 */
@property (nonatomic, copy, nullable) NSString *defaultSourceId;

/**
 * Shipping information associated with the customer.
 */
@property (nonatomic, nullable) STPShippingInfos *shippingInfos;

@end

// This method is used internally by Stripe to deserialize API responses and exposed here for convenience and testing purposes only. You should not use it in
// your own code.
@interface STPCustomer (PrivateMethods)
- (nonnull instancetype)initWithAttributeDictionary:(nonnull NSDictionary *)attributeDictionary;
@end


//
// Created by Antoine Lavail on 05/10/15.
// Copyright (c) 2015 Stripe, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface STPShippingMethod : NSObject

/**
 *  The Stripe ID for the shipping method.
 */
@property (nonatomic, readonly, nullable) NSString *shippingMethodId;

/**
 *  A positive integer in the smallest currency unit
 *  (that is, 100 cents for $1.00, or 1 for ¥1, Japanese Yen being a 0-decimal currency)
 *  representing the total amount for the line item.
 *
 */
@property (nonatomic, readonly) NSInteger *amount;

/**
 *  3-letter ISO code representing the currency of the line item.
 */
@property (nonatomic, copy, nullable) NSString *currency;

/**
 *  Description of the line item, meant to be displayable to the user (e.g., "Express shipping").
 */
@property (nonatomic, copy, nullable) NSString *shippingMethodDescription;

@end
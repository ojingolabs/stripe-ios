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
 * Shipping information associated with the customer.
 */
@property (nonatomic, copy, nullable) NSArray<STPShippingInfos*> *shippingInfos;


@end

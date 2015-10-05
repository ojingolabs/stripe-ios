//
// Created by Antoine Lavail on 05/10/15.
// Copyright (c) 2015 Stripe, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface STPShippingInfos : NSObject

/**
 *  Shipping info's name. Required
 */
@property (nonatomic, copy) NSString *infosName;

/**
 *  Shipping info's phone
 */
@property (nonatomic, copy, nullable) NSString *phone;

/**
 *  Shipping info's line1. Required
 */
@property (nonatomic, copy) NSString *line1;

/**
 *  Shipping info's line2
 */
@property (nonatomic, copy, nullable) NSString *line2;


/**
 *  Shipping info's country
 */
@property (nonatomic, copy, nullable) NSString *country;


/**
 *  Shipping info's postalCode
 */
@property (nonatomic, copy, nullable) NSString *postalCode;


/**
 *  Shipping info's state
 */
@property (nonatomic, copy, nullable) NSString *state;


@end
//
// Created by Antoine Lavail on 05/10/15.
// Copyright (c) 2015 Stripe, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface STPPackage : NSObject

/**
 *  Height, in inches. Maximum precision is 2 decimal places.
 */
@property (nonatomic) float height;


/**
 *  Length, in inches. Maximum precision is 2 decimal places.
 */
@property (nonatomic) float length;


/**
 *  Weight, in ounces. Maximum precision is 2 decimal places.
 */
@property (nonatomic) float weight;


/**
 *  Width, in inches. Maximum precision is 2 decimal places.
 */
@property (nonatomic) float width;

@end
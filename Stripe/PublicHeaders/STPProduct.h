//
//  STPProduct.h
//  Stripe
//
//  Created by Antoine Lavail on 02/10/15.
//  Copyright © 2015 Stripe, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class STPSku, STPPackage;

@interface STPProduct : NSObject

/**
 *  The Stripe ID for the product.
 */
@property (nonatomic, readonly, nullable) NSString *prodId;

/**
 *  Whether or not the product is currently available for purchase.
 */
@property (nonatomic) BOOL active;

/**
 *  Whether or not the product is currently available for purchase.
 */
@property (nonatomic, nullable, copy) NSArray<NSString*>* images;

/**
 *  The product’s name, meant to be displayable to the customer.
 */
@property (nonatomic, copy, nullable) NSString *productName;

/**
 *  A short one-line description of the product, meant to be displayable to the customer.
 */
@property (nonatomic, copy, nullable) NSString *caption;

/**
 *  The product’s description, meant to be displayable to the customer.
 */
@property (nonatomic, copy, nullable) NSString *productDescription;

/**
 *  A URL of a publicly-accessible webpage for this product.
 */
@property (nonatomic, copy, nullable) NSString *productUrl;

/**
 * A list of up to 5 attributes that each SKU can provide values for (e.g. ["color", "size"]).
 */
@property (nonatomic, copy, nullable) NSArray<NSString*> *attributes;

/**
 *  Whether this product is a shipped good.
 */
@property (nonatomic) BOOL shippable;

/**
 * A sublist of active SKUs associated with this product.
 */
@property (nonatomic, copy, nullable) NSArray<STPSku*> *skus;

/**
 * The dimensions of this product, from the perspective of shipping.
 * A SKU associated with this product can override this value by having its own `STPPackage`
 *
 */
@property (nonatomic, copy, nullable) STPPackage *packageDimensions;

@end

// This method is used internally by Stripe to deserialize API responses and exposed here for convenience and testing purposes only. You should not use it in
// your own code.
@interface STPProduct (PrivateMethods)
- (nonnull instancetype)initWithAttributeDictionary:(nonnull NSDictionary *)attributeDictionary;
@end

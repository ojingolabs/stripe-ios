//
//  STPSku.h
//  Stripe
//
//  Created by Antoine Lavail on 02/10/15.
//  Copyright © 2015 Stripe, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class STPPackage, STPInventory;

@interface STPSku : NSObject

/**
 *  The Stripe ID for the SKU.
 */
@property (nonatomic, readonly, nullable) NSString *skuId;

/**
 *  The ID of the product this SKU is associated with. The product must be currently active.
 */
@property (nonatomic, readonly, nullable) NSString *refProdId;

/**
 *  Whether or not the SKU is currently available for purchase.
 */
@property (nonatomic) BOOL active;

/**
 * A dictionary of attributes and values for the attributes defined by the product.
 * If, for example, a product’s attributes are ["size", "gender"],
 * a valid SKU has the following dictionary of attributes: {"size": "Medium", "gender": "Unisex"}
 *
 */
@property (nonatomic, copy, nullable) NSArray<NSString*> *attributes;

/**
 *  The URL of an image for this SKU, meant to be displayable to the customer.
 */
@property (nonatomic, nullable, copy) NSData* image;

/**
 *  The cost of the item as a positive integer in the smallest currency unit
 *  (that is, 100 cents to charge $1.00, or 1 to charge ¥1, Japanese Yen being a 0-decimal currency).
 *
 */
@property (nonatomic, nonnull) NSInteger *price;

/**
 *  3-letter ISO code for currency.
 */
@property (nonatomic, copy, nullable) NSString *currency;

/**
 * Description of the SKU’s inventory.
 *
 */
@property (nonatomic, copy, nullable) STPInventory *inventory;

/**
 * The dimensions of this product, from the perspective of shipping.
 * A SKU associated with this product can override this value by having its own `STPPackage`
 *
 */
@property (nonatomic, copy, nullable) STPPackage *packageDimensions;




@end

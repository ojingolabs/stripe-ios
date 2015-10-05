//
// Created by Antoine Lavail on 05/10/15.
// Copyright (c) 2015 Stripe, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 *  The various inventory types.
 */
typedef NS_ENUM(NSInteger, STPInventoryType) {
    STPInventoryTypeFinite,
    STPInventoryTypeBucket,
    STPInventoryTypeInfinite,
    STPInventoryTypeUnknown = NSIntegerMax
};

/**
 *  The various inventory values.
 */
typedef NS_ENUM(NSInteger, STPInventoryValue) {
    STPInventoryValueInStock,
    STPInventoryValueLimited,
    STPInventoryValueOutOfStock,
    STPInventoryValueUnknown = NSIntegerMax
};


@interface STPInventory : NSObject


- (nonnull instancetype)initWithAttributeDictionary:(nonnull NSDictionary *)attributeDictionary;

/**
 *  Inventory type. Possible values are finite, bucket, and infinite.
 */
@property (nonatomic) STPInventoryType inventoryType;

/**
 *  The count of inventory available. Will be present if and only if type is finite.
 *
 */
@property (nonatomic) NSInteger quantity;

/**
 *  An indicator of the inventory available.
 *  Possible values are in_stock, limited, and out_of_stock. Will be present if and only if type is bucket.
 */
@property (nonatomic) STPInventoryValue inventoryValue;

@end

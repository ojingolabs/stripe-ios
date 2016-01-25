//
// Created by Antoine Lavail on 05/10/15.
// Copyright (c) 2015 Stripe, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 *  The various order status.
 */
typedef NS_ENUM(NSInteger, STPOrderItemType) {
    STPOrderItemTypeSku,
    STPOrderItemTypeTax,
    STPOrderItemTypeShipping,
    STPOrderItemTypeDiscount,
    STPOrderItemTypeUnknown = NSIntegerMax
};


@interface STPOrderItem : NSObject

/**
 *  A positive integer in the smallest currency unit
 *  (that is, 100 cents for $1.00, or 1 for ¥1, Japanese Yen being a 0-decimal currency)
 *  representing the total amount for the line item.
 */
@property (nonatomic) NSInteger amount;

/**
 *  3-letter ISO code representing the currency of the line item.
 */
@property (nonatomic, copy, nullable) NSString *currency;

/**
 *  Description of the line item, meant to be displayable to the user (e.g., "Express shipping").
 */
@property (nonatomic, copy, nullable) NSString *itemDescription;

/**
 *  Current order item type. Can be Sku, Tax, Shipping or Discount
 */
@property (nonatomic) STPOrderItemType type;

/**
 *  The ID of the associated object for this line item. Expandable if not null (e.g., expandable to a SKU).
 */
@property (nonatomic, copy, nullable) NSString *parentId;

/**
 * A positive integer representing the number of instances of parent that are included in this order item.
 * Applicable/present only if type is sku.
 */
@property (nonatomic) NSInteger quantity;

- (nullable NSDictionary*)dictionaryOutputWithIndex:(int)idx;

@end

@interface STPOrderItem (PrivateMethods)
- (nonnull instancetype)initWithAttributeDictionary:(nonnull NSDictionary *)attributeDictionary;
@end

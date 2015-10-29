//
//  STPSku.m
//  Stripe
//
//  Created by Antoine Lavail on 02/10/15.
//  Copyright © 2015 Stripe, Inc. All rights reserved.
//

#import "STPSku.h"
#import "STPPackage.h"
#import "STPOrderItem.h"
#import "STPInventory.h"

@implementation STPSku

- (instancetype)init {
    self = [super init];
    if (self) {
    }
    
    return self;
}

@end

// This method is used internally by Stripe to deserialize API responses and exposed here for convenience and testing purposes only. You should not use it in
// your own code.
@implementation STPSku (PrivateMethods)
- (nonnull instancetype)initWithAttributeDictionary:(nonnull NSDictionary *)attributeDictionary {
    self = [self init];

    NSMutableDictionary *dict = [NSMutableDictionary dictionary];

    [attributeDictionary enumerateKeysAndObjectsUsingBlock:^(id key, id obj, __unused BOOL *stop) {
        if (obj != [NSNull null]) {
            dict[key] = obj;
        }
    }];

    if (self) {
        _skuId = dict[@"id"];
        _active = [dict[@"active"] boolValue];
        _currency = dict[@"currency"];
        _price = [dict[@"price"] integerValue];
        _refProdId = dict[@"product"];
        _imageURL = dict[@"image"];
        if (dict[@"package_dimensions"]) {
            _packageDimensions = [[STPPackage alloc] initWithAttributeDictionary:dict[@"package_dimensions"]];
        }
        _inventory = [[STPInventory alloc] initWithAttributeDictionary:dict[@"inventory"]];
    }
    return self;
}

+ (STPOrderItem*)createOrderItemFromSku:(STPSku*)sku andQuantity:(NSInteger)quantity {
    STPOrderItem *orderItem = [[STPOrderItem alloc] init];
    orderItem.type = STPOrderItemTypeSku;
    orderItem.parentId = sku.skuId;
    orderItem.amount = sku.price;
    orderItem.currency = sku.currency;
    orderItem.quantity = quantity;
    return orderItem;
}

@end

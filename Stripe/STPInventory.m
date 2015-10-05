//
// Created by Antoine Lavail on 05/10/15.
// Copyright (c) 2015 Stripe, Inc. All rights reserved.
//

#import "STPInventory.h"

@implementation STPInventory

- (instancetype)init {
    self = [super init];
    if (self) {
    }

    return self;
}

- (nonnull instancetype)initWithAttributeDictionary:(nonnull NSDictionary *)attributeDictionary {
    self = [self init];

    NSMutableDictionary *dict = [NSMutableDictionary dictionary];

    [attributeDictionary enumerateKeysAndObjectsUsingBlock:^(id key, id obj, __unused BOOL *stop) {
        if (obj != [NSNull null]) {
            dict[key] = obj;
        }
    }];

    if (self) {
        _quantity = [dict[@"quantity"] integerValue];
        [self setTypeWithString:dict[@"type"]];
        if (_inventoryType == STPInventoryTypeBucket) {
            [self setValueWithString:dict[@"value"]];
        } else {
            _inventoryValue = STPInventoryValueUnknown;
        }
    }
    return self;
}

- (void)setTypeWithString:(NSString*)strType {
    if ([strType isEqualToString:@"finite"]) {
        _inventoryType = STPInventoryTypeFinite;
    }
    else if ([strType isEqualToString:@"bucket"]) {
        _inventoryType = STPInventoryTypeBucket;
    }
    else if ([strType isEqualToString:@"infinite"]) {
        _inventoryType = STPInventoryTypeInfinite;
    } else {
        _inventoryType = STPInventoryTypeUnknown;
    }
}

- (void)setValueWithString:(NSString*)strValue {
    if ([strValue isEqualToString:@"in_stock"]) {
        _inventoryValue = STPInventoryValueInStock;
    }
    else if ([strValue isEqualToString:@"limited"]) {
        _inventoryValue = STPInventoryValueLimited;
    }
    else if ([strValue isEqualToString:@"out_of_stock"]) {
        _inventoryValue = STPInventoryValueOutOfStock;
    } else {
        _inventoryValue = STPInventoryValueUnknown;
    }
}
@end

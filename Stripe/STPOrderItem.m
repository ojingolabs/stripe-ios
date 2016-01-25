//
// Created by Antoine Lavail on 05/10/15.
// Copyright (c) 2015 Stripe, Inc. All rights reserved.
//

#import "STPOrderItem.h"


@implementation STPOrderItem {

}

- (NSDictionary*)dictionaryOutputWithIndex:(int)idx {
    NSString *prefix = [NSString stringWithFormat:@"items[%d]",idx];
    return @{
            [NSString stringWithFormat:@"%@[amount]",prefix] : @(_amount),
            [NSString stringWithFormat:@"%@[currency]",prefix] : _currency,
            [NSString stringWithFormat:@"%@[type]",prefix] : [[self class] orderTypeString:_type],
            [NSString stringWithFormat:@"%@[parent]",prefix] : _parentId,
            [NSString stringWithFormat:@"%@[quantity]",prefix] : @(_quantity)
    };
}

+ (NSString*)orderTypeString:(STPOrderItemType)type
{
    switch(type) {
        case STPOrderItemTypeSku:
            return @"sku";
        case STPOrderItemTypeTax:
            return @"tax";
        case STPOrderItemTypeShipping:
            return @"shipping";
        case STPOrderItemTypeDiscount:
            return @"discount";
        default:
            return @"unknown";
    }
}

+ (STPOrderItemType)orderType:(NSString*)type
{
    if ([type isEqualToString:@"sku"])
    {
        return STPOrderItemTypeSku;
    }
    else if ([type isEqualToString:@"tax"])
    {
        return STPOrderItemTypeTax;
    }
    else if ([type isEqualToString:@"shipping"])
    {
        return STPOrderItemTypeShipping;
    }
    else if ([type isEqualToString:@"discount"])
    {
        return STPOrderItemTypeDiscount;
    }
    return STPOrderItemTypeUnknown;
}

@end


@implementation STPOrderItem(PrivateMethods)

- (instancetype)initWithAttributeDictionary:(NSDictionary *)attributeDictionary {
    self = [self init];

    NSMutableDictionary *dict = [NSMutableDictionary dictionary];

    [attributeDictionary enumerateKeysAndObjectsUsingBlock:^(id key, id obj, __unused BOOL *stop) {
        if (obj != [NSNull null]) {
            dict[key] = obj;
        }
    }];

    if (self) {
        _amount = [dict[@"amount"] integerValue];
        _currency = dict[@"currency"];
        _itemDescription = dict[@"description"];
        _parentId = dict[@"parent"];
        _type = [STPOrderItem orderType:dict[@"type"]];
        if (STPOrderItemTypeSku == _type) {
            _quantity = [dict[@"quantity"] integerValue];
        }
    }
    return self;
}

@end

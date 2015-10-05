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

@end

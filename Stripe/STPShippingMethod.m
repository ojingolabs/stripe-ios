//
// Created by Antoine Lavail on 05/10/15.
// Copyright (c) 2015 Stripe, Inc. All rights reserved.
//

#import "STPShippingMethod.h"


@implementation STPShippingMethod

- (instancetype)init {
    self = [super init];
    if (self) {
    }

    return self;
}

@end

@implementation STPShippingMethod (PrivateMethods)

- (instancetype)initWithAttributeDictionary:(nonnull NSDictionary *)attributeDictionary {
    self = [self init];

    NSMutableDictionary *dict = [NSMutableDictionary dictionary];

    [attributeDictionary enumerateKeysAndObjectsUsingBlock:^(id key, id obj, __unused BOOL *stop) {
        if (obj != [NSNull null]) {
            dict[key] = obj;
        }
    }];

    if (self) {
        _shippingMethodId = dict[@"id"];
        _amount = [dict[@"amount"] integerValue];
        _currency = dict[@"currency"];
        _shippingMethodDescription = dict[@"description"];
    }
    return self;
}

@end

//
// Created by Antoine Lavail on 05/10/15.
// Copyright (c) 2015 Stripe, Inc. All rights reserved.
//

#import "STPPackage.h"


@implementation STPPackage

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
        _height = [dict[@"height"] floatValue];
        _length = [dict[@"length"] floatValue];
        _weight = [dict[@"weight"] floatValue];
        _width = [dict[@"width"] floatValue];
    }
    return self;
}

@end

//
//  STPCustomer.m
//  Stripe
//
//  Created by Antoine Lavail on 02/10/15.
//  Copyright © 2015 Stripe, Inc. All rights reserved.
//

#import "STPCustomer.h"
#import "STPCard.h"
#import "STPShippingInfos.h"

@implementation STPCustomer

- (instancetype)init {
    self = [super init];
    if (self) {
        _sources = [NSArray array];
    }

    return self;
}

@end

@implementation STPCustomer(PrivateMethods)

- (instancetype)initWithAttributeDictionary:(NSDictionary *)attributeDictionary {
    self = [self init];

    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [attributeDictionary enumerateKeysAndObjectsUsingBlock:^(id key, id obj, __unused BOOL *stop) {
        if (obj != [NSNull null]) {
            dict[key] = obj;
        }
    }];

    if (self) {
        _custId = dict[@"id"];
        _email = dict[@"email"];
        _delinquent = [dict[@"delinquent"] boolValue];
        _currency = dict[@"currency"];
        _defaultSourceId = dict[@"default_source"];

        if (dict[@"sources"] && dict[@"sources"][@"data"]) {
            NSMutableArray<STPCard*> *sourcesArray = [[NSMutableArray alloc] initWithCapacity:[dict[@"sources"][@"data"] count]];
            for (id source in dict[@"sources"][@"data"]) {
                [sourcesArray addObject:[[STPCard alloc] initWithAttributeDictionary:source]];
            }
            _sources = [NSArray arrayWithArray:sourcesArray];
        }
        if (dict[@"shipping"]) {
            _shippingInfos = [[STPShippingInfos alloc] initWithAttributeDictionary:dict[@"shipping"]];
        }
    }
    return self;
}

@end

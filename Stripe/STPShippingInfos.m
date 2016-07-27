//
// Created by Antoine Lavail on 05/10/15.
// Copyright (c) 2015 Stripe, Inc. All rights reserved.
//

#import "STPShippingInfos.h"


@implementation STPShippingInfos

- (instancetype)init {
    self = [super init];
    if (self) {
        _infosName = @"";
        _phone = @"";
        _line1 = @"";
        _line2 = @"";
        _city = @"";
        _country = @"";
        _postalCode = @"";
        _state = @"";
        _carrier = @"";
        _trackingNumber = @"";
    }

    return self;
}

- (instancetype)initWithAttributeDictionary:(nonnull NSDictionary *)attributeDictionary {
    self = [self init];

    NSMutableDictionary *dict = [NSMutableDictionary dictionary];

    [attributeDictionary enumerateKeysAndObjectsUsingBlock:^(id key, id obj, __unused BOOL *stop) {
        if (obj != [NSNull null]) {
            dict[key] = obj;
        }
    }];

    if (self) {
        _infosName = (dict[@"name"] == nil) ? @"" : dict[@"name"];
        _phone = (dict[@"phone"] == nil) ? @"" : dict[@"phone"];
        _line1 = ([dict[@"address"][@"line1"] isEqual:[NSNull null]]) ? @"" : dict[@"address"][@"line1"];
        _line2 = ([dict[@"address"][@"line2"] isEqual:[NSNull null]]) ? @"" : dict[@"address"][@"line2"];
        _city = ([dict[@"address"][@"city"] isEqual:[NSNull null]]) ? @"" : dict[@"address"][@"city"];
        _country = ([dict[@"address"][@"country"] isEqual:[NSNull null]]) ? @"" : dict[@"address"][@"country"];
        _postalCode = ([dict[@"address"][@"postal_code"] isEqual:[NSNull null]]) ? @"" : dict[@"address"][@"postal_code"];
        _state = ([dict[@"address"][@"state"] isEqual:[NSNull null]]) ? @"" : dict[@"address"][@"state"];
        _carrier = (dict[@"carrier"] == nil) ? @"" : dict[@"carrier"];
        _trackingNumber = (dict[@"tracking_number"] == nil) ? @"" : dict[@"tracking_number"];
    }
    return self;
}

- (NSDictionary*)dictionaryOutput {
    return @{
            @"shipping[name]":_infosName,
            @"shipping[phone]":(_phone) ? _phone : @"",
            @"shipping[address][line1]":_line1,
            @"shipping[address][line2]":(_line2) ? _line2 : @"",
            @"shipping[address][city]":(_city) ? _city : @"",
            @"shipping[address][country]":(_country) ? _country : @"",
            @"shipping[address][postal_code]":(_postalCode) ? _postalCode : @"",
            @"shipping[address][state]":(_state) ? _state : @"",
    };
}

- (BOOL)isEqualToShippingInfos:(nonnull STPShippingInfos*)shippingInfos {
    if ([self.infosName isEqual:shippingInfos.infosName] &&
        [self.country isEqual:shippingInfos.country] &&
        [self.line1 isEqual:shippingInfos.line1] &&
        [self.line2 isEqual:shippingInfos.line2] &&
        [self.city isEqual:shippingInfos.city] &&
        [self.state isEqual:shippingInfos.state] &&
        [self.postalCode isEqual:shippingInfos.postalCode] &&
        [self.phone isEqual:shippingInfos.phone]) {
        return YES;
    } else {
        return NO;
    }
}

@end

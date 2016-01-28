//
//  STPOrder.m
//  Stripe
//
//  Created by Antoine Lavail on 02/10/15.
//  Copyright © 2015 Stripe, Inc. All rights reserved.
//

#import <Stripe/Stripe.h>

@implementation STPOrder


- (instancetype)init {
    self = [super init];
    if (self) {
    }

    return self;
}

+ (NSString*)orderStatusToString:(STPOrderStatus)orderStatus {
    switch (orderStatus) {
        case STPOrderStatusCreated:
            return @"created";
        case STPOrderStatusPaid:
            return @"paid";
        case STPOrderStatusCanceled:
            return @"canceled";
        case STPOrderStatusFulfilled:
            return @"fulfilled";
        case STPOrderStatusReturned:
            return @"returned";
        default:
            return @"unknown";
    }
}
@end

@implementation STPOrder(PrivateMethods)

- (instancetype)initWithAttributeDictionary:(NSDictionary *)attributeDictionary {
    self = [self init];

    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [attributeDictionary enumerateKeysAndObjectsUsingBlock:^(id key, id obj, __unused BOOL *stop) {
        if (obj != [NSNull null]) {
            dict[key] = obj;
        }
    }];

    if (self) {
        _orderId = dict[@"id"];
        _amount = [dict[@"amount"] integerValue];
        _currency = dict[@"currency"];
        _applicationFee = [dict[@"application_fee"] integerValue];
        _customerId = dict[@"customer"];
        _selectedShippingMethodId = dict[@"selected_shipping_method"];
        _metadata = dict[@"metadata"];
        _email = dict[@"email"];

        _orderStatus = [self orderStatusFromString:dict[@"status"]];
        if (_orderStatus == STPOrderStatusPaid || _orderStatus == STPOrderStatusFulfilled || _orderStatus == STPOrderStatusReturned) {
            _chargeId = dict[@"charge"];
        }

        _shippingInfos = [[STPShippingInfos alloc] initWithAttributeDictionary:dict[@"shipping"]];

        NSMutableArray *methods = [NSMutableArray arrayWithCapacity:[dict[@"shipping_methods"] count]];
        for (id method in dict[@"shipping_methods"]) {
            [methods addObject:[[STPShippingMethod alloc] initWithAttributeDictionary:method]];
        }
        _shippingMethods = methods;

        NSMutableArray *items = [NSMutableArray arrayWithCapacity:[dict[@"items"] count]];
        for (id item in dict[@"items"]) {
            [items addObject:[[STPOrderItem alloc] initWithAttributeDictionary:item]];
        }
        _items = items;
    }
    return self;
}

- (STPOrderStatus)orderStatusFromString:(NSString*)status
{
    if ([status isEqualToString:@"created"]) {
        return STPOrderStatusCreated;
    }
    else if ([status isEqualToString:@"paid"]) {
        return STPOrderStatusPaid;
    }
    else if ([status isEqualToString:@"canceled"]) {
        return STPOrderStatusCanceled;
    }
    else if ([status isEqualToString:@"fulfilled"]) {
        return STPOrderStatusFulfilled;
    }
    else if ([status isEqualToString:@"returned"]) {
        return STPOrderStatusReturned;
    }
    else {
        return STPOrderStatusUnknown;
    }
}
@end

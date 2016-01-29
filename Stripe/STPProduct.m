//
//  STPProduct.m
//  Stripe
//
//  Created by Antoine Lavail on 02/10/15.
//  Copyright © 2015 Stripe, Inc. All rights reserved.
//

#import "STPProduct.h"
#import "STPPackage.h"
#import "STPSku.h"

@implementation STPProduct

- (instancetype)init {
    self = [super init];
    if (self) {
        _images = [NSArray array];
        _attributes = [NSArray array];
    }

    return self;
}

+ (NSNumber *)priceMinForSTPProduct:(nonnull STPProduct *)product
{
    __block float minPrice = -1;
    if (product.skus.count > 0)
    {
        minPrice = product.skus.firstObject.price;
        [product.skus enumerateObjectsUsingBlock:^(STPSku *sku, NSUInteger idx, BOOL *stop) {
            minPrice = MIN(minPrice,sku.price);
        }];
    }
    return (minPrice == -1) ? nil : @(minPrice);
}

+ (NSNumber *)priceMaxForSTPProduct:(nonnull STPProduct *)product
{
    __block float maxPrice;
    if (product.skus.count > 0)
    {
        maxPrice = product.skus.firstObject.price;
        [product.skus enumerateObjectsUsingBlock:^(STPSku *sku, NSUInteger idx, BOOL *stop) {
            maxPrice = MAX(maxPrice,sku.price);
        }];
    }
    return (maxPrice == -1) ? nil : @(maxPrice);
}

@end

@implementation STPProduct(PrivateMethods)

- (instancetype)initWithAttributeDictionary:(NSDictionary *)attributeDictionary {
    self = [self init];

    NSMutableDictionary *dict = [NSMutableDictionary dictionary];

    [attributeDictionary enumerateKeysAndObjectsUsingBlock:^(id key, id obj, __unused BOOL *stop) {
        if (obj != [NSNull null]) {
            dict[key] = obj;
        }
    }];

    if (self) {
        _prodId = dict[@"id"];
        _active = [dict[@"active"] boolValue];
        _shippable = [dict[@"shippable"] boolValue];
        _productName = dict[@"name"] ? dict[@"name"] : @"";
        _caption = dict[@"caption"] ? dict[@"caption"] : @"";
        _productDescription = dict[@"description"] ? dict[@"description"] : @"";
        _productUrl = dict[@"url"];

        if (dict[@"images"]) {
            NSMutableArray<NSString*> *imagesArray = [[NSMutableArray alloc] initWithCapacity:[dict[@"images"] count]];
            for (NSString *imageURL in dict[@"images"]) {
                if (imageURL)
                    [imagesArray addObject:imageURL];
            }
            _images = [NSArray arrayWithArray:imagesArray];
        }

        if (dict[@"attributes"]) {
            NSMutableArray<NSString*> *attrsArray = [[NSMutableArray alloc] initWithCapacity:[dict[@"attributes"] count]];
            for (NSString *attr in dict[@"attributes"]) {
                if (attr)
                    [attrsArray addObject:attr];
            }
            _attributes = [NSArray arrayWithArray:attrsArray];
        }

        if (dict[@"package_dimensions"]) {
            _packageDimensions = [[STPPackage alloc] initWithAttributeDictionary:dict[@"package_dimensions"]];
        }

        if (dict[@"skus"]) {
            NSMutableArray<STPSku*> *skusArray = [[NSMutableArray alloc] initWithCapacity:[dict[@"skus"][@"data"] count]];
            for (id sku in dict[@"skus"][@"data"]) {
                if (sku)
                    [skusArray addObject:[[STPSku alloc] initWithAttributeDictionary:sku]];
            }
            _skus = [NSArray arrayWithArray:skusArray];
        }
    }
    return self;
}

@end


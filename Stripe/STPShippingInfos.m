//
// Created by Antoine Lavail on 05/10/15.
// Copyright (c) 2015 Stripe, Inc. All rights reserved.
//

#import "STPShippingInfos.h"


@implementation STPShippingInfos
{
    STPShippingInfoValidationErrors _firstValidationErrorCode;
}

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
        _firstValidationErrorCode = STPShippingInfoValidationErrorNoError;
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
        
        _firstValidationErrorCode = STPShippingInfoValidationErrorNoError;
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

- (STPShippingInfoValidationErrors)validationErrorCode
{
    BOOL isValid = [self isValid];
    if (isValid)
        _firstValidationErrorCode = STPShippingInfoValidationErrorNoError;
    
    return _firstValidationErrorCode;
}

- (BOOL)isValid
{
    BOOL isValid =  [self validateName:self.infosName] && [self validatePhone:self.phone] && [self validateStreet:self.line1 line2:self.line2] && [self validateCity:self.city] && [self validateState:self.state] && [self validatePostalCode:self.postalCode] && [self validateCountry:self.country];
    
    if (isValid)
        _firstValidationErrorCode = STPShippingInfoValidationErrorNoError;
    
    return isValid;
}

- (BOOL)validateName:(NSString *)name
{
    if (name == nil) {
        _firstValidationErrorCode = STPShippingInfoValidationErrorFullNameLength;
        return NO;
    }
    NSMutableCharacterSet *characterSet = [NSMutableCharacterSet letterCharacterSet];
    [characterSet formUnionWithCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@" .-"]];
    
    BOOL condition1 = [name stringByTrimmingCharactersInSet:characterSet].length == 0;
    BOOL condition2 = name.length >= 2 && name.length <= 150;
    
    if (!condition1)
        _firstValidationErrorCode = STPShippingInfoValidationErrorFullNameInvalidCharacters;
    
    if (!condition2)
        _firstValidationErrorCode = STPShippingInfoValidationErrorFullNameLength;
    
    return condition1 && condition2;
}

- (BOOL)validatePhone:(NSString *)phone
{
    if (phone == nil) {
        _firstValidationErrorCode = STPShippingInfoValidationErrorPhoneLength;
        return NO;
    }
    NSMutableCharacterSet *characterSet = [NSMutableCharacterSet decimalDigitCharacterSet];
    [characterSet formUnionWithCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@"+"]];
    
    BOOL condition1 = [phone stringByTrimmingCharactersInSet:characterSet].length == 0;
    BOOL condition2 = phone.length >= 6 && phone.length <= 35;
    BOOL condition3 = phone.length > 0 && [phone characterAtIndex:0] == '+';
    
    if (!condition1)
        _firstValidationErrorCode = STPShippingInfoValidationErrorPhoneInvalidCharacters;
    
    if (!condition2)
        _firstValidationErrorCode = STPShippingInfoValidationErrorPhoneLength;
    
    if (!condition3)
        _firstValidationErrorCode = STPShippingInfoValidationErrorPhonePlusCharacter;
    
    return condition1 && condition2 && condition3;
}

- (BOOL)validateStreet:(NSString *)line1 line2:(NSString *)line2
{
    if (line1 == nil) {
        _firstValidationErrorCode = STPShippingInfoValidationErrorAddressLength;
        return NO;
    }
    NSString *fullAddress = [line1 stringByAppendingString:line2];
    NSMutableCharacterSet *characterSet = [NSMutableCharacterSet decimalDigitCharacterSet];
    [characterSet formUnionWithCharacterSet:[NSCharacterSet letterCharacterSet]];
    [characterSet formUnionWithCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@"-/\\&_()'\"* .,:;?!"]];
    
    BOOL condition1 = [fullAddress stringByTrimmingCharactersInSet:characterSet].length == 0;
    BOOL condition2 = fullAddress.length >= 4 && fullAddress.length <= 200;
    
    if (!condition1)
        _firstValidationErrorCode = STPShippingInfoValidationErrorAddressInvalidCharacters;
    
    if (!condition2)
        _firstValidationErrorCode = STPShippingInfoValidationErrorAddressLength;
    
    return condition1 && condition2;
}

- (BOOL)validatePostalCode:(NSString *)postalCode
{
    if (postalCode == nil) {
        _firstValidationErrorCode = STPShippingInfoValidationErrorPostalCodeLength;
        return NO;
    }
    NSMutableCharacterSet *characterSet = [NSMutableCharacterSet decimalDigitCharacterSet];
    [characterSet formUnionWithCharacterSet:[NSCharacterSet letterCharacterSet]];
    [characterSet formUnionWithCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@"- "]];
    
    BOOL condition1 = [postalCode stringByTrimmingCharactersInSet:characterSet].length == 0;
    BOOL condition2 = postalCode.length >= 4 && postalCode.length <= 32;
    
    if (!condition1)
        _firstValidationErrorCode = STPShippingInfoValidationErrorPostalCodeInvalidCharacters;
    
    if (!condition2)
        _firstValidationErrorCode = STPShippingInfoValidationErrorPostalCodeLength;
    
    return condition1 && condition2;
}

- (BOOL)validateCity:(NSString *)city
{
    if (city == nil) {
        _firstValidationErrorCode = STPShippingInfoValidationErrorCityLength;
        return NO;
    }
    NSMutableCharacterSet *characterSet = [NSMutableCharacterSet letterCharacterSet];
    [characterSet addCharactersInString:@" -'"];
    
    BOOL condition1 = [city stringByTrimmingCharactersInSet:characterSet].length == 0;
    BOOL condition2 = city.length >= 1 && city.length <= 100;
    
    if (!condition1)
        _firstValidationErrorCode = STPShippingInfoValidationErrorCityInvalidCharacters;
    
    if (!condition2)
        _firstValidationErrorCode = STPShippingInfoValidationErrorCityLength;
    
    return condition1 && condition2;
}

- (BOOL)validateState:(NSString *)state
{
    if (state == nil) {
        _firstValidationErrorCode = STPShippingInfoValidationErrorStateLength;
        return NO;
    }
    NSMutableCharacterSet *characterSet = [NSMutableCharacterSet letterCharacterSet];
    
    BOOL condition1 = [state stringByTrimmingCharactersInSet:characterSet].length == 0;
    BOOL condition2 = state.length <= 100;
    
    if (!condition1)
        _firstValidationErrorCode = STPShippingInfoValidationErrorStateInvalidCharacters;
    
    if (!condition2)
        _firstValidationErrorCode = STPShippingInfoValidationErrorStateLength;
    
    return condition1 && condition2;
}

- (BOOL)validateCountry:(NSString *)country
{
    if (country == nil) {
        _firstValidationErrorCode = STPShippingInfoValidationErrorCountryLength;
        return NO;
    }
    NSMutableCharacterSet *characterSet = [NSMutableCharacterSet letterCharacterSet];
    
    BOOL condition1 = [country stringByTrimmingCharactersInSet:characterSet].length == 0;
    BOOL condition2 = country.length >= 1 && country.length <= 100;
    
    if (!condition1)
        _firstValidationErrorCode = STPShippingInfoValidationErrorCountryInvalidCharacters;
    
    if (!condition2)
        _firstValidationErrorCode = STPShippingInfoValidationErrorCountryLength;
    
    return condition1 && condition2;
}

@end

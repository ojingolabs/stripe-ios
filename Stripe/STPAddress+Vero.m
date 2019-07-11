//
//  STPAddress+Vero.m
//  Vero Labs, Inc.
//
//  Created by Antoine Lavail on 1/09/19.
//  Copyright © 2019 Vero Labs, Inc. All rights reserved.
//

#import "STPAddress+Vero.h"

STPAddressValidationErrors _firstValidationErrorCode;

@implementation STPAddress (Vero)

- (NSDictionary*)dictionaryOutput {
    return @{
             @"shipping[name]":self.name,
             @"shipping[phone]":(self.phone) ? self.phone : @"",
             @"shipping[address][line1]":self.line1,
             @"shipping[address][line2]":(self.line2) ? self.line2 : @"",
             @"shipping[address][city]":(self.city) ? self.city : @"",
             @"shipping[address][country]":(self.country) ? self.country : @"",
             @"shipping[address][postal_code]":(self.postalCode) ? self.postalCode : @"",
             @"shipping[address][state]":(self.state) ? self.state : @"",
             };
}

- (BOOL)isEqualToShippingAddress:(STPAddress*)address
{
    if ([self.name isEqual:address.name] &&
        [self.country isEqual:address.country] &&
        [self.line1 isEqual:address.line1] &&
        [self.line2 isEqual:address.line2] &&
        [self.city isEqual:address.city] &&
        [self.state isEqual:address.state] &&
        [self.postalCode isEqual:address.postalCode] &&
        [self.phone isEqual:address.phone]) {
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)isEqualToBillingAddress:(STPAddress*)address
{
    if ([self.name isEqual:address.name] &&
        [self.country isEqual:address.country] &&
        [self.line1 isEqual:address.line1] &&
        [self.line2 isEqual:address.line2] &&
        [self.city isEqual:address.city] &&
        [self.state isEqual:address.state] &&
        [self.postalCode isEqual:address.postalCode]) {
        return YES;
    } else {
        return NO;
    }
}

- (STPAddressValidationErrors)shippingValidationErrorCode
{
    BOOL isValid = [self isValidShipping];
    if (isValid)
        _firstValidationErrorCode = STPAddressValidationErrorNoError;
    
    return _firstValidationErrorCode;
}

- (STPAddressValidationErrors)billingValidationErrorCode
{
    BOOL isValid = [self isValidBilling];
    if (isValid)
        _firstValidationErrorCode = STPAddressValidationErrorNoError;

    return _firstValidationErrorCode;
}

- (BOOL)isValidShipping
{
    BOOL isValid =  [self validateName:self.name] && [self validatePhone:self.phone] && [self validateStreet:self.line1 line2:self.line2] && [self validateCity:self.city] && [self validateState:self.state] && [self validatePostalCode:self.postalCode] && [self validateCountry:self.country];
    
    if (isValid)
        _firstValidationErrorCode = STPAddressValidationErrorNoError;
    
    return isValid;
}

- (BOOL)isValidBilling
{
    BOOL isValid =  [self validateName:self.name] && [self validateStreet:self.line1 line2:self.line2] && [self validateCity:self.city] && [self validateState:self.state] && [self validatePostalCode:self.postalCode] && [self validateCountry:self.country];

    if (isValid)
        _firstValidationErrorCode = STPAddressValidationErrorNoError;

    return isValid;
}

- (BOOL)validateName:(NSString *)name
{
    if (name == nil) {
        _firstValidationErrorCode = STPAddressValidationErrorFullNameLength;
        return NO;
    }
    BOOL condition1 = name.length >= 2 && name.length <= 150;
    if (!condition1)
        _firstValidationErrorCode = STPAddressValidationErrorFullNameLength;
    
    return condition1;
}

- (BOOL)validatePhone:(NSString *)phone
{
    if (phone == nil) {
        _firstValidationErrorCode = STPAddressValidationErrorPhoneLength;
        return NO;
    }
    NSMutableCharacterSet *characterSet = [NSMutableCharacterSet decimalDigitCharacterSet];
    [characterSet formUnionWithCharacterSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [characterSet formUnionWithCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@"+"]];
    
    BOOL condition1 = [phone stringByTrimmingCharactersInSet:characterSet].length == 0;
    BOOL condition2 = phone.length >= 6 && phone.length <= 35;
    
    if (!condition1)
        _firstValidationErrorCode = STPAddressValidationErrorPhoneInvalidCharacters;
    
    if (!condition2)
        _firstValidationErrorCode = STPAddressValidationErrorPhoneLength;
    
    return condition1 && condition2;
}

- (BOOL)validateStreet:(NSString *)line1 line2:(NSString *)line2
{
    if (line1 == nil) {
        _firstValidationErrorCode = STPAddressValidationErrorAddressLength;
        return NO;
    }
    NSString *fullAddress = [line1 stringByAppendingString:line2];
    BOOL condition1 = fullAddress.length >= 4 && fullAddress.length <= 250;
    if (!condition1)
        _firstValidationErrorCode = STPAddressValidationErrorAddressLength;
    
    return condition1;
}

- (BOOL)validatePostalCode:(NSString *)postalCode
{
    if (postalCode == nil) {
        _firstValidationErrorCode = STPAddressValidationErrorPostalCodeLength;
        return NO;
    }
    BOOL condition1 = postalCode.length >= 4 && postalCode.length <= 32;
    if (!condition1)
        _firstValidationErrorCode = STPAddressValidationErrorPostalCodeLength;
    
    return condition1;
}

- (BOOL)validateCity:(NSString *)city
{
    if (city == nil) {
        _firstValidationErrorCode = STPAddressValidationErrorCityLength;
        return NO;
    }
    BOOL condition1 = city.length >= 1 && city.length <= 100;
    if (!condition1)
        _firstValidationErrorCode = STPAddressValidationErrorCityLength;
    
    return condition1;
}

- (BOOL)validateState:(NSString *)state
{
    if (state == nil) {
        _firstValidationErrorCode = STPAddressValidationErrorStateLength;
        return NO;
    }
    BOOL condition1 = state.length <= 100;
    if (!condition1)
        _firstValidationErrorCode = STPAddressValidationErrorStateLength;
    
    return condition1;
}

- (BOOL)validateCountry:(NSString *)country
{
    if (country == nil) {
        _firstValidationErrorCode = STPAddressValidationErrorCountryLength;
        return NO;
    }
    NSMutableCharacterSet *characterSet = [NSMutableCharacterSet letterCharacterSet];
    
    BOOL condition1 = [country stringByTrimmingCharactersInSet:characterSet].length == 0;
    BOOL condition2 = country.length >= 1 && country.length <= 100;
    
    if (!condition1)
        _firstValidationErrorCode = STPAddressValidationErrorCountryInvalidCharacters;
    
    if (!condition2)
        _firstValidationErrorCode = STPAddressValidationErrorCountryLength;
    
    return condition1 && condition2;
}

@end

//
//  STPAddress.m
//  Stripe
//
//  Created by Ben Guo on 4/13/16.
//  Copyright © 2016 Stripe, Inc. All rights reserved.
//

#import "NSDictionary+Stripe.h"
#import "STPAddress.h"
#import "STPCardValidator.h"
#import "STPEmailAddressValidator.h"
#import "STPPhoneNumberValidator.h"
#import "STPPostalCodeValidator.h"

#import <Contacts/Contacts.h>

#define FAUXPAS_IGNORED_IN_FILE(...)
FAUXPAS_IGNORED_IN_FILE(APIAvailability)

NSString *stringIfHasContentsElseNil(NSString *string);

@interface STPAddress ()

@property (nonatomic, readwrite, nonnull, copy) NSDictionary *allResponseFields;
@property (nonatomic, readwrite, nullable, copy) NSString *givenName;
@property (nonatomic, readwrite, nullable, copy) NSString *familyName;
@end

@implementation STPAddress
{
    STPAddressValidationErrors _firstValidationErrorCode;
}

+ (NSDictionary *)shippingInfoForChargeWithAddress:(nullable STPAddress *)address
                                    shippingMethod:(nullable PKShippingMethod *)method {
    if (!address) {
        return nil;
    }
    NSMutableDictionary *params = [NSMutableDictionary new];
    params[@"name"] = address.name;
    params[@"phone"] = address.phone;
    params[@"carrier"] = method.label;
    NSMutableDictionary *addressDict = [NSMutableDictionary new];
    addressDict[@"line1"] = address.line1;
    addressDict[@"line2"] = address.line2;
    addressDict[@"city"] = address.city;
    addressDict[@"state"] = address.state;
    addressDict[@"postal_code"] = address.postalCode;
    addressDict[@"country"] = address.country;
    params[@"address"] = [addressDict copy];
    return [params copy];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"

- (instancetype)initWithABRecord:(ABRecordRef)record {
    self = [super init];
    if (self) {
        NSString *firstName = (__bridge_transfer NSString*)ABRecordCopyValue(record, kABPersonFirstNameProperty);
        NSString *lastName = (__bridge_transfer NSString*)ABRecordCopyValue(record, kABPersonLastNameProperty);
        NSString *first = firstName ?: @"";
        NSString *last = lastName ?: @"";
        NSString *name = [@[first, last] componentsJoinedByString:@" "];
        _name = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

        ABMultiValueRef emailValues = ABRecordCopyValue(record, kABPersonEmailProperty);
        _email = (__bridge_transfer NSString *)(ABMultiValueCopyValueAtIndex(emailValues, 0));
        if (emailValues != NULL) {
            CFRelease(emailValues);
        }
        
        ABMultiValueRef phoneValues = ABRecordCopyValue(record, kABPersonPhoneProperty);
        NSString *phone = (__bridge_transfer NSString *)(ABMultiValueCopyValueAtIndex(phoneValues, 0));
        if (phoneValues != NULL) {
            CFRelease(phoneValues);
        }
        phone = [STPCardValidator sanitizedNumericStringForString:phone];
        if ([phone length] > 0) {
            _phone = phone;
        }

        ABMultiValueRef addressValues = ABRecordCopyValue(record, kABPersonAddressProperty);
        if (addressValues != NULL) {
            if (ABMultiValueGetCount(addressValues) > 0) {
                CFDictionaryRef dict = ABMultiValueCopyValueAtIndex(addressValues, 0);
                NSString *street = CFDictionaryGetValue(dict, kABPersonAddressStreetKey);
                if (street.length > 0) {
                    _line1 = street;
                }
                NSString *city = CFDictionaryGetValue(dict, kABPersonAddressCityKey);
                if (city.length > 0) {
                    _city = city;
                }
                NSString *state = CFDictionaryGetValue(dict, kABPersonAddressStateKey);
                if (state.length > 0) {
                    _state = state;
                }
                NSString *zip = CFDictionaryGetValue(dict, kABPersonAddressZIPKey);
                if (zip.length > 0) {
                    _postalCode = zip;
                }
                NSString *country = CFDictionaryGetValue(dict, kABPersonAddressCountryCodeKey);
                if (country.length > 0) {
                    _country = [country uppercaseString];
                }
                if (dict != NULL) {
                    CFRelease(dict);
                }
            }
            CFRelease(addressValues);
        }
    }
    return self;
}

- (ABRecordRef)ABRecordValue {
    ABRecordRef record = ABPersonCreate();
    if ([self firstName] != nil) {
        CFStringRef firstNameRef = (__bridge CFStringRef)[self firstName];
        ABRecordSetValue(record, kABPersonFirstNameProperty, firstNameRef, nil);
    }
    if ([self lastName] != nil) {
        CFStringRef lastNameRef = (__bridge CFStringRef)[self lastName];
        ABRecordSetValue(record, kABPersonLastNameProperty, lastNameRef, nil);
    }
    if (self.phone != nil) {
        ABMutableMultiValueRef phonesRef = ABMultiValueCreateMutable(kABMultiStringPropertyType);
        ABMultiValueAddValueAndLabel(phonesRef, (__bridge CFStringRef)self.phone,
                                     kABPersonPhoneMainLabel, NULL);
        ABRecordSetValue(record, kABPersonPhoneProperty, phonesRef, nil);
        CFRelease(phonesRef);
    }
    if (self.email != nil) {
        ABMutableMultiValueRef emailsRef = ABMultiValueCreateMutable(kABMultiStringPropertyType);
        ABMultiValueAddValueAndLabel(emailsRef, (__bridge CFStringRef)self.email,
                                     kABHomeLabel, NULL);
        ABRecordSetValue(record, kABPersonEmailProperty, emailsRef, nil);
        CFRelease(emailsRef);
    }
    ABMutableMultiValueRef addressRef = ABMultiValueCreateMutable(kABMultiDictionaryPropertyType);
    NSMutableDictionary *addressDict = [NSMutableDictionary dictionary];
    addressDict[(NSString *)kABPersonAddressStreetKey] = [self street];
    addressDict[(NSString *)kABPersonAddressCityKey] = self.city;
    addressDict[(NSString *)kABPersonAddressStateKey] = self.state;
    addressDict[(NSString *)kABPersonAddressZIPKey] = self.postalCode;
    addressDict[(NSString *)kABPersonAddressCountryCodeKey] = self.country;
    ABMultiValueAddValueAndLabel(addressRef, (__bridge CFTypeRef)[addressDict copy], kABWorkLabel, NULL);
    ABRecordSetValue(record, kABPersonAddressProperty, addressRef, nil);
    CFRelease(addressRef);
    return CFAutorelease(record);
}

#pragma clang diagnostic pop

- (NSString *)sanitizedPhoneStringFromCNPhoneNumber:(CNPhoneNumber *)phoneNumber {
    NSString *phone = phoneNumber.stringValue;
    if (phone) {
        phone = [STPCardValidator sanitizedNumericStringForString:phone];
    }

    return stringIfHasContentsElseNil(phone);
}

- (instancetype)initWithCNContact:(CNContact *)contact {
    self = [super init];
    if (self) {

        _givenName = stringIfHasContentsElseNil(contact.givenName);
        _familyName = stringIfHasContentsElseNil(contact.familyName);
        _name = stringIfHasContentsElseNil([CNContactFormatter stringFromContact:contact
                                                                           style:CNContactFormatterStyleFullName]);
        _email = stringIfHasContentsElseNil([contact.emailAddresses firstObject].value);
        _phone = [self sanitizedPhoneStringFromCNPhoneNumber:contact.phoneNumbers.firstObject.value];


        [self setAddressFromCNPostalAddress:contact.postalAddresses.firstObject.value];
    }
    return self;
}

- (instancetype)initWithPKContact:(PKContact *)contact {
    self = [super init];
    if (self) {
        NSPersonNameComponents *nameComponents = contact.name;
        if (nameComponents) {
            _givenName = stringIfHasContentsElseNil(nameComponents.givenName);
            _familyName = stringIfHasContentsElseNil(nameComponents.familyName);
            _name = stringIfHasContentsElseNil([NSPersonNameComponentsFormatter localizedStringFromPersonNameComponents:nameComponents
                                                                                                                  style:NSPersonNameComponentsFormatterStyleDefault
                                                                                                                options:(NSPersonNameComponentsFormatterOptions)0]);
        }
        _email = stringIfHasContentsElseNil(contact.emailAddress);
        _phone = [self sanitizedPhoneStringFromCNPhoneNumber:contact.phoneNumber];
        [self setAddressFromCNPostalAddress:contact.postalAddress];

    }
    return self;
}

- (void)setAddressFromCNPostalAddress:(CNPostalAddress *)address {
    if (address) {
        _line1 = stringIfHasContentsElseNil(address.street);
        _city = stringIfHasContentsElseNil(address.city);
        _state = stringIfHasContentsElseNil(address.state);
        _postalCode = stringIfHasContentsElseNil(address.postalCode);
        _country = stringIfHasContentsElseNil(address.ISOCountryCode.uppercaseString);
    }
}

- (PKContact *)PKContactValue {
    PKContact *contact = [PKContact new];
    NSPersonNameComponents *name = [NSPersonNameComponents new];
    name.givenName = [self firstName];
    name.familyName = [self lastName];
    contact.name = name;
    contact.emailAddress = self.email;
    CNMutablePostalAddress *address = [CNMutablePostalAddress new];
    address.street = [self street];
    address.city = self.city;
    address.state = self.state;
    address.postalCode = self.postalCode;
    address.country = self.country;
    contact.postalAddress = address;
    contact.phoneNumber = [CNPhoneNumber phoneNumberWithStringValue:self.phone];
    return contact;
}

- (NSString *)firstName {
    if (self.givenName) {
        return self.givenName;
    }
    else {
        NSArray<NSString *>*components = [self.name componentsSeparatedByString:@" "];
        return [components firstObject];
    }
}

- (NSString *)lastName {
    if (self.familyName) {
        return self.familyName;
    }
    else {
        NSArray<NSString *>*components = [self.name componentsSeparatedByString:@" "];
        NSString *firstName = [components firstObject];
        NSString *lastName = [self.name stringByReplacingOccurrencesOfString:firstName withString:@""];
        lastName = [lastName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if ([lastName length] == 0) {
            lastName = nil;
        }
        return lastName;
    }
}

- (NSString *)street {
    NSString *street = nil;
    if (self.line1 != nil) {
        street = [@"" stringByAppendingString:self.line1];
    }
    if (self.line2 != nil) {
        street = [@[street ?: @"", self.line2] componentsJoinedByString:@" "];
    }
    return street;
}

- (BOOL)containsRequiredFields:(STPBillingAddressFields)requiredFields {
    BOOL containsFields = YES;
    switch (requiredFields) {
        case STPBillingAddressFieldsNone:
            return YES;
        case STPBillingAddressFieldsZip:
            return ([STPPostalCodeValidator validationStateForPostalCode:self.postalCode
                                                             countryCode:self.country] == STPCardValidationStateValid);
        case STPBillingAddressFieldsFull:
            return [self hasValidPostalAddress];
    }
    return containsFields;
}

- (BOOL)containsContentForBillingAddressFields:(STPBillingAddressFields)desiredFields {
    switch (desiredFields) {
        case STPBillingAddressFieldsNone:
            return NO;
        case STPBillingAddressFieldsZip:
            return self.postalCode.length > 0;
        case STPBillingAddressFieldsFull:
            return [self hasPartialPostalAddress];
    }

    return NO;
}

- (BOOL)containsRequiredShippingAddressFields:(PKAddressField)requiredFields {
    BOOL containsFields = YES;
    if (requiredFields & PKAddressFieldName) {
        containsFields = containsFields && [self.name length] > 0;
    }
    if (requiredFields & PKAddressFieldEmail) {
        containsFields = containsFields && [STPEmailAddressValidator stringIsValidEmailAddress:self.email];
    }
    if (requiredFields & PKAddressFieldPhone) {
        containsFields = containsFields && [STPPhoneNumberValidator stringIsValidPhoneNumber:self.phone forCountryCode:self.country];
    }
    if (requiredFields & PKAddressFieldPostalAddress) {
        containsFields = containsFields && [self hasValidPostalAddress];
    }
    return containsFields;
}

- (BOOL)containsContentForShippingAddressFields:(PKAddressField)desiredFields {
    return (((desiredFields & PKAddressFieldName) && self.name.length > 0)
            || ((desiredFields & PKAddressFieldEmail) && self.email.length > 0)
            || ((desiredFields & PKAddressFieldPhone) && self.phone.length > 0)
            || ((desiredFields & PKAddressFieldPostalAddress) && [self hasPartialPostalAddress]));
}

- (BOOL)hasValidPostalAddress {
    return (self.line1.length > 0 
            && self.city.length > 0 
            && self.country.length > 0 
            && (self.state.length > 0 || ![self.country isEqualToString:@"US"])  
            && ([STPPostalCodeValidator validationStateForPostalCode:self.postalCode
                                                         countryCode:self.country] == STPCardValidationStateValid));
}

/**
 Does this STPAddress contain any data in the postal address fields?

 If they are all empty or nil, returns NO. Even a single character in a
 single field will return YES.
 */
- (BOOL)hasPartialPostalAddress {
    return (self.line1.length > 0
            || self.line2.length > 0
            || self.city.length > 0
            || self.country.length > 0
            || self.state.length > 0
            || self.postalCode.length > 0);
}

+ (PKAddressField)applePayAddressFieldsFromBillingAddressFields:(STPBillingAddressFields)billingAddressFields {
    FAUXPAS_IGNORED_IN_METHOD(APIAvailability);
    switch (billingAddressFields) {
        case STPBillingAddressFieldsNone:
            return PKAddressFieldNone;
        case STPBillingAddressFieldsZip:
        case STPBillingAddressFieldsFull:
            return PKAddressFieldPostalAddress;
    }
}

#pragma mark STPAPIResponseDecodable

+ (NSArray *)requiredFields {
    return @[];
}

+ (instancetype)decodedObjectFromAPIResponse:(NSDictionary *)response {
    NSDictionary *dict = [response stp_dictionaryByRemovingNullsValidatingRequiredFields:[self requiredFields]];
    if (!dict) {
        return nil;
    }

    STPAddress *address = [self new];
    address.allResponseFields = dict;
    address.city = dict[@"city"];
    address.country = dict[@"country"];
    address.line1 = dict[@"line1"];
    address.line2 = dict[@"line2"];
    address.postalCode = dict[@"postal_code"];
    address.state = dict[@"state"];
    return address;
}

- (NSDictionary*)dictionaryOutput {
    return @{
             @"shipping[name]":_name,
             @"shipping[phone]":(_phone) ? _phone : @"",
             @"shipping[address][line1]":_line1,
             @"shipping[address][line2]":(_line2) ? _line2 : @"",
             @"shipping[address][city]":(_city) ? _city : @"",
             @"shipping[address][country]":(_country) ? _country : @"",
             @"shipping[address][postal_code]":(_postalCode) ? _postalCode : @"",
             @"shipping[address][state]":(_state) ? _state : @"",
             };
}

- (BOOL)isEqualToAddress:(STPAddress*)address
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

- (STPAddressValidationErrors)validationErrorCode
{
    BOOL isValid = [self isValid];
    if (isValid)
        _firstValidationErrorCode = STPAddressValidationErrorNoError;
    
    return _firstValidationErrorCode;
}

- (BOOL)isValid
{
    BOOL isValid =  [self validateName:self.name] && [self validatePhone:self.phone] && [self validateStreet:self.line1 line2:self.line2] && [self validateCity:self.city] && [self validateState:self.state] && [self validatePostalCode:self.postalCode] && [self validateCountry:self.country];
    
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
    NSMutableCharacterSet *characterSet = [NSMutableCharacterSet letterCharacterSet];
    [characterSet formUnionWithCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@" .-"]];
    
    BOOL condition1 = [name stringByTrimmingCharactersInSet:characterSet].length == 0;
    BOOL condition2 = name.length >= 2 && name.length <= 150;
    
    if (!condition1)
        _firstValidationErrorCode = STPAddressValidationErrorFullNameInvalidCharacters;
    
    if (!condition2)
        _firstValidationErrorCode = STPAddressValidationErrorFullNameLength;
    
    return condition1 && condition2;
}

- (BOOL)validatePhone:(NSString *)phone
{
    if (phone == nil) {
        _firstValidationErrorCode = STPAddressValidationErrorPhoneLength;
        return NO;
    }
    NSMutableCharacterSet *characterSet = [NSMutableCharacterSet decimalDigitCharacterSet];
    [characterSet formUnionWithCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@"+"]];
    
    BOOL condition1 = [phone stringByTrimmingCharactersInSet:characterSet].length == 0;
    BOOL condition2 = phone.length >= 6 && phone.length <= 35;
    BOOL condition3 = phone.length > 0 && [phone characterAtIndex:0] == '+';
    
    if (!condition1)
        _firstValidationErrorCode = STPAddressValidationErrorPhoneInvalidCharacters;
    
    if (!condition2)
        _firstValidationErrorCode = STPAddressValidationErrorPhoneLength;
    
    if (!condition3)
        _firstValidationErrorCode = STPAddressValidationErrorPhonePlusCharacter;
    
    return condition1 && condition2 && condition3;
}

- (BOOL)validateStreet:(NSString *)line1 line2:(NSString *)line2
{
    if (line1 == nil) {
        _firstValidationErrorCode = STPAddressValidationErrorAddressLength;
        return NO;
    }
    NSString *fullAddress = [line1 stringByAppendingString:line2];
    NSMutableCharacterSet *characterSet = [NSMutableCharacterSet decimalDigitCharacterSet];
    [characterSet formUnionWithCharacterSet:[NSCharacterSet letterCharacterSet]];
    [characterSet formUnionWithCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@"-/\\&_()'\"* .,:;?!#"]];
    
    BOOL condition1 = [fullAddress stringByTrimmingCharactersInSet:characterSet].length == 0;
    BOOL condition2 = fullAddress.length >= 4 && fullAddress.length <= 200;
    
    if (!condition1)
        _firstValidationErrorCode = STPAddressValidationErrorAddressInvalidCharacters;
    
    if (!condition2)
        _firstValidationErrorCode = STPAddressValidationErrorAddressLength;
    
    return condition1 && condition2;
}

- (BOOL)validatePostalCode:(NSString *)postalCode
{
    if (postalCode == nil) {
        _firstValidationErrorCode = STPAddressValidationErrorPostalCodeLength;
        return NO;
    }
    NSMutableCharacterSet *characterSet = [NSMutableCharacterSet decimalDigitCharacterSet];
    [characterSet formUnionWithCharacterSet:[NSCharacterSet letterCharacterSet]];
    [characterSet formUnionWithCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@"- "]];
    
    BOOL condition1 = [postalCode stringByTrimmingCharactersInSet:characterSet].length == 0;
    BOOL condition2 = postalCode.length >= 4 && postalCode.length <= 32;
    
    if (!condition1)
        _firstValidationErrorCode = STPAddressValidationErrorPostalCodeInvalidCharacters;
    
    if (!condition2)
        _firstValidationErrorCode = STPAddressValidationErrorPostalCodeLength;
    
    return condition1 && condition2;
}

- (BOOL)validateCity:(NSString *)city
{
    if (city == nil) {
        _firstValidationErrorCode = STPAddressValidationErrorCityLength;
        return NO;
    }
    NSMutableCharacterSet *characterSet = [NSMutableCharacterSet letterCharacterSet];
    [characterSet addCharactersInString:@" -'"];
    
    BOOL condition1 = [city stringByTrimmingCharactersInSet:characterSet].length == 0;
    BOOL condition2 = city.length >= 1 && city.length <= 100;
    
    if (!condition1)
        _firstValidationErrorCode = STPAddressValidationErrorCityInvalidCharacters;
    
    if (!condition2)
        _firstValidationErrorCode = STPAddressValidationErrorCityLength;
    
    return condition1 && condition2;
}

- (BOOL)validateState:(NSString *)state
{
    if (state == nil) {
        _firstValidationErrorCode = STPAddressValidationErrorStateLength;
        return NO;
    }
    NSMutableCharacterSet *characterSet = [NSMutableCharacterSet letterCharacterSet];
    
    BOOL condition1 = [state stringByTrimmingCharactersInSet:characterSet].length == 0;
    BOOL condition2 = state.length <= 100;
    
    if (!condition1)
        _firstValidationErrorCode = STPAddressValidationErrorStateInvalidCharacters;
    
    if (!condition2)
        _firstValidationErrorCode = STPAddressValidationErrorStateLength;
    
    return condition1 && condition2;
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

NSString *stringIfHasContentsElseNil(NSString *string) {
    if (string.length > 0) {
        return string;
    }
    else {
        return nil;
    }
}


//
//  STPAddress+Vero.h
//  Vero Labs, Inc.
//
//  Created by Antoine Lavail on 1/09/19.
//  Copyright © 2019 Vero Labs, Inc. All rights reserved.
//

#import "STPAddress.h"

@interface STPAddress (Vero)

typedef NS_ENUM(NSInteger, STPAddressValidationErrors) {
    STPAddressValidationErrorFullNameLength = 0,
    STPAddressValidationErrorFullNameInvalidCharacters = 1,
    STPAddressValidationErrorPhoneLength = 2,
    STPAddressValidationErrorPhoneInvalidCharacters = 3,
    STPAddressValidationErrorPhonePlusCharacter = 4,
    STPAddressValidationErrorAddressLength = 5,
    STPAddressValidationErrorAddressInvalidCharacters = 6,
    STPAddressValidationErrorPostalCodeLength = 7,
    STPAddressValidationErrorPostalCodeInvalidCharacters = 8,
    STPAddressValidationErrorCityLength = 9,
    STPAddressValidationErrorCityInvalidCharacters = 10,
    STPAddressValidationErrorStateLength = 11,
    STPAddressValidationErrorStateInvalidCharacters = 12,
    STPAddressValidationErrorCountryLength = 13,
    STPAddressValidationErrorCountryInvalidCharacters = 14,
    STPAddressValidationErrorNoError = 15
};

- (nullable NSDictionary*)dictionaryOutput;
- (BOOL)isEqualToShippingAddress:(nonnull STPAddress*)address;
- (BOOL)isEqualToBillingAddress:(nonnull STPAddress*)address;
- (BOOL)isValidShipping;
- (BOOL)isValidBilling;
- (STPAddressValidationErrors)shippingValidationErrorCode;
- (STPAddressValidationErrors)billingValidationErrorCode;

@end

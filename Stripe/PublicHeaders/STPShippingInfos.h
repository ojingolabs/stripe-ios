//
// Created by Antoine Lavail on 05/10/15.
// Copyright (c) 2015 Stripe, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, STPShippingInfoValidationErrors) {
    STPShippingInfoValidationErrorFullNameLength = 0,
    STPShippingInfoValidationErrorFullNameInvalidCharacters = 1,
    STPShippingInfoValidationErrorPhoneLength = 2,
    STPShippingInfoValidationErrorPhoneInvalidCharacters = 3,
    STPShippingInfoValidationErrorPhonePlusCharacter = 4,
    STPShippingInfoValidationErrorAddressLength = 5,
    STPShippingInfoValidationErrorAddressInvalidCharacters = 6,
    STPShippingInfoValidationErrorPostalCodeLength = 7,
    STPShippingInfoValidationErrorPostalCodeInvalidCharacters = 8,
    STPShippingInfoValidationErrorCityLength = 9,
    STPShippingInfoValidationErrorCityInvalidCharacters = 10,
    STPShippingInfoValidationErrorStateLength = 11,
    STPShippingInfoValidationErrorStateInvalidCharacters = 12,
    STPShippingInfoValidationErrorCountryLength = 13,
    STPShippingInfoValidationErrorCountryInvalidCharacters = 14,
    STPShippingInfoValidationErrorNoError = 15
};

@interface STPShippingInfos : NSObject

- (nonnull instancetype)initWithAttributeDictionary:(nonnull NSDictionary *)attributeDictionary;

/**
 *  Shipping info's name. Required
 */
@property (nonatomic, copy, nonnull) NSString *infosName;

/**
 *  Shipping info's phone
 */
@property (nonatomic, copy, nullable) NSString *phone;

/**
 *  Shipping info's line1. Required
 */
@property (nonatomic, copy, nonnull) NSString *line1;

/**
 *  Shipping info's line2
 */
@property (nonatomic, copy, nullable) NSString *line2;

/**
 *  Shipping info's city
 */
@property (nonatomic, copy, nullable) NSString *city;

/**
 *  Shipping info's country
 */
@property (nonatomic, copy, nullable) NSString *country;

/**
 *  Shipping info's postalCode
 */
@property (nonatomic, copy, nullable) NSString *postalCode;

/**
 *  Shipping info's state
 */
@property (nonatomic, copy, nullable) NSString *state;

/**
 *  The delivery service that shipped a physical product, such as Fedex, UPS, USPS, etc.
 */
@property (nonatomic, copy, nullable) NSString *carrier;

/**
 *  The tracking number for a physical product, obtained from the delivery service. If multiple tracking numbers were generated for this purchase, please separate them with commas.
 */
@property (nonatomic, copy, nullable) NSString *trackingNumber;

- (nullable NSDictionary*)dictionaryOutput;
- (BOOL)isEqualToShippingInfos:(nonnull STPShippingInfos*)shippingInfos;

- (BOOL)isValid;
- (STPShippingInfoValidationErrors)validationErrorCode;

@end

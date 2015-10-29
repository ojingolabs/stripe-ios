//
//  STPCardTest.m
//  Stripe
//
//  Created by Saikat Chakrabarti on 11/5/12.
//
//

@import XCTest;

#import "STPFormEncoder.h"
#import "STPCard.h"
#import "StripeError.h"

@interface STPCardTest : XCTestCase
@property (nonatomic) STPCardParams *card;
@end

@implementation STPCardTest

- (void)setUp {
    _card = [[STPCardParams alloc] init];
}

#pragma mark Helpers
- (NSDateComponents *)currentDateComponents {
    // FIXME This is a copy of the code that already exists in a private method in STPCard
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    return [gregorian components:NSCalendarUnitYear fromDate:[NSDate date]];
}

- (NSInteger)currentYear {
    return [[self currentDateComponents] year];
}

- (NSDictionary *)completeAttributeDictionary {
    return @{
        @"id": @"1",
        @"exp_month": @"12",
        @"exp_year": @"2013",
        @"name": @"Smerlock Smolmes",
        @"address_line1": @"221A Baker Street",
        @"address_city": @"New York",
        @"address_state": @"NY",
        @"address_zip": @"12345",
        @"address_country": @"USA",
        @"last4": @"1234",
        @"dynamic_last4": @"5678",
        @"brand": @"MasterCard",
        @"country": @"Japan",
        @"currency": @"usd",
    };
}

- (void)testInitializingCardWithAttributeDictionary {
    STPCard *cardWithAttributes = [STPCard decodedObjectFromAPIResponse:[self completeAttributeDictionary]];

    XCTAssertTrue([cardWithAttributes expMonth] == 12, @"expMonth is set correctly");
    XCTAssertTrue([cardWithAttributes expYear] == 2013, @"expYear is set correctly");
    XCTAssertEqualObjects([cardWithAttributes name], @"Smerlock Smolmes", @"name is set correctly");
    XCTAssertEqualObjects([cardWithAttributes addressLine1], @"221A Baker Street", @"addressLine1 is set correctly");
    XCTAssertEqualObjects([cardWithAttributes addressCity], @"New York", @"addressCity is set correctly");
    XCTAssertEqualObjects([cardWithAttributes addressState], @"NY", @"addressState is set correctly");
    XCTAssertEqualObjects([cardWithAttributes addressZip], @"12345", @"addressZip is set correctly");
    XCTAssertEqualObjects([cardWithAttributes addressCountry], @"USA", @"addressCountry is set correctly");
    XCTAssertEqualObjects([cardWithAttributes last4], @"1234", @"last4 is set correctly");
    XCTAssertEqualObjects([cardWithAttributes dynamicLast4], @"5678", @"last4 is set correctly");
    XCTAssertEqual([cardWithAttributes brand], STPCardBrandMasterCard, @"type is set correctly");
    XCTAssertEqualObjects([cardWithAttributes country], @"Japan", @"country is set correctly");
    XCTAssertEqualObjects([cardWithAttributes currency], @"usd", @"currency is set correctly");
}

- (void)testFormEncode {
    NSDictionary *attributes = [self completeAttributeDictionary];
    STPCard *cardWithAttributes = [STPCard decodedObjectFromAPIResponse:attributes];

    NSData *encoded = [STPFormEncoder formEncodedDataForObject:cardWithAttributes];
    NSString *formData = [[NSString alloc] initWithData:encoded encoding:NSUTF8StringEncoding];

    NSArray *parts = [formData componentsSeparatedByString:@"&"];

    NSSet *expectedKeys = [NSSet setWithObjects:@"card[number]",
                                                @"card[exp_month]",
                                                @"card[exp_year]",
                                                @"card[cvc]",
                                                @"card[name]",
                                                @"card[address_line1]",
                                                @"card[address_line2]",
                                                @"card[address_city]",
                                                @"card[address_state]",
                                                @"card[address_zip]",
                                                @"card[address_country]",
                                                @"card[currency]",
                                                nil];

    NSArray *values = [attributes allValues];
    NSMutableArray *encodedValues = [NSMutableArray array];
    for (NSString *value in values) {
        [encodedValues addObject:[STPFormEncoder stringByURLEncoding:value]];
    }

    NSSet *expectedValues = [NSSet setWithArray:encodedValues];
    for (NSString *part in parts) {
        NSArray *subparts = [part componentsSeparatedByString:@"="];
        NSString *key = subparts[0];
        NSString *value = subparts[1];

        XCTAssertTrue([expectedKeys containsObject:key], @"unexpected key %@", key);
        XCTAssertTrue([expectedValues containsObject:value], @"unexpected value %@", value);
    }
}

#pragma mark -last4 tests
- (void)testLast4ReturnsCardNumberLast4WhenNotSet {
    self.card.number = @"4242424242424242";
    XCTAssertEqualObjects(self.card.last4, @"4242", @"last4 correctly returns the last 4 digits of the card number");
}

- (void)testLast4ReturnsNullWhenNoCardNumberSet {
    XCTAssertEqualObjects(nil, self.card.last4, @"last4 returns nil when nothing is set");
}

- (void)testLast4ReturnsNullWhenCardNumberIsLessThanLength4 {
    self.card.number = @"123";
    XCTAssertEqualObjects(nil, self.card.last4, @"last4 returns nil when number length is < 3");
}

- (void)testCardEquals {
    STPCard *card1 = [STPCard decodedObjectFromAPIResponse:[self completeAttributeDictionary]];
    STPCard *card2 = [STPCard decodedObjectFromAPIResponse:[self completeAttributeDictionary]];

    XCTAssertEqualObjects(card1, card1, @"card should equal itself");
    XCTAssertEqualObjects(card1, card2, @"cards with equal data should be equal");
}

@end

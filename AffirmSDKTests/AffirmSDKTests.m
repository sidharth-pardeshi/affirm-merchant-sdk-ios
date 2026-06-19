//
//  AffirmSDKTests.m
//  AffirmSDKTests
//
//  Created by Victor Zhu on 2019/3/4.
//  Copyright © 2019 Affirm, Inc. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "../AffirmSDK/AffirmConfiguration.h"
#import "../AffirmSDK/AffirmUtils.h"
#import "../AffirmSDK/AffirmRequest.h"
#import "../AffirmSDK/AffirmItem.h"
#import "../AffirmSDK/AffirmCardValidator.h"

@interface AffirmSDKTests : XCTestCase

@end

@implementation AffirmSDKTests

- (void)setUp
{
    [[AffirmConfiguration sharedInstance] configureWithPublicKey:@"PKNCHBIVYOT8JSOZ" environment:AffirmEnvironmentSandbox];
}

- (void)testTracker
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"track test"];
    AffirmLogRequest *request = [[AffirmLogRequest alloc] initWithEventName:@"Test" eventParameters:@{} logCount:0];
    [AffirmTrackerClient send:request handler:^(AffirmResponse * _Nullable response, NSError * _Nullable error) {
        XCTAssertNil(error);
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:10 handler:nil];
}

- (void)testUtil
{
    XCTAssertNotNil([NSBundle sdkBundle]);
    XCTAssertNotNil([NSBundle resourceBundle]);
    XCTAssertEqualObjects([[NSDecimalNumber decimalNumberWithString:@"500"] toIntegerCents], @(50000));
    
    NSString *jsonString = @"{\"number\":\"40012959709\",\"callback_id\":\"4DACF-ASBJ-WEAS-GBNZ\",\"date\":\"2018-09-12\"}";
    XCTAssertEqualObjects([jsonString convertToDictionary][@"number"], @"40012959709");
    XCTAssertEqualObjects([jsonString convertToDictionary][@"callback_id"], @"4DACF-ASBJ-WEAS-GBNZ");
    XCTAssertEqualObjects([jsonString convertToDictionary][@"date"], @"2018-09-12");
    
    NSString *jsonStringError = @"{\"number\":\"40012959709,\"callback_id\":\"4DACF-ASBJ-WEAS-GBNZ\",\"date\":\"2018-09-12\"}";
    XCTAssertNil([jsonStringError convertToDictionary]);
}

- (void)testPromoRequestPathAndParameters
{
    [[AffirmConfiguration sharedInstance] configureWithPublicKey:@"PKNCHBIVYOT8JSOZ"
                                                     environment:AffirmEnvironmentSandbox
                                                          locale:@"en_US"
                                                     countryCode:@"USA"
                                                        currency:@"USD"
                                                    merchantName:@"Affirm Test"];
    NSDecimalNumber *amount = [NSDecimalNumber decimalNumberWithString:@"1234.56"];
    AffirmItem *item = [AffirmItem itemWithName:@"Affirm Test Item"
                                            SKU:@"test_item"
                                      unitPrice:amount
                                       quantity:1
                                            URL:[NSURL URLWithString:@"https://sandbox.affirm.com/item"]];
    AffirmPromoRequest *request = [[AffirmPromoRequest alloc] initWithPublicKey:@"PKNCHBIVYOT8JSOZ"
                                                                        promoId:@"promo_123"
                                                                         amount:amount
                                                                        showCTA:YES
                                                                       pageType:@"product"
                                                                       logoType:@"logo"
                                                                      logoColor:@"blue"
                                                                          items:@[item]];
    NSDictionary *parameters = request.parameters;

    XCTAssertEqualObjects(request.path, @"/api/promos/v2/PKNCHBIVYOT8JSOZ");
    XCTAssertEqual(request.method, AffirmHTTPMethodGET);
    XCTAssertEqualObjects(parameters[@"is_sdk"], @"true");
    XCTAssertEqualObjects(parameters[@"field"], @"ala");
    XCTAssertEqualObjects(parameters[@"show_cta"], @"true");
    XCTAssertEqualObjects(parameters[@"amount"], [amount toIntegerCents]);
    XCTAssertEqualObjects(parameters[@"promo_external_id"], @"promo_123");
    XCTAssertEqualObjects(parameters[@"page_type"], @"product");
    XCTAssertEqualObjects(parameters[@"logo_type"], @"logo");
    XCTAssertEqualObjects(parameters[@"logo_color"], @"blue");
    XCTAssertEqualObjects(parameters[@"locale"], @"en_US");
    NSArray *items = parameters[@"items"];
    NSDictionary *requestItem = items.firstObject;
    XCTAssertEqual(items.count, 1);
    XCTAssertEqualObjects(requestItem[@"display_name"], @"Affirm Test Item");
    XCTAssertEqualObjects(requestItem[@"sku"], @"test_item");
    XCTAssertEqualObjects(requestItem[@"unit_price"], [amount toIntegerCents]);
    XCTAssertEqualObjects(requestItem[@"item_url"], @"https://sandbox.affirm.com/item");
}

- (void)testVisaCard
{
    AffirmBrand *brand = [[AffirmCardValidator sharedCardValidator] brandForCardNumber:@"4242 4242 4242 4242"];
    XCTAssertEqual(brand.type, AffirmBrandTypeVisa);
}

- (void)testMasterCard
{
    AffirmBrand *brand = [[AffirmCardValidator sharedCardValidator] brandForCardNumber:@"5555555555554444"];
    XCTAssertEqual(brand.type, AffirmBrandTypeMastercard);
}

- (void)testAmericanExpress
{
    AffirmBrand *brand = [[AffirmCardValidator sharedCardValidator] brandForCardNumber:@"378282246310005"];
    XCTAssertEqual(brand.type, AffirmBrandTypeAmex);
}

- (void)testDiscover
{
    AffirmBrand *brand = [[AffirmCardValidator sharedCardValidator] brandForCardNumber:@"6011111111111117"];
    XCTAssertEqual(brand.type, AffirmBrandTypeDiscover);
}

- (void)testDinersClub
{
    AffirmBrand *brand = [[AffirmCardValidator sharedCardValidator] brandForCardNumber:@"3056930009020004"];
    XCTAssertEqual(brand.type, AffirmBrandTypeDinersClub);
}

- (void)testJCB
{
    AffirmBrand *brand = [[AffirmCardValidator sharedCardValidator] brandForCardNumber:@"3566002020360505"];
    XCTAssertEqual(brand.type, AffirmBrandTypeJCB);
}

@end

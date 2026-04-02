//
//  AffirmConfigurationTests.m
//  AffirmSDKTests
//
//  Created by yijie on 2019/3/20.
//  Copyright © 2019 Affirm, Inc. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "../AffirmSDK/AffirmConfiguration.h"
#import "../AffirmSDK/AffirmUtils.h"
#import "../AffirmSDK/AffirmRequest.h"

@interface AffirmConfigurationTests : XCTestCase

@end

@implementation AffirmConfigurationTests

- (void)setUp
{
    [[AffirmConfiguration sharedInstance] configureWithPublicKey:@"PKNCHBIVYOT8JSOZ" environment:AffirmEnvironmentSandbox];
}

- (void)testExamples
{
    XCTAssertEqualObjects([[AffirmConfiguration sharedInstance] environmentDescription], @"sandbox");
    XCTAssertFalse([AffirmConfiguration sharedInstance].isProductionEnvironment);
    XCTAssertEqualObjects([AffirmConfiguration sharedInstance].publicKey, @"PKNCHBIVYOT8JSOZ");
    [[AffirmConfiguration sharedInstance] configureWithPublicKey:@"OKSJJASBDJBAJBC" environment:AffirmEnvironmentProduction];
    XCTAssertEqualObjects([[AffirmConfiguration sharedInstance] environmentDescription], @"production");
    XCTAssertTrue([AffirmConfiguration sharedInstance].isProductionEnvironment);
    XCTAssertEqualObjects([AffirmConfiguration sharedInstance].publicKey, @"OKSJJASBDJBAJBC");
}

- (void)testSimpleConfigureResetsLocaleCountryCodeCurrency
{
    // First configure with CA settings
    [[AffirmConfiguration sharedInstance] configureWithPublicKey:@"CA_KEY"
                                                    environment:AffirmEnvironmentSandbox
                                                         locale:@"en_CA"
                                                    countryCode:@"CAN"
                                                       currency:@"CAD"
                                                   merchantName:nil];
    XCTAssertEqualObjects([AffirmConfiguration sharedInstance].locale, @"en_CA");
    XCTAssertEqualObjects([AffirmConfiguration sharedInstance].countryCode, @"CAN");
    XCTAssertEqualObjects([AffirmConfiguration sharedInstance].currency, @"CAD");

    // Now re-configure with simple method (simulating region switch with new public key)
    [[AffirmConfiguration sharedInstance] configureWithPublicKey:@"UK_KEY"
                                                    environment:AffirmEnvironmentSandbox];

    // locale, countryCode, currency should be reset to defaults
    XCTAssertEqualObjects([AffirmConfiguration sharedInstance].locale, @"en_US");
    XCTAssertEqualObjects([AffirmConfiguration sharedInstance].countryCode, @"USA");
    XCTAssertEqualObjects([AffirmConfiguration sharedInstance].currency, @"USD");
}

- (void)testFullConfigureUpdatesLocaleCountryCodeCurrency
{
    [[AffirmConfiguration sharedInstance] configureWithPublicKey:@"UK_KEY"
                                                    environment:AffirmEnvironmentSandbox
                                                         locale:@"en_GB"
                                                    countryCode:@"GBR"
                                                       currency:@"GBP"
                                                   merchantName:nil];
    XCTAssertEqualObjects([AffirmConfiguration sharedInstance].locale, @"en_GB");
    XCTAssertEqualObjects([AffirmConfiguration sharedInstance].countryCode, @"GBR");
    XCTAssertEqualObjects([AffirmConfiguration sharedInstance].currency, @"GBP");
}

- (void)testSetLocale
{
    [[AffirmConfiguration sharedInstance] setLocale:@"en_GB"];
    XCTAssertEqualObjects([AffirmConfiguration sharedInstance].locale, @"en_GB");
}

- (void)testSetCountryCode
{
    [[AffirmConfiguration sharedInstance] setCountryCode:@"GBR"];
    XCTAssertEqualObjects([AffirmConfiguration sharedInstance].countryCode, @"GBR");
}

- (void)testSetCurrency
{
    [[AffirmConfiguration sharedInstance] setCurrency:@"GBP"];
    XCTAssertEqualObjects([AffirmConfiguration sharedInstance].currency, @"GBP");
}

- (void)testRegionSwitchCAtoUK
{
    // Start with CA config
    [[AffirmConfiguration sharedInstance] configureWithPublicKey:@"CA_KEY"
                                                    environment:AffirmEnvironmentSandbox
                                                         locale:@"en_CA"
                                                    countryCode:@"CAN"
                                                       currency:@"CAD"
                                                   merchantName:nil];

    // Switch to UK using full configure (like Android re-initialization)
    [[AffirmConfiguration sharedInstance] configureWithPublicKey:@"UK_KEY"
                                                    environment:AffirmEnvironmentSandbox
                                                         locale:@"en_GB"
                                                    countryCode:@"GBR"
                                                       currency:@"GBP"
                                                   merchantName:nil];

    XCTAssertEqualObjects([AffirmConfiguration sharedInstance].locale, @"en_GB");
    XCTAssertEqualObjects([AffirmConfiguration sharedInstance].countryCode, @"GBR");
    XCTAssertEqualObjects([AffirmConfiguration sharedInstance].currency, @"GBP");
}

- (void)testRegionSwitchCAtoUKUsingSetters
{
    // Start with CA config
    [[AffirmConfiguration sharedInstance] configureWithPublicKey:@"CA_KEY"
                                                    environment:AffirmEnvironmentSandbox
                                                         locale:@"en_CA"
                                                    countryCode:@"CAN"
                                                       currency:@"CAD"
                                                   merchantName:nil];

    // Switch to UK using individual setters
    [[AffirmConfiguration sharedInstance] setLocale:@"en_GB"];
    [[AffirmConfiguration sharedInstance] setCountryCode:@"GBR"];
    [[AffirmConfiguration sharedInstance] setCurrency:@"GBP"];

    XCTAssertEqualObjects([AffirmConfiguration sharedInstance].locale, @"en_GB");
    XCTAssertEqualObjects([AffirmConfiguration sharedInstance].countryCode, @"GBR");
    XCTAssertEqualObjects([AffirmConfiguration sharedInstance].currency, @"GBP");
}

@end

//
//  ExamplesUITests.m
//  ExamplesUITests
//
//  Created by Victor Zhu on 2019/3/5.
//  Copyright © 2019 Affirm, Inc. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "XCTestCase+Utils.h"
#import "XCUIElementQuery+Utils.h"

@interface ExamplesUITests : XCTestCase

@property (nonatomic, strong) XCUIApplication *app;

@end

@implementation ExamplesUITests

static NSString *const AffirmExpectedPromoMessage = @"As low as $60/month at 0% APR. Learn more";

- (void)setUp
{
    self.continueAfterFailure = NO;
    self.app = [[XCUIApplication alloc] init];
}

- (void)launchWithPromoFixture:(NSString *)fixture
{
    self.app.launchArguments = @[@"-AffirmPromoMockMode", @"enabled"];
    self.app.launchEnvironment = @{@"AFFIRM_PROMO_FIXTURE": fixture};
    [self.app launch];
}

- (XCUIElement *)elementWithIdentifier:(NSString *)identifier
{
    return [[self.app descendantsMatchingType:XCUIElementTypeAny] objectForKeyedSubscript:identifier];
}

- (void)waitForElementToBeUnavailable:(XCUIElement *)element duration:(NSTimeInterval)duration
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"exists == NO OR hittable == NO"];
    [self expectationForPredicate:predicate evaluatedWithObject:element handler:nil];
    [self waitForExpectationsWithTimeout:duration handler:nil];
}

- (void)clearCookies
{
    [self.app.buttons[@"Clear Cookies"] tap];
    XCUIElement *okButton = [self.app.buttons objectForKeyedSubscript:@"OK"];
    [self waitForElement:okButton duration:5];
    [okButton tap];
}

- (void)testAla
{
    [self launchWithPromoFixture:@"adaptive"];

    XCUIElement *alaElement = [self.app.buttons objectForKeyedSubscript:@"affirm_promo_native_button"];
    [self waitForElement:alaElement duration:10];
    XCTAssertTrue(alaElement.exists);
    XCTAssertEqualObjects(alaElement.label, AffirmExpectedPromoMessage);
}

- (void)testPromoButtonRendersAdaptiveAla
{
    [self launchWithPromoFixture:@"adaptive"];
    
    XCUIElement *alaElement = [self.app.buttons objectForKeyedSubscript:@"affirm_promo_native_button"];
    [self waitForElement:alaElement duration:10];
    XCTAssertTrue(alaElement.exists);
    XCTAssertEqualObjects(alaElement.label, AffirmExpectedPromoMessage);
}

- (void)testHtmlPromoMessageRendersAdaptiveAla
{
    [self launchWithPromoFixture:@"adaptive"];

    XCUIElement *alaElement = [self elementWithIdentifier:@"affirm_promo_html_button"];
    [self waitForElement:alaElement duration:10];
    XCTAssertTrue(alaElement.exists);
    XCTAssertTrue([alaElement.label containsString:@"$60/month"]);
    XCTAssertTrue([alaElement.label containsString:@"Learn more"]);
}

- (void)testEmptyPromoDoesNotShowButton
{
    [self launchWithPromoFixture:@"empty"];

    XCUIElement *alaElement = [self.app.buttons objectForKeyedSubscript:@"affirm_promo_native_button"];
    [self waitForElementToBeUnavailable:alaElement duration:10];
    XCTAssertFalse(alaElement.exists && alaElement.hittable);
}

- (void)testErrorPromoDoesNotShowButton
{
    [self launchWithPromoFixture:@"error"];

    XCUIElement *alaElement = [self.app.buttons objectForKeyedSubscript:@"affirm_promo_native_button"];
    [self waitForElementToBeUnavailable:alaElement duration:10];
    XCTAssertFalse(alaElement.exists && alaElement.hittable);
}

- (void)testAdaptivePromoTapPresentsPrequal
{
    [self launchWithPromoFixture:@"adaptive"];

    XCUIElement *alaElement = [self.app.buttons objectForKeyedSubscript:@"affirm_promo_native_button"];
    [self waitForElement:alaElement duration:10];
    [alaElement tap];

    XCUIElement *closeButton = [self.app.buttons objectForKeyedSubscript:@"Close"];
    [self waitForElement:closeButton duration:10];
    XCTAssertTrue(closeButton.exists);
}

- (void)testBuyWithAffirm
{
    XCTSkip(@"Sandbox-dependent checkout smoke test; deterministic promo messaging coverage is tested separately.");
    [self launchWithPromoFixture:@"adaptive"];
    [self clearCookies];
    
    [self.app.buttons[@"Buy with Affirm"] tap];
}

- (void)testVCNCheckout
{
    XCTSkip(@"Sandbox-dependent checkout smoke test; deterministic promo messaging coverage is tested separately.");
    [self launchWithPromoFixture:@"adaptive"];
    [self clearCookies];
    
    [self.app.buttons[@"VCN Checkout"] tap];
    
    XCUIElement *errorElement = self.app.staticTexts[@"Error"];
    [self waitForElement:errorElement duration:15];
    XCTAssertTrue(errorElement.exists);
    
    [self.app.buttons[@"OK"] tap];
}

@end

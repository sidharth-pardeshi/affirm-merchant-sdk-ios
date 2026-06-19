//
//  UpfunnelPromoMessagingUITests.m
//  ExamplesUITests
//

#import <XCTest/XCTest.h>
#import "../XCTestCase+Utils.h"

@interface UpfunnelPromoMessagingUITests : XCTestCase

@property (nonatomic, strong) XCUIApplication *app;

@end

@implementation UpfunnelPromoMessagingUITests

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

- (void)attachScreenshotWithName:(NSString *)name
{
    XCTAttachment *attachment = [XCTAttachment attachmentWithScreenshot:[self.app screenshot]];
    attachment.name = name;
    attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:attachment];
}

- (void)testPromoButtonRendersAdaptiveAla
{
    [self launchWithPromoFixture:@"adaptive"];

    XCUIElement *alaElement = [self.app.buttons objectForKeyedSubscript:@"affirm_promo_native_button"];
    [self waitForElement:alaElement duration:10];
    XCTAssertTrue(alaElement.exists);
    XCTAssertEqualObjects(alaElement.label, AffirmExpectedPromoMessage);
    [self attachScreenshotWithName:@"native-ala-rendered"];
}

- (void)testHtmlPromoMessageRendersAdaptiveAla
{
    [self launchWithPromoFixture:@"adaptive"];

    XCUIElement *alaElement = [self elementWithIdentifier:@"affirm_promo_html_button"];
    [self waitForElement:alaElement duration:10];
    XCTAssertTrue(alaElement.exists);
    XCTAssertTrue([alaElement.label containsString:@"$60/month"]);
    XCTAssertTrue([alaElement.label containsString:@"Learn more"]);
    [self attachScreenshotWithName:@"html-ala-rendered"];
}

- (void)testEmptyPromoDoesNotShowButton
{
    [self launchWithPromoFixture:@"empty"];

    XCUIElement *alaElement = [self.app.buttons objectForKeyedSubscript:@"affirm_promo_native_button"];
    [self waitForElementToBeUnavailable:alaElement duration:10];
    XCTAssertFalse(alaElement.exists && alaElement.hittable);
    [self attachScreenshotWithName:@"empty-promo-hidden"];
}

- (void)testErrorPromoDoesNotShowButton
{
    [self launchWithPromoFixture:@"error"];

    XCUIElement *alaElement = [self.app.buttons objectForKeyedSubscript:@"affirm_promo_native_button"];
    [self waitForElementToBeUnavailable:alaElement duration:10];
    XCTAssertFalse(alaElement.exists && alaElement.hittable);
    [self attachScreenshotWithName:@"error-promo-hidden"];
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
    [self attachScreenshotWithName:@"adaptive-promo-prequal-presented"];
}

@end

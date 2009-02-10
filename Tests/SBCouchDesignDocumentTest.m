#import <SenTestingKit/SenTestingKit.h>
#import "SBCouchView.h"
#import "CouchObjC.h"
#import "SBCouchDesignDocument.h"


static NSString *MAP_FUNCTION     = @"function(doc) { if(doc.name == 'Frank'){ emit('Number of Franks', 1);}}";
static NSString *REDUCE_FUNCTION  = @"function(k, v, rereduce) { return sum(v);}";

static NSString *DESIGN_DOC_NAME  = @"datacenter";
static NSString *VIEW_1           = @"hardware";
static NSString *VIEW_2           = @"software";
static NSString *VIEW_3           = @"wonderousThings";

@interface SBCouchDesignDocumentTest : SenTestCase {
    SBCouchDesignDocument *designDocument;
}
@property (retain) SBCouchDesignDocument *designDocument;
@end

@implementation SBCouchDesignDocumentTest
@synthesize designDocument;

#pragma mark -

/*
 {"_id":"_design/datacenter",
 "_rev":"1508484904",
 "language":"javascript",
 "views":{"hardware":{"map":"function(doc) {\n  emit(\"datacenter\", doc);\n  // More changes\n}"},
 "software":{"map":"function(doc) {\n  emit(\"software\", doc);\n  // More changes\n}"}}
 }
 */
-(void)testViewRetrieval{
    
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    [dict setObject:@"_design/datacenter" forKey:@"_id"];
    [dict setObject:@"1508484904" forKey:@"_rev"];
    [dict setObject:@"javascript" forKey:@"language"];    
    
    NSMutableDictionary *view1Dict = [[NSMutableDictionary alloc] init];
    [view1Dict setObject:MAP_FUNCTION forKey:@"map"];    
    [view1Dict setObject:REDUCE_FUNCTION forKey:@"reduce"];    

            
    NSMutableDictionary *views = [[NSMutableDictionary alloc] init];
    [views setObject:view1Dict forKey:VIEW_1];
    [views setObject:view1Dict forKey:VIEW_2];
    
    [dict setObject:views forKey:@"views"];
    
    SBCouchDesignDocument *designDoc = [[SBCouchDesignDocument alloc] initWithDictionary:dict];
    
    NSDictionary *returnedViews = [designDoc views];
    STAssertNotNil(returnedViews, @"Views were not returned");
    SBDebug(@"--> %@", [designDoc JSONRepresentation]);
    SBDebug(@"--> %i", [[returnedViews allKeys] count]);

    STAssertTrue([[returnedViews allKeys] count] == 2, @"Missing views [%i]", [[returnedViews allKeys] count]);
    
    [dict release];
    [designDoc release];
}

-(void)estRetrievingViewsMapsAndWhatNot{
    SBCouchView *view = [self.designDocument view:VIEW_1];   
    STAssertNotNil(view,@"Did not recieve view. [%@]", view);
}

-(void)estSimplestThingThatWillWork{
    STAssertTrue([designDocument.language isEqualToString:COUCH_KEY_LANGUAGE_DEFAULT], nil);
    
    SBDebug(@"identity %@", designDocument.identity);
    
    id views = [designDocument views];
    STAssertNotNil(views, nil);
    
    NSString *v = [designDocument JSONRepresentation];
    NSDictionary *dict = [v JSONValue];
    STAssertNotNil(dict, nil);
    SBCouchDesignDocument *newDesignDoc = [[SBCouchDesignDocument alloc] initWithDictionary:dict];
    STAssertNotNil(newDesignDoc, nil);
    NSDictionary *newViews = [newDesignDoc views];
    STAssertNotNil(newViews, nil);
    
    NSArray *keys = [newViews allKeys];
    STAssertTrue([keys count] == 3, @"Missing views %i", [newViews allKeys]);
    
}

#pragma mark - 
-(void)setUp{
    SBCouchView *view = [[[SBCouchView alloc] initWithName:@"totals" andMap:MAP_FUNCTION andReduce:REDUCE_FUNCTION] autorelease];
    
    designDocument = [[SBCouchDesignDocument alloc] initWithDesignDomain:DESIGN_DOC_NAME];
    [designDocument addView:view withName:VIEW_1];
    [designDocument addView:view withName:VIEW_2];
    [designDocument addView:view withName:VIEW_3];
}
-(void)tearDown{
    [designDocument release];  
}

@end

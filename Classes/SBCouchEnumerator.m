//
//  SBCouchEnumerator.m
//  CouchObjC
//
//  Created by Robert Evans on 1/10/09.
//  Copyright 2009 South And Valley. All rights reserved.
//

#import "SBCouchEnumerator.h"
#import "SBCouchDatabase.h"
#import "CouchObjC.h"

@implementation SBCouchEnumerator

@synthesize couchView;
@synthesize totalRows;
@synthesize offset;
@synthesize rows;
@synthesize currentIndex;
@synthesize queryOptions;
@synthesize sizeOfLastFetch;


-(id)initWithView:(SBCouchView*)aCouchView{
    
    self = [super init];
    if(self != nil){
        // Setting the currentIndex to -1 is used to indicate that we don't have an index yet. 
        self.currentIndex = -1;
        self.couchView    = aCouchView;
        // take a copy of the queryOptions for purposes of pagination. 
        self.queryOptions = aCouchView.queryOptions;
        self.rows = [NSMutableArray arrayWithCapacity:10];
    }
    return self;  
}

-(void) dealloc{
    [self.rows release];
    [super dealloc];

}
-(id)itemAtIndex:(NSInteger)idx{
    // trying to access something outside our range of options. 
    if(idx > totalRows)
        return nil;

    // trying to access something that has not yet been fetched
    if(idx >= [rows count]){  
        [self fetchNextPage];
        if( [self itemAtIndex:idx]){
            // TODO might want to autorelase this
            SBCouchDocument *doc = [[SBCouchDocument alloc] initWithNSDictionary:[rows objectAtIndex:idx] couchDatabase:self.couchView.couchDatabase];
            return doc;
        }else{
            return nil;
        }
    }
    // TODO Might want to autorelease this. 
    SBCouchDocument *doc = [[SBCouchDocument alloc] initWithNSDictionary:[rows objectAtIndex:idx] couchDatabase:self.couchView.couchDatabase];
    return doc;
}

-(BOOL)shouldFetchNextBatch{
    if(self.currentIndex == -1)
        return YES;
    
    // if the index is >= to the number of rows we can fetch more, 
    // but if the size of the last fetch was larger than the batch size (i.e limit)
    //
    // The default for limit is zero and sizeOfLastFetch is set to -1 when 
    if(currentIndex >= [rows count] && self.sizeOfLastFetch >= self.queryOptions.limit)
        return YES;
    
    return NO;
}
- (id)nextObject{
    // At some point lastObjectsID will 
    if([self shouldFetchNextBatch]){
        //[self setStartKey:[[rows lastObject] objectForKey:@"id"]];
        NSString *lastObjectsID = [[self.rows lastObject] objectForKey:@"id"];
        // The first time through, we won't have any rows
        if(lastObjectsID)
            self.queryOptions.startkey = lastObjectsID;
        
        [self fetchNextPage];
    }
    
    // If the call to fetchNextPage did not expand the number of rows to a number 
    // greater than currentIndex
    if(currentIndex >= [rows count]){
        //[rows release], rows = nil;
        return nil;
    }
        
    id object = [rows objectAtIndex:currentIndex];
    [self setCurrentIndex:[self currentIndex] +1 ];
    // TODO might want to autorelease this. 
    SBCouchDocument *doc = [[SBCouchDocument alloc] initWithNSDictionary:object couchDatabase:self.couchView.couchDatabase];
    // XXX Is this a proper identity? 
    doc.identity = [doc objectForKey:@"id"];
    return doc;
} 
- (NSArray *)allObjects{
    return nil;
}

-(void)fetchNextPage{   
    // contruct a new URL using our own copy of the query options
    NSString *contructedUrl = [NSString stringWithFormat:@"%@?%@", self.couchView.name, [self.queryOptions queryString]];
    //NSString *viewUrl = [self.couchView urlString];   
    NSDictionary *etf = [self.couchView.couchDatabase get:contructedUrl];

    // If this is our first attempt at a fetch, we need to initialize the currentIndex
    if(self.currentIndex == -1 ){
        self.totalRows    = [[etf objectForKey:@"total_rows"] integerValue]; 
        self.offset       = [[etf objectForKey:@"offset"] integerValue];
        self.currentIndex = 0;
        // Since this is not our first fetch, set the skip value to 1 
        // XXX This should be moved someplace where its only ever called 
        //     once. No need to set this on every fetch. 
        self.queryOptions.skip=1;
    }

    NSArray *newRows = [etf objectForKey:@"rows"];
    [rows addObjectsFromArray:newRows];
    if([newRows count] <= 0){
        self.sizeOfLastFetch = -1;
    }else{
        self.sizeOfLastFetch = [newRows count];
    }
}

@end

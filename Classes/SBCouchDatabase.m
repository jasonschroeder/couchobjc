/*
Copyright (c) 2008, Stig Brautaset. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

  * Redistributions of source code must retain the above copyright notice,
    this list of conditions and the following disclaimer.

  * Redistributions in binary form must reproduce the above copyright notice,
    this list of conditions and the following disclaimer in the documentation
    and/or other materials provided with the distribution.

  * Neither the name of the author nor the names of its contributors may be
    used to endorse or promote products derived from this software without
    specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import "SBCouchServer.h"
#import "SBCouchDatabase.h"
#import "SBCouchResponse.h"
#import "NSDictionary+CouchObjC.h"
#import "SBCouchDocument.h"

#import <JSON/JSON.h>
#import "CouchObjC.h"

@interface SBCouchDatabase (Private)
   -(NSString*)contructURL:(NSString*)withRevisionCount:(BOOL)withCount andInfo:(BOOL)andInfo revision:(NSString*)revisionOrNil;
@end 

@implementation SBCouchDatabase

@synthesize name;

- (id)initWithServer:(SBCouchServer*)s name:(NSString*)n
{
    if (self = [super init]) {
        server = [s retain];
        name = [n copy];
    }
    return self;
}

- (void)dealloc
{
    [server release];
    [name release];
    [super dealloc];
}

/**
 You can use this to query database information by simply passing an empty string. You can also
 get documents, by passing the document names (ids).
 
 @code
 // retrieve a document
 NSDictionary *doc = [db get:@"document_name"];
 
 // get a list of all documents
 NSDictionary *list = [db get:@"_all_docs"];
 @endcode
 */
 - (NSDictionary*)get:(NSString*)args
{
    NSString *urlString = [NSString stringWithFormat:@"http://%@:%u/%@/%@", server.host, server.port, self.name, args];
    STIGDebug(@"Document URL  %@", urlString);
    NSURL *url = [NSURL URLWithString:urlString];   
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    
    NSError *error;
    NSHTTPURLResponse *response;
    NSData *data = [NSURLConnection sendSynchronousRequest:request
                                         returningResponse:&response
                                                     error:&error];
    
    if (200 == [response statusCode]) {
        NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return [json JSONValue];
    }
    
    return nil;    
}




-(NSString*)constructURL:(NSString*)docId withRevisionCount:(BOOL)withCount andInfo:(BOOL)andInfo revision:(NSString*)revisionOrNil {
    NSString *docWithRevArgument;
    if(andInfo)
    {
        docWithRevArgument = [NSString stringWithFormat:@"%@?revs=true&revs_info=true", docId];
    } else{
        docWithRevArgument = [NSString stringWithFormat:@"%@", docId];
    }
    
    if(revisionOrNil != nil){
        docWithRevArgument = [NSString stringWithFormat:@"%@&rev=%@",docWithRevArgument,revisionOrNil];
    }
    return docWithRevArgument;
}

- (SBCouchDesignDocument*)getDesignDocument:(NSString*)docId{
    return [self getDesignDocument:docId withRevisionCount:NO andInfo:NO revision:nil];
}

- (SBCouchDesignDocument*)getDesignDocument:(NSString*)docId withRevisionCount:(BOOL)withCount andInfo:(BOOL)andInfo revision:(NSString*)revisionOrNil{
    NSString *docWithRevArgument = [self constructURL:docId withRevisionCount:withCount andInfo:andInfo revision:revisionOrNil];
        
    NSMutableDictionary *mutable = [NSMutableDictionary dictionaryWithDictionary:[self get:docWithRevArgument]];  
    assert(mutable);
    SBCouchDesignDocument *couchDocument = [[[SBCouchDesignDocument  alloc] initWithNSDictionary:mutable] autorelease];
    
    [couchDocument setServerName:[server serverURLAsString]];
    [couchDocument setDatabaseName:[self name]];
    return couchDocument;
}

/**
 ?revs=true but might want to use revs_info=true and peek into the 
 status field to figure out what to do. 
 */
- (SBCouchDocument*)getDocument:(NSString*)docId withRevisionCount:(BOOL)withCount andInfo:(BOOL)andInfo revision:(NSString*)revisionOrNil
{

    NSString *docWithRevArgument = [self constructURL:docId withRevisionCount:withCount andInfo:andInfo revision:revisionOrNil];
    
    STIGDebug(@"Document URL  %@", docWithRevArgument);
    
    NSMutableDictionary *mutable = [NSMutableDictionary dictionaryWithDictionary:[self get:docWithRevArgument]];
    
    SBCouchDocument *couchDocument = [[[SBCouchDocument alloc] initWithNSDictionary:mutable] autorelease];
    
    [couchDocument setServerName:[server serverURLAsString]];
    [couchDocument setDatabaseName:[self name]];
    return couchDocument;
}

- (SBCouchResponse*)createDocument:(SBCouchDesignDocument*)doc{
    return [self putDocument:doc named:doc.identity];
}

/**
 Use this method to create documents when you don't care what their names (ids) will be.
 */
- (SBCouchResponse*)postDocument:(NSDictionary*)doc
{
    NSData *body = [[doc JSONRepresentation] dataUsingEncoding:NSUTF8StringEncoding];
    NSString *urlString = [NSString stringWithFormat:@"http://%@:%u/%@/", server.host, server.port, self.name];
    NSURL *url = [NSURL URLWithString:urlString];    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];    
    [request setHTTPBody:body];
    [request setHTTPMethod:@"POST"];
    
    NSError *error;
    NSHTTPURLResponse *response;
    NSData *data = [NSURLConnection sendSynchronousRequest:request
                                         returningResponse:&response
                                                     error:&error];
    
    if (201 == [response statusCode]) {
        NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return [[SBCouchResponse alloc] initWithDictionary:[json JSONValue]];
    }
    
    return nil;    
}

/**
 Use this method to create documents with a particular name, or updating documents.
 */
- (SBCouchResponse*)putDocument:(NSDictionary*)doc named:(NSString*)x
{
    NSData *body = [[doc JSONRepresentation] dataUsingEncoding:NSUTF8StringEncoding];
    NSString *urlString = [NSString stringWithFormat:@"http://%@:%u/%@/%@", server.host, server.port, self.name, x];
    NSURL *url = [NSURL URLWithString:urlString];    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];    
    [request setHTTPBody:body];
    [request setHTTPMethod:@"PUT"];
    
    NSError *error;
    NSHTTPURLResponse *response;
    NSData *data = [NSURLConnection sendSynchronousRequest:request
                                         returningResponse:&response
                                                     error:&error];
    
    if (201 == [response statusCode]) {
        NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return [[SBCouchResponse alloc] initWithDictionary:[json JSONValue]];
    }
    
    return nil;    
}

- (SBCouchResponse*)putDocument:(SBCouchDocument*)couchDocument
{
    NSData *body = [[couchDocument JSONRepresentation] dataUsingEncoding:NSUTF8StringEncoding];
    NSString *urlString = [NSString stringWithFormat:@"http://%@:%u/%@/%@", server.host, server.port, self.name, [couchDocument objectForKey:@"_id"]];
    NSURL *url = [NSURL URLWithString:urlString];    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];    
    [request setHTTPBody:body];
    [request setHTTPMethod:@"PUT"];
    
    NSError *error;
    NSHTTPURLResponse *response;
    NSData *data = [NSURLConnection sendSynchronousRequest:request
                                         returningResponse:&response
                                                     error:&error];
    
    if (201 == [response statusCode]) {
        NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return [[SBCouchResponse alloc] initWithDictionary:[json JSONValue]];
    }
    
    return nil;    
    
}



/**
 This method extracts the name and revision from the document and attempts to delete that.
 */
- (SBCouchResponse*)deleteDocument:(NSDictionary*)doc
{
    NSString *urlString = [NSString stringWithFormat:@"http://%@:%u/%@/%@?rev=%@", server.host, server.port, self.name, doc.name, doc.rev];
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];    
    [request setHTTPMethod:@"DELETE"];
    
    NSError *error;
    NSHTTPURLResponse *response;
    NSData *data = [NSURLConnection sendSynchronousRequest:request
                                         returningResponse:&response
                                                     error:&error];
    // 412 == conflict
    // 200 == OK
    NSLog(@"response code from the delete %i", [response statusCode]);
    if (200 == [response statusCode]) {
        NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return [[SBCouchResponse alloc] initWithDictionary:[json JSONValue]];
    }
    
    return nil;
}

-(NSEnumerator*) view:(NSString*)viewName{
    return [[[SBCouchEnumerator alloc] init] autorelease];
}

-(NSEnumerator*)allDocsInBatchesOf:(NSInteger)count{
    SBCouchEnumerator *enumerator = [[[SBCouchEnumerator alloc] initWithBatchesOf:count 
                                                                        database:self
                                                                            view:@"_all_docs"] autorelease];
    return (NSEnumerator*)enumerator;
}
-(NSEnumerator*) allDocs{
    NSDictionary *list = [self get:@"_all_docs"];
    
    return [[list objectForKey:@"rows"] objectEnumerator];
    //return [[[STIGCouchViewEnumerator alloc] init] autorelease];
}

- (NSEnumerator*)getDesignDocuments{
    NSString *url = @"_all_docs?group=true&startkey=%22_design%22&endkey=%22_design0%22";
    //NSDictionary *list =  [self get:url];
    //return [[list objectForKey:@"rows"] objectEnumerator];
    
    
    SBCouchEnumerator *enumerator = [[[SBCouchEnumerator alloc] initWithBatchesOf:-1 
                                                                        database:self
                                                                            view:url] autorelease];
    return (NSEnumerator*)enumerator;
}


@end

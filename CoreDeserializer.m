//
//  CoreDeserializer.m
//  Core Resource
//
//  Created by Mike Laurence on 3/11/10.
//  Copyright 2010 Mike Laurence.
//

#import "CoreDeserializer.h"
#import "CoreResult.h"
#import "NSObject+Core.h"
#import "Artist.h"

@implementation CoreDeserializer

static NSArray* allowedFormats;

@synthesize source, sourceString, resourceClass, format, coreManager;
@synthesize target, action;

- (id) initWithSource:(id)sourceObj andResourceClass:(Class)clazz {
    if (self = [super init]) {
        self.source = sourceObj;
        self.resourceClass = clazz;
    }
    return self;
}


- (void) main {
    // Use format to change deserialization class and convert serialized string into resources
    Class newClass = [resourceClass performSelector:@selector(deserializerClassForFormat:) withObject:[self format]];
    if (newClass != nil) {
        // Change runtime class (in order to capture correct resourcesFromString method)
        self->isa = newClass;
        
        // Get Core Manager from resource class if it hasn't been defined yet
        if (coreManager == nil)
            coreManager = [resourceClass performSelector:@selector(coreManager)];

        // Create "scratchpad" object context; we will merge this context into the main context once deserialization is complete
        managedObjectContext = [coreManager newContext];
        [[NSNotificationCenter defaultCenter] addObserver:self 
            selector:@selector(contextDidSave:) 
            name:NSManagedObjectContextDidSaveNotification 
            object:managedObjectContext];

        resources = [[self resourcesFromString:[self sourceString]] retain];

        // Attempt to save object context; if there's an error, it will be placed in the CoreResult (which is sent to the target)
        [managedObjectContext save:&error];
            
        // Remove context save observer
        [[NSNotificationCenter defaultCenter] removeObserver:self 
            name:NSManagedObjectContextDidSaveNotification object:managedObjectContext];
    }
    else {
        error = [[[NSError alloc] initWithDomain:$S(@"Couldn't deserialize with format '%@'", format) code:0 userInfo:nil] retain];
        [self performSelectorOnMainThread:@selector(notify) withObject:nil waitUntilDone:NO];
        
        // Log error if level is high enough
        if (coreManager.logLevel > 3)
            NSLog(@"CoreDeserializer error: %@", [error description]);
    }
}


/**
    When the context saves, send a message to our Core Manager to merge in the updated data
*/
- (void) contextDidSave:(NSNotification*)notification {
    NSLog(@"contextDidSave");
    [coreManager performSelectorOnMainThread:@selector(mergeContext:) 
        withObject:notification 
        waitUntilDone:NO];
        
    [self performSelectorOnMainThread:@selector(notify) withObject:nil waitUntilDone:NO];
}

- (void) notify {
    // Perform action on target if possible
    if (target && action && [target respondsToSelector:action]) {
        CoreResult *result = error == nil ?
            [[CoreResult alloc] initWithSource:source andResources:resources] :
            [[CoreResult alloc] initWithError:error];
        [result faultResourcesWithContext:[resourceClass performSelector:@selector(managedObjectContext)]];
            
        NSLog(@"Deserialized into CoreResult with source %@, resource count %i", source, [resources count]);
                          
        // Perform on main thread, since UI updates are very likely in delegate calls
        [target performSelector:action withObject:result];
        [result release];
    }
}


#pragma mark -
#pragma mark Source

/**
    Retrieves serialized string from source (since source could be a request, string, etc.)
*/
- (NSString*) sourceString {
    NSString* rawSourceString = [source isKindOfClass:[NSString class]] ? source : [source get:@selector(responseString)];
    sourceString = [[rawSourceString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] retain];
    return sourceString;
}


#pragma mark -
#pragma mark Format determination

- (NSString*) format {
    if (format != nil)
        return format;

    if (allowedFormats == nil)
        allowedFormats = [$A(@"json", @"xml") retain];
    
    // Attempt to determine format using response content type
    if (format == nil)
        format = [self formatFromHeader:@"Content-Type" inDictionary:@selector(responseHeaders)];
        
    // Attempt to determine format using request accept header
    if (format == nil)
        format = [self formatFromHeader:@"Accept" inDictionary:@selector(requestHeaders)];
        
    // Attempt to determine format using URL extension
    if (format == nil) {
        NSURL *url = [source get:@selector(url)];
        if (url != nil)
            format = [self allowedFormatsFromString:[url relativePath]];
    }
    
    // Attempt to determine format by looking at first content character
    if (format == nil) {
        NSString* firstContentChar = [[self sourceString] substringToIndex:1];
        if ([firstContentChar isEqualToString:@"<"])
            return @"xml";
        if ([firstContentChar isEqualToString:@"{"] || [firstContentChar isEqualToString:@"["])
            return @"json";
    }
    
    return [format retain];
}

- (NSString*) formatFromHeader:(NSString*)header inDictionary:(SEL)dictionarySelector {
    NSDictionary *headers = [source get:dictionarySelector];
    if (headers != nil) {
        NSString *headerValue = [headers objectForKey:header];
        if (headerValue != nil)
            return [self allowedFormatsFromString:headerValue];
    }
    return nil;
}

- (NSString*) allowedFormatsFromString:(NSString*)string {
    for (NSString* allowedFormat in allowedFormats) {
        if ([string rangeOfString:allowedFormat options:NSCaseInsensitiveSearch].location != NSNotFound)
            return allowedFormat;
    }
    return nil;
}


#pragma mark -
#pragma mark Deserialization

- (id) resourcesFromString:(NSString*)string { return nil; }

- (NSArray*) resourcesFromCollection:(id)collection {
    return [resourceClass performSelector:@selector(create:withOptions:)
        withObject:collection withObject:$D(managedObjectContext, @"context", $B(NO), @"timestamp")];
}


#pragma mark -
#pragma mark Lifecycle end

- (void) dealloc {
    [sourceString release];
    [source release];
    [format release];
    [coreManager release];
    [managedObjectContext release];
    [error release];
    [resources release];
    [target release];
    [super dealloc];
}

@end



#pragma mark -
#pragma mark Format deserializers


@implementation CoreJSONDeserializer

- (id) resourcesFromString:(NSString*)string {

    // Deserialize JSON
    SBJsonParser *jsonParser = [SBJsonParser new];
    id jsonData = [jsonParser objectWithString:string];
    if (jsonData == nil) { // Record error and return if JSON parsing failed
        error = [[[NSError alloc] initWithDomain:$S(@"JSON parsing failed: %@", [jsonParser errorTrace]) code:0 userInfo:nil] retain];
        return nil;
    }
    
    return [self resourcesFromJSONData:jsonData];
}

- (id) resourcesFromJSONData:(id)jsonData {
    // Convert raw JSON to resource data parsable by CoreResource create/update methods
    id resourceCollection = [self resourceCollectionFromJSONData:jsonData];
    
    // Create/update resources
    return [self resourcesFromCollection:resourceCollection];
}        

- (id) resourceCollectionFromJSONData:(id)jsonData {

    return jsonData;

    // COLLAPSE JSON

    /*

    // Turn collection into array if not already one
    NSArray* jsonArray = [jsonData isKindOfClass:[NSDictionary class]] ? jsonData : $A(jsonData);

    if (jsonArray != nil) {
        NSMutableArray *jsonResources = [NSMutableArray arrayWithCapacity:[jsonArray count]]; // Container for deserialized resources
        if (coreManager.logLevel > 1)
            NSLog(@"Deserializing %@ %@", [NSNumber numberWithInt:[jsonArray count]], [resourceClass performSelector:@selector(remoteCollectionName)]);

        // Iterate through JSON elements and attempt to create/update resources for each
        for (id jsonElement in jsonArray) {
            id properties = [resourceClass performSelector:@selector(resourcePropertiesFromJSONElement:withParent:)
                    withObject:jsonElement withObject:nil];
            id resource = [resourceClass performSelector:@selector(createOrUpdateWithDictionary:andOptions:)
                withObject:properties withObject:$D(managedObjectContext, @"context")];
            if (resource != nil)
                [jsonResources addObject:resource];
        }
        return jsonResources;
    }
    
    return nil;
    */
}

@end


#ifdef DDXMLDocument

@implementation CoreXMLDeserializer

- (NSArray*) resourcesFromString:(NSString*)string {

    // Deserialize XML
    DDXMLDocument *doc = [[DDXMLDocument alloc] initWithXMLString:string options:0 error:&error];
    
    return nil;
}

@end

#endif


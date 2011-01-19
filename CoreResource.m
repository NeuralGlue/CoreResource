//
//  CoreResource.m
//  CoreResource
//
//  Created by Mike Laurence on 12/24/09.
//  Copyright Mike Laurence 2010. All rights reserved.
//

#import "CoreResource.h"
#import "CoreUtils.h"
#import "CoreRequest.h"
#import "CoreResult.h"
#import "CoreDeserializer.h"
#import "JSON.h"
#import "NSString+InflectionSupport.h"
#import "NSSet+Core.h"

@implementation CoreResource

@synthesize remoteDidFinishSelector, remoteDidFailSelector;
#pragma mark -
#pragma mark Configuration

-(id)initWithEntity:(NSEntityDescription *)entity insertIntoManagedObjectContext:(NSManagedObjectContext *)context {
	if ((self = [super initWithEntity:entity insertIntoManagedObjectContext:context])){
		self.remoteDidFailSelector = @selector(remoteDidFail:);
		self.remoteDidFinishSelector = @selector(remoteDidFinish:);
	}
	return self;
}

+ (CoreManager*) coreManager {
    return [CoreManager sharedCoreManager];
}

+ (BOOL) useBundleRequests {
    return [[self coreManager] useBundleRequests];
}

+ (NSString*) remoteSiteURL {
    return [[self coreManager] remoteSiteURL];
}

+ (NSString*) remoteCollectionName {
    return [[[NSStringFromClass(self) deCamelizeWith:@"_"] substringFromIndex:1] stringByAppendingString:@"s"];
}

+ (NSString*) remoteURLForCollectionAction:(Action)action {
    return [NSString stringWithFormat:@"%@/%@", [self remoteSiteURL], [self remoteCollectionName]];
}

//TODO: depreciate this. Doesn't make sense to be using an ivar for a static method.
+ (NSString*) remoteURLForResource:(id)resourceId action:(Action)action {
    return [NSString stringWithFormat:@"%@/%@/%@", [[self class] remoteSiteURL], [[self class] remoteCollectionName], resourceId]; 
}

- (NSString*) remoteURLForAction:(Action)action {
	NSString *suffix = @"";
	if (action != Create) {
		suffix = [NSString stringWithFormat:@"/%d", [self localId]];
	}
	return [NSString stringWithFormat:@"%@/%@%@", [[self class] remoteSiteURL], [[self class] remoteCollectionName],suffix];
    //return [[self class] remoteURLForResource:[self localId] action:action];
}

+ (NSString*) bundlePathForCollectionAction:(Action)action {
    return [NSString stringWithFormat:@"%@", [self remoteCollectionName]];
}

+ (NSString*) bundlePathForResource:(id)resourceId action:(Action)action {
    return [NSString stringWithFormat:@"%@.%@", [[self class] remoteCollectionName], resourceId];
}

- (NSString*) bundlePathForAction:(Action)action {
    return [[self class] bundlePathForResource:[self localId] action:action];
}

+ (void) configureRequest:(CoreRequest*)request forAction:(NSString*)action {}

-(NSString *)HTTPMethodForAction:(Action)action {
	NSString *headString = nil;
	switch (action) {
		case Create:
			headString = @"POST";
			break;
		case Read:
			headString = @"GET";
			break;
		case Update:
			headString = @"PUT";
			break;
		case Destroy:
			headString = @"DELETE";
			break;
		default:
			headString = @"GET" ;// default to immutable request
			break;
	}
	return headString;
}

#pragma mark -
#pragma mark Serialization
+(BOOL)usesRootNode {
	return YES;
}
+ (NSString *) rootNodeName{
	
	return [[self entityName] lowercaseString];
}
+ (NSString*) localNameForRemoteField:(NSString*)name {
    return name;
}

+ (NSString*) remoteNameForLocalField:(NSString*)name {
    return name;
}

+ (NSString*) localIdField {
    return @"resourceId";
}

- (id) localId {
    return [self performSelector:NSSelectorFromString([[self class] localIdField])];
}

+ (NSString*) remoteIdField {
    return @"id";
}

+ (NSString*) createdAtField {
    return @"createdAt";
}

+ (NSString*) updatedAtField {
    return @"updatedAt";
}

+ (NSDateFormatter*) dateParser {
    return [[self coreManager] defaultDateParser];
}

+ (NSDateFormatter*) dateParserForField:(NSString*)field {
    return [self dateParser];
}

+ (Class) deserializerClassForFormat:(NSString*)format {
    return NSClassFromString($S(@"Core%@Deserializer", [format uppercaseString]));
}

/**
 Retrieves the actual data collection from the initial deserialized collection.
 This should be used, for example. if your response has its data objects nested, e.g.:
 
 { results: [{ name: 'Mike' }, { name: 'Mork' }] }
 
 It could also just be used to fine-tune the deserialized data before it's converted to model objects.
 
 Defaults to just returning the initial collection, which would work if you have no nested-ness, e.g.:
 
 [{ name: 'Mike' }, { name: 'Mork' }]
 */
+ (NSArray*) dataCollectionFromDeserializedCollection:(id)deserializedCollection {
    return deserializedCollection;
}

+ (id) resourceElementFromJSONCollection:(id)collection withParent:(id)parent {
    return collection;
}


- (NSString*) toJson {
    return [self toJson:nil];
}

- (NSString*) toJson:(id)options {
    NSMutableDictionary* mOptions = options != nil ? [[options mutableCopy]autorelease] : [NSMutableDictionary dictionary];
    [mOptions setObject:$B(YES) forKey:@"$serializeDates"];
    return [[self properties:mOptions] JSONRepresentation];
}

- (NSMutableDictionary*) properties {
    return [self properties:nil withoutObjects:nil];
}

- (NSMutableDictionary*) properties:(NSDictionary*)options {
    return [self properties:options withoutObjects:nil];
}

- (NSMutableDictionary*) properties:(NSDictionary*)options withoutObjects:(NSMutableArray*)withouts {
    NSArray* only = [options objectForKey:@"$only"];
    NSArray* except = [options objectForKey:@"$except"];
    BOOL serializeDates = [[options objectForKey:@"$serializeDates"] boolValue];
	BOOL includeObjectId = YES; //[[options objectForKey:@"includeObjectId"] boolValue];
	
    if (withouts == nil)
        withouts = [NSMutableArray array];
    [withouts addObject:self];
    
    NSMutableDictionary* dict = [NSMutableDictionary dictionary];
    
    // If indent option is set, "indent" this object's nesting within a named dictionary
    /*
	 if ([options objectForKey:$indent]) {
	 NSMutableDictionary* indentDict = [NSMutableDictionary dictionary];
	 [dict setObject:indentDict forKey:key];
	 dict = indentDict;
	 }
	 */
    
    for (NSPropertyDescription* prop in [[[self class] entityDescription] properties]) {
        NSString* key = prop.name;
        if ((only == nil || [only containsObject:key]) && (except == nil || ![except containsObject:key])) {
            id value = [self valueForKey:key];
            if (value == nil)
                value = [NSNull null];
			
            // For attributes, simply set the value
            if ([prop isKindOfClass:[NSAttributeDescription class]]) {
                // Serialize dates if serializeDates is set
                if ([value isKindOfClass:[NSDate class]] && serializeDates)
                    value = [[[self class] dateParserForField:key] stringFromDate:value];
				
                [dict setObject:value forKey:key];
            }
			
            // For relationships, recursively branch off properties:ignoringObjects call
            else {
                NSRelationshipDescription* rel = (NSRelationshipDescription*)prop;
                if ([rel isToMany]) {
                    NSSet* relResources = value;
                    NSMutableArray* relArray = [NSMutableArray arrayWithCapacity:[relResources count]];
                    for (CoreResource* resource in relResources) {
                        // Only add objects which are not part of the withouts array
                        // (most importantly, ignore objects that have been previously added)
                        if (![withouts containsObject:resource])
                            [relArray addObject:[resource properties:options withoutObjects:withouts]];
                    }
                    [dict setObject:relArray forKey:key];
                }
                else {
                    if (![withouts containsObject:value])
                        [dict setObject:value forKey:key];
                }
            }
        }
    }
	//Do we need the local objectID?
	if (includeObjectId) {
		NSManagedObjectID *objectId = [self objectID];
		if ([objectId isTemporaryID]) {
			NSError *error= nil;
			if (![[self managedObjectContext] obtainPermanentIDsForObjects:[NSArray arrayWithObject:self] error:&error]){
				ALog(@"A temporary Id is being serialized for posting due to error: %@", [error localizedDescription]);
				//TODO: figure some way of building an objectId or halting the process.
			}
			objectId = [self objectID]; // try again to get a permenant Id.
		}
			
		NSString *objectIdString = [[objectId URIRepresentation] absoluteString];
		[dict setValue:objectIdString forKey:@"objectId"];
	}
    return dict;
}




#pragma mark -
#pragma mark Core Data

+ (NSManagedObjectContext*) managedObjectContext {
    return [[self coreManager] managedObjectContext];
}

+ (NSManagedObjectModel*) managedObjectModel {
    return [[self coreManager] managedObjectModel];
}

+ (NSString*) entityName {
    return [NSString stringWithFormat:@"%@", self];
}

+ (NSEntityDescription*) entityDescription {
    NSEntityDescription* entity = [[[self coreManager] entityDescriptions] objectForKey:self];
    if (entity == nil) {
        entity = [NSEntityDescription entityForName:[self entityName] inManagedObjectContext:[[self coreManager] managedObjectContext]];
        [[[self coreManager] entityDescriptions] setObject:entity forKey:self];
    }
    return entity;
}

+ (NSDictionary*) relationshipsByName {
    NSDictionary* rels = [[[CoreManager sharedCoreManager] modelRelationships] objectForKey:self];
    if (rels == nil) {
        // Cache relationships dictionary if not yet extant
        rels = [[self entityDescription] relationshipsByName];
        [[[CoreManager sharedCoreManager] modelRelationships] setObject:rels forKey:self];
    }
    return rels;
}

+ (BOOL) hasRelationships {
    return [[self relationshipsByName] count] > 0;
}

+ (NSDictionary*) attributesByName {
    NSDictionary* attr = [[[CoreManager sharedCoreManager] modelAttributes] objectForKey:self];
    if (attr == nil) {
        // Cache properties dictionary if not yet extant
        attr = [[self entityDescription] attributesByName];
        [[[CoreManager sharedCoreManager] modelAttributes] setObject:attr forKey:self];
    }
    return attr;
}

+ (NSDictionary*) propertiesByName {
    NSDictionary* props = [[[CoreManager sharedCoreManager] modelProperties] objectForKey:self];
    if (props == nil) {
        // Cache properties dictionary if not yet extant
        props = [[self entityDescription] propertiesByName];
        [[[CoreManager sharedCoreManager] modelProperties] setObject:props forKey:self];
    }
    return props;
}

/**
 Returns the property description for a given property in a given model.
 By default, this caches the resulting dictionaries provided by Core Data
 in order to maximize efficiency (caching performed in #propertiesByName).
 */
+ (NSPropertyDescription*) propertyDescriptionForField:(NSString*)field inModel:(Class)modelClass {
    return [[modelClass propertiesByName] objectForKey:field];
}

+ (NSPropertyDescription*) propertyDescriptionForField:(NSString*)field {
    return [self propertyDescriptionForField:field inModel:self];
}


#pragma mark -
#pragma mark Create

+ (id) create:(id)parameters {
    return [self create:parameters withOptions:[self defaultCreateOptions]];
}

+ (id) create:(id)parameters withOptions:(NSDictionary*)options {
    if ([parameters isKindOfClass:[NSArray class]]) {
        // Iterate through items and attempt to create resources for each
        NSMutableArray *resources = [NSMutableArray arrayWithCapacity:[parameters count]];
        for (id item in parameters)
            [resources addObject:[self create:item withOptions:options]];
		
        return resources;
    }
    else {
        // Get managed object context from options or just use default
        id context = [options objectForKey:@"context"];
        if (context == nil)
            context = [self managedObjectContext];
        else if ([context isEqual:[NSNull null]])
            context = nil;
		
        // Insert new managed object into context
        CoreResource *resource = [[self alloc] initWithEntity:[self entityDescription] 
							   insertIntoManagedObjectContext:context];
		
        // Update new object with properties
        [resource update:parameters withOptions:options];
        
        // Set createdAt timestamp if possible (and not prohibited in options)
        id doTimestamp = [options objectForKey:@"timestamp"];
        if (doTimestamp == nil || [doTimestamp boolValue] == YES) {
            SEL createdAtSel = NSSelectorFromString([self createdAtField]);
            if ([resource respondsToSelector:createdAtSel])
                [resource setValue:[NSDate date] forKey:[self createdAtField]];
        }
        
        // Log creation
        if ([[self class] coreManager].logLevel > 1) {
            DLog(@"Created new %@ [#%@] in context %@", self, [resource valueForKey:[self localIdField]], context);
            if ([[self class] coreManager].logLevel > 4)
                DLog(@"=> %@", resource);
        }
        
        // Call didCreate for user-specified create hooks
        [resource didCreate];
		
        return [resource autorelease];
    }
}

+ (id) createOrUpdate:(id)parameters {
    return [self createOrUpdate:parameters withOptions:[self defaultCreateOrUpdateOptions]];
}

+ (id) createOrUpdate:(id)parameters withOptions:(NSDictionary*)options {
    // If parameters are just a resource of this class, return it untouched
    if ([parameters isKindOfClass:self])
        return parameters;
	
    else if ([parameters isKindOfClass:[NSArray class]]) {
        // Iterate through items and attempt to create or update resources for each
        NSMutableArray *resources = [NSMutableArray arrayWithCapacity:[parameters count]];
        for (id item in parameters)
            [resources addObject:[self createOrUpdate:item withOptions:options]];
		
        return resources;
    }
    
    else if ([parameters isKindOfClass:[NSDictionary class]]) {
        // Get remote ID
        id resourceId = [parameters valueForKey:[self remoteIdField]];
        id objectId = [parameters valueForKey:@"objectId"];
        // If there is an ID, attempt to find existing record
        if (resourceId != nil) {
            CoreResult* findResult = [self findLocal:resourceId inContext:[options objectForKey:@"context"]];
            
            DLog(@"Find %@ [#%@] in context %@ (found %i)", self, resourceId, [options objectForKey:@"context"], [findResult resourceCount]);
			
            // If there is a result, update it (if necessary) instead of creating it
			CoreResource *existingResource = nil;
			NSError *error = nil;
			
            if ([findResult resourceCount] == 1) {
                existingResource = [findResult resource];
			} else {
				// We don't have any resources. Last chance: check to see if the resource does exist but it is in the create process
				if (objectId != nil && objectId != @"") {
					DLog(@"Object Id = %@", objectId);
					// Try to create a proper URL out of the objectId:
					
					NSManagedObjectID *oid = [[[CoreManager sharedCoreManager]persistentStoreCoordinator] managedObjectIDForURIRepresentation:[NSURL URLWithString:objectId]];
					NSManagedObjectContext *moc = [options objectForKey:@"context"];
					if (!moc) {
						ALog(@"Object will not be retrieved from a nil ManagedObjectContext");
					}
					
					existingResource = (CoreResource *)[moc existingObjectWithID:oid error:&error];
				}

				
			}
			
			if (existingResource) {
				// Determine whether this object needs to be updated (relationships will still be checked no matter what)
				BOOL shouldUpdate = [existingResource shouldUpdateWith:parameters];
				if (shouldUpdate) {
					[existingResource update:parameters withOptions:options];
				}
				else {
					DLog(@"Skipping update of %@ with id %@ because it is already up-to-date", 
						 [existingResource class], [existingResource valueForKey:[[existingResource class] localIdField]]);
				}
				
				return existingResource;
			}else {
				DLog(@"Error: %@\n%@", [error localizedDescription], [error userInfo]);
			}
			
			
			
		}
		
		
		// Otherwise, no existing record found, so create a new object
		return [self create:parameters withOptions:options];
	}
	
	return nil;
}


/**
 Determines whether or not an existing (local) record should be updated with data from the provided dictionary
 (presumably retrieved from a remote source.) The most likely determinant would be if the new data is newer
 than the object, which by default is determined through the field returned by [self updatedAtField]
 The other possibility is that this is a newly posted object with the resourceId set for
 the first time
 */
- (BOOL) shouldUpdateWith:(NSDictionary*)dict {
	if (![self isInRemoteCollection]) {
		return YES;
	}
    SEL updatedAtSel = NSSelectorFromString([[self class] updatedAtField]);
    if ([self respondsToSelector:updatedAtSel]) {
        NSDate *updatedAt = (NSDate*)[self performSelector:updatedAtSel];
        if (updatedAt != nil) {
            NSString *dictUpdatedAtString = [dict objectForKey:[[self class] updatedAtField]];
            if (dictUpdatedAtString != nil) {
                NSDate *dictUpdatedAt = [[[self class] dateParserForField:[[self class] updatedAtField]] dateFromString:dictUpdatedAtString];
                if (updatedAt != nil) {
                    return [updatedAt compare:dictUpdatedAt] == NSOrderedAscending;
                }
            }
        }
    }
    return YES;
}

- (void) update:(NSDictionary*)dict {
    [self update:dict withOptions:[[self class] defaultUpdateOptions]];
}

- (void) update:(NSDictionary*)dict withOptions:(NSDictionary*)options {
	
    // Loop through and apply fields in dictionary (if they exist on the object)
    for (NSString* field in [dict allKeys]) {
		
        // Get local field name (by default, this is the same as the remote name)
        // If this is an ID field, use remote/localIdField methods; otherwise, localNameForRemoteField
        NSString* localField = nil;
        if ([field isEqualToString:[[self class] remoteIdField]])
            localField = [[self class] localIdField];
        else
            localField = [[self class] localNameForRemoteField:field];
        
        NSPropertyDescription *propertyDescription = [[self class] propertyDescriptionForField:localField inModel:[self class]];
        
        if (propertyDescription != nil) {
            id value = [dict objectForKey:field];
            
            // If property is a relationship, do some cascading object creation/updation
            if ([propertyDescription isKindOfClass:[NSRelationshipDescription class]]) {
				
                // Get relationship class from core data info
                NSRelationshipDescription *relationshipDescription = (NSRelationshipDescription*)propertyDescription;
                Class relationshipClass = NSClassFromString([[relationshipDescription destinationEntity] managedObjectClassName]);
                id newRelatedResources = nil;
                id existingRelatedResources = [self valueForKey:localField];
				
                // Get relationship options
                NSDictionary* relationshipOptions = [options objectForKey:relationshipClass];
                
				
                // ===== Get related resources from value ===== //
				
                // If the value is a dictionary or array, use it to create or update an resource                
                if ([value isKindOfClass:[NSDictionary class]] || [value isKindOfClass:[NSArray class]]) {
                    newRelatedResources = [relationshipClass createOrUpdate:value withOptions:options];
                    if ([newRelatedResources isKindOfClass:[NSArray class]])
                        newRelatedResources = [NSMutableSet setWithArray:newRelatedResources];
                }
                
                // Otherwise, if the value is a resource itself, use it directly
                else if ([value isKindOfClass:relationshipClass])
                    newRelatedResources = value;
				
                // ===== Apply related resources to self ===== //
                
                NSString *rule = [relationshipOptions objectForKey:@"rule"];
                
                // To-many relationships
                if ([relationshipDescription isToMany]) {
                    
                    // If rule is to add, append new objects to existing
                    if ([rule isEqualToString:@"append"])
                        newRelatedResources = [existingRelatedResources setByAddingObjectsFromSet:newRelatedResources];
					
                    // If relationship rule is destroy, destroy all old resources that aren't in the new set
                    else if ([rule isEqualToString:@"destroy"]) {
                        NSSet* danglers = [existingRelatedResources difference:newRelatedResources];
                        for (id dangler in danglers)
                            [dangler destroyLocal];
                    }
                    
                    // Default action is to replace the set with no further reprecussions (old resources will still persist)
                    [self setValue:newRelatedResources forKey:localField];
                }
                
                // Singular relationships
                else {
                    // Only process if the new value is different from the current value
                    if (![newRelatedResources isEqual:existingRelatedResources]) {
                        
                        // Set new value
                        [self setValue:newRelatedResources forKey:localField];
                        
                        // If relationship rule is destroy, get rid of the old resource
                        if ([rule isEqualToString:@"destroy"])
                            [existingRelatedResources destroyLocal];
                    }
                }
            }
            
            // If it's an attribute, just assign the value to the object (unless the object is up-to-date)
            else if ([propertyDescription isKindOfClass:[NSAttributeDescription class]]) {                
                
                DLog(@"[%@] Setting remote field: %@, local field: %@, value: %@", [self class], field, localField, value);
                
                // Check if value is NSNull, which should be set as nil on fields (since NSNull is just used as a collection placeholder)
                if ([value isEqual:[NSNull null]])
                    [self setValue:nil forKey:localField];
				
                else {
                    // Perform additional processing on value based on attribute type
                    switch ([(NSAttributeDescription*)propertyDescription attributeType]) {
                        case NSDateAttributeType:
                            if (value != nil && [value isKindOfClass:[NSString class]])
                                value = [[[self class] dateParserForField:localField] dateFromString:value];
                            break;
                    }
                    [self setValue:value forKey:localField];
                }
            }
        }
    }
}

/**
 Override for post-create hooks
 */
- (void) didCreate {}

+ (NSDictionary*) defaultCreateOptions { return nil; }

+ (NSDictionary*) defaultCreateOrUpdateOptions { return [self defaultCreateOptions]; }

+ (NSDictionary*) defaultUpdateOptions { return nil; }


#pragma mark -
#pragma mark Read

+ (CoreResult*) find:(id)resourceId {
    return [self find:resourceId andNotify:nil withSelector:nil];
}

+ (CoreResult*) find:(id)resourceId andNotify:(id)del withSelector:(SEL)selector {
    CoreResult* localResult = [self findLocal:resourceId];
    if ([localResult hasAnyResources])
        return localResult;
    [self findRemote:resourceId andNotify:del withSelector:selector];
    return [[[CoreResult alloc] init] autorelease];
}

+ (CoreResult*) findAll {
    return [self findAll:nil andNotify:nil withSelector:nil];
}

+ (CoreResult*) findAll:(id)parameters {
    return [self findAll:parameters andNotify:nil withSelector:nil];
}

+ (CoreResult*) findAll:(id)parameters andNotify:(id)del withSelector:(SEL)selector {
    CoreResult* localResult = [self findAllLocal];
    [self findAllRemote:parameters andNotify:del withSelector:selector];
    return localResult;
}

+ (CoreResult*) findLocal:(id)resourceId {
    return [self findLocal:resourceId inContext:nil];
}

+ (CoreResult*) findLocal:(id)resourceId inContext:(NSManagedObjectContext*)context {
    return [self findAllLocal:$D(resourceId, [self localIdField], $S(@"find%@", NSStringFromClass(self)), @"$template")
					inContext:context];
}

+ (CoreResult*) findAllLocal {
    return [self findAllLocal:nil];
}

+ (CoreResult*) findAllLocal:(id)parameters {
    return [self findAllLocal:parameters inContext:nil];
}

+ (CoreResult*) findAllLocal:(id)parameters inContext:(NSManagedObjectContext*)context {
    if (context == nil)
        context = [self managedObjectContext];
	
    // Generate (or get templated) fetch request
    NSFetchRequest* fetch = [self fetchRequest:parameters];
    NSError* error = nil;
    
    // Perform fetch
    NSArray* resources = [context executeFetchRequest:fetch error:&error];
	
    CoreResult* result = error == nil ?
	[[[CoreResult alloc] initWithResources:resources] autorelease] :
	[[[CoreResult alloc] initWithError:error] autorelease];
    return result;
}

+ (void) findRemote:(id)resourceId {
    [self findRemote:resourceId andNotify:nil withSelector:nil];
}

+ (void) findRemote:(id)resourceId andNotify:(id)del withSelector:(SEL)selector {
    CoreRequest *request = [[[CoreRequest alloc] initWithURL:
							 [CoreUtils URLWithSite:[self remoteURLForResource:resourceId action:Read] andFormat:@"json" andParameters:nil]] autorelease];
    request.delegate = self;
    request.didFinishSelector = @selector(findRemoteDidFinish:);
    request.didFailSelector = @selector(findRemoteDidFail:);
    request.coreDelegate = del;
    request.coreSelector = selector;
    [self configureRequest:request forAction:@"find"];
	
    // If we're using bundle requests, just attempt to find the data within the project
    if ([self useBundleRequests]) {
        request.bundleDataPath = [self bundlePathForResource:resourceId action:Read];
        [request executeAsBundleRequest];
    }
    
    // Enqueue as remote HTTP request 
    else
        [[self coreManager] enqueueRequest:request];
}

+ (void) findAllRemote {
    [self findAllRemote:nil];
}

+ (void) findAllRemote:(id)parameters {
    [self findAllRemote:parameters andNotify:nil withSelector:nil];
}

+ (void) findAllRemote:(id)parameters andNotify:(id)del withSelector:(SEL)selector {
    CoreRequest *request = [[[CoreRequest alloc] initWithURL:
							 [CoreUtils URLWithSite:[self remoteURLForCollectionAction:Read] andFormat:@"json" andParameters:parameters]] autorelease];
    request.delegate = self;
    request.didFinishSelector = @selector(findRemoteDidFinish:);
    request.didFailSelector = @selector(findRemoteDidFail:);
    request.coreDelegate = del;
    request.coreSelector = selector;
    [self configureRequest:request forAction:@"findAll"];
	DLog(@"Request Url: %@", [request.url description]);
    // If we're using bundle requests, just attempt to find the data within the project
    if ([self useBundleRequests]) {
		DLog(@"Using bundle Request");
        request.bundleDataPath = [self bundlePathForCollectionAction:Read];
        [request executeAsBundleRequest];
    }
    
    // Enqueue as remote HTTP request 
    else
        [[self coreManager] enqueueRequest:request];
}

+ (void) findRemoteDidFinish:(CoreRequest*)request {
    // Create and enqueue deserializer in non-blocking thread
    CoreDeserializer* deserializer = [[CoreJSONDeserializer alloc] initWithSource:request andResourceClass:self];
    deserializer.target = request.coreDelegate;
    deserializer.action = request.coreSelector;
    [[[self coreManager] deserialzationQueue] addOperation:deserializer];
    [deserializer release];
    DLog(@"===> Class version: done with findRemoteDidFinish (queue: %@, operations: %@)", 
		 [[self coreManager] deserialzationQueue], [[[self coreManager] deserialzationQueue] operations] );
}

+ (void) findRemoteDidFail:(CoreRequest*)request {
    // Notify core delegate (if extant) of failure
    if (request.coreDelegate && request.coreSelector && [request.coreDelegate respondsToSelector:request.coreSelector]) {
        CoreResult* result = [[[CoreResult alloc] initWithError:[request error]] autorelease];
        [request.coreDelegate performSelector:request.coreSelector withObject:result];
    }
}

+ (int) countLocal {
    return [self countLocal:nil];
}

+ (int) countLocal:(id)parameters {
    return [self countLocal:parameters inContext:nil];
}

+ (int) countLocal:(id)parameters inContext:(NSManagedObjectContext*)context {
    if (context == nil)
        context = [self managedObjectContext];
	
    // Generate (or get templated) fetch request
    NSFetchRequest* fetch = [self fetchRequest:parameters];
    NSError* error = nil;
    
    NSLog(@"Count: %i in context %@", [context countForFetchRequest:fetch error:&error], context);
    
    // Perform count
    return [context countForFetchRequest:fetch error:&error];
}
#pragma mark --
#pragma mark Remote 

/* A resource should only get a remoteId if it has been in the remote collection.
 Note that this does not guarantee that it is still in the collection
 If neeesary we cna implement a check, but we don't care at the moment.
 */
//TODO: remember to add a code path for a remote resource no lnger exists for a gien resourceId (ie decide if we should delete local or just reset the remoteId
-(BOOL) isInRemoteCollection {
	return ([self localId] != nil);
}

/* 
 Push should be called at the application's discretion. It doesn't make sense to be calling ppush on every coreData save as it means that we'll
 need to be checking if we ude primitive update methods and whatever. Much easier to seprate the concerns so that we just synchronize changes 
 when we feel we need to.
 */
-(void)push {
	// Push may be a Create or Update. Delete should be handled via remote delete
	
	if ([self isInRemoteCollection]) {
		// we may be doing an update or Delete
		[self pushForAction:Update];
	} else {
		[self pushForAction:Create];
	}
}

-(void)pushForAction:(Action)action{
	[self pushForAction:action AndNotify:nil withSelector:nil];
}

-(void)pushForAction:(Action)action AndNotify:(id)del withSelector:(SEL)selector  {
	CoreRequest *requestForPush = [self requestForPushForAction:action];
	requestForPush.delegate = self;
    requestForPush.didFinishSelector = self.remoteDidFinishSelector;
    requestForPush.didFailSelector = self.remoteDidFailSelector;
    requestForPush.coreDelegate = del;
    requestForPush.coreSelector = selector;
	[[[self class]coreManager] enqueueRequest:requestForPush];
}
-(CoreRequest *) requestForPushForAction:(Action)action {
	// no remote updates are possible if we're using bundles.
	if ([[self class] useBundleRequests])
		return nil;
	
	CoreRequest *aRequest = [CoreRequest requestWithURL:[CoreUtils URLWithSite:[self remoteURLForAction:action] andFormat:@"json" andParameters:nil]];
	[aRequest setRequestMethod:[self HTTPMethodForAction:action]];
	if (action != Destroy) {
		// TODO: We're not actually using the attributes properties or post!
		NSDictionary *properties = [self properties:$D([NSNumber numberWithBool:YES], @"$serializeDates", [NSNumber numberWithBool:NO], @"$relationships", [NSNumber numberWithBool:(action == Create)], @"includeObjectId")];
		
		NSDictionary *post = [[self class] usesRootNode] ? $D(properties, [[self class] rootNodeName]) : properties;
		
		
		DLog(@"Properties: %@", [self toJson]);
		
		
		[aRequest appendPostData:[[self toJson] dataUsingEncoding:NSUTF8StringEncoding]];
	}
	return aRequest;	
}

/*
 Pushing an instance failed.
 */
- (void) remoteDidFail:(CoreResult *) result{
	
	[[self class] remoteDidFail:result];
}
/*
 Pushing an instance succeeded.
 */
- (void) remoteDidFinish:(CoreRequest *) request{
	// Create and enqueue deserializer in non-blocking thread
    CoreDeserializer* deserializer = [[CoreJSONDeserializer alloc] initWithSource:request andResourceClass:[self class]];
    deserializer.target = request.coreDelegate;
    deserializer.action = request.coreSelector;
    [[[[self class]coreManager] deserialzationQueue] addOperation:deserializer];
    [deserializer release];
    DLog(@"===> done with findRemoteDidFinish (queue: %@, operations: %@)", 
		 [[[self class]coreManager] deserialzationQueue], [[[[self class]coreManager] deserialzationQueue] operations] );
}
+ (void) remoteDidFinish:(CoreResult *) result{
	
	if([result hasAnyResources]){
		
		for(id object in result)
			[self create:object];
		
		[[self coreManager]save];
	}
}

+ (void) remoteDidFail:(CoreResult *) result{
	
	NSLog(@"Connection Failed: %@", [result error]);
}

#pragma mark -
#pragma mark Delete

+ (void) destroyAllLocal {
	// debug - make one line:
	NSArray *resources = [[[self class] findAllLocal] resources];
    for (CoreResource* model in resources )
        [[self managedObjectContext] deleteObject:model];
	[[self coreManager]save];
}

- (void) destroyLocal {
    [[[self class] managedObjectContext] deleteObject:self];
}



#pragma mark -
#pragma mark Results Management

+ (NSFetchRequest*) fetchRequest {
    NSFetchRequest *fetchRequest = [[[NSFetchRequest alloc] init] autorelease];
    [fetchRequest setEntity:[self entityDescription]];
    return fetchRequest;
}

+ (NSFetchRequest*) fetchRequest:(id)parameters {
    NSFetchRequest* fetch = nil;
	
    // If there's a template parameter, use it to get a stored fetch request (increases efficiency)
    NSString* templateName = [parameters isKindOfClass:[NSDictionary class]] ? [parameters objectForKey:@"$template"] : nil;
    if (templateName != nil)
        fetch = [[[self class] managedObjectModel] fetchRequestFromTemplateWithName:templateName substitutionVariables:parameters];
	
    // If no fetch template was found, generate one
    if (fetch == nil) {
        id sortParameters = [parameters isKindOfClass:[NSDictionary class]] ?
		[CoreUtils sortDescriptorsFromParameters:[parameters objectForKey:@"$sort"]] : nil;
        fetch = [self fetchRequestWithSort:sortParameters 
							  andPredicate:templateName != nil ? 
				 [self variablePredicateWithParameters:parameters] :
				 [self predicateWithParameters:parameters]];
        
        // If there's a template name, store this fetch as a template
        if (templateName != nil) {
            [[[self class] managedObjectModel] setFetchRequestTemplate:fetch forName:templateName];
			
            // Now apply the substitution variables by resetting the fetch request to the template-provided version
            if (parameters != nil)
                fetch = [[[self class] managedObjectModel] fetchRequestFromTemplateWithName:templateName substitutionVariables:parameters];
        }
    }
    
    return fetch;
}

+ (NSFetchRequest*) fetchRequestWithDefaultSort {
    NSFetchRequest *fetchRequest = [self fetchRequest];
    [fetchRequest setSortDescriptors:[NSArray arrayWithObject:
									  [[[NSSortDescriptor alloc] initWithKey:[self localIdField] ascending:YES] autorelease]]];
    return fetchRequest;
}

+ (NSFetchRequest*) fetchRequestWithSort:(id)sorting andPredicate:(NSPredicate*)predicate {
    NSFetchRequest *fetchRequest = [self fetchRequest];
    [fetchRequest setSortDescriptors:[CoreUtils sortDescriptorsFromParameters:sorting]];
    [fetchRequest setPredicate:predicate];
    return fetchRequest;
}

+ (NSPredicate*) variablePredicateWithParameters:(id)parameters {    
    // If parameters are a dictionary, remove all meta keys ($sort, $template, etc.) 
    // and any attributes that don't exist for this class
    if ([parameters isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary* mutableParameters = [NSMutableDictionary dictionaryWithCapacity:[parameters count]];
        for (NSString* key in parameters) {
            if ([self propertyDescriptionForField:key] != nil)
                [mutableParameters setObject:[parameters objectForKey:key] forKey:key];
        }
        return [CoreUtils variablePredicateFromObject:mutableParameters];
    }
    
    return [CoreUtils variablePredicateFromObject:parameters];
}

+ (NSPredicate*) predicateWithParameters:(id)parameters {
    return parameters != nil ? [[self variablePredicateWithParameters:parameters] predicateWithSubstitutionVariables:parameters] : nil;
}

#if TARGET_OS_IPHONE
+ (CoreResultsController*) coreResultsControllerWithSort:(id)sorting andSectionKey:(NSString*)sectionKey {
    NSFetchRequest *fetchRequest = [self fetchRequestWithSort:sorting andPredicate:nil];
    return [self coreResultsControllerWithRequest:fetchRequest andSectionKey:sectionKey];
}

+ (CoreResultsController*) coreResultsControllerWithRequest:(NSFetchRequest*)fetchRequest andSectionKey:(NSString*)sectionKey {
    CoreResultsController* coreResultsController = [[[CoreResultsController alloc] initWithFetchRequest:fetchRequest 
																				   managedObjectContext:[[self coreManager] managedObjectContext] 
																					 sectionNameKeyPath:sectionKey 
																							  cacheName:@"Root"] autorelease];
    coreResultsController.entityClass = self;
    return coreResultsController;
}
#endif

@end


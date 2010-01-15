//
//  CoreResource.h
//  CoreResource
//
//  Created by Mike Laurence on 12/24/09.
//  Copyright Punkbot LLC 2010. All rights reserved.
//

#include "ASIHTTPRequest.h"

@interface CoreManager : NSObject {
    NSManagedObjectModel *managedObjectModel;
    NSManagedObjectContext *managedObjectContext;	    
    NSPersistentStoreCoordinator *persistentStoreCoordinator;
    
    NSOperationQueue *requestQueue;
    
    NSString *remoteSiteURL;
    float localRequestDelay;
    NSDateFormatter *defaultDateParser;
    
    NSMutableDictionary *modelPropertyTypes;
    NSMutableDictionary *modelRelationships;
}

@property (nonatomic, retain, readonly) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, retain, readonly) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, retain, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@property (nonatomic, retain) NSOperationQueue *requestQueue;

@property (nonatomic, retain) NSString *remoteSiteURL;
@property (nonatomic, assign) float localRequestDelay;
@property (nonatomic, retain) NSDateFormatter *defaultDateParser;

@property (nonatomic, retain) NSMutableDictionary *modelPropertyTypes;
@property (nonatomic, retain) NSMutableDictionary *modelRelationships;

+ (CoreManager*) main;
+ (void) setMain: (CoreManager*)newMain;

- (NSString *)applicationDocumentsDirectory;


#pragma mark -
#pragma mark Networking
+ (BOOL) checkReachability:(BOOL)showConnectionError;
- (void) enqueueRequest:(ASIHTTPRequest*)request;


#pragma mark -
#pragma mark Alerts & Errors
+ (void) alertWithError:(NSError*)error;
+ (void) alertWithTitle:(NSString*)title andMessage:(NSString*)message;
+ (void) logCoreDataError:(NSError*)error;

#pragma mark -
#pragma mark Core Data
- (void)save;

@end


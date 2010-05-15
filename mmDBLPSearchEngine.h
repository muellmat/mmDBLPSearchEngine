/* mmDBLPSearchEngine */
//
//  Created by muellmat on 15-05-2010.
//  Copyright (c) 2010 Mekentosj.com. All rights reserved.
//
//  Based on the SDK created by Mekentosj on 17-01-2007.
//  Copyright (c) 2007 Mekentosj.com. All rights reserved.
// 
//  For use outside of the Papers application structure, please contact
//  Mekentosj at feedback@mekentosj.com
//  DO NOT REDISTRIBUTE WITHOUT ALL THE INCLUDED FILES
//
//
//  Overview
//
//  This header file acts as a template to start building your new search engine plugin.
//  More documentation can be found in the protocol file.

#import <Cocoa/Cocoa.h>

#import "PapersSearchPluginProtocol.h"

@interface mmDBLPSearchEngine : NSObject <PapersSearchPluginProtocol, PapersMatchPluginProtocol, PapersAutoMatchPluginProtocol>
{
	IBOutlet NSWindow *preferenceWindow;
	
	id delegate;
	
	NSDictionary * predefinedSearchTerms;
	NSDictionary * searchFields; 
	
	NSNumber *itemsPerPage;
	NSNumber *itemOffset;
	NSNumber *itemsFound;
	NSNumber *itemsToRetrieve;
	NSNumber *retrievedItems;
	
	NSString *statusString;	
	
    NSError *searchError;
}

- (id)delegate;
- (void)setDelegate:(id)newDelegate;

- (NSNumber *)itemsFound;
- (void)setItemsFound:(NSNumber *)newItemsFound;

- (NSNumber *)itemsToRetrieve;
- (void)setItemsToRetrieve:(NSNumber *)newItemsToRetrieve;

- (NSNumber *)retrievedItems;
- (void)setRetrievedItems:(NSNumber *)newRetrievedItems;
- (void)incrementRetrievedItemsWith: (int)value;

- (NSString *)statusString;
- (void)setStatusString:(NSString *)newStatusString;

- (NSError *)searchError;
- (void)setSearchError:(NSError *)newSearchError;


@end

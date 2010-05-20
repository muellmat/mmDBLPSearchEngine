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
//  The dblp Search Engine plugin allows users of Papers to query dblp.
//  It leverages the full potential of the SDK thanks to the rich eUtils that
//  the NLM provides. 
//
//  The plugin provides all three major services: Searching, Matching and 
//  auto-matching, implementing all three respective protocols.
//  In addition a series of plugin-specific helper methods have been 
//  implemented through a "dblp_methods" category.

#import <Cocoa/Cocoa.h>

#import "PapersSearchPluginProtocol.h"
#import "DBLP.h"

@interface mmDBLPSearchEngine : NSObject <PapersSearchPluginProtocol, PapersMatchPluginProtocol, PapersAutoMatchPluginProtocol> {
	IBOutlet NSWindow *preferenceWindow;
	
	id delegate;
	
	NSDictionary *predefinedSearchTerms;
	NSDictionary *searchFields; 
	
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

- (NSNumber*)itemsFound;
- (void)setItemsFound:(NSNumber*)newItemsFound;

- (NSNumber*)itemsToRetrieve;
- (void)setItemsToRetrieve:(NSNumber*)newItemsToRetrieve;

- (NSNumber*)retrievedItems;
- (void)setRetrievedItems:(NSNumber*)newRetrievedItems;
- (void)incrementRetrievedItemsWith:(int)value;

- (NSString*)statusString;
- (void)setStatusString:(NSString*)newStatusString;

- (NSError*)searchError;
- (void)setSearchError:(NSError*)newSearchError;


@end

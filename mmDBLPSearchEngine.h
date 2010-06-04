/* mmDBLPSearchEngine */
//
//  Created by Matthias MŸller <muellmat@informatik.uni-tuebingen.de> 
//  on 15-05-2010. This source is based on the SDK created by Mekentosj on 
//  17-01-2007. Copyright (c) 2007 Mekentosj.com. All rights reserved.
//
//
//
//  Overview
//
//  The DBLP Search Engine plugin allows users of Papers to query DBLP.
//
//  The plugin provides two major services: Searching and Matching, 
//  implementing all two respective protocols. In addition a series of 
//  plugin-specific helper methods have been implemented through a 
//  "dblp_methods" category.

#import <Cocoa/Cocoa.h>
#import "PapersSearchPluginProtocol.h"
#import "DBLP.h"

@interface mmDBLPSearchEngine : NSObject   <PapersSearchPluginProtocol, 
											PapersMatchPluginProtocol, 
											PapersAutoMatchPluginProtocol> {
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

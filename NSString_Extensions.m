#import "NSString_Extensions.h"


@implementation NSString(Filtering)

- (NSString *)filteredPubMedQuery
{		
	// Char -> @" "
	NSCharacterSet *spacing_set = [NSCharacterSet characterSetWithCharactersInString: NSLocalizedStringFromTableInBundle(@"SYMBOLS_TO_BE_REMOVED", nil, [NSBundle bundleForClass: NSClassFromString(@"mtPubmedSearchEngine")], @"Symbols that need to be replaced by a space in the query - DO NOT TRANSLATE")];
	// Char -> @""
	NSCharacterSet *deleting_set = [NSCharacterSet characterSetWithCharactersInString: NSLocalizedStringFromTableInBundle(@"SYMBOLS_TO_BE_CONVERTED_TO_SPACE", nil, [NSBundle bundleForClass: NSClassFromString(@"mtPubmedSearchEngine")], @"Symbols that need to be replaced by a space in the query - DO NOT TRANSLATE")];
	
	int i;
	NSMutableString* filteredString = [NSMutableString stringWithCapacity: [self length]];
	
	for(i=0; i < [self length]; i++){
		if([deleting_set characterIsMember: [self characterAtIndex: i]])
			continue;
		if([spacing_set characterIsMember: [self characterAtIndex: i]])
			[filteredString appendString: @" "];	                
		else
			[filteredString appendString: [self substringWithRange: NSMakeRange(i,1)]];
	}
	
	[filteredString replaceOccurrencesOfString: @"\"" withString: @"" options: NSLiteralSearch range: NSMakeRange(0, [filteredString length])];
	[filteredString replaceOccurrencesOfString: @"  " withString: @" " options: NSLiteralSearch range: NSMakeRange(0, [filteredString length])];
	[filteredString replaceOccurrencesOfString: @"\\" withString: @" " options: NSLiteralSearch range: NSMakeRange(0, [filteredString length])];
	
	return [NSString stringWithString: filteredString];
}

- (NSString *)filteredKeyword
{		
	NSMutableString* filteredString = [NSMutableString stringWithString: self];	
	[filteredString replaceOccurrencesOfString: @"," withString: @":" options: NSLiteralSearch range: NSMakeRange(0, [filteredString length])];	
	return [NSString stringWithString: filteredString];
}


- (NSString *)stringByRemovingTrailingPeriodsAndMarks{
    return [self stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@",. *"]];
}

- (NSString *)stringByRemovingTrailingPeriods
{
    return [self stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"."]];
}

- (NSString *)stringByRemovingPeriods
{
    return [self stringByRemovingCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"."]];
}

- (NSString *)stringByRemovingPeriodsAndTrailingMarks
{
	NSString *tmp = [self stringByRemovingCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"."]];
	return [tmp stringByRemovingTrailingPeriodsAndMarks];
}

- (NSString *)stringByRemovingAccents {
	NSMutableString *str = [NSMutableString stringWithString: self];
	CFStringTransform ((CFMutableStringRef)str, 
					   NULL,
					   kCFStringTransformStripCombiningMarks,
					   FALSE);
	
    return [NSString stringWithString: str];
}

#pragma mark Helper Methods

- (NSString *)stringByRemovingCharactersFromSet:(NSCharacterSet *)set
{
    NSMutableString	*temp;
	
    if([self rangeOfCharacterFromSet:set options:NSLiteralSearch].length == 0)
        return self;
    
    temp = [[self mutableCopyWithZone:[self zone]] autorelease];
    [temp removeCharactersInSet:set];
	
    return temp;
}


@end 


@implementation NSMutableString(Filtering)

- (void)removeCharactersInSet:(NSCharacterSet *)set
{
    NSRange		matchRange, searchRange, replaceRange;
    unsigned int	length;
	
    length = [self length];
    matchRange = [self rangeOfCharacterFromSet:set options:NSLiteralSearch range:NSMakeRange(0, length)];
    
    while(matchRange.length > 0)
    {
        replaceRange = matchRange;
        searchRange.location = NSMaxRange(replaceRange);
        searchRange.length = length - searchRange.location;
        
        for(;;)
        {
            matchRange = [self rangeOfCharacterFromSet:set options:NSLiteralSearch range:searchRange];
            if((matchRange.length == 0) || (matchRange.location != searchRange.location))
                break;
            replaceRange.length += matchRange.length;
            searchRange.length -= matchRange.length;
            searchRange.location += matchRange.length;
        }
        
        [self deleteCharactersInRange:replaceRange];
        matchRange.location -= replaceRange.length;
        length -= replaceRange.length;
    }
}

@end

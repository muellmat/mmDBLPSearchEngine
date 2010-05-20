//
//  NSString(Filtering).h

#import <Foundation/Foundation.h>

@interface NSString(Filtering)

- (NSString *)filteredPubMedQuery;
- (NSString *)stringByRemovingTrailingPeriodsAndMarks;
- (NSString *)stringByRemovingTrailingPeriods;
- (NSString *)stringByRemovingPeriods;
- (NSString *)stringByRemovingPeriodsAndTrailingMarks;
- (NSString *)stringByRemovingAccents;
- (NSString *)filteredKeyword;

- (NSString *)stringByRemovingCharactersFromSet:(NSCharacterSet *)set;

@end


@interface NSMutableString(Filtering)

- (void)removeCharactersInSet:(NSCharacterSet *)set;

@end

//
//  JJRSObjectDescription.h
//
//  Created by John Scott on 29/01/2016.
//
//

#import <Foundation/Foundation.h>

@interface JJRSObjectDescription : NSCoder

+(NSString * _Nonnull)descriptionForObject:(nullable id)anObject;

+(NSAttributedString * _Nonnull)attributedDescriptionForObject:(nullable id)anObject;

@end

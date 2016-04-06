//
//  JJRSObjectDescription.m
//
//  Created by John Scott on 29/01/2016.
//
//

#import "JJRSObjectDescription.h"

#import <objc/runtime.h>

#include <stdarg.h>


#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#define COLOR(rgb) [UIColor colorWithRed:(((rgb>>16) & 0xFF)/255.) green:(((rgb>>8) & 0xFF)/255.) blue:(((rgb>>0) & 0xFF)/255.) alpha:1]
#define FONT(fontName, fontSize) [UIFont fontWithName:fontName size:fontSize]
#elif TARGET_OS_MAC
#import <AppKit/AppKit.h>
#define COLOR(rgb) [NSColor colorWithRed:(((rgb>>16) & 0xFF)/255.) green:(((rgb>>8) & 0xFF)/255.) blue:(((rgb>>0) & 0xFF)/255.) alpha:1]
#define FONT(fontName, fontSize) [NSFont fontWithName:fontName size:fontSize]
#endif


#define KEY_COLOR COLOR(0x3F6E74)
#define COMMENT_COLOR COLOR(0x007400)
#define STRING_COLOR COLOR(0xC41A16)
#define PLAIN_COLOR COLOR(0x000000)
#define KEYWORD_COLOR COLOR(0xAA0D91)
#define NUMBER_COLOR COLOR(0x1C00CF)

NSArray <NSString*> *_JJRSObjectDescriptionGetPropertyNamesForObject(id anObject)
{
    unsigned int propertyCount = 0;
    objc_property_t *propertyList = class_copyPropertyList(object_getClass(anObject), &propertyCount);
    
    NSMutableArray *propertyNames = [NSMutableArray array];
    
    for (unsigned int propertyIndex = 0; propertyIndex<propertyCount; propertyIndex++)
    {
        NSString *propertyName = [[NSString alloc] initWithUTF8String:property_getName(propertyList[propertyIndex])];
        [propertyNames addObject:propertyName];
    }
    
    if (propertyList)
    {
        free(propertyList);
    }
    return [propertyNames copy];
}

@interface JJRSObjectDescription ()

@property (nonatomic, readonly) NSAttributedString *buffer;

- (void)appendWithColor:(id)color format:(NSString *)format, ... NS_FORMAT_FUNCTION(2,3);

@end

@implementation JJRSObjectDescription
{
    NSMutableAttributedString *_buffer;
    NSUInteger _depth;
    NSHashTable *_references;
    NSDateFormatter *_rfc3339DateFormatter;
    NSArray <NSString*> *_excludedPropertyNames;
}

-(instancetype)init
{
    self = [super init];
    if (self)
    {
        _buffer = [[NSMutableAttributedString alloc] init];
        _references = [NSHashTable hashTableWithOptions:NSPointerFunctionsObjectPersonality];
        
        /*
         https://developer.apple.com/library/mac/qa/qa1480/_index.html
         */
        
        _rfc3339DateFormatter = [[NSDateFormatter alloc] init];
        _rfc3339DateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        _rfc3339DateFormatter.dateFormat = @"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'";
        _rfc3339DateFormatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
        
        _excludedPropertyNames = _JJRSObjectDescriptionGetPropertyNamesForObject(NSObject.new);
    }
    return self;
}

-(id)buffer
{
    return _buffer;
}

+(NSString * _Nonnull)descriptionForObject:(nullable id)rootObject
{
    return [[self attributedDescriptionForObject:rootObject] string];
}

+(NSAttributedString * _Nonnull)attributedDescriptionForObject:(nullable id)rootObject
{
    @autoreleasepool
    {
        JJRSObjectDescription *archiver = [[JJRSObjectDescription alloc] init];
        [archiver encodeObject:rootObject];
        return archiver.buffer;
    }
}

-(BOOL)allowsKeyedCoding
{
    return YES;
}

- (void)appendWithColor:(id)color format:(NSString *)format, ...
{
    va_list vl;
    va_start(vl, format);
    NSString *string = [[NSString alloc] initWithFormat:format arguments:vl];
    va_end(vl);
    
    NSDictionary *attributes = @{
                                 NSFontAttributeName : FONT(@"Menlo", 10.),
                                 NSForegroundColorAttributeName : color
                                 };
    
    NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:string attributes:attributes];
    [_buffer appendAttributedString:attributedString];
}

-(void)padBuffer
{
    [self appendWithColor:PLAIN_COLOR format:@"%@", [@"" stringByPaddingToLength:_depth*2 withString:@"    " startingAtIndex:0]];
}

- (void)encodeObject:(nullable __kindof NSObject<NSCoding>*)objv forKey:(NSString *)key
{
    [self padBuffer];
    if (key)
    {
        [self appendWithColor:KEY_COLOR format:@"%@", key];
        [self appendWithColor:PLAIN_COLOR format:@" = "];
    }
    [self encodeObject:objv];
}

- (void)encodeObject:(nullable __kindof NSObject<NSCoding>*)objv
{
    if (!objv)
    {
        [self appendWithColor:KEYWORD_COLOR format:@"nil\n"];
    }
    else if ([objv.classForKeyedArchiver isSubclassOfClass:NSDictionary.class])
    {
        NSDictionary *typedObjv = objv;
        
        [self appendWithColor:PLAIN_COLOR format:@"{\n"];
        _depth++;
        [typedObjv enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop)
         {
             [self encodeObject:obj forKey:key];
         }];
        _depth--;
        [self padBuffer];
        [self appendWithColor:PLAIN_COLOR format:@"}\n"];
        
    }
    else if ([objv.classForKeyedArchiver isSubclassOfClass:NSArray.class])
    {
        NSArray *typedObjv = objv;
        [self appendWithColor:PLAIN_COLOR format:@"[\n"];
        _depth++;
        [typedObjv enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop)
         {
             if (idx > 0)
             {
                 [self padBuffer];
                 [self appendWithColor:COMMENT_COLOR format:@"// %lu\n", (unsigned long)idx];
             }
             [self padBuffer];
             [self encodeObject:obj];
         }];
        _depth--;
        [self padBuffer];
        [self appendWithColor:PLAIN_COLOR format:@"]\n"];
    }
    else if (NSString.class == objv.classForKeyedArchiver)
    {
        NSString *typedObjv = objv;
        [self appendWithColor:STRING_COLOR format:@"\"%@\"\n", typedObjv];
    }
    else if (NSNumber.class == objv.classForKeyedArchiver)
    {
        NSNumber *typedObjv = objv;
        [self appendWithColor:NUMBER_COLOR format:@"%@\n", typedObjv];
    }
    else if (NSUUID.class == objv.classForKeyedArchiver)
    {
        NSUUID *typedObjv = objv;
        [self padBuffer];
        [self appendWithColor:PLAIN_COLOR format:@"%@\n", typedObjv];
    }
    else if (NSDate.class == objv.classForKeyedArchiver)
    {
        NSDate *typedObjv = objv;
        [self padBuffer];
        [self appendWithColor:PLAIN_COLOR format:@"%@\n", typedObjv];
    }
    else if (NSURL.class == objv.classForKeyedArchiver)
    {
        NSURL *typedObjv = objv;
        [self padBuffer];
        [self appendWithColor:PLAIN_COLOR format:@"%@\n", typedObjv];
    }
    else if (![_references containsObject:objv])
    {
        [_references addObject:objv];
        
        NSUInteger bufferLength = _buffer.length;
        
        /*
         Given we're never going to rely on this output we can try encodeWithCoder: whether the class
         publicly conforms to NSCoding or not.
        */
        
        @try
        {
            [self appendWithColor:PLAIN_COLOR format:@"<%@: %p> {\n", NSStringFromClass(objv.class), objv];
            
            _depth++;

            [objv encodeWithCoder:self];
            
            _depth--;
            [self padBuffer];
            [self appendWithColor:PLAIN_COLOR format:@"}\n"];
        }
        @catch (NSException *exception)
        {
            [_buffer deleteCharactersInRange:NSMakeRange(bufferLength, _buffer.length - bufferLength)];
            
            [self appendWithColor:PLAIN_COLOR format:@"<%@: %p>\n", NSStringFromClass(objv.class), objv];
        }
    }
    else
    {
        [self appendWithColor:PLAIN_COLOR format:@"<%@: %p>\n", NSStringFromClass(objv.class), objv];
    }
}

- (void)encodeConditionalObject:(nullable id)objv forKey:(NSString *)key
{
    [self encodeObject:objv forKey:key];
}

- (void)encodeBool:(BOOL)boolv forKey:(NSString *)key
{
    [self padBuffer];
    if (key)
    {
        [self appendWithColor:KEY_COLOR format:@"%@", key];
        [self appendWithColor:PLAIN_COLOR format:@" = "];
    }

    [self appendWithColor:KEYWORD_COLOR format:@"%@\n", boolv ? @"true" : @"false"];
}

- (void)encodeInt:(int)intv forKey:(NSString *)key
{
    NSNumber *JSONObject = [NSNumber numberWithInt:intv];
    [self encodeObject:JSONObject forKey:key];
}

- (void)encodeInt32:(int32_t)intv forKey:(NSString *)key
{
    NSNumber *JSONObject = [NSNumber numberWithInt:intv];
    [self encodeObject:JSONObject forKey:key];
}

- (void)encodeInt64:(int64_t)intv forKey:(NSString *)key
{
    NSNumber *JSONObject = [NSNumber numberWithLongLong:intv];
    [self encodeObject:JSONObject forKey:key];
}

- (void)encodeFloat:(float)realv forKey:(NSString *)key
{
    NSNumber *JSONObject = [NSNumber numberWithFloat:realv];
    [self encodeObject:JSONObject forKey:key];
}

- (void)encodeDouble:(double)realv forKey:(NSString *)key
{
    NSNumber *JSONObject = [NSNumber numberWithDouble:realv];
    [self encodeObject:JSONObject forKey:key];
}

- (void)encodeBytes:(nullable const uint8_t *)bytesp length:(NSUInteger)lenv forKey:(NSString *)key;
{
    [self padBuffer];
    if (key)
    {
        [self appendWithColor:KEY_COLOR format:@"%@", key];
        [self appendWithColor:PLAIN_COLOR format:@" = "];
    }
    [self appendWithColor:PLAIN_COLOR format:@"%@\n", [NSData dataWithBytes:bytesp length:lenv]];
}

@end

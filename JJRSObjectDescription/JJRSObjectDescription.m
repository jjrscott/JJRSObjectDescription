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

-(BOOL)requiresSecureCoding
{
    return NO;
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
    if ([_buffer.string hasSuffix:@"\n"])
    {
        [self appendWithColor:PLAIN_COLOR format:@"%@", [@"" stringByPaddingToLength:_depth*2 withString:@"    " startingAtIndex:0]];
    }
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
        [self padBuffer];
        [self appendWithColor:KEYWORD_COLOR format:@"nil\n"];
    }
    else if ([objv.classForKeyedArchiver isSubclassOfClass:NSNull.class])
    {
        [self padBuffer];
        [self appendWithColor:KEYWORD_COLOR format:@"null\n"];
    }
    else if ([objv.classForKeyedArchiver isSubclassOfClass:NSDictionary.class])
    {
        NSDictionary *typedObjv = objv;
        [self padBuffer];
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
        [self padBuffer];
        [self appendWithColor:PLAIN_COLOR format:@"[\n"];
        _depth++;
        [typedObjv enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop)
         {
             [self padBuffer];
             [self appendWithColor:COMMENT_COLOR format:@"%lu = ", (unsigned long)idx];
             [self padBuffer];
             [self encodeObject:obj];
         }];
        _depth--;
        [self padBuffer];
        [self appendWithColor:PLAIN_COLOR format:@"]\n"];
    }
    else if ([objv.classForKeyedArchiver isSubclassOfClass:NSSet.class])
    {
        NSSet *typedObjv = objv;
        [self padBuffer];
        [self appendWithColor:PLAIN_COLOR format:@"(\n"];
        _depth++;
        [typedObjv enumerateObjectsUsingBlock:^(id  _Nonnull obj, BOOL * _Nonnull stop)
         {
             [self padBuffer];
             [self encodeObject:obj];
         }];
        _depth--;
        [self padBuffer];
        [self appendWithColor:PLAIN_COLOR format:@")\n"];
    }
    else if ([objv.classForKeyedArchiver isSubclassOfClass:NSString.class])
    {
        NSString *typedObjv = objv;
        [self padBuffer];
        [self appendWithColor:STRING_COLOR format:@"\"%@\"\n", typedObjv];
    }
    else if ([objv.classForKeyedArchiver isSubclassOfClass:NSNumber.class])
    {
        NSNumber *typedObjv = objv;
        [self padBuffer];
        [self appendWithColor:NUMBER_COLOR format:@"%@\n", typedObjv];
    }
    else if ([objv.classForKeyedArchiver isSubclassOfClass:NSUUID.class])
    {
        NSUUID *typedObjv = objv;
        [self padBuffer];
        [self appendWithColor:PLAIN_COLOR format:@"%@\n", typedObjv];
    }
    else if ([objv.classForKeyedArchiver isSubclassOfClass:NSDate.class])
    {
        NSDate *typedObjv = objv;
        [self padBuffer];
        [self appendWithColor:PLAIN_COLOR format:@"%@\n", typedObjv];
    }
    else if ([objv.classForKeyedArchiver isSubclassOfClass:NSURL.class])
    {
        NSURL *typedObjv = objv;
        [self padBuffer];
        [self appendWithColor:STRING_COLOR format:@"%@\n", typedObjv];
    }
    else if ([objv.classForKeyedArchiver isSubclassOfClass:NSData.class])
    {
        NSData *typedObjv = objv;
        [self padBuffer];
        
        NSInteger maxLength = 1024;
        
        [self appendWithColor:STRING_COLOR format:@"<"];

        [typedObjv enumerateByteRangesUsingBlock:^(const void * _Nonnull bytes, NSRange byteRange, BOOL * _Nonnull stop) {
            
            const unsigned char *chars = bytes;
            
            for (NSInteger offset=0; offset<byteRange.length; offset++)
            {
                [self appendWithColor:STRING_COLOR format:@"%02x", chars[offset]];
                const NSInteger nextIndex = offset + byteRange.location + 1;

                if (nextIndex >= typedObjv.length)
                {
                    *stop = YES;
                    break;
                }
                
                if (0 == nextIndex % 4)
                {
                    [self appendWithColor:STRING_COLOR format:@" "];
                }
                
                if(nextIndex >= maxLength)
                {
                    [self appendWithColor:PLAIN_COLOR format:@"..."];
                    *stop = YES;
                    break;
                }
            }
        }];
        
        [self appendWithColor:STRING_COLOR format:@">\n"];
    }
    else if (![_references containsObject:objv])
    {
        [_references addObject:objv];
        
        /*
         Given we're never going to rely on this output we can test for encodeWithCoder: whether the class
         publicly conforms to NSCoding or not.
        */
        
        if ([objv respondsToSelector:@selector(encodeWithCoder:)])
        {
            [self padBuffer];
            [self appendWithColor:PLAIN_COLOR format:@"<%@: %p> {\n", NSStringFromClass(objv.class), (__bridge void*)objv];
            
            _depth++;
            
            [objv encodeWithCoder:self];
            
            _depth--;
            [self padBuffer];
            [self appendWithColor:PLAIN_COLOR format:@"}\n"];
        }
        else
        {
            [self appendWithColor:PLAIN_COLOR format:@"<%@: %p>\n", NSStringFromClass(objv.class), (__bridge void*)objv];
        }
    }
    else
    {
        [self appendWithColor:PLAIN_COLOR format:@"<%@: %p>\n", NSStringFromClass(objv.class), (__bridge void*)objv];
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
    NSNumber *boxedObject = [NSNumber numberWithInt:intv];
    [self encodeObject:boxedObject forKey:key];
}

- (void)encodeInt32:(int32_t)intv forKey:(NSString *)key
{
    NSNumber *boxedObject = [NSNumber numberWithInt:intv];
    [self encodeObject:boxedObject forKey:key];
}

- (void)encodeInt64:(int64_t)intv forKey:(NSString *)key
{
    NSNumber *boxedObject = [NSNumber numberWithLongLong:intv];
    [self encodeObject:boxedObject forKey:key];
}

- (void)encodeFloat:(float)realv forKey:(NSString *)key
{
    NSNumber *boxedObject = [NSNumber numberWithFloat:realv];
    [self encodeObject:boxedObject forKey:key];
}

- (void)encodeDouble:(double)realv forKey:(NSString *)key
{
    NSNumber *boxedObject = [NSNumber numberWithDouble:realv];
    [self encodeObject:boxedObject forKey:key];
}

- (void)encodeBytes:(nullable const uint8_t *)bytesp length:(NSUInteger)lenv forKey:(NSString *)key;
{
    NSData *boxedObject = [NSData dataWithBytes:bytesp length:lenv];
    [self encodeObject:boxedObject forKey:key];
}

- (id)objectOfObjCType:(const char *)type at:(const void *)addr actualLength:(NSInteger*)actualLength
{
    switch (*type)
    {
            //        case _C_ID:
            //        break;
            //        case _C_CLASS:
            //        break;
            //        case _C_SEL:
            //        break;
            //        case _C_CHR:
            //        break;
            //        case _C_UCHR:
            //        break;
            //        case _C_SHT:
            //        break;
            //        case _C_USHT:
            //        break;
        case _C_INT:
            if (actualLength)
            {
                *actualLength = sizeof(int);
            }
            return [NSNumber numberWithInt:*(int *)addr];
            //        case _C_UINT:
            //        break;
            //        case _C_LNG:
            //        break;
            //        case _C_ULNG:
            //        break;
            //        case _C_LNG_LNG:
            //        break;
            //        case _C_ULNG_LNG:
            //        break;
            //        case _C_FLT:
            //        break;
            //        case _C_DBL:
            //        break;
            //        case _C_BFLD:
            //        break;
            //        case _C_BOOL:
            //        break;
            //        case _C_VOID:
            //        break;
            //        case _C_UNDEF:
            //        break;
            //        case _C_PTR:
            //        break;
            //        case _C_CHARPTR:
            //        break;
            //        case _C_ATOM:
            //        break;
            //        case _C_ARY_B:
            //        break;
            //        case _C_ARY_E:
            //        break;
            //        case _C_UNION_B:
            //        break;
            //        case _C_UNION_E:
            //        break;
            //        case _C_STRUCT_B:
            //        break;
            //        case _C_STRUCT_E:
            //        break;
            //        case _C_VECTOR:
            //        break;
            //        case _C_CONST:
            //        break;
    }
    return @"---";
}

- (void)encodeValueOfObjCType:(const char *)type at:(const void *)addr
{
    id boxedObject = [self objectOfObjCType:type at:addr actualLength:NULL];
    [self encodeObject:boxedObject];
}

- (void)encodeDataObject:(NSData *)data
{
    [self encodeObject:data];
}

- (void)encodeRootObject:(id)rootObject
{
    [self encodeObject:rootObject];
}

- (void)encodeBycopyObject:(nullable id)anObject
{
    [self encodeObject:anObject];
}

- (void)encodeByrefObject:(nullable id)anObject
{
    [self encodeObject:anObject];
}

- (void)encodeConditionalObject:(nullable id)object
{
    [self encodeObject:object];
}

- (void)encodeValuesOfObjCTypes:(const char *)types, ...
{
    
}

- (void)encodeArrayOfObjCType:(const char *)type count:(NSUInteger)count at:(const void *)array
{
    NSMutableArray *boxedArray = [NSMutableArray array];
    NSInteger offset = 0;
    for (NSInteger index=0; index<count; index++)
    {
        NSInteger actualLength = 0;
        id boxedObject = [self objectOfObjCType:type at:(void*)(((char *)array)+offset) actualLength:&actualLength];
        offset += actualLength;
        [boxedArray addObject:boxedObject];
    }
    [self encodeObject:boxedArray];
}

- (void)encodeBytes:(nullable const void *)byteaddr length:(NSUInteger)length
{
    NSData *boxedObject = [NSData dataWithBytes:byteaddr length:length];
    [self encodeObject:boxedObject];
}


@end

//
//  JJRSObjectDescription.m
//
//  Created by John Scott on 29/01/2016.
//
//

#import "JJRSObjectDescription.h"

@interface JJRSObjectDescription ()

@property (nonatomic, readonly) NSString *buffer;

@end

@implementation JJRSObjectDescription
{
    NSMutableString *_buffer;
    NSUInteger _depth;
    NSMutableArray *_references;
    NSDateFormatter *_rfc3339DateFormatter;
}

-(instancetype)init
{
    self = [super init];
    if (self)
    {
        _buffer = [NSMutableString string];
        _references = [NSMutableArray array];
        
        /*
         https://developer.apple.com/library/mac/qa/qa1480/_index.html
         */
        
        _rfc3339DateFormatter = [[NSDateFormatter alloc] init];
        _rfc3339DateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        _rfc3339DateFormatter.dateFormat = @"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'";
        _rfc3339DateFormatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    }
    return self;
}

-(id)buffer
{
    return _buffer;
}

+(NSString*)descriptionForObject:(id)rootObject
{
    @autoreleasepool
    {
        JJRSObjectDescription *archiver = [[JJRSObjectDescription alloc] init];
        [archiver _encodeObject:rootObject];
        return archiver.buffer;
    }
}

-(BOOL)allowsKeyedCoding
{
    return YES;
}

-(void)padBuffer
{
    [_buffer appendString:[@"" stringByPaddingToLength:_depth*4 withString:@"    " startingAtIndex:0]];
}

- (void)encodeObject:(nullable __kindof NSObject<NSCoding>*)objv forKey:(NSString *)key
{
    [self padBuffer];
    if (key)
    {
        [_buffer appendFormat:@"%@ = ", key];
    }

    [self _encodeObject:objv];
}

- (void)_encodeObject:(nullable __kindof NSObject<NSCoding>*)objv
{
    if (!objv)
    {
        [_buffer appendString:@"nil\n"];
    }
    else if ([objv.classForKeyedArchiver isSubclassOfClass:NSDictionary.class])
    {
        NSDictionary *typedObjv = objv;
        
        [_buffer appendString:@"{\n"];
        _depth++;
        [typedObjv enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop)
         {
             [self encodeObject:obj forKey:key];
         }];
        _depth--;
        [self padBuffer];
        [_buffer appendString:@"}\n"];
        
    }
    else if ([objv.classForKeyedArchiver isSubclassOfClass:NSArray.class])
    {
        NSArray *typedObjv = objv;
        [_buffer appendString:@"[\n"];
        _depth++;
        [typedObjv enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop)
         {
             [self padBuffer];
             [self _encodeObject:obj];
         }];
        _depth--;
        [self padBuffer];
        [_buffer appendString:@"]\n"];
    }
    else if (NSString.class == objv.classForKeyedArchiver)
    {
        NSString *typedObjv = objv;
        [_buffer appendFormat:@"\"%@\"\n", typedObjv];
    }
    else if (NSNumber.class == objv.classForKeyedArchiver)
    {
        NSNumber *typedObjv = objv;
        [_buffer appendFormat:@"%@\n", typedObjv];
    }
    else if (NSUUID.class == objv.classForKeyedArchiver)
    {
        NSUUID *typedObjv = objv;
        [self padBuffer];
        [_buffer appendFormat:@"%@\n", typedObjv];
    }
    else if (NSDate.class == objv.classForKeyedArchiver)
    {
        NSDate *typedObjv = objv;
        [self padBuffer];
        [_buffer appendFormat:@"%@\n", typedObjv];
    }
    else if (![_references containsObject:objv])
    {
            [_references addObject:objv];
        
        if ([objv conformsToProtocol:@protocol(NSCoding)])
        {
            [_buffer appendFormat:@"<%@: %p> {\n", NSStringFromClass(objv.class), objv];
            
            _depth++;
            
            NSUInteger bufferLength = _buffer.length;
            
            @try
            {
                [objv encodeWithCoder:self];
            }
            @catch (NSException *exception)
            {
                [_buffer deleteCharactersInRange:NSMakeRange(bufferLength, _buffer.length - bufferLength)];
                
                [self padBuffer];
                [_buffer appendFormat:@"!! Error = %@\n", exception];
                [self padBuffer];
                [_buffer appendFormat:@"!! Description = %@\n", objv.description];
            }
            _depth--;
            [self padBuffer];
            [_buffer appendString:@"}\n"];
        }
        else
        {
            [_buffer appendFormat:@"<%@: %p> %@\n", NSStringFromClass(objv.class), objv, objv.description];
        }
    }
    else
    {
        [_buffer appendFormat:@"<%@: %p>\n", NSStringFromClass(objv.class), objv];
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
        [_buffer appendFormat:@"%@ = ", key];
    }

    [_buffer appendFormat:@"%@\n", boolv ? @"true" : @"false"];
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
        [_buffer appendFormat:@"%@ = ", key];
    }
    [_buffer appendFormat:@"%@\n", [NSData dataWithBytes:bytesp length:lenv]];
}

@end

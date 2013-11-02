@import <Foundation/CPObject.j>
@import "CRSupport.j"

var defaultIdentifierKey = @"id",
    classAttributeNames  = [CPDictionary dictionary];

@implementation CappuccinoResource : CPObject
{
    CPString            identifier      @accessors;
    CappuccinoResource  parentResource  @accessors;
}

#pragma mark -
#pragma mark Class methods

// override this method to use a custom identifier for lookups
+ (CPString)identifierKey
{
    return defaultIdentifierKey;
}

// this provides very, very basic pluralization (adding an 's').
// override this method for more complex inflections
+ (CPURL)resourcePath
{
    return [CPURL URLWithString:[self basePath] + [self railsName] + @"s"];
}

+ (CPString)railsName
{
    return [[self className] railsifiedString];
}

// override to change base url for absolute path
+ (CPString)basePath
{
    return @"/";
}

#pragma mark -
#pragma mark Initialization

- (id)init
{
    if (self = [super init])
    {
        parentResource = nil;
    }
    return self;
}

- (JSObject)attributes
{
    CPLog.warn('This method must be declared in your class to save properly.');
    return {};
}

// switch to this if we can get attribute types
// + (CPDictionary)attributes
// {
//     var array = class_copyIvarList(self),
//         dict  = [[CPDictionary alloc] init];
//
//     for (var i = 0; i < array.length; i++)
//         [dict setObject:array[i].type forKey:array[i].name];
//     return dict;
// }

- (CPArray)attributeNames
{
    if ([classAttributeNames objectForKey:[self className]]) {
        return [classAttributeNames objectForKey:[self className]];
    }

    var attributeNames = [CPArray array],
        klass          = [self class],
        attributes     = class_copyIvarList(klass);

    // Retrieve ivar from parent class if any (except if the parent class is CappuccinoResource)
    while ((klass = class_getSuperclass(klass)) != CappuccinoResource) {
        [attributes addObjectsFromArray:class_copyIvarList(klass)];
    }

    for (var i = 0; i < attributes.length; i++) {
        [attributeNames addObject:attributes[i].name];
    }

    [classAttributeNames setObject:attributeNames forKey:[self className]];

    return attributeNames;
}

- (void)setAttributes:(JSObject)attributes
{
    for (var attribute in attributes) {
        if (attribute == [[self class] identifierKey]) {
            [self setIdentifier:attributes[attribute].toString()];
        } else {
            var attributeName = [attribute cappifiedString];
            if ([[self attributeNames] containsObject:attributeName]) {
                var value = attributes[attribute];
                var numberOfArrayElements = 1;
                var objectArray = nil;

                /*
                 * I would much rather retrieve the ivar class than pattern match the
                 * response from Rails, but objective-j does not support this.
                */
                switch (typeOf(value)) {
                    case "array":
                        numberOfArrayElements = value.length;
                        objectArray = [CPArray array];
                    case "object":
                        if(value)
                        {
                            try
                            {
                                for(var i=0;i<numberOfArrayElements;i++)
                                {
                                    var resource = [self getResourceForCustomAttribute:attributeName];
                                    if(objectArray)
                                        [resource setAttributes:value[i]];
                                    else
                                        [resource setAttributes:value];

                                    if(objectArray)
                                        [objectArray addObject:resource]
                                    else
                                        [self setValue:resource forKey:attributeName];
                                }
                                if(objectArray)
                                {
                                    [self setValue:objectArray forKey:attributeName];
                                }
                            }
                            catch(anException)
                            {
                                CPLog.warn(@"An issue occured while translating a JSON attribute("+attributeName+") to a valid object -- " + anException)
                            }
                            break;
                        }
                        break;

                    case "boolean":
                        if (value) {
                            [self setValue:YES forKey:attributeName];
                        } else {
                            [self setValue:NO forKey:attributeName];
                        }
                        break;
                    case "number":
                        [self setValue:value forKey:attributeName];
                        break;
                    case "string":
                        if (value.match(/^\d{4}-\d{2}-\d{2}$/)) {
                            // its a date
                            [self setValue:[CPDate dateWithDateString:value] forKey:attributeName];
                        } else if (value.match(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\+\d{2}:\d{2}|Z)$/)) {
                            // its a datetime
                            [self setValue:[CPDate dateWithDateTimeString:value] forKey:attributeName];
                        } else {
                            // its a string
                            [self setValue:value forKey:attributeName];
                        }
                        break;
                }
            }
        }
    }
}

+ (id)new
{
    return [self new:nil];
}

+ (id)new:(JSObject)attributes
{
    var resource = [[self alloc] init];

    if (!attributes)
        attributes = {};

    [resource setAttributes:attributes];
    return resource;
}

+ (id)create:(JSObject)attributes
{
    var resource = [self new:attributes];
    if ([resource save]) {
        return resource;
    } else {
        return nil;
    }
}

- (BOOL)save
{
    CPLog.trace([self className] + ".save");

    var request = [self resourceWillSave];

    if (!request) {
        return NO;
    }

    var response = [CPURLConnection sendSynchronousRequest:request];

    if (response[0] >= 400) {
        [self resourceDidNotSave:response[1]];
        return NO;
    } else {
        [self resourceDidSave:response[1]];
        return YES;
    }
}

- (BOOL)destroy
{
    CPLog.trace([self className] + ".destroy");

    var request = [self resourceWillDestroy];

    if (!request) {
        return NO;
    }

    var response = [CPURLConnection sendSynchronousRequest:request];

    if (response[0] == 200) {
        [self resourceDidDestroy];
        return YES;
    } else {
        return NO;
    }
}

+ (CPArray)all
{
    var request = [self collectionWillLoad];

    if (!request) {
        return NO;
    }

    var response = [CPURLConnection sendSynchronousRequest:request];

    if (response[0] >= 400) {
        return nil;
    } else {
        return [self collectionDidLoad:response[1]];
    }
}

+ (CPArray)allWithParams:(JSObject)params
{
    return [self allWithParams:params forParent:nil];
}

+ (CPArray)allWithParams:(JSObject)params forParent:(id)parent
{
    var request = [self collectionWillLoad:params forParent:parent];

    var response = [CPURLConnection sendSynchronousRequest:request];

    if (response[0] >= 400) {
        return nil;
    } else {
        return [self collectionDidLoad:response[1] forParent:parent];
    }
}

+ (id)find:(CPString)identifier
{
    return [self find:identifier forParent:nil];
}

+ (id)find:(CPString)identifier forParent:(id)parent
{
    var request = [self resourceWillLoad:identifier];

    if (!request) {
        return NO;
    }

    var response = [CPURLConnection sendSynchronousRequest:request];

    if (response[0] >= 400) {
        return nil;
    } else {
        return [self resourceDidLoad:response[1] forParent:parent];
    }
}

+ (id)findWithParams:(JSObject)params
{
    var collection = [self allWithParams:params];

    if ([collection count] > 0) {
        return [collection objectAtIndex:0];
    } else {
        return nil;
    }
}

// All the following methods post notifications using their class name
// You can observe these notifications and take further action if desired
+ (CPURLRequest)resourceWillLoad:(CPString)identifier
{
    var path             = [self resourcePath] + "/" + identifier,
        notificationName = [self className] + "ResourceWillLoad";

    if (!path) {
        return nil;
    }

    var request = [CPURLRequest requestJSONWithURL:path];
    [request setHTTPMethod:@"GET"];

    [[CPNotificationCenter defaultCenter] postNotificationName:notificationName object:self];
    return request;
}

+ (id)resourceDidLoad:(CPString)aResponse
{
    return [self resourceDidLoad:aResponse forParent:nil];
}

+ (id)resourceDidLoad:(CPString)aResponse forParent:(id)parent
{
    var response         = [aResponse toJSON],
        attributes       = response[[self railsName]],
        notificationName = [self className] + "ResourceDidLoad",
        resource         = [self new];

    [resource setAttributes:attributes];
    [resource setParentResource:parent];
    [[CPNotificationCenter defaultCenter] postNotificationName:notificationName object:resource];
    return resource;
}

+ (CPURLRequest)collectionWillLoad
{
    return [self collectionWillLoad:nil];
}

+ (CPURLRequest)collectionWillLoad:(id)params
{
    return [self collectionWillLoad:params forParent:nil];
}

// can handle a JSObject or a CPDictionary
+ (CPURLRequest)collectionWillLoad:(id)params forParent:(id)parent
{
    var path,
        notificationName = [self className] + "CollectionWillLoad";

    // Determine if resource path needs to be prefixed by parent
    if (parent) {
        path = [[parent class] resourcePath] + "/" + [parent identifier] + '/' + [self resourcePath];
    } else {
        path = [self resourcePath];
    }

    if (params) {
        if (params.isa && [params isKindOfClass:CPDictionary]) {
            path += ("?" + [CPString paramaterStringFromCPDictionary:params]);
        } else {
            path += ("?" + [CPString paramaterStringFromJSON:params]);
        }
    }

    if (!path) {
        return nil;
    }

    var request = [CPURLRequest requestJSONWithURL:path];
    [request setHTTPMethod:@"GET"];

    [[CPNotificationCenter defaultCenter] postNotificationName:notificationName object:self];

    return request;
}

+ (CPArray)collectionDidLoad:(CPString)aResponse
{
    return [self collectionDidLoad:aResponse forParent:nil]
}

+ (CPArray)collectionDidLoad:(CPString)aResponse forParent:(id)parent
{
    var resourceArray    = [CPArray array],
        notificationName = [self className] + "CollectionDidLoad";

    if ([[aResponse stringByTrimmingWhitespace] length] > 0) {
        var collection = [aResponse toJSON];

        for (var i = 0; i < collection.length; i++) {
            var resource   = collection[i];
            var attributes = resource[[self railsName]];
            var obj = [self new:attributes];
            [obj setParentResource:parent];
            [resourceArray addObject:obj];
        }
    }

    [[CPNotificationCenter defaultCenter] postNotificationName:notificationName object:resourceArray];
    return resourceArray;
}

- (CPURLRequest)resourceWillSave
{
    var abstractNotificationName = [self className] + "ResourceWillSave";

    if (identifier) {
        var path             = [[self class] resourcePath] + "/" + identifier,
            notificationName = [self className] + "ResourceWillUpdate";
    } else {
        var path,
            notificationName = [self className] + "ResourceWillCreate";

        // Determine if resource path needs to be prefixed by parent
        if ([self parentResource]) {
            path = [[[self parentResource] class] resourcePath] + "/" + [[self parentResource] identifier] + '/' + [[self class] resourcePath];
        } else {
            path = [[self class] resourcePath];
        }
    }

    if (!path) {
        return nil;
    }

    var request = [CPURLRequest requestJSONWithURL:path];

    [request setHTTPMethod:identifier ? @"PUT" : @"POST"];
    [request setHTTPBody:[CPString JSONFromObject:[self attributes]]];

    [[CPNotificationCenter defaultCenter] postNotificationName:notificationName object:self];
    [[CPNotificationCenter defaultCenter] postNotificationName:abstractNotificationName object:self];
    return request;
}

- (void)resourceDidSave:(CPString)aResponse
{
    CPLog.trace([self className] + ".resourceDidSave");

    if ([aResponse length] > 1)
    {
        var response    = [aResponse toJSON],
            attributes  = response[[[self class] railsName]];
    }
    var abstractNotificationName = [self className] + "ResourceDidSave";

    if (identifier) {
        var notificationName = [self className] + "ResourceDidUpdate";
    } else {
        var notificationName = [self className] + "ResourceDidCreate";
    }

    [self setAttributes:attributes];
    [[CPNotificationCenter defaultCenter] postNotificationName:notificationName object:self];
    [[CPNotificationCenter defaultCenter] postNotificationName:abstractNotificationName object:self];
}

- (void)resourceDidNotSave:(CPString)aResponse
{
    CPLog.trace([self className] + ".resourceDidNotSave");

    var abstractNotificationName = [self className] + "ResourceDidNotSave";

    if (identifier) {
        var notificationName = [self className] + "ResourceDidNotUpdate";
    } else {
        var notificationName = [self className] + "ResourceDidNotCreate";
    }

    var userInfo = [CPDictionary dictionaryWithJSObject:[aResponse toJSON]];

    [[CPNotificationCenter defaultCenter] postNotificationName:notificationName object:self userInfo:userInfo];
    [[CPNotificationCenter defaultCenter] postNotificationName:abstractNotificationName object:self userInfo:userInfo];
}

- (CPURLRequest)resourceWillDestroy
{
    var path             = [[self class] resourcePath] + "/" + identifier,
        notificationName = [self className] + "ResourceWillDestroy";

    if (!path) {
        return nil;
    }

    var request = [CPURLRequest requestJSONWithURL:path];
    [request setHTTPMethod:@"DELETE"];

    [[CPNotificationCenter defaultCenter] postNotificationName:notificationName object:self];
    return request;
}

-(void)resourceDidDestroy
{
    var notificationName = [self className] + "ResourceDidDestroy";
    [[CPNotificationCenter defaultCenter] postNotificationName:notificationName object:self];
}

- (CPString)description
{
    return [CPString stringWithFormat:"<%s> id:%s", [self className], [self identifier]];
}

-(BOOL)isEqual:(CappuccinoResource)other {
  if ([self class] == [other class] && [self identifier] == [other identifier]) {
    if ([self identifier] == null && [other identifier] == null){
      // Neither object has _not_ been saved (we can tell because the identifiers are null)
      // so use the normal CPObject isEquals
      return([super isEqual:other]);
    } else {
      // This object has been saved, class and the identifiers are equal, so they are equal
      return YES;
    }
  }
  // The class or identifiers don't match
  return NO;
}

-(BOOL)isNewRecord{
  return ([self identifier] == null ? YES : NO)
}

@end

@implementation CappuccinoResource (CPCoding)

- (id)initWithCoder:(CPCoder)coder
{
    CPLog.trace([self className] + " initWithCoder");
    if (self = [super init]) {
        self = [[self class] find:[coder decodeObjectForKey:"identifier"]];
    }
    return self;
}

- (void)encodeWithCoder:(CPCoder)coder
{
    CPLog.trace([self className] + " encodeWithCoder");
    [coder encodeObject:[self identifier] forKey:"identifier"];
}

@end


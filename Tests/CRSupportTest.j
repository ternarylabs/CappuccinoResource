@import "TestHelper.j"

@implementation CRSupportTest : OJTestCase

- (void)testCPStringRailsifiedString
{
    [self assert:@"movies" equals:[[CPString stringWithString:@"Movies"] railsifiedString]];
    [self assert:@"movie_titles" equals:[[CPString stringWithString:@"MovieTitles"] railsifiedString]];
    [self assert:@"happy_birth_day" equals:[[CPString stringWithString:@"HappyBirthDay"] railsifiedString]];
}

- (void)testCPStringCappifiedString
{
    [self assert:@"movies" equals:[[CPString stringWithString:@"Movies"] cappifiedString]];
    [self assert:@"movieTitles" equals:[[CPString stringWithString:@"movie_titles"] cappifiedString]];
    [self assert:@"happyBirthDay" equals:[[CPString stringWithString:@"happy_birth_day"] cappifiedString]];
}

- (void)testCPStringToJSONWithSingleObject
{
    var string1   = '{"user":{"email":"test@test.com","password":"secret"}}',
        expected1 = {"user":{"email":"test@test.com","password":"secret"}},
        actual1   = [string1 toJSON],
        string2   = '{"movie":{"id":42,"title":"Terminator 2"}}',
        expected2 = {"movie":{"id":42,"title":"Terminator 2"}},
        actual2   = [string2 toJSON];

    [self assert:expected1.user.email equals:actual1.user.email];
    [self assert:expected1.user.password equals:actual1.user.password];
    [self assert:expected2.movie.id equals:actual2.movie.id];
    [self assert:expected2.movie.title equals:actual2.movie.title];
}

- (void)testCPStringToJSONWithMultipleObjects
{
    var string   = '[{"user":{"id":1,"email":"one@test.com"}},{"user":{"id":2,"email":"two@test.com"}}]',
        expected = [{"user":{"id":1,"email":"one@test.com"}},{"user":{"id":2,"email":"two@test.com"}}],
        actual   = [string toJSON];

    [self assert:2 equals:[actual count]];
    [self assert:expected[0].user.email equals:actual[0].user.email];
    [self assert:expected[0].user.id equals:actual[0].user.id];
    [self assert:expected[1].user.email equals:actual[1].user.email];
    [self assert:expected[1].user.id equals:actual[1].user.id];
}

- (void)testCPStringParamaterStringFromJSON
{
    var params   = {"name":"joe","age":27,"sex":"yes please"},
        expected = 'name=joe&age=27&sex=yes%20please';
    [self assert:expected equals:[CPString paramaterStringFromJSON:params]];
}

- (void)testCPURLRequestRequestJSONWithURL
{
    var request = [CPURLRequest requestJSONWithURL:@"/"];
    [self assert:@"application/json" equals:[request valueForHTTPHeaderField:@"Accept"]];
    [self assert:@"application/json" equals:[request valueForHTTPHeaderField:@"Content-Type"]];
}

@end
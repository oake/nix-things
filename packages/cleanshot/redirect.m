// libcsredirect — injected into CleanShot X to redirect its hardcoded cloud API
// host (api.cleanshot.cloud) to a configured replacement.
//
// Swizzles NSURLSession's task factories (which Swift's URLSession bridges
// through) to rewrite only the request host, over https — path/query/body/auth
// are untouched, and every other host (e.g. licensing) is left alone.
//
// Replacement host, resolved at startup: $CLEANSHOT_API_HOST, else
// ~/Library/Application Support/CleanShotRedirect/host. Unset ⇒ no redirect.

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static NSString *const kSourceHost = @"api.cleanshot.cloud";
static NSString *targetHost;

static NSString *ConfiguredHost(void) {
    const char *env = getenv("CLEANSHOT_API_HOST");
    if (env && *env) return @(env);
    NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:
        @"Library/Application Support/CleanShotRedirect/host"];
    NSString *s = [[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL]
        stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return s.length ? s : nil;
}

static id RewriteURL(NSURL *url) {
    if (![url.host isEqualToString:kSourceHost]) return url;
    NSURLComponents *c = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    c.scheme = @"https";
    c.host = targetHost;
    c.port = nil;
    return c.URL ?: url;
}

static id RewriteRequest(NSURLRequest *req) {
    NSURL *url = RewriteURL(req.URL);
    if (url == req.URL) return req;
    NSMutableURLRequest *m = [req mutableCopy];
    m.URL = url;
    if ([m valueForHTTPHeaderField:@"Host"]) [m setValue:url.host forHTTPHeaderField:@"Host"];
    return m;
}

// Swizzle a task factory, rewriting its first argument (a request or URL) with
// `rw`; `trailing` is the number of pass-through args after it (0–2).
typedef id (*Rewriter)(id);

static void hook(Class cls, SEL sel, Rewriter rw, int trailing) {
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return;
    IMP orig = method_getImplementation(m);
    id block;
    switch (trailing) {
        case 0:  block = ^(id s, id a)             { return ((id(*)(id, SEL, id))orig)(s, sel, rw(a)); }; break;
        case 1:  block = ^(id s, id a, id b)       { return ((id(*)(id, SEL, id, id))orig)(s, sel, rw(a), b); }; break;
        default: block = ^(id s, id a, id b, id c) { return ((id(*)(id, SEL, id, id, id))orig)(s, sel, rw(a), b, c); }; break;
    }
    method_setImplementation(m, imp_implementationWithBlock(block));
}

__attribute__((constructor))
static void install(void) {
    targetHost = ConfiguredHost();
    if (!targetHost.length) return;

    Class cls = NSURLSession.class;
    Rewriter req = (Rewriter)RewriteRequest, url = (Rewriter)RewriteURL;
    hook(cls, @selector(dataTaskWithRequest:), req, 0);
    hook(cls, @selector(dataTaskWithRequest:completionHandler:), req, 1);
    hook(cls, @selector(uploadTaskWithStreamedRequest:), req, 0);
    hook(cls, @selector(uploadTaskWithRequest:fromData:), req, 1);
    hook(cls, @selector(uploadTaskWithRequest:fromData:completionHandler:), req, 2);
    hook(cls, @selector(uploadTaskWithRequest:fromFile:), req, 1);
    hook(cls, @selector(uploadTaskWithRequest:fromFile:completionHandler:), req, 2);
    hook(cls, @selector(downloadTaskWithRequest:), req, 0);
    hook(cls, @selector(downloadTaskWithRequest:completionHandler:), req, 1);
    hook(cls, @selector(dataTaskWithURL:), url, 0);
    hook(cls, @selector(dataTaskWithURL:completionHandler:), url, 1);
    hook(cls, @selector(downloadTaskWithURL:), url, 0);
    hook(cls, @selector(downloadTaskWithURL:completionHandler:), url, 1);
}

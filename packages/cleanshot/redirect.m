// libcsredirect — injected into CleanShot X to redirect its hardcoded cloud API
// host and cloud dashboard URL to configured replacements.
//
// Swizzles NSURLSession's task factories (which Swift's URLSession bridges
// through) to rewrite only the request host, over https — path/query/body/auth
// are untouched, and every other host (e.g. licensing) is left alone.
//
// API host: $CLEANSHOT_API_HOST, else
// ~/Library/Application Support/CleanShotRedirect/host.
// Dashboard URL: $CLEANSHOT_DASHBOARD_URL, else
// ~/Library/Application Support/CleanShotRedirect/dashboard-url.
// Each redirect is independently optional.

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <objc/runtime.h>

static NSString *const kSourceHost = @"api.cleanshot.cloud";
static NSString *targetHost;
static NSURL *targetDashboardURL;

static NSString *ConfiguredValue(const char *environmentKey, NSString *fileName) {
    const char *env = getenv(environmentKey);
    if (env && *env) return @(env);
    NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:
        [@"Library/Application Support/CleanShotRedirect" stringByAppendingPathComponent:fileName]];
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

static NSURL *RewriteDashboardURL(NSURL *url) {
    if (!targetDashboardURL || ![url.host.lowercaseString isEqualToString:@"cleanshot.com"]) return url;

    NSURLComponents *source = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    NSString *sourcePath = source.percentEncodedPath ?: @"";
    if (![sourcePath isEqualToString:@"/cloud"] && ![sourcePath hasPrefix:@"/cloud/"]) return url;

    NSURLComponents *target = [NSURLComponents componentsWithURL:targetDashboardURL
        resolvingAgainstBaseURL:NO];
    NSString *suffix = [sourcePath substringFromIndex:@"/cloud".length];
    if (suffix.length) {
        NSString *basePath = target.percentEncodedPath ?: @"";
        while ([basePath hasSuffix:@"/"]) basePath = [basePath substringToIndex:basePath.length - 1];
        target.percentEncodedPath = [basePath stringByAppendingString:suffix];
    }
    target.percentEncodedQuery = source.percentEncodedQuery;
    target.percentEncodedFragment = source.percentEncodedFragment;
    return target.URL ?: url;
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

static void hookWorkspaceOpenURL(void) {
    Class cls = NSWorkspace.class;

    SEL legacy = @selector(openURL:);
    Method legacyMethod = class_getInstanceMethod(cls, legacy);
    if (legacyMethod) {
        IMP orig = method_getImplementation(legacyMethod);
        id block = ^BOOL(id workspace, NSURL *url) {
            return ((BOOL(*)(id, SEL, NSURL *))orig)(workspace, legacy, RewriteDashboardURL(url));
        };
        method_setImplementation(legacyMethod, imp_implementationWithBlock(block));
    }

    SEL modern = @selector(openURL:configuration:completionHandler:);
    Method modernMethod = class_getInstanceMethod(cls, modern);
    if (modernMethod) {
        IMP orig = method_getImplementation(modernMethod);
        id block = ^(id workspace, NSURL *url, id configuration, id completionHandler) {
            ((void(*)(id, SEL, NSURL *, id, id))orig)(workspace, modern,
                RewriteDashboardURL(url), configuration, completionHandler);
        };
        method_setImplementation(modernMethod, imp_implementationWithBlock(block));
    }
}

__attribute__((constructor))
static void install(void) {
    targetHost = ConfiguredValue("CLEANSHOT_API_HOST", @"host");
    NSString *dashboard = ConfiguredValue("CLEANSHOT_DASHBOARD_URL", @"dashboard-url");
    if (dashboard.length) targetDashboardURL = [NSURL URLWithString:dashboard];

    if (targetDashboardURL) hookWorkspaceOpenURL();
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

//
//  RCTBackgroundGeolocation.m
//  RCTBackgroundGeolocation
//
//  Created by Marian Hello on 04/06/16.
//  Copyright © 2016 mauron85. All rights reserved.
//

#import "RCTBackgroundGeolocation.h"
#if __has_include("RCTLog.h")
#import "RCTLog.h"
#else
#import <React/RCTLog.h>
#endif
#if __has_include("RCTEventDispatcher.h")
#import "RCTEventDispatcher.h"
#else
#import <React/RCTEventDispatcher.h>
#endif
#import "MAURConfig.h"
#import "MAURBackgroundGeolocationFacade.h"
#import "MAURBackgroundTaskManager.h"
#import <CoreLocation/CoreLocation.h> // (추가) 권한 상태 확인용

#define isNull(value) value == nil || [value isKindOfClass:[NSNull class]]

@implementation RCTBackgroundGeolocation {
    MAURBackgroundGeolocationFacade* facade;

    // (추가) iOS10+ 알림 델리게이트 유지용
    API_AVAILABLE(ios(10.0))
    __weak id<UNUserNotificationCenterDelegate> prevNotificationDelegate;

    // (추가) JS configure에서 넘어온 옵션 저장
    BOOL useSignificantChanges;
}

@synthesize bridge = _bridge;

RCT_EXPORT_MODULE();


-(instancetype)init
{
    self = [super init];
    if (self) {
        facade = [[MAURBackgroundGeolocationFacade alloc] init];
        facade.delegate = self;

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppPause:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppResume:) name:UIApplicationWillEnterForegroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onFinishLaunching:) name:UIApplicationDidFinishLaunchingNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppTerminate:) name:UIApplicationWillTerminateNotification object:nil];

        // HACK: it seems to be too late to register on launch observer so trigger it manually
        [self onFinishLaunching:nil];

        // (추가) 기본값
        useSignificantChanges = NO;
    }

    return self;
}

/**
 * configure plugin
 *
 * JS에서 넘어온 config에 `useSignificantChanges: boolean`을 지원.
 * - 가능하면 facade/Config로 전달(메서드 존재 시)
 */
RCT_EXPORT_METHOD(configure:(NSDictionary*)configDictionary success:(RCTResponseSenderBlock)success failure:(RCTResponseSenderBlock)failure)
{
    RCTLogInfo(@"RCTBackgroundGeolocation #configure");
    MAURConfig* config = [MAURConfig fromDictionary:configDictionary];
    NSError *error = nil;

    // (추가) useSignificantChanges 파싱
    id usc = [configDictionary objectForKey:@"useSignificantChanges"];
    if (!isNull(usc)) {
        useSignificantChanges = [usc boolValue];
    } else {
        useSignificantChanges = NO;
    }

    // (선택) MAURConfig가 속성을 지원한다면 KVC로 주입 (없어도 무시되도록 try/catch)
    @try {
        [config setValue:@(useSignificantChanges) forKey:@"useSignificantChanges"];
    } @catch (NSException *exception) {
        // ignore if key doesn't exist
    }

    if ([facade configure:config error:&error]) {
        // (추가) facade가 해당 API를 제공한다면 런타임 체크 후 전달
        if ([facade respondsToSelector:@selector(setUseSignificantChanges:)]) {
            // id<NSObject>로 캐스팅 후 performSelector는 ARC 경고가 있을 수 있어 pragma로 무시
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [facade performSelector:@selector(setUseSignificantChanges:) withObject:@(useSignificantChanges)];
#pragma clang diagnostic pop
        }
        success(@[[NSNull null]]);
    } else {
        NSDictionary *dict = [self errorToDictionary:MAURBGConfigureError message:@"Configuration error" cause:error];
        failure(@[dict]);
    }
}

RCT_EXPORT_METHOD(start)
{
    RCTLogInfo(@"RCTBackgroundGeolocation #start");

    // (추가) iOS 권한 승격이 필요한 경우 보조 호출 (facade가 구현했다면)
    if ([facade respondsToSelector:@selector(ensureAlwaysAuthorization)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [facade performSelector:@selector(ensureAlwaysAuthorization)];
#pragma clang diagnostic pop
    } else {
        // 최소한 권한 상태 로그 (디버깅 도움)
        CLAuthorizationStatus st = [CLLocationManager authorizationStatus];
        RCTLogInfo(@"RCTBackgroundGeolocation auth status (pre-start): %ld", (long)st);
    }

    // (추가) 시작 전에 significant-changes 모드 전달(가능하면)
    if ([facade respondsToSelector:@selector(setUseSignificantChanges:)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [facade performSelector:@selector(setUseSignificantChanges:) withObject:@(useSignificantChanges)];
#pragma clang diagnostic pop
    }

    NSError *error = nil;
    [facade start:&error];

    if (error == nil) {
        [self sendEvent:@"start"];
    } else {
        [self sendError:error];
    }
}

RCT_EXPORT_METHOD(stop)
{
    RCTLogInfo(@"RCTBackgroundGeolocation #stop");
    NSError *error = nil;
    [facade stop:&error];

    if (error == nil) {
        [self sendEvent:@"stop"];
    } else {
        [self sendError:error];
    }
}

RCT_EXPORT_METHOD(switchMode:(NSNumber*)mode success:(RCTResponseSenderBlock)success failure:(RCTResponseSenderBlock)failure)
{
    RCTLogInfo(@"RCTBackgroundGeolocation #switchMode");
    [facade switchMode:[mode integerValue]];
}

RCT_EXPORT_METHOD(isLocationEnabled:(RCTResponseSenderBlock)success failure:(RCTResponseSenderBlock)failure)
{
    RCTLogInfo(@"RCTBackgroundGeolocation #isLocationEnabled");
    success(@[@([facade locationServicesEnabled])]);
}

RCT_EXPORT_METHOD(showAppSettings)
{
    RCTLogInfo(@"RCTBackgroundGeolocation #showAppSettings");
    [facade showAppSettings];
}

RCT_EXPORT_METHOD(showLocationSettings)
{
    RCTLogInfo(@"RCTBackgroundGeolocation #showLocationSettings");
    [facade showLocationSettings];
}

RCT_EXPORT_METHOD(getLocations:(RCTResponseSenderBlock)success failure:(RCTResponseSenderBlock)failure)
{
    RCTLogInfo(@"RCTBackgroundGeolocation #getLocations");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *locations = [facade getLocations];
        NSMutableArray* dictionaryLocations = [[NSMutableArray alloc] initWithCapacity:[locations count]];
        for (MAURLocation* location in locations) {
            [dictionaryLocations addObject:[location toDictionaryWithId]];
        }
        success(@[dictionaryLocations]);
    });
}

RCT_EXPORT_METHOD(getValidLocations:(RCTResponseSenderBlock)success failure:(RCTResponseSenderBlock)failure)
{
    RCTLogInfo(@"RCTBackgroundGeolocation #getValidLocations");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *locations = [facade getValidLocations];
        NSMutableArray* dictionaryLocations = [[NSMutableArray alloc] initWithCapacity:[locations count]];
        for (MAURLocation* location in locations) {
            [dictionaryLocations addObject:[location toDictionaryWithId]];
        }
        success(@[dictionaryLocations]);
    });
}

RCT_EXPORT_METHOD(deleteLocation:(int)locationId success:(RCTResponseSenderBlock)success failure:(RCTResponseSenderBlock)failure)
{
    RCTLogInfo(@"RCTBackgroundGeolocation #deleteLocation");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        BOOL result = [facade deleteLocation:[NSNumber numberWithInt:locationId] error:&error];
        if (result) {
            success(@[[NSNull null]]);
        } else {
            NSDictionary *dict = [self errorToDictionary:MAURBGServiceError message:@"Failed to delete location" cause:error];
            failure(@[dict]);
        }
    });
}

RCT_EXPORT_METHOD(deleteAllLocations:(RCTResponseSenderBlock)success failure:(RCTResponseSenderBlock)failure)
{
    RCTLogInfo(@"RCTBackgroundGeolocation #deleteAllLocations");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        BOOL result = [facade deleteAllLocations:&error];
        if (result) {
            success(@[[NSNull null]]);
        } else {
            NSDictionary *dict = [self errorToDictionary:MAURBGServiceError message:@"Failed to delete locations" cause:error];
            failure(@[dict]);
        }
    });
}

RCT_EXPORT_METHOD(getCurrentLocation:(NSDictionary*)options success:(RCTResponseSenderBlock)success failure:(RCTResponseSenderBlock)failure)
{
    RCTLogInfo(@"RCTBackgroundGeolocation #getCurrentLocation");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        NSNumber *timeout = [options objectForKey:@"timeout"] ?: [NSNumber numberWithInt:INT_MAX];
        NSNumber *maximumAge = [options objectForKey:@"maximumAge"] ?: [NSNumber numberWithLong:LONG_MAX];
        NSNumber *enableHighAccuracy = [options objectForKey:@"enableHighAccuracy"] ?: [NSNumber numberWithBool:NO];

        MAURLocation *location = [facade getCurrentLocation:timeout.intValue maximumAge:maximumAge.longValue enableHighAccuracy:enableHighAccuracy.boolValue error:&error];
        if (location != nil) {
            success(@[[location toDictionary]]);
        } else {
            NSDictionary *dict = [self errorToDictionary:error];
            failure(@[dict]);
        }
    });
}

RCT_EXPORT_METHOD(getStationaryLocation:(RCTResponseSenderBlock)success failure:(RCTResponseSenderBlock)failure)
{
    RCTLogInfo(@"RCTBackgroundGeolocation #getStationaryLocation");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        MAURLocation *stationaryLocation = [facade getStationaryLocation];
        if (stationaryLocation) {
            success(@[[stationaryLocation toDictionary]]);
        } else {
            success(@[@(NO)]);
        }
    });
}

RCT_EXPORT_METHOD(getLogEntries:(int)limit fromLogEntryId:(int)logEntry minLogLevel:(NSString*)minLogLevel success:(RCTResponseSenderBlock)success failure:(RCTResponseSenderBlock)failure)
{
    RCTLogInfo(@"RCTBackgroundGeolocation #getLogEntries");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *logs = [facade getLogEntries:limit fromLogEntryId:logEntry minLogLevelFromString:minLogLevel];
        success(@[logs]);
    });
}

RCT_EXPORT_METHOD(getConfig:(RCTResponseSenderBlock)success failure:(RCTResponseSenderBlock)failure)
{
    RCTLogInfo(@"RCTBackgroundGeolocation #getConfig");
    MAURConfig *config = [facade getConfig];
    if (config == nil) {
        config = [[MAURConfig alloc] init]; // default config
    }

    // (추가) 런타임에 facade/Config가 flag를 유지하지 않는 경우를 대비해 반영
    NSMutableDictionary *dict = [[config toDictionary] mutableCopy];
    if (dict == nil) { dict = [NSMutableDictionary new]; }
    [dict setObject:@(useSignificantChanges) forKey:@"useSignificantChanges"];

    success(@[dict]);
}

RCT_EXPORT_METHOD(checkStatus:(RCTResponseSenderBlock)success failure:(RCTResponseSenderBlock)failure)
{
    RCTLogInfo(@"RCTBackgroundGeolocation #checkStatus");
    BOOL isRunning = [facade isStarted];
    BOOL locationServicesEnabled = [facade locationServicesEnabled];
    NSInteger authorizationStatus = [facade authorizationStatus];

    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:3];
    [dict setObject:[NSNumber numberWithBool:isRunning] forKey:@"isRunning"];
    [dict setObject:[NSNumber numberWithBool:locationServicesEnabled] forKey:@"hasPermissions"]; // @deprecated
    [dict setObject:[NSNumber numberWithBool:locationServicesEnabled] forKey:@"locationServicesEnabled"];
    [dict setObject:[NSNumber numberWithInteger:authorizationStatus] forKey:@"authorization"];
    // (추가) 현재 설정된 significant-change 노출
    [dict setObject:@(useSignificantChanges) forKey:@"useSignificantChanges"];

    success(@[dict]);
}

RCT_EXPORT_METHOD(startTask:(RCTResponseSenderBlock)callback)
{
    NSUInteger taskKey = [[MAURBackgroundTaskManager sharedTasks] beginTask];
    callback(@[[NSNumber numberWithInteger:taskKey]]);
}

RCT_EXPORT_METHOD(endTask:(NSNumber* _Nonnull)taskKey)
{
    [[MAURBackgroundTaskManager sharedTasks] endTaskWithKey:[taskKey integerValue]];
}

RCT_EXPORT_METHOD(forceSync:(RCTResponseSenderBlock)success failure:(RCTResponseSenderBlock)failure)
{
    [facade forceSync];
}

-(void) sendEvent:(NSString*)name
{
    NSString *event = [NSString stringWithFormat:@"%@", name];
    [_bridge.eventDispatcher sendDeviceEventWithName:event body:[NSNull null]];
}

-(void) sendEvent:(NSString*)name resultAsDictionary:(NSDictionary*)resultAsDictionary
{
    NSString *event = [NSString stringWithFormat:@"%@", name];
    [_bridge.eventDispatcher sendDeviceEventWithName:event body:resultAsDictionary];
}

-(void) sendEvent:(NSString*)name resultAsArray:(NSArray*)resultAsArray
{
    NSString *event = [NSString stringWithFormat:@"%@", name];
    [_bridge.eventDispatcher sendDeviceEventWithName:event body:resultAsArray];
}

-(void) sendEvent:(NSString*)name resultAsNumber:(NSNumber*)resultAsNumber
{
    NSString *event = [NSString stringWithFormat:@"%@", name];
    [_bridge.eventDispatcher sendDeviceEventWithName:event body:resultAsNumber];
}

- (NSDictionary*) errorToDictionary:(NSInteger)code message:(NSString*)message cause:(NSError*)error
{
    NSDictionary *userInfo = [error userInfo];
    NSString *errorMessage = [error localizedDescription];
    if (errorMessage == nil) {
        errorMessage = [[userInfo objectForKey:NSUnderlyingErrorKey] localizedDescription];
    }
    return @{ @"code": [NSNumber numberWithInteger:code], @"message":message, @"cause":errorMessage};
}

- (NSDictionary*) errorToDictionary:(NSError*)error
{
    NSDictionary *userInfo = [error userInfo];
    NSString *errorMessage = [error localizedDescription];
    if (errorMessage == nil) {
        errorMessage = [[userInfo objectForKey:NSUnderlyingErrorKey] localizedDescription];
    }
    return @{ @"code": [NSNumber numberWithInteger:error.code], @"message":errorMessage};
}

-(void) sendError:(NSError*)error
{
    [self sendEvent:@"error" resultAsDictionary:[self errorToDictionary:error]];
}

- (NSString *)loggerDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : NSTemporaryDirectory();

    return [basePath stringByAppendingPathComponent:@"SQLiteLogger"];
}

- (void) onAuthorizationChanged:(MAURLocationAuthorizationStatus)authStatus
{
    RCTLogInfo(@"RCTBackgroundGeolocation onAuthorizationChanged");
    [self sendEvent:@"authorization" resultAsNumber:[NSNumber numberWithInteger:authStatus]];
}

- (void) onLocationChanged:(MAURLocation*)location
{
    RCTLogInfo(@"RCTBackgroundGeolocation onLocationChanged");
    [self sendEvent:@"location" resultAsDictionary:[location toDictionaryWithId]];
}

- (void) onStationaryChanged:(MAURLocation*)location
{
    RCTLogInfo(@"RCTBackgroundGeolocation onStationaryChanged");
    [self sendEvent:@"stationary" resultAsDictionary:[location toDictionaryWithId]];
}

- (void) onError:(NSError*)error
{
    RCTLogInfo(@"RCTBackgroundGeolocation onError");
    [self sendError:error];
}

- (void) onLocationPause
{
    RCTLogInfo(@"RCTBackgroundGeoLocation location updates paused");
    [self sendEvent:@"stop"];
}

- (void) onLocationResume
{
    RCTLogInfo(@"RCTBackgroundGeoLocation location updates resumed");
    [self sendEvent:@"start"];
}

- (void) onActivityChanged:(MAURActivity *)activity
{
    RCTLogInfo(@"RCTBackgroundGeoLocation activity changed");
    [self sendEvent:@"activity" resultAsDictionary:[activity toDictionary]];
}

- (void) onAppResume:(NSNotification *)notification
{
    RCTLogInfo(@"RCTBackgroundGeoLocation resumed");
    [facade switchMode:MAURForegroundMode];
    [self sendEvent:@"foreground"];
}

- (void) onAppPause:(NSNotification *)notification
{
    RCTLogInfo(@"RCTBackgroundGeoLocation paused");
    [facade switchMode:MAURBackgroundMode];
    [self sendEvent:@"background"];
}

- (void) onAbortRequested
{
    RCTLogInfo(@"RCTBackgroundGeoLocation abort requested by the server");

    if (_bridge)
    {
        [self sendEvent:@"abort_requested"];
    }
    else
    {
        [facade stop:nil];
    }
}

- (void) onHttpAuthorization
{
    RCTLogInfo(@"RCTBackgroundGeoLocation http authorization");

    if (_bridge)
    {
        [self sendEvent:@"http_authorization"];
    }
}

/**@
 * on UIApplicationDidFinishLaunchingNotification
 */
-(void) onFinishLaunching:(NSNotification *)notification
{
    NSDictionary *dict = [notification userInfo];

    MAURConfig *config = [facade getConfig];
    if (config.isDebugging)
    {
        if (@available(iOS 10, *))
        {
            UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
            prevNotificationDelegate = center.delegate;
            center.delegate = self;
        }
    }

    if ([dict objectForKey:UIApplicationLaunchOptionsLocationKey]) {
        RCTLogInfo(@"RCTBackgroundGeolocation started by system on location event.");
        if (![config stopOnTerminate]) {
            // (추가) 부팅/시스템 재기동으로 깨어났을 때도 flag 반영 시도
            if ([facade respondsToSelector:@selector(setUseSignificantChanges:)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                [facade performSelector:@selector(setUseSignificantChanges:) withObject:@(useSignificantChanges)];
#pragma clang diagnostic pop
            }
            [facade start:nil];
            [facade switchMode:MAURBackgroundMode];
        }
    }
}

-(void) userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler
{
    if (prevNotificationDelegate && [prevNotificationDelegate respondsToSelector:@selector(userNotificationCenter:willPresentNotification:withCompletionHandler:)])
    {
        // Give other delegates (like FCM) the chance to process this notification

        [prevNotificationDelegate userNotificationCenter:center willPresentNotification:notification withCompletionHandler:^(UNNotificationPresentationOptions options) {
            completionHandler(UNNotificationPresentationOptionAlert);
        }];
    }
    else
    {
        completionHandler(UNNotificationPresentationOptionAlert);
    }
}

-(void) onAppTerminate:(NSNotification *)notification
{
    RCTLogInfo(@"RCTBackgroundGeoLocation appTerminate");
    [facade onAppTerminate];
}

+(BOOL)requiresMainQueueSetup {
    return NO;
}

@end

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FFmpegWrapper : NSObject

+ (NSString *)versionInfo;
+ (void)setLogLevel:(int32_t)level;
+ (void)setLogCallback:(void (^)(int32_t level, NSString *message))block;
+ (void)clearLogCallback;

+ (int32_t)executeWithArgs:(NSArray<NSString *> *)args
                  logLevel:(int32_t)logLevel
              shouldCancel:(BOOL (^)(void))shouldCancel
                onProgress:(void (^)(int64_t time, double bitrate, double speed, int frame, double fps, int64_t size))onProgress;

@end

NS_ASSUME_NONNULL_END

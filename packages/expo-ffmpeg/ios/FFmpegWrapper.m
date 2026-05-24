#import "FFmpegWrapper.h"
#import "FFmpeg.h"

static void (^_logBlock)(int32_t level, NSString *message) = nil;

static void ffmpeg_log_callback(void *ptr, int level, const char *fmt, va_list vl) {
    if (!_logBlock) return;
    char message[1024];
    vsnprintf(message, sizeof(message), fmt, vl);
    NSString *msg = [NSString stringWithUTF8String:message];
    if (msg) {
        _logBlock(level, msg);
    }
}

@implementation FFmpegWrapper

+ (NSString *)versionInfo {
    const char *version = av_version_info();
    return [NSString stringWithUTF8String:version];
}

+ (void)setLogLevel:(int32_t)level {
    av_log_set_level(level);
}

+ (void)setLogCallback:(void (^)(int32_t level, NSString *message))block {
    _logBlock = [block copy];
    av_log_set_callback(ffmpeg_log_callback);
}

+ (void)clearLogCallback {
    _logBlock = nil;
    av_log_set_callback(NULL);
}

+ (int32_t)executeWithArgs:(NSArray<NSString *> *)args
                  logLevel:(int32_t)logLevel
              shouldCancel:(BOOL (^)(void))shouldCancel
                onProgress:(void (^)(int64_t time, double bitrate, double speed, int frame, double fps, int64_t size))onProgress {
    av_log_set_level(logLevel);

    // Parse arguments
    NSString *inputFile = nil;
    NSString *outputFile = nil;

    for (NSUInteger i = 0; i < args.count; i++) {
        if ([args[i] isEqualToString:@"-i"] && i + 1 < args.count) {
            i++;
            inputFile = args[i];
        } else if (![args[i] hasPrefix:@"-"] && i == args.count - 1) {
            outputFile = args[i];
        }
    }

    if (!inputFile || !outputFile) {
        av_log(NULL, AV_LOG_ERROR, "Missing input or output file\n");
        return 1;
    }

    // Open input
    AVFormatContext *inputCtx = NULL;
    int ret = avformat_open_input(&inputCtx, [inputFile UTF8String], NULL, NULL);
    if (ret < 0) {
        av_log(NULL, AV_LOG_ERROR, "Could not open input file\n");
        return ret;
    }

    ret = avformat_find_stream_info(inputCtx, NULL);
    if (ret < 0) {
        av_log(NULL, AV_LOG_ERROR, "Could not find stream info\n");
        avformat_close_input(&inputCtx);
        return ret;
    }

    // Create output context
    AVFormatContext *outputCtx = NULL;
    ret = avformat_alloc_output_context2(&outputCtx, NULL, NULL, [outputFile UTF8String]);
    if (ret < 0 || !outputCtx) {
        av_log(NULL, AV_LOG_ERROR, "Could not create output context\n");
        avformat_close_input(&inputCtx);
        return ret;
    }

    // Copy streams
    for (unsigned int i = 0; i < inputCtx->nb_streams; i++) {
        AVStream *inStream = inputCtx->streams[i];
        AVStream *outStream = avformat_new_stream(outputCtx, NULL);
        if (!outStream) {
            av_log(NULL, AV_LOG_ERROR, "Could not create output stream\n");
            avformat_close_input(&inputCtx);
            avformat_free_context(outputCtx);
            return AVERROR(ENOMEM);
        }
        ret = avcodec_parameters_copy(outStream->codecpar, inStream->codecpar);
        if (ret < 0) {
            av_log(NULL, AV_LOG_ERROR, "Could not copy codec parameters\n");
            avformat_close_input(&inputCtx);
            avformat_free_context(outputCtx);
            return ret;
        }
        outStream->codecpar->codec_tag = 0;
    }

    // Open output file
    if (!(outputCtx->oformat->flags & AVFMT_NOFILE)) {
        ret = avio_open(&outputCtx->pb, [outputFile UTF8String], AVIO_FLAG_WRITE);
        if (ret < 0) {
            av_log(NULL, AV_LOG_ERROR, "Could not open output file\n");
            avformat_close_input(&inputCtx);
            avformat_free_context(outputCtx);
            return ret;
        }
    }

    // Write header
    ret = avformat_write_header(outputCtx, NULL);
    if (ret < 0) {
        av_log(NULL, AV_LOG_ERROR, "Could not write header\n");
        avformat_close_input(&inputCtx);
        if (!(outputCtx->oformat->flags & AVFMT_NOFILE))
            avio_closep(&outputCtx->pb);
        avformat_free_context(outputCtx);
        return ret;
    }

    // Copy packets
    AVPacket *packet = av_packet_alloc();
    int64_t totalSize = 0;
    int frameCount = 0;

    while (av_read_frame(inputCtx, packet) >= 0) {
        if (shouldCancel()) {
            av_packet_free(&packet);
            av_write_trailer(outputCtx);
            avformat_close_input(&inputCtx);
            if (!(outputCtx->oformat->flags & AVFMT_NOFILE))
                avio_closep(&outputCtx->pb);
            avformat_free_context(outputCtx);
            return 255;
        }

        AVStream *inStream = inputCtx->streams[packet->stream_index];
        AVStream *outStream = outputCtx->streams[packet->stream_index];

        // Rescale timestamps
        packet->pts = av_rescale_q_rnd(packet->pts, inStream->time_base, outStream->time_base,
                                        AV_ROUND_NEAR_INF | AV_ROUND_PASS_MINMAX);
        packet->dts = av_rescale_q_rnd(packet->dts, inStream->time_base, outStream->time_base,
                                        AV_ROUND_NEAR_INF | AV_ROUND_PASS_MINMAX);
        packet->duration = av_rescale_q(packet->duration, inStream->time_base, outStream->time_base);
        packet->pos = -1;

        totalSize += packet->size;
        frameCount++;

        ret = av_interleaved_write_frame(outputCtx, packet);
        if (ret < 0) {
            av_log(NULL, AV_LOG_ERROR, "Error writing packet\n");
            break;
        }

        // Report progress periodically
        if (frameCount % 30 == 0 && onProgress) {
            int64_t timeMs = 0;
            if (outStream->time_base.den > 0) {
                timeMs = av_rescale_q(packet->pts, outStream->time_base, (AVRational){1, 1000});
            }
            onProgress(timeMs, 0.0, 0.0, frameCount, 0.0, totalSize);
        }

        av_packet_unref(packet);
    }

    av_packet_free(&packet);
    av_write_trailer(outputCtx);
    avformat_close_input(&inputCtx);
    if (!(outputCtx->oformat->flags & AVFMT_NOFILE))
        avio_closep(&outputCtx->pb);
    avformat_free_context(outputCtx);

    return 0;
}

@end

import { ConfigPlugin, createRunOncePlugin } from '@expo/config-plugins';
import { withFFmpegAndroid } from './withFFmpegAndroid';
import { withFFmpegIOS } from './withFFmpegIOS';

const pkg = require('../../package.json');

export interface FFmpegPluginProps {
  /**
   * Include x86_64 ABI for Android emulators (increases APK size)
   * @default false
   */
  includeX86?: boolean;

  /**
   * Custom URL for downloading prebuilt binaries
   * Use this if you're self-hosting the FFmpeg binaries
   */
  binaryUrl?: string;

  /**
   * Android-specific NDK version
   * @default "27.1.12297006"
   */
  ndkVersion?: string;
}

const withFFmpeg: ConfigPlugin<FFmpegPluginProps | void> = (config, props = {}) => {
  const {
    includeX86 = false,
    binaryUrl,
    ndkVersion = '27.1.12297006',
  } = props || {};

  // Apply Android modifications
  config = withFFmpegAndroid(config, { includeX86, ndkVersion });

  // Apply iOS modifications
  config = withFFmpegIOS(config, { binaryUrl });

  return config;
};

export default createRunOncePlugin(withFFmpeg, pkg.name, pkg.version);

export { withFFmpegAndroid } from './withFFmpegAndroid';
export { withFFmpegIOS } from './withFFmpegIOS';

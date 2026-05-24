import { ConfigPlugin, withXcodeProject, withPodfileProperties } from '@expo/config-plugins';

interface IOSPluginProps {
  binaryUrl?: string;
}

/**
 * Modifies iOS Xcode project and Podfile for FFmpeg integration
 */
export const withFFmpegIOS: ConfigPlugin<IOSPluginProps> = (
  config,
  { binaryUrl }
) => {
  // Configure Podfile properties if needed
  config = withPodfileProperties(config, (config) => {
    // Can be used to pass configuration to the podspec
    if (binaryUrl) {
      config.modResults['EXPO_FFMPEG_BINARY_URL'] = binaryUrl;
    }
    return config;
  });

  // Modify Xcode project settings
  config = withXcodeProject(config, (config) => {
    const xcodeProject = config.modResults;

    const buildSettings = xcodeProject.pbxXCBuildConfigurationSection();

    for (const key in buildSettings) {
      const setting = buildSettings[key];

      if (typeof setting !== 'object' || !setting.buildSettings) {
        continue;
      }

      setting.buildSettings.ENABLE_BITCODE = 'NO';
    }

    return config;
  });

  return config;
};

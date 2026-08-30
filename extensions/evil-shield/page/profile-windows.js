globalThis.__EVIL_SHIELD_CFG__ = {
  salt: '',
  features: globalThis.__EVIL_SHIELD_FEATURES__ || {
    platform: true, hardware: true, locale: true, screen: true,
    canvas: true, webgl: true, audio: true, webrtc: true, devices: true, plugins: true
  },
  profile: {
    userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36',
    platform: 'Win32',
    oscpu: undefined,
    uaData: {
      platform: 'Windows',
      platformVersion: '15.0.0',
      architecture: 'x86',
      bitness: '64',
      fullVersion: '141.0.0.0',
      brands: [
        { brand: 'Chromium', version: '141' },
        { brand: 'Google Chrome', version: '141' },
        { brand: 'Not?A_Brand', version: '24' }
      ]
    },
    hardwareConcurrency: 8,
    deviceMemory: 8,
    maxTouchPoints: 0,
    languages: ['en-US', 'en'],
    timezone: 'UTC',
    timezoneOffset: 0,
    screenWidth: 1920,
    screenHeight: 1080,
    devicePixelRatio: 1,
    webglVendor: 'Google Inc. (Intel)',
    webglRenderer: 'ANGLE (Intel, Intel(R) UHD Graphics Direct3D11 vs_5_0 ps_5_0, D3D11)'
  }
};

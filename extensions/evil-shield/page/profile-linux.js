globalThis.__EVIL_SHIELD_CFG__ = {
  salt: '',
  features: globalThis.__EVIL_SHIELD_FEATURES__ || {
    platform: true, hardware: true, locale: true, screen: true,
    canvas: true, webgl: true, audio: true, webrtc: true, devices: true, plugins: true
  },
  profile: {
    userAgent: 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36',
    platform: 'Linux x86_64',
    oscpu: 'Linux x86_64',
    uaData: {
      platform: 'Linux',
      platformVersion: '6.6.0',
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
    webglVendor: 'Mesa',
    webglRenderer: 'llvmpipe (LLVM 17.0.6, 256 bits)'
  }
};

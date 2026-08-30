globalThis.__EVIL_SHIELD_CFG__ = {
  salt: '',
  features: Object.assign({
    platform: false, hardware: true, locale: false, screen: true,
    canvas: true, webgl: true, audio: true, webrtc: true, devices: true, plugins: true
  }, globalThis.__EVIL_SHIELD_FEATURES__ || {}),
  profile: {
    hardwareConcurrency: 8,
    deviceMemory: 8,
    maxTouchPoints: 0
  }
};

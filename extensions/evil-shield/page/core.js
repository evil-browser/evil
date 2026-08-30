(() => {
  const cfg = globalThis.__EVIL_SHIELD_CFG__;
  if (!cfg || globalThis.__EVIL_SHIELD_ON__) return;
  globalThis.__EVIL_SHIELD_ON__ = true;

  const nativeError = Error;
  const define = (target, prop, value) => {
    try {
      Object.defineProperty(target, prop, {
        get: () => value,
        configurable: true,
        enumerable: true
      });
    } catch (e) {}
  };

  const proxyFn = (target, prop, handler) => {
    try {
      const original = target[prop];
      if (typeof original !== 'function') return;
      const wrapped = new Proxy(original, { apply: handler });
      Object.defineProperty(target, prop, {
        value: wrapped,
        writable: true,
        configurable: true
      });
    } catch (e) {}
  };

  const hash = (str) => {
    let h1 = 0xdeadbeef, h2 = 0x41c6ce57;
    for (let i = 0; i < str.length; i++) {
      const ch = str.charCodeAt(i);
      h1 = Math.imul(h1 ^ ch, 2654435761);
      h2 = Math.imul(h2 ^ ch, 1597334677);
    }
    h1 = Math.imul(h1 ^ (h1 >>> 16), 2246822507) ^ Math.imul(h2 ^ (h2 >>> 13), 3266489909);
    h2 = Math.imul(h2 ^ (h2 >>> 16), 2246822507) ^ Math.imul(h1 ^ (h1 >>> 13), 3266489909);
    return 4294967296 * (2097151 & h2) + (h1 >>> 0);
  };

  const rng = (seed) => {
    let a = seed >>> 0;
    return () => {
      a |= 0;
      a = (a + 0x6d2b79f5) | 0;
      let t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  };

  let origin = 'null';
  try { origin = location.origin || location.href; } catch (e) {}
  const seed = hash(origin + '|' + (cfg.salt || ''));
  const rand = rng(seed);
  const noiseTable = new Array(64);
  for (let i = 0; i < 64; i++) noiseTable[i] = rand();
  let noiseIndex = 0;
  const nextNoise = () => noiseTable[noiseIndex++ & 63];

  const p = cfg.profile || {};

  if (cfg.features.platform) {
    if (p.userAgent) {
      define(navigator, 'userAgent', p.userAgent);
      define(navigator, 'appVersion', p.userAgent.replace(/^Mozilla\//, ''));
    }
    if (p.platform) define(navigator, 'platform', p.platform);
    if (p.oscpu !== undefined) define(navigator, 'oscpu', p.oscpu);
    define(navigator, 'vendor', 'Google Inc.');
    define(navigator, 'vendorSub', '');
    define(navigator, 'productSub', '20030107');

    if (navigator.userAgentData && p.uaData) {
      const brands = p.uaData.brands || [];
      const high = {
        architecture: p.uaData.architecture || 'x86',
        bitness: p.uaData.bitness || '64',
        model: '',
        platform: p.uaData.platform || 'Linux',
        platformVersion: p.uaData.platformVersion || '6.6.0',
        uaFullVersion: p.uaData.fullVersion || '141.0.0.0',
        fullVersionList: p.uaData.fullVersionList || brands,
        wow64: false,
        mobile: false,
        brands
      };
      const fake = {
        brands,
        mobile: false,
        platform: p.uaData.platform || 'Linux',
        toJSON: () => ({ brands, mobile: false, platform: p.uaData.platform || 'Linux' }),
        getHighEntropyValues: (hints) => {
          const out = { brands, mobile: false, platform: high.platform };
          (hints || []).forEach((h) => { if (h in high) out[h] = high[h]; });
          return Promise.resolve(out);
        }
      };
      define(navigator, 'userAgentData', fake);
    }
  }

  if (cfg.features.hardware) {
    const cores = p.hardwareConcurrency || 8;
    const mem = p.deviceMemory || 8;
    define(navigator, 'hardwareConcurrency', cores);
    define(navigator, 'deviceMemory', mem);
    define(navigator, 'maxTouchPoints', p.maxTouchPoints || 0);
  }

  if (cfg.features.locale) {
    const langs = p.languages || ['en-US', 'en'];
    define(navigator, 'language', langs[0]);
    define(navigator, 'languages', Object.freeze(langs.slice()));
    if (p.timezone) {
      const tz = p.timezone;
      proxyFn(Intl.DateTimeFormat.prototype, 'resolvedOptions', (target, self, args) => {
        const out = Reflect.apply(target, self, args);
        out.timeZone = tz;
        return out;
      });
      const offsetMinutes = p.timezoneOffset === undefined ? 0 : p.timezoneOffset;
      proxyFn(Date.prototype, 'getTimezoneOffset', () => offsetMinutes);
    }
  }

  if (cfg.features.screen) {
    const bucket = (n) => {
      const steps = [720, 768, 800, 900, 1024, 1080, 1200, 1440, 1600, 1800, 2160];
      let best = steps[0];
      for (const s of steps) if (Math.abs(s - n) < Math.abs(best - n)) best = s;
      return best;
    };
    const w = p.screenWidth || bucket(screen.width);
    const h = p.screenHeight || bucket(screen.height);
    define(screen, 'width', w);
    define(screen, 'height', h);
    define(screen, 'availWidth', w);
    define(screen, 'availHeight', h - 40);
    define(screen, 'colorDepth', 24);
    define(screen, 'pixelDepth', 24);
    define(window, 'devicePixelRatio', p.devicePixelRatio || 1);
  }

  if (cfg.features.canvas) {
    const perturb = (data) => {
      const len = data.length;
      const step = Math.max(4, (len / 512) | 0) & ~3;
      for (let i = 0; i < len; i += step) {
        const n = nextNoise();
        const delta = n < 0.5 ? -1 : 1;
        data[i] = Math.max(0, Math.min(255, data[i] + delta));
        data[i + 1] = Math.max(0, Math.min(255, data[i + 1] + delta));
        data[i + 2] = Math.max(0, Math.min(255, data[i + 2] + delta));
      }
      return data;
    };

    proxyFn(CanvasRenderingContext2D.prototype, 'getImageData', (target, self, args) => {
      const result = Reflect.apply(target, self, args);
      try { perturb(result.data); } catch (e) {}
      return result;
    });

    const noisyCanvas = (canvas) => {
      try {
        const ctx = canvas.getContext('2d');
        if (!ctx) return;
        const img = Object.getPrototypeOf(ctx).getImageData.call(ctx, 0, 0, canvas.width, canvas.height);
        perturb(img.data);
        ctx.putImageData(img, 0, 0);
      } catch (e) {}
    };

    proxyFn(HTMLCanvasElement.prototype, 'toDataURL', (target, self, args) => {
      noisyCanvas(self);
      return Reflect.apply(target, self, args);
    });
    proxyFn(HTMLCanvasElement.prototype, 'toBlob', (target, self, args) => {
      noisyCanvas(self);
      return Reflect.apply(target, self, args);
    });
  }

  if (cfg.features.webgl) {
    const spoofParam = (target, self, args) => {
      const param = args[0];
      if (param === 37445) return p.webglVendor || 'Intel Inc.';
      if (param === 37446) return p.webglRenderer || 'Intel Iris OpenGL Engine';
      if (param === 7936) return 'WebKit';
      if (param === 7937) return 'WebKit WebGL';
      return Reflect.apply(target, self, args);
    };
    if (window.WebGLRenderingContext) {
      proxyFn(WebGLRenderingContext.prototype, 'getParameter', spoofParam);
      proxyFn(WebGLRenderingContext.prototype, 'readPixels', (target, self, args) => {
        const out = Reflect.apply(target, self, args);
        const buf = args[6];
        if (buf && buf.length) {
          for (let i = 0; i < buf.length; i += Math.max(4, (buf.length / 256) | 0)) {
            buf[i] = Math.max(0, Math.min(255, buf[i] + (nextNoise() < 0.5 ? -1 : 1)));
          }
        }
        return out;
      });
    }
    if (window.WebGL2RenderingContext) {
      proxyFn(WebGL2RenderingContext.prototype, 'getParameter', spoofParam);
    }
  }

  if (cfg.features.audio) {
    if (window.AnalyserNode) {
      proxyFn(AnalyserNode.prototype, 'getFloatFrequencyData', (target, self, args) => {
        const out = Reflect.apply(target, self, args);
        const arr = args[0];
        for (let i = 0; i < arr.length; i += 32) arr[i] += (nextNoise() - 0.5) * 0.0005;
        return out;
      });
    }
    if (window.AudioBuffer) {
      proxyFn(AudioBuffer.prototype, 'getChannelData', (target, self, args) => {
        const arr = Reflect.apply(target, self, args);
        for (let i = 0; i < arr.length; i += 512) arr[i] += (nextNoise() - 0.5) * 1e-7;
        return arr;
      });
    }
  }

  if (cfg.features.webrtc && window.RTCPeerConnection) {
    const isLocal = (candidate) => /(\s|^)(10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.|169\.254\.|fe80:|\.local)/i.test(candidate);
    const OriginalPC = window.RTCPeerConnection;
    const PatchedPC = function (...args) {
      const pc = new OriginalPC(...args);
      const originalAdd = pc.addEventListener.bind(pc);
      pc.addEventListener = (type, listener, opts) => {
        if (type !== 'icecandidate') return originalAdd(type, listener, opts);
        return originalAdd(type, (event) => {
          if (event && event.candidate && isLocal(event.candidate.candidate)) return;
          listener(event);
        }, opts);
      };
      return pc;
    };
    PatchedPC.prototype = OriginalPC.prototype;
    window.RTCPeerConnection = PatchedPC;
    window.webkitRTCPeerConnection = PatchedPC;
  }

  if (cfg.features.devices) {
    const denied = () => Promise.reject(new nativeError('NotAllowedError'));
    if (navigator.getBattery) define(navigator, 'getBattery', denied);
    if (navigator.bluetooth) define(navigator, 'bluetooth', undefined);
    if (navigator.usb) define(navigator, 'usb', undefined);
    if (navigator.serial) define(navigator, 'serial', undefined);
    if (navigator.hid) define(navigator, 'hid', undefined);
  }

  if (cfg.features.plugins) {
    const empty = Object.freeze({ length: 0, item: () => null, namedItem: () => null, refresh: () => {} });
    define(navigator, 'plugins', empty);
    define(navigator, 'mimeTypes', empty);
  }

  define(navigator, 'webdriver', false);
})();

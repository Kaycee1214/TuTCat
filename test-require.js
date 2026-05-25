console.log('=== Test Electron Module Loading ===');
console.log('process.type:', process.type);
console.log('process.versions.electron:', process.versions.electron);

// Try all possible ways to import electron
console.log('\n=== Testing require methods ===');

try {
  const electron1 = require('electron');
  console.log('require("electron"):', electron1);
  console.log('typeof:', typeof electron1);
} catch (e) {
  console.log('require("electron") failed:', e.message);
}

try {
  const electron2 = require('@electron/remote');
  console.log('require("@electron/remote"):', electron2);
} catch (e) {
  console.log('require("@electron/remote") failed:', e.message);
}

try {
  const app = require('electron').app;
  console.log('require("electron").app:', app);
} catch (e) {
  console.log('require("electron").app failed:', e.message);
}

try {
  const app = require('app');
  console.log('require("app"):', app);
} catch (e) {
  console.log('require("app") failed:', e.message);
}

// Check if there's a different way in Electron 26
console.log('\n=== Checking global ===');
console.log('global.electron:', typeof global.electron);
console.log('global.app:', typeof global.app);
console.log('global.BrowserWindow:', typeof global.BrowserWindow);

process.exit(0);
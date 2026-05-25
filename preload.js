const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  getConfig: () => ipcRenderer.invoke('get-config'),
  saveConfig: (config) => ipcRenderer.invoke('save-config', config),
  getAssets: () => ipcRenderer.invoke('get-assets'),
  openAssetsFolder: () => ipcRenderer.invoke('open-assets-folder'),
  quitApp: () => ipcRenderer.invoke('quit-app'),
  getScreenSize: () => ipcRenderer.invoke('get-screen-size'),
  onConfigUpdated: (callback) => ipcRenderer.on('config-updated', (event, config) => callback(config))
});
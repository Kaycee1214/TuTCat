console.log('=== Electron Test Start ===');

const electron = require('electron');
console.log('electron module:', Object.keys(electron));

const { app, BrowserWindow, ipcMain } = electron;
console.log('app:', app);
console.log('ipcMain:', ipcMain);

if (!app) {
  console.error('app is undefined!');
  process.exit(1);
}

if (!ipcMain) {
  console.error('ipcMain is undefined!');
  process.exit(1);
}

console.log('app.whenReady:', app.whenReady);
console.log('ipcMain.handle:', ipcMain.handle);

app.whenReady().then(() => {
  console.log('App is ready!');
  const win = new BrowserWindow({
    width: 400,
    height: 300,
    webPreferences: {
      nodeIntegration: true,
      contextIsolation: false
    }
  });
  win.loadURL('data:text/html,<h1>Hello Electron!</h1>');
});

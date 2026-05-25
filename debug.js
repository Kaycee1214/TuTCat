console.log('=== Debug Electron ===');
console.log('process.versions:', process.versions);
console.log('process.type:', process.type);

// Try to understand what electron module gives us
let electron;
try {
  electron = require('electron');
  console.log('electron type:', typeof electron);
  console.log('electron:', electron);

  // Check if it's the path string (from npm package)
  if (typeof electron === 'string') {
    console.log('electron is a string (path):', electron);
    console.log('This means we are NOT running inside Electron!');
    console.log('We are running with Node.js directly.');
    process.exit(1);
  }

  // It should be an object with app, BrowserWindow, etc.
  const { app, BrowserWindow, ipcMain } = electron;
  console.log('app:', typeof app);
  console.log('BrowserWindow:', typeof BrowserWindow);
  console.log('ipcMain:', typeof ipcMain);

} catch (e) {
  console.error('Error loading electron:', e);
  process.exit(1);
}

const { app, BrowserWindow } = electron;

function createWindow() {
  const win = new BrowserWindow({
    width: 400,
    height: 300,
    webPreferences: {
      nodeIntegration: true,
      contextIsolation: false
    }
  });
  win.loadURL('data:text/html,<h1>It Works!</h1>');
}

app.whenReady().then(createWindow);

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

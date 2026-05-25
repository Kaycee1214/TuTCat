const { app, BrowserWindow, ipcMain, shell, Notification, screen } = require('electron');
const path = require('path');
const fs = require('fs');

let mainWindow = null;
let config = {
  walkSpeed: 2,
  defaultPosition: { x: null, y: null },
  waterReminder: 60,
  toiletReminder: 120
};

function getConfigPath() {
  return path.join(app.getPath('userData'), 'config.json');
}

function getAssetPath() {
  return path.join(app.getPath('userData'), 'assets');
}

function loadConfig() {
  const configPath = getConfigPath();
  try {
    if (fs.existsSync(configPath)) {
      const data = fs.readFileSync(configPath, 'utf8');
      config = { ...config, ...JSON.parse(data) };
    }
  } catch (e) {
    console.log('加载配置失败:', e);
  }
}

function saveConfig() {
  const configPath = getConfigPath();
  try {
    fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
  } catch (e) {
    console.log('保存配置失败:', e);
  }
}

function copyDefaultAssets() {
  const defaultAssetsPath = path.join(__dirname, 'assets');
  const userAssetsPath = getAssetPath();

  if (!fs.existsSync(userAssetsPath)) {
    fs.mkdirSync(userAssetsPath, { recursive: true });
    ['hover', 'play', 'walk'].forEach(dir => {
      const srcDir = path.join(defaultAssetsPath, dir);
      const destDir = path.join(userAssetsPath, dir);
      if (fs.existsSync(srcDir)) {
        fs.mkdirSync(destDir, { recursive: true });
        fs.readdirSync(srcDir).forEach(file => {
          fs.copyFileSync(path.join(srcDir, file), path.join(destDir, file));
        });
      }
    });
  }
}

function createWindow() {
  const primaryDisplay = screen.getPrimaryDisplay();
  const { width, height } = primaryDisplay.workAreaSize;

  const defaultX = config.defaultPosition.x !== null ? config.defaultPosition.x : Math.floor(width / 2) - 120;
  const defaultY = config.defaultPosition.y !== null ? config.defaultPosition.y : Math.floor(height / 2) - 120;

  mainWindow = new BrowserWindow({
    width: 240,
    height: 240,
    x: defaultX,
    y: defaultY,
    frame: false,
    transparent: true,
    alwaysOnTop: true,
    resizable: false,
    skipTaskbar: false,
    hasShadow: false,
    backgroundColor: '#00000000',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      nodeIntegration: false,
      contextIsolation: true,
      webSecurity: false
    }
  });

  mainWindow.loadFile('index.html');

  mainWindow.on('closed', () => {
    mainWindow = null;
  });

  mainWindow.on('moved', () => {
    if (mainWindow) {
      const [x, y] = mainWindow.getPosition();
      config.defaultPosition = { x, y };
      saveConfig();
    }
  });

  startReminders();
}

function startReminders() {
  if (config.waterReminder > 0) {
    setInterval(() => {
      if (mainWindow) {
        new Notification({
          title: '喝水提醒',
          body: '该喝水啦！保持身体健康~'
        }).show();
      }
    }, config.waterReminder * 60 * 1000);
  }

  if (config.toiletReminder > 0) {
    setInterval(() => {
      if (mainWindow) {
        new Notification({
          title: '上厕所提醒',
          body: '久坐伤身，起来活动一下吧~'
        }).show();
      }
    }, config.toiletReminder * 60 * 1000);
  }
}

ipcMain.handle('get-config', () => config);

ipcMain.handle('save-config', (_event, newConfig) => {
  config = { ...config, ...newConfig };
  saveConfig();
  if (mainWindow) {
    mainWindow.webContents.send('config-updated', config);
  }
  return true;
});

ipcMain.handle('get-assets', () => {
  const assetsPath = getAssetPath();
  const assets = { hover: [], play: [], walk: [] };

  ['hover', 'play', 'walk'].forEach(type => {
    const dir = path.join(assetsPath, type);
    if (fs.existsSync(dir)) {
      assets[type] = fs.readdirSync(dir)
        .filter(f => f.endsWith('.gif') || f.endsWith('.png'))
        .map(f => path.join(dir, f));
    }
  });

  return assets;
});

ipcMain.handle('open-assets-folder', () => {
  const assetsPath = getAssetPath();
  ['hover', 'play', 'walk'].forEach(type => {
    const dir = path.join(assetsPath, type);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
  });
  shell.openPath(assetsPath);
  return true;
});

ipcMain.handle('quit-app', () => app.quit());

ipcMain.handle('get-screen-size', () => {
  const primaryDisplay = screen.getPrimaryDisplay();
  return primaryDisplay.workAreaSize;
});

app.whenReady().then(() => {
  loadConfig();
  copyDefaultAssets();
  createWindow();
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) {
    createWindow();
  }
});
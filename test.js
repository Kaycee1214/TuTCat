const { app } = require('electron');

app.whenReady().then(() => {
  console.log('Electron app is ready!');
  app.quit();
});
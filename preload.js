const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  isElectron:    true,
  getBattery:    ()  => ipcRenderer.invoke('get-battery'),
  batteryReport: ()  => ipcRenderer.invoke('battery-report'),
});

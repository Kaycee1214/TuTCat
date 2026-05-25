// 状态管理
const state = {
  currentAnimation: 'walk',
  isPlaying: false,
  walkDirection: 1,
  position: { x: 0, y: 0 },
  walkSpeed: 2,
  walkTimer: null,
  directionChangeTimer: null,
  assets: { hover: [], play: [], walk: [] },
  isHovering: false,
  isDragging: false,
  lastInteraction: 0
};

// DOM 元素
const petImage = document.getElementById('pet-image');
const contextMenu = document.getElementById('context-menu');

// 初始化
async function init() {
  state.assets = await window.electronAPI.getAssets();
  const config = await window.electronAPI.getConfig();
  state.walkSpeed = config.walkSpeed || 2;

  window.electronAPI.onConfigUpdated((newConfig) => {
    state.walkSpeed = newConfig.walkSpeed || 2;
  });

  if (state.assets.walk.length > 0) {
    playAnimation('walk');
    startWalking();
  } else {
    petImage.style.display = 'none';
  }

  setupEventListeners();
}

// 播放动画
function playAnimation(type, index = null) {
  const assets = state.assets[type];
  if (!assets || assets.length === 0) return null;

  const assetIndex = index !== null ? index : Math.floor(Math.random() * assets.length);
  const asset = assets[assetIndex];

  if (asset) {
    petImage.src = `file://${asset}`;
    state.currentAnimation = type;
    state.isPlaying = true;

    // GIF 播放完成后检查是否需要恢复
    if (type !== 'walk') {
      const duration = type === 'hover' ? 2000 : 3000;
      setTimeout(() => {
        if (state.currentAnimation === type && !state.isHovering) {
          resumeWalking();
        }
      }, duration);
    }
  }

  return asset;
}

// 开始走路
function startWalking() {
  if (state.walkTimer) return;

  state.walkTimer = setInterval(() => {
    if (state.currentAnimation !== 'walk' || state.isHovering || state.isDragging) return;

    // 移动窗口
    window.moveBy(state.walkDirection * state.walkSpeed, 0);

    // 翻转图片
    if (state.walkDirection > 0) {
      petImage.classList.add('mirrored');
    } else {
      petImage.classList.remove('mirrored');
    }
  }, 50);

  // 随机改变方向
  scheduleDirectionChange();
}

// 调度方向改变
function scheduleDirectionChange() {
  if (state.directionChangeTimer) {
    clearTimeout(state.directionChangeTimer);
  }

  const randomDelay = 2000 + Math.random() * 4000;
  state.directionChangeTimer = setTimeout(async () => {
    const screenSize = await window.electronAPI.getScreenSize();
    const currentX = window.screenX;
    const margin = 50;

    // 检查是否碰到屏幕边缘
    if (currentX <= margin) {
      state.walkDirection = 1;
    } else if (currentX >= screenSize.width - 240 - margin) {
      state.walkDirection = -1;
    } else {
      state.walkDirection = Math.random() > 0.5 ? 1 : -1;
    }

    scheduleDirectionChange();
  }, randomDelay);
}

// 停止走路
function stopWalking() {
  if (state.walkTimer) {
    clearInterval(state.walkTimer);
    state.walkTimer = null;
  }
  if (state.directionChangeTimer) {
    clearTimeout(state.directionChangeTimer);
    state.directionChangeTimer = null;
  }
}

// 恢复走路
function resumeWalking() {
  state.isHovering = false;
  state.isPlaying = false;
  playAnimation('walk');
  startWalking();
}

// 播放互动动画
function playInteractionAnimation(type) {
  stopWalking();
  state.isHovering = false;

  if (state.assets[type] && state.assets[type].length > 0) {
    playAnimation(type);
  }
}

// 事件监听
function setupEventListeners() {
  // 鼠标进入 - hover 动画
  petImage.addEventListener('mouseenter', () => {
    if (state.currentAnimation === 'walk' && state.assets.hover.length > 0) {
      state.isHovering = true;
      stopWalking();
      playAnimation('hover');
    }
  });

  // 鼠标离开
  petImage.addEventListener('mouseleave', () => {
    state.isHovering = false;
    setTimeout(() => {
      if (!state.isHovering && state.currentAnimation !== 'walk') {
        resumeWalking();
      }
    }, 500);
  });

  // 点击 - play 动画
  petImage.addEventListener('click', (e) => {
    if (e.button === 0 && !contextMenu.classList.contains('show')) {
      e.preventDefault();
      playInteractionAnimation('play');
    }
  });

  // 右键菜单
  document.addEventListener('contextmenu', (e) => {
    e.preventDefault();
    showContextMenu(e.clientX, e.clientY);
  });

  // 隐藏菜单
  document.addEventListener('click', (e) => {
    if (!contextMenu.contains(e.target)) {
      contextMenu.classList.remove('show');
    }
  });

  // 菜单项点击
  document.querySelectorAll('.menu-item').forEach(item => {
    item.addEventListener('click', (e) => {
      e.stopPropagation();
      handleMenuAction(item.dataset.action);
      contextMenu.classList.remove('show');
    });
  });

  // 拖拽
  petImage.addEventListener('mousedown', (e) => {
    if (e.button === 0) {
      state.isDragging = true;
    }
  });

  document.addEventListener('mouseup', () => {
    state.isDragging = false;
  });
}

// 显示右键菜单
function showContextMenu(x, y) {
  contextMenu.style.left = `${x}px`;
  contextMenu.style.top = `${y}px`;
  contextMenu.classList.add('show');
}

// 处理菜单动作
async function handleMenuAction(action) {
  switch (action) {
    case 'change-pose':
      const randomIndex = Math.floor(Math.random() * state.assets.play.length);
      playInteractionAnimation('play');
      break;

    case 'feed':
      if (state.assets.play.length > 0) {
        playInteractionAnimation('play');
      }
      break;

    case 'play':
      playInteractionAnimation('play');
      break;

    case 'settings':
      window.electronAPI.openAssetsFolder();
      break;

    case 'quit':
      window.electronAPI.quitApp();
      break;
  }
}

// 启动
init();

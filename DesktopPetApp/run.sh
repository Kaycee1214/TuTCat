#!/bin/bash

echo "重新编译并启动 DesktopPet..."
echo ""

cd ~/DesktopPet/DesktopPetApp

# 清理旧的构建
rm -rf ~/Desktop/DesktopPet.app

# 重新编译
echo "编译中..."
xcodebuild -scheme DesktopPet -configuration Debug MACOSX_DEPLOYMENT_TARGET=14.0 clean build > /tmp/xcode_build.log 2>&1

if [ $? -eq 0 ]; then
    echo "编译成功"

    # 复制应用
    cp -R "/Users/makexin01/Library/Developer/Xcode/DerivedData/DesktopPet-alxcuntpoxblazaerpbcivgimcen/Build/Products/Debug/DesktopPet.app" ~/Desktop/

    # 复制素材
    mkdir -p ~/Desktop/DesktopPet.app/Contents/Resources/Assets
    cp -r ~/DesktopPet/assets/* ~/Desktop/DesktopPet.app/Contents/Resources/Assets/

    # 复制应用图标到 Resources 根目录
    cp ~/DesktopPet/assets/AppIcon.icns ~/Desktop/DesktopPet.app/Contents/Resources/AppIcon.icns

    echo "素材已复制到应用包"
    echo "启动应用..."

    # 启动应用
    open ~/Desktop/DesktopPet.app

    echo "应用已启动！"
    echo ""
    echo "素材位置："
    ls -la ~/Desktop/DesktopPet.app/Contents/Resources/Assets/
    echo ""
    echo "请在 Console.app 中搜索 'DesktopPet' 查看日志"
    echo ""
else
    echo "编译失败，查看日志："
    tail -20 /tmp/xcode_build.log
fi
# Homebrew Cask Formula Template for SkillStudio
#
# 这个文件是 Homebrew Cask 配方的模板，用于 `brew install --cask skillstudio`
#
# 使用方法：
#   1. 创建一个新仓库: github.com/zhls-ayl/homebrew-skillstudio
#   2. 将此文件放在: Casks/skillstudio.rb
#   3. 每次发布新版本时，更新 version 和 sha256
#
# 用户安装命令：
#   brew tap zhls-ayl/skillstudio
#   brew install --cask skillstudio
#
# 计算 sha256：
#   shasum -a 256 SkillStudio-vX.Y.Z-universal.zip

cask "skillstudio" do
  version "0.0.1"
  sha256 "6356ee6d06b82d3c35a372e76b0a875fe22c12a2ec64dc3be6f8c4c304f61314"

  url "https://github.com/zhls-ayl/SkillStudio/releases/download/v#{version}/SkillStudio-v#{version}-universal.zip"
  name "SkillStudio"
  desc "Native macOS application for managing AI code agent skills"
  homepage "https://github.com/zhls-ayl/SkillStudio"

  # 要求 macOS Sonoma 或更高版本
  depends_on macos: ">= :sonoma"

  # 告诉 Homebrew 将 .app 移动到 /Applications/
  app "SkillStudio.app"

  # zap 定义完全卸载时需要清理的文件
  # 只在 brew zap（非 brew uninstall）时执行
  zap trash: [
    "~/.agents/.skill-lock.json",
  ]
end

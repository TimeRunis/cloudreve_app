abstract class Constants {
  // 本地存储配置
  static var configPrefix = {
    "app_config": "app_config",
  };
  static var appConfig = {
    "isDarkMode": "${configPrefix['configPrefix']}.isDarkMode",
    "userInfo": "${configPrefix['configPrefix']}.userInfo",
    "session": "${configPrefix['configPrefix']}.session"
  };
  // 文件类型
  static var fileType = {
    "dir": "dir",
    "file": "file",
  };

  // 可预览的图片后缀
  static Set<String> canPrePicSet = {
    "png","jpg","jpeg","gif","webp"
  };

  // 可预览的视频后缀
  static Set<String> canPreVideoSet = {
    "mp4","avi"
  };
  
}

# 内置扩展接口

## 边界

- 核心：`lib/services/media_command.dart`、`lib/providers/media_provider.dart`、`lib/providers/app_provider.dart`，负责 FFmpeg 本地处理、进程状态与公共输出路径。
- 扩展协议：`lib/extensions/toolbox_extension.dart`，提供 ID、名称、说明、页面列表和忙碌状态检查。
- 注册表：`lib/extensions/registry.dart`，这是宿主导入具体扩展实现的唯一位置。
- yt-dlp：`lib/plugins/yt_dlp/`，包含页面、下载状态、Cookie 编解码、工具更新及模型。

宿主根据启用列表注册扩展导航。每个页面有稳定 ID；页面切换保留状态，非活动页面暂停动画。扩展停用时移除页面。忙碌状态由扩展提供，阻止任务进行中从界面停用。

## 添加扩展

1. 在 `lib/plugins/<id>/` 实现 `ToolboxExtension`。
2. 返回稳定的扩展 ID、`ExtensionPage` 列表和忙碌状态。
3. 在 `bundledExtensions` 中注册。
4. 独立管理扩展私有配置；通过公共设置读取 FFmpeg 路径、默认输出目录。
5. 为配置持久化、启用/停用、任务结束及错误路径添加验证。

这是编译时模块化，不是外部代码加载器。外部插件分发、版本协议、安装包签名与隔离不在本版范围内。

## 兼容性

沿用 FFmpeg 和下载路径的原 SharedPreferences 键。启用列表保存为 `enabled_extensions`；初次迁移仅在已有 `yt_dlp_path` 键时默认启用 yt-dlp。用户主动停用后保存空列表，不会再次自动启用。

Cookie 文件位置兼容旧版。Netscape 导入保留 HttpOnly 和空值。自定义 Cookie 内容只写 Cookie 文件，新写入的偏好元数据不包含原始 Cookie；历史数据可读取，不主动删除用户配置。

# 来源与第三方许可

## 随游戏运行的依赖

| 文件 / 组件 | 来源 | 许可与用途 |
|---|---|---|
| Godot 4.7.2 Windows 模板 | https://github.com/godotengine/godot/releases/tag/4.7.2-stable | MIT；完整引擎许可见 GODOT_LICENSE.txt，所含第三方组件见同版本 GODOT_COPYRIGHT.txt。 |
| assets/fonts/NotoSansSC.ttf | https://github.com/google/fonts/tree/main/ofl/notosanssc | SIL OFL 1.1；版权原文在 assets/fonts/OFL.txt。用于中文排版。 |
| assets/fonts/SolmereSans.ttf | 上述 Noto Sans SC 的本地静态 wght=450 实例 | 同为 SIL OFL 1.1；避免变量字体默认过细。构建方法见 tools/build_font.py。不是原创字库，不单独销售字体。 |
| assets/fonts/Caveat.ttf | https://github.com/google/fonts/tree/main/ofl/caveat | SIL OFL 1.1；版权原文在 assets/fonts/Caveat-OFL.txt。用于可对照的手写物证。 |
| assets/fonts/DynaPuff.ttf | https://github.com/google/fonts/tree/main/ofl/dynapuff | SIL OFL 1.1；设置英文圆润手绘字体；保留 DynaPuff-OFL.txt 与 pinned provenance。 |
| assets/fonts/ZCOOLKuaiLe.ttf | https://github.com/google/fonts/tree/main/ofl/zcoolkuaile | SIL OFL 1.1；设置中文快乐体后备；保留 ZCOOLKuaiLe-OFL.txt 与 pinned provenance。 |
| assets/audio/foley/water_touch_*.wav | https://opengameart.org/content/6-short-water-splashes | ezwa / qubodup；CC0 1.0；原样解码为 PCM，原页、文件与 SHA256 见 water-provenance.json。 |
| assets/audio/foley/ | 下表列明的作者与原始页面 | CC0 1.0；剪辑、滤波与混音用于游戏声音。加工清单见 sample_manifest.json。 |

引擎与上述字体允许商业项目使用；分发时保留其版权及许可文本。录音与拟音的原始页面均明确标示 CC0 1.0，可用于商业项目与改编。Windows 成品的 Licenses 目录包含字体和引擎许可、声音来源说明与清单、Kenney 素材包自带的许可原文。没有另外引入需联网调用的游戏服务、付费素材库、开源玩法插件或他人游戏代码。

## 第三方声音

| 游戏中的用途 | 作者 / 原始页面 | 许可 |
|---|---|---|
| 纸张拿取、滑动、展开 | keweldog — [rustling paper.wav](https://freesound.org/people/keweldog/sounds/181774/) | CC0 1.0 |
| 小铃 | JohnsonBrandEditing — [Ding Ding Small Bell](https://freesound.org/people/JohnsonBrandEditing/sounds/173932/) | CC0 1.0 |
| 开门、关门 | Iwan Gabovitch / qubodup — [Door open, door close](https://opengameart.org/content/door-open-door-close) | CC0 1.0 |
| 海岸环境 | jasinski — [alkaibeach.aif](https://freesound.org/people/jasinski/sounds/18363/) | CC0 1.0 |
| 鸟鸣 | syncopika — [Bird chirping sounds](https://opengameart.org/content/bird-chirping-sounds) | CC0 1.0 |
| 街区与经过滤波的室内环境层 | MiLeuthner — [Residential neighborhood](https://freesound.org/people/MiLeuthner/sounds/399028/) | CC0 1.0 |
| 树间风声 | nickydunne — [Wind in trees.WAV](https://freesound.org/people/nickydunne/sounds/463551/) | CC0 1.0 |
| 电车经过 | mdayalan — [Dublin's Luas Tram Arriving and Departing](https://freesound.org/people/mdayalan/sounds/239646/) | CC0 1.0 |
| 不同地面脚步、木件、印章及金属工具拟音 | Kenney — [Impact Sounds 1.0](https://kenney.nl/assets/impact-sounds) | CC0 1.0；包内原文为 KENNEY_CC0.txt |

[CC0 许可说明](https://creativecommons.org/publicdomain/zero/1.0/)。作者署名在此自愿保留。Freesound 输入取自其公开的高质量 MP3 预览，不冒称无损原始下载。街区录音经过低通滤波构成室内背景，木质冲击用于印章拟音；这些不是在虚构小镇现场录制或真实盖章的声音。详见 [AUDIO_PROVENANCE.md](AUDIO_PROVENANCE.md)、`assets/audio/foley/sample_manifest.json` 和 `source_downloads.json`，其中记录原始 URL、片段时间、处理参数和 SHA-256。

## 本项目内容

2026-10-17 当前邮差使用用户最新指定的五帧8fps原动画提取物，不是 AI 生成。保留原像素、深色鞋/眼线、亮发及共同脚位，采用邻接黑底透明处理；原视频保持私有且不修改。站立副本取自原帧2。来源哈希、裁切、透明处理和角色注册见 `assets/faefever_v2/characters/courier_video_provenance_20261017.json`。压缩黑边与外侧黑墨线的恢复存在信息限制，不称为原生alpha。2026-10-16的六帧白底版本及其证据属于保留的历史版本。不擅自给用户原稿转授开源许可。

用户最新手提箱PNG本身已有透明底。像素不变的裁切位于 `assets/authoring/supplied_case_20261017`，作为下一次完整开箱制作的原画材料；当前没有把关闭整箱图片冒充箱盖、内腔或锁扣，也未选入运行包。来源只记录哈希，原图路径及原文件保持私有。

- 用户原始美术按本次项目授权使用，保留原件，不擅自转授开源许可。批准的场景副本仅处理外围白底，见 ASSET_PROVENANCE.md。
- 新增场景及 Mira、June 为本次任务生成的独立图像；见 GENERATED_ASSETS.md。不是下载的“免费商用素材”，也不冒称手绘原稿。
- 行走邮差使用独立生成的绘画动作图集；Nora、尘缘的舞台形象使用新生成的立绘。工作证显示新邮差。用户提供的角色原图保持独立留存，没有作为生成输入。生成提示、图集范围与动作限制见 CHARACTER_GENERATION.md。物件图标与纸张交互仍由项目代码绘制。
- 轻柔配乐 afternoon.wav 由 tools/build_audio.py 程序合成；当前环境音与大部分动作声音使用上表的录音 / 拟音，通过 tools/prepare_audio.py 加工。旧版合成动作声音保留在源码中，当前控制器不选用。
- 书信在原规格基础上扩写，没有引用或复制文学作品的受保护译文。
- specification 中的参考截图作为用户提供的开发资料保存在私有源码仓库中，未打入游戏运行包。参考游戏的美术、音轨、标识和源码没有用于成品。

## 仅制作时使用

Python、NumPy、Pillow、SciPy、fontTools 用于音频加工、合成配乐、授权的透明显示副本与静态字体，不随 Windows 程序打包其解释器或库。FFmpeg 用于声音采样转换与演示视频转码，成品不附转码程序。工具各自许可不替代素材本身的来源记录。


Settings R3 sources (2026-10-17): exact original authored PDF JPEG layers (user authorized grouping); runtime white-matte compositing, no AI repaint. Lilita One, DynaPuff, ZCOOL KuaiLe and Noto Sans SC: original SIL OFL1.1 notices and pinned font hashes in assets/fonts. Evan Wallace WebGL Water: pinned MIT water.js step/drop equations ported into scripts/ui/water_field.gd; third_party/webgl-water retains original source/header, commit/hash and full MIT notice. No upstream JavaScript or demo photographs executed. Native GodotPhysics2D (Godot MIT) supplies actual 2D rigid-body contacts. Vaporware by The Cynic Project / cynicmusic.com / pixelsphere.org: complete CC0 track, source https://opengameart.org/content/calm-piano-1-vaporware; assets/audio/settings-music-provenance.json records unchanged source fingerprint and Ogg transcode.

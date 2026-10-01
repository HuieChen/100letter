# 新增图像记录

本目录记录生成内容，不把用户原件称作生成图。运行素材包括下列室内/居民图、七幅独立环境画，以及另表登记的人物动作素材；被否决的背景试稿没有混进游戏目录。

| 运行文件 | 本次图像工具输出标识 | 最终方向 |
|---|---|---|
| assets/generated/post_office_interior.png | exec-4da77e1c-79a0-47a5-a7e1-c6550bd218e0 | 平面邮局工作台，方正窗框，浅暖木色，简约海景，安静侧光。 |
| assets/generated/npc_mira.png | exec-8f569ab1-4723-47b3-981d-a57232912997 | 栗色头发、米白上衣、灰紫长裤；以新生成 Nora 为风格参考重绘的透明立绘，双臂自然分开。完整提示与哈希见 CHARACTER_GENERATION.md。 |
| assets/generated/npc_june.png | exec-0d822287-8a65-498b-9a5a-530bad4235fe | 墨青头发、鼠尾草色外衣、浅杏上衣、燕麦色长裤；与新邮差 / Nora 一致的墨线、平涂与透明轮廓。完整提示与哈希见 CHARACTER_GENERATION.md。 |

## 七处室外环境

`assets/generated/environments/` 中的 `post_office`、`community_center`、`bus_stop`、`residential`、`lookout`、`chess_stall`、`tarot_shop` 均为图像生成工具制作的独立 PNG。完整提示词、输出标识及来源写在 [ENVIRONMENT_GENERATION.json](ENVIRONMENT_GENERATION.json)。场景程序负责摆放、光照过渡及小范围前景遮挡，不再通过程序绘制房屋、海面和植被。

第一幅背景使用 Faefever 官方 Steam 截图作线条、色块和疏密参考，明确排除复制其人物、文字、界面、建筑及具体布局；后续六幅仅使用本项目新生成的第一幅作风格参考。合成审核发现初稿黑线压过原建筑，因此最终七图又只以我们生成的图进行减线、降低对比和暖色绘画调整；最终输出标识、提示词与原因见 [ENVIRONMENT_REFINEMENT.json](ENVIRONMENT_REFINEMENT.json)。参考截图不在源码或运行包中分发。用户提供的建筑、人物及其他原图从未送入生成模型，原件与授权的外围白底透明副本仍分别保留。

新邮差八个行走姿态、两幅站姿和交接/观察姿态，以及 Nora、尘缘、Mira、June 四位居民的新绘画，详见 [CHARACTER_GENERATION.md](CHARACTER_GENERATION.md)。人物使用生成工具输出的透明通道，动作系统按落脚点对齐；静止交接姿态仍不等于完整逐帧手部动画。

检查点包括肩—上臂—前臂—手的连接，左右手归属，衣袖与手腕遮挡，双脚落地，缩小到游戏实际显示尺寸后的轮廓、饱和度与焦点。机器检查和画面复核并不等于完整的人体美术终审；玩家反馈中仍需持续关注这一项。

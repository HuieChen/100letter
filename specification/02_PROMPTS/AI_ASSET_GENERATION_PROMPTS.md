# AI 缺失素材生成提示词规范

> 这些提示词只用于**缺失素材**。任何用户 LOCKED 素材不得作为 image-to-image 输入，不得让 AI 重画或融图。

## 全局风格前缀（所有提示词都加）
**中文版本：**
> 2D 手绘扁平独立游戏美术，point-and-click adventure，参考 Faefever 的平面手绘感与舞台式构图，只借 Crushed in Time 的几何概括和清晰 silhouette，不要 3D，不要写实，不要厚涂，不要电影光影。低细节、清晰色块、少纹理、轮廓干净、平面几何、温暖海边小镇夏日配色。奶油白、青绿、灰蓝、暖橙、少量珊瑚色。画面重点单一，留白充分，不堆砌小物，不做 AI 常见复杂花卉和高频装饰。所有文字区域留空，由程序后期排字。

**Negative prompt：**
> photorealistic, realistic 3D, cinematic rendering, volumetric light, detailed texture, hyper-detailed, painterly oil painting, glossy material, complex perspective, cluttered desk, excessive flowers, excessive paper scraps, overdecorated, anime screenshot, pixel art, UI text baked into image, character redraw, existing user asset remake

---

## A01 邮局室内背景
用途：邮局主工作台后方环境，不含用户主角、不含用户建筑。

提示词：
> 2D flat hand-drawn post office interior for a warm Mediterranean seaside town, front-facing point-and-click stage composition. A simple counter, 12–20 mail slots, one filing cabinet, one notice board, one wall clock, one window showing pale blue sea light, one green desk lamp silhouette. Minimal props, large clean shapes, cream walls, muted teal, soft warm orange accents. Clear empty central/lower zone for gameplay UI and desk overlay. No people, no letters with readable text, no detailed clutter, no photorealism, no 3D.

输出：16:9 PNG，1920×1080 或更高；作为独立背景。

## A02 邮局工作桌底图
> 2D flat top-down / shallow-angle wooden worktable, simplified geometric shapes, clean warm medium-brown surface, subtle paper-wear only, no realistic wood grain, no objects, no shadows except soft flat contact shadow, large empty center for envelopes, Faefever-like simplicity, transparent or clean rectangular background.

## A03 档案册 UI 底图
> Open paper directory book UI, 2D flat graphic design, cream paper, muted teal cloth spine, simple tabs, minimal wear, large blank areas for portrait and text, no baked text, no ornate Victorian detail, clean indie puzzle game interface, transparent PNG.

## A04 信件检查工具套件（每件独立透明 PNG）
逐个生成：放大镜、虚构安全拆封工具、快速拆封刀、纸张修复笔、透明修复胶带、镊子、邮戳、印章、纸夹、修复印。
共同要求：
> isolated 2D flat game prop, front / slight top view, geometric simplified silhouette, 2–4 flat colors, minimal highlight, no texture realism, no drop shadow baked in, transparent background.

## A05 普通信封套件
> isolated standard paper envelope for a fictional seaside post office, 2D flat, cream/off-white, simplified paper texture, blank recipient area, blank postage area, clean back flap, transparent background, no readable text, no realistic photography.
需要：正面、背面、轻微旧化、急件版、陈年版、雨损版，共 6 张独立 PNG。

## A06 信纸套件
> isolated 2D flat stationery sheet, cream paper, subtle botanical corner mark / very simple line decoration, large blank writing area, slight fold guides, no readable text, transparent background.
需要：普通、正式、私人手写、旧纸、雨损、邮局内部记录 6 类。

## A07 Case 03 水损碎片
> six to eight torn paper fragments from one damaged invitation, 2D flat, visible water stain boundaries, each fragment clearly distinct silhouette, blank or placeholder faint lines only, no final readable clue text baked in, transparent background. The shapes must be designed so they can physically fit together like a real torn sheet but should not be too obvious.

## A08 Case 04 旧照片
> 2D stylized printed photograph prop, simplified flat illustration of two small-town residents seen from behind at a seaside lookout during a summer community event, no resemblance to the locked protagonist or Chenyuan, muted faded blue and warm orange, simple silhouettes, dated-photo feel without photorealism, transparent border, no readable text.

## A09 公告栏小物
分别生成：社区活动表、旧店名牌、居民楼门牌、撕掉一半的姓名贴、公交时刻表卡、旧活动票、搬迁通知卡。
要求：平面纸片，留空文字区，由程序排字。

## A10 新 NPC（仅 Mira / June，如 MVP 需要可见）
> original new female small-town resident character, NOT resembling the locked heroine and NOT resembling Chenyuan, front-facing 2D hand-drawn point-and-click character, simplified anatomy, clean shapes, calm everyday summer clothes, muted warm palette, minimal details, transparent background, neutral standing pose. No dynamic action pose. Create each NPC as a separate unique design.

注意：不得使用用户主角或尘缘图片作为参考输入。

## A11 对话框与纸张 UI
> flat 2D paper dialogue panel, cream rectangular sheet with slightly irregular torn edge, one muted teal name tab, very minimal shadow, transparent background, no text, no decoration except one tiny bird/post mark icon placeholder.

## A12 地图背景（如果不能直接使用用户现有建筑拼排）
只生成“空白地形底图”，用户已有建筑在引擎中叠加。
> top-down stylized seaside town terrain map without any buildings, 2D flat hand-drawn, cream roads, muted green hills, blue coastline, simple harbor shape, clean large areas, no landmarks, no text, no icons, no 3D perspective, designed as a neutral background for separately overlaid user-provided building sprites.

## A13 音效生成/搜索关键词
若有音频生成能力，生成：
- paper slide short soft
- envelope flip light
- stamp soft wooden thunk
- paper fragment snap subtle
- repair tape soft pull
- map unfold paper
- distant summer seaside ambience
- soft bus stop ambience
- subtle deadline reminder bell
要求全部轻、短、不尖锐、不 ASMR 化。

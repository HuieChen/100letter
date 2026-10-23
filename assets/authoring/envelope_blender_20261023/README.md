# 蜡封信封 Blender 模型

这是根据用户提供的信封图制作的可编辑 Blender 模型，并附有通用 glTF 版本。

## 文件

- `ornate_wax_envelope.blend`：Blender 源文件；原始参考图已打包进文件。
- `ornate_wax_envelope.glb`：可导入其他 3D 软件或游戏引擎的纹理模型。
- `preview_front.png`：正面细节预览。
- `preview_three_quarter.png`：斜视角，可见信封纸边和凸起火漆。
- `preview_back.png`：背面折片结构。
- `source_reference.jpg`：用户原图的逐字节副本。
- `../../../tools/create_ornate_envelope_blender.py`：重建模型的脚本。
- `provenance.json`：来源哈希与模型尺寸记录。

## 模型说明

尺寸按 220 × 140 mm 制作。正面图案与火漆细节直接使用原图纹理，没有重画；纸张厚度、切边、背面折片和凸起火漆由独立几何体构成。Blender 集合分为信封部件和预览灯光/相机两组。它是独立模型资产，尚未替换进 2D 游戏场景。

用 Blender 5.1 或更高版本从项目根目录运行重建脚本即可重新生成模型。脚本需要此目录中的 `source_reference.jpg`。

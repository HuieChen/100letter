from __future__ import annotations

import math
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "authoring" / "envelope_blender_20261023"
SOURCE = OUT / "source_reference.jpg"
BLEND = OUT / "ornate_wax_envelope.blend"
GLB = OUT / "ornate_wax_envelope.glb"

# Measurements follow the supplied 1280 x 1280 reference screenshot.
IMAGE_W = 1280.0
IMAGE_H = 1280.0
ENVELOPE_CROP = (187.0, 423.0, 907.0, 577.0)  # x, y(top), width, height
SEAL_CROP = (575.0, 652.0, 136.0, 124.0)

WIDTH = 0.220
HEIGHT = WIDTH * ENVELOPE_CROP[3] / ENVELOPE_CROP[2]
PAPER_THICKNESS = 0.00078


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.materials, bpy.data.meshes, bpy.data.curves, bpy.data.cameras, bpy.data.lights):
        for item in list(datablocks):
            if item.users == 0:
                datablocks.remove(item)
    for collection in list(bpy.data.collections):
        if collection.name != "Collection":
            bpy.data.collections.remove(collection)
    default = bpy.data.collections.get("Collection")
    if default:
        default.name = "MODEL | sealed envelope"
        model_collection = default
    else:
        model_collection = bpy.data.collections.new("MODEL | sealed envelope")
        bpy.context.scene.collection.children.link(model_collection)
    studio = bpy.data.collections.new("STUDIO | cameras and lights")
    bpy.context.scene.collection.children.link(studio)
    return model_collection, studio


def new_image_material(name, image, roughness=0.88):
    material = bpy.data.materials.new(name)
    material.diffuse_color = (0.83, 0.72, 0.63, 1.0)
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    output.location = (520, 40)
    paint = nodes.new("ShaderNodeEmission")
    paint.location = (240, 40)
    paint.inputs["Strength"].default_value = 1.0
    tex = nodes.new("ShaderNodeTexImage")
    tex.location = (-280, 140)
    tex.image = image
    tex.interpolation = "Cubic"
    tex.label = "Original user artwork | packed into this blend"
    texcoord = nodes.new("ShaderNodeTexCoord")
    texcoord.location = (-520, 140)
    links.new(texcoord.outputs["UV"], tex.inputs["Vector"])
    # The original painted pixels stay color-faithful under studio lighting.
    # The surrounding paper thickness, folds, and raised wax still receive light.
    links.new(paint.outputs["Emission"], output.inputs["Surface"])
    links.new(tex.outputs["Color"], paint.inputs["Color"])
    return material


def new_simple_paper(name, color, roughness=0.91, grain_strength=0.055):
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*color, 1.0)
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    shader = nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1.0)
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Specular IOR Level"].default_value = 0.16
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 1550.0
    noise.inputs["Detail"].default_value = 2.0
    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = grain_strength
    bump.inputs["Distance"].default_value = 0.000045
    links.new(noise.outputs["Fac"], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], shader.inputs["Normal"])
    return material


def source_uv_from_xz(x_norm: float, z_norm: float):
    x0, y0, cw, ch = ENVELOPE_CROP
    return ((x0 + x_norm * cw) / IMAGE_W,
            1.0 - (y0 + (1.0 - z_norm) * ch) / IMAGE_H)


def create_body(collection, front_material, edge_material, back_material):
    x = WIDTH / 2
    z = HEIGHT / 2
    y0 = -PAPER_THICKNESS / 2
    y1 = PAPER_THICKNESS / 2
    vertices = [(-x, y0, -z), (x, y0, -z), (x, y0, z), (-x, y0, z),
                (-x, y1, -z), (x, y1, -z), (x, y1, z), (-x, y1, z)]
    faces = [(0, 1, 2, 3), (4, 7, 6, 5),
             (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
    mesh = bpy.data.meshes.new("Envelope body | thin folded paper")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(front_material)
    mesh.materials.append(edge_material)
    mesh.materials.append(back_material)
    mesh.polygons[0].material_index = 0
    mesh.polygons[1].material_index = 2
    for poly in mesh.polygons[2:]:
        poly.material_index = 1
    mesh.update()
    uv = mesh.uv_layers.new(name="Original artwork UV")
    uv_by_vertex = {
        0: source_uv_from_xz(0, 0), 1: source_uv_from_xz(1, 0),
        2: source_uv_from_xz(1, 1), 3: source_uv_from_xz(0, 1),
    }
    for loop_index in mesh.polygons[0].loop_indices:
        uv.data[loop_index].uv = uv_by_vertex[mesh.loops[loop_index].vertex_index]
    obj = bpy.data.objects.new("Envelope | printed front and paper core", mesh)
    collection.objects.link(obj)
    bevel = obj.modifiers.new("Soft cut paper edge", "BEVEL")
    bevel.width = 0.00065
    bevel.segments = 3
    bevel.material = 1
    bevel.harden_normals = True
    normals = obj.modifiers.new("Weighted paper normals", "WEIGHTED_NORMAL")
    normals.keep_sharp = True
    return obj


def make_back_flap(name, points, y, material, collection):
    vertices = [(x, y, z) for x, z in points]
    mesh = bpy.data.meshes.new(name + " mesh")
    mesh.from_pydata(vertices, [], [tuple(range(len(vertices)))])
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(material)
    for poly in mesh.polygons:
        poly.use_smooth = False
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    solid = obj.modifiers.new("Paper fold thickness", "SOLIDIFY")
    solid.thickness = 0.00018
    bevel = obj.modifiers.new("Soft folded edge", "BEVEL")
    bevel.width = 0.00018
    bevel.segments = 2
    return obj


def make_fold_line(name, points, y, material, collection, radius=0.00012):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = 2
    spline = curve.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for point, (x, z) in zip(spline.points, points):
        point.co = (x, y, z, 1.0)
    obj = bpy.data.objects.new(name, curve)
    collection.objects.link(obj)
    obj.data.materials.append(material)
    return obj


def create_back(collection, back_material, crease_material):
    left, right = -WIDTH / 2, WIDTH / 2
    bottom, top = -HEIGHT / 2, HEIGHT / 2
    center = (0.0, 0.0)
    base_y = PAPER_THICKNESS / 2 + 0.00010
    # Physical fold order: lower flap first, side folds second, top flap last.
    make_back_flap("Back flap | lower", [(left, bottom), (right, bottom), center], base_y, back_material, collection)
    make_back_flap("Back flap | left", [(left, top), (left, bottom), center], base_y + 0.00018, back_material, collection)
    make_back_flap("Back flap | right", [(right, top), (right, bottom), center], base_y + 0.00018, back_material, collection)
    make_back_flap("Back flap | top", [(left, top), (right, top), center], base_y + 0.00036, back_material, collection)
    seam_y = base_y + 0.00062
    make_fold_line("Fold seam | left", [(left, top), center], seam_y, crease_material, collection)
    make_fold_line("Fold seam | right", [(right, top), center], seam_y, crease_material, collection)
    make_fold_line("Fold seam | bottom left", [(left, bottom), center], seam_y, crease_material, collection)
    make_fold_line("Fold seam | bottom right", [(right, bottom), center], seam_y, crease_material, collection)


def create_seal(collection, image_material, side_material, image):
    x0, y0, sw, sh = SEAL_CROP
    cx, cy = x0 + sw / 2, y0 + sh / 2
    rx = WIDTH * sw / ENVELOPE_CROP[2] / 2
    rz = HEIGHT * sh / ENVELOPE_CROP[3] / 2
    center_x = -WIDTH / 2 + WIDTH * (cx - ENVELOPE_CROP[0]) / ENVELOPE_CROP[2]
    center_z = HEIGHT / 2 - HEIGHT * (cy - ENVELOPE_CROP[1]) / ENVELOPE_CROP[3]
    y_back = -PAPER_THICKNESS / 2 - 0.00008
    y_top = y_back - 0.00135
    segments = 64
    vertices = []
    for y, scale in ((y_back, 0.98), (y_top, 0.95)):
        for i in range(segments):
            theta = 2.0 * math.pi * i / segments
            handmade = 1.0 + 0.022 * math.sin(5 * theta + 0.4) + 0.014 * math.sin(9 * theta - 0.7)
            px = center_x + rx * scale * handmade * math.cos(theta)
            pz = center_z + rz * scale * handmade * math.sin(theta)
            vertices.append((px, y, pz))
    faces = []
    for i in range(segments):
        n = (i + 1) % segments
        faces.append((i, n, segments + n, segments + i))
    faces.append(tuple(segments + i for i in range(segments)))
    mesh = bpy.data.meshes.new("Wax seal | irregular raised edge")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(side_material)
    mesh.materials.append(image_material)
    for poly in mesh.polygons:
        poly.material_index = 0 if poly.index < segments else 1
    mesh.update()
    uv = mesh.uv_layers.new(name="Wax detail UV | exact source crop")
    top_poly = mesh.polygons[-1]
    for loop_index in top_poly.loop_indices:
        vertex_index = mesh.loops[loop_index].vertex_index
        px, _, pz = mesh.vertices[vertex_index].co
        nx = (px - center_x) / rx
        nz = (pz - center_z) / rz
        sx = cx + nx * sw / 2
        sy = cy - nz * sh / 2
        uv.data[loop_index].uv = (sx / image.size[0], 1.0 - sy / image.size[1])
    obj = bpy.data.objects.new("Seal | raised source-matched wax", mesh)
    collection.objects.link(obj)
    bevel = obj.modifiers.new("Rounded wax edge", "BEVEL")
    bevel.width = 0.00022
    bevel.segments = 3
    bevel.material = 0
    normals = obj.modifiers.new("Soft wax normals", "WEIGHTED_NORMAL")
    normals.keep_sharp = True
    return obj


def make_studio(studio_collection):
    world = bpy.data.worlds.new("Soft warm-white studio") if not bpy.data.worlds else bpy.data.worlds[0]
    bpy.context.scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.97, 0.96, 0.94, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.95

    camera_data = bpy.data.cameras.new("Envelope product camera")
    camera = bpy.data.objects.new("Camera | front three-quarter", camera_data)
    studio_collection.objects.link(camera)
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = 0.315
    camera_data.lens = 55
    bpy.context.scene.camera = camera

    def aim_camera(position):
        camera.location = position
        direction = Vector((0.0, 0.0, 0.0)) - camera.location
        camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()

    def area_light(name, position, power, size, color):
        data = bpy.data.lights.new(name, "AREA")
        data.energy = power
        data.shape = "DISK"
        data.size = size
        data.color = color
        obj = bpy.data.objects.new(name, data)
        studio_collection.objects.link(obj)
        obj.location = position
        obj.rotation_euler = (Vector((0, 0, 0)) - obj.location).to_track_quat("-Z", "Y").to_euler()
        return obj

    aim_camera((0.11, -0.90, 0.11))
    area_light("Key | broad softbox", (-0.32, -0.38, 0.39), 0.9, 0.42, (1.0, 0.93, 0.84))
    area_light("Fill | cool softbox", (0.28, -0.36, 0.03), 0.5, 0.55, (0.84, 0.91, 1.0))
    area_light("Rim | paper edge", (0.02, 0.10, 0.32), 0.55, 0.38, (1.0, 0.95, 0.88))
    return camera, aim_camera


def render_view(scene, camera, aim_camera, position, path, resolution=(1600, 1200)):
    aim_camera(position)
    scene.render.resolution_x, scene.render.resolution_y = resolution
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def main():
    if not SOURCE.exists():
        raise FileNotFoundError(f"Place the supplied reference at: {SOURCE}")
    OUT.mkdir(parents=True, exist_ok=True)
    clear = clear_scene()
    model_collection, studio_collection = clear

    image = bpy.data.images.load(str(SOURCE), check_existing=False)
    if tuple(image.size) != (1280, 1280):
        raise RuntimeError(f"Expected 1280x1280 reference image, got {tuple(image.size)}")
    image.name = "SOURCE | exact user envelope artwork"
    front = new_image_material("Front | original painted paper artwork", image, 0.89)
    edge = new_simple_paper("Cut edge | warm pressed paper", (0.58, 0.43, 0.33), 0.9, 0.035)
    back = new_simple_paper("Reverse | warm cream stationery", (0.77, 0.65, 0.54), 0.93, 0.06)
    crease = new_simple_paper("Fold lines | soft beige impression", (0.55, 0.43, 0.34), 0.9, 0.025)
    wax_side = new_simple_paper("Wax edge | deep wine red", (0.27, 0.025, 0.045), 0.61, 0.025)

    create_body(model_collection, front, edge, back)
    create_back(model_collection, back, crease)
    create_seal(model_collection, front, wax_side, image)

    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 32
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 1200
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "Medium High Contrast"
    scene.view_settings.exposure = 0.0
    scene.view_settings.gamma = 1.0
    scene.render.image_settings.color_depth = "8"
    camera, aim_camera = make_studio(studio_collection)

    # Export only the envelope assembly, with the exact source image embedded.
    bpy.ops.object.select_all(action="DESELECT")
    for obj in model_collection.objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = next(obj for obj in model_collection.objects if obj.type == "MESH")
    bpy.ops.export_scene.gltf(filepath=str(GLB), export_format="GLB", use_selection=True)

    # Three saved review angles: source-faithful front, dimensional front, and real folded back.
    render_view(scene, camera, aim_camera, (0.045, -0.95, 0.018), OUT / "preview_front.png")
    render_view(scene, camera, aim_camera, (0.17, -0.90, 0.14), OUT / "preview_three_quarter.png")
    render_view(scene, camera, aim_camera, (0.035, 0.95, 0.018), OUT / "preview_back.png")

    image.pack()
    aim_camera((0.13, -0.94, 0.10))
    bpy.context.preferences.filepaths.save_version = 0
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type == "VIEW_3D":
                area.spaces.active.region_3d.view_perspective = "CAMERA"
                area.spaces.active.shading.type = "MATERIAL"
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = bpy.data.objects.get("Envelope | printed front and paper core")
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND), compress=True)
    print(f"MODEL_SAVED={BLEND}")
    print(f"GLB_SAVED={GLB}")
    print(f"REFERENCE_SIZE={tuple(image.size)}")
    print(f"MODEL_DIMENSIONS_M={WIDTH:.6f} x {HEIGHT:.6f} x {PAPER_THICKNESS:.6f}")


if __name__ == "__main__":
    main()

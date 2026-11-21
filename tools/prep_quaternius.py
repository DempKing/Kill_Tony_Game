"""Copy the Quaternius CC0 files the game uses into assets/models/quaternius,
downscale their textures and bake a clothing mask for each base body."""
import json, os, shutil, struct, sys
from PIL import Image, ImageDraw, ImageFilter

SRC = sys.argv[1]          # extracted zips dir
DST = sys.argv[2]          # assets/models/quaternius
UBC = os.path.join(SRC, "Universal Base Characters[Standard]")
BODY = os.path.join(UBC, "Base Characters", "Godot - UE")
HAIR = os.path.join(UBC, "Hairstyles", "Origin at 0", "glTF (Godot)")
CARS = os.path.join(SRC, "Realistic Car Pack - Nov 2018", "OBJ")

def find_image(src_dir, uri):
    """Some referenced images live elsewhere in the pack, or without '_png'."""
    for cand in [uri, uri.replace("_png.png", ".png")]:
        p = os.path.join(src_dir, cand)
        if os.path.exists(p):
            return p
        for root, _, files in os.walk(UBC):
            if cand in files:
                return os.path.join(root, cand)
    raise FileNotFoundError(uri)

def copy_gltf(src_dir, name, out_dir, tex_size=512):
    os.makedirs(out_dir, exist_ok=True)
    d = json.load(open(os.path.join(src_dir, name + ".gltf")))
    for b in d["buffers"]:
        shutil.copy(os.path.join(src_dir, b["uri"]), out_dir)
    for im in d.get("images", []):
        uri = im["uri"]
        img = Image.open(find_image(src_dir, uri))
        size = 128 if "Eye" in uri else tex_size
        img.thumbnail((size, size), Image.LANCZOS)
        img.save(os.path.join(out_dir, uri))
    shutil.copy(os.path.join(src_dir, name + ".gltf"), out_dir)
    return d

def accessor(d, binbytes, idx):
    a = d["accessors"][idx]
    bv = d["bufferViews"][a["bufferView"]]
    comps = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[a["type"]]
    fmt = {5126: "f", 5123: "H", 5125: "I", 5121: "B"}[a["componentType"]]
    size = struct.calcsize(fmt)
    stride = bv.get("byteStride", size * comps)
    off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    out = []
    for i in range(a["count"]):
        out.append(struct.unpack_from("<" + fmt * comps, binbytes, off + i * stride))
    return out

def bake_mask(d, out_dir, size=512):
    """R = shirt, G = pants, B = shoes, by each triangle's rest-pose position."""
    binbytes = open(os.path.join(out_dir, d["buffers"][0]["uri"]), "rb").read()
    mesh = d["meshes"][2]["primitives"][0]
    pos = accessor(d, binbytes, mesh["attributes"]["POSITION"])
    uv = accessor(d, binbytes, mesh["attributes"]["TEXCOORD_0"])
    idx = [i[0] for i in accessor(d, binbytes, mesh["indices"])]
    H = max(p[1] for p in pos)
    img = Image.new("RGB", (size, size), (0, 0, 0))
    dr = ImageDraw.Draw(img)
    for t in range(0, len(idx), 3):
        tri = idx[t:t + 3]
        cx = sum(abs(pos[i][0]) for i in tri) / 3.0
        cy = sum(pos[i][1] for i in tri) / 3.0
        col = (0, 0, 0)
        if cy < 0.065 * H:
            col = (0, 0, 255)                       # shoes
        elif cy < 0.56 * H and cx < 0.3:
            col = (0, 255, 0)                       # pants (hips and legs)
        elif cx > 0.16 and cx < 0.6 and cy > 0.7 * H:
            col = (255, 0, 0)                       # sleeves (arms are out in T-pose)
        elif cx <= 0.16 and (cy < 0.795 * H or (cy < 0.835 * H and cx > 0.075)):
            col = (255, 0, 0)                       # torso, up to the collar
        if col == (0, 0, 0):
            continue
        dr.polygon([(uv[i][0] * size, uv[i][1] * size) for i in tri], fill=col)
    img = img.filter(ImageFilter.MaxFilter(5))      # close UV seams
    img.save(os.path.join(out_dir, d["_mask_name"]))

chars = os.path.join(DST, "characters")
for g in ["Male", "Female"]:
    name = f"Superhero_{g}_FullBody"
    d = copy_gltf(BODY, name, chars)
    d["_mask_name"] = f"T_{g}_ClothesMask.png"
    bake_mask(d, chars)
    # Light skin texture too (the gltf references the dark one).
    light = {"Male": "T_Superhero_Male_Ligh.png", "Female": "T_Superhero_Female_Light_BaseColor.png"}[g]
    img = Image.open(find_image(BODY, light)); img.thumbnail((512, 512), Image.LANCZOS)
    img.save(os.path.join(chars, light))
for h in ["Hair_SimpleParted", "Hair_Long", "Hair_Buns", "Hair_Buzzed", "Hair_BuzzedFemale", "Hair_Beard"]:
    copy_gltf(HAIR, h, os.path.join(DST, "hair"))
os.makedirs(os.path.join(DST, "cars"), exist_ok=True)
for c in ["NormalCar1", "NormalCar2", "SUV", "Taxi", "SportsCar", "Cop"]:
    for ext in (".obj", ".mtl"):
        shutil.copy(os.path.join(CARS, c + ext), os.path.join(DST, "cars"))
for lic, sub in [(os.path.join(UBC, "License_Standard.txt"), "characters"), (os.path.join(SRC, "Universal Animation Library[Standard]", "License.txt"), "animations"), (os.path.join(SRC, "Realistic Car Pack - Nov 2018", "License.txt"), "cars")]:
    os.makedirs(os.path.join(DST, sub), exist_ok=True)
    shutil.copy(lic, os.path.join(DST, sub, "LICENSE.txt"))
print("done")

"""Writes the app's history file (EasyStash JSON) for a screenshot-only container, using the preview persons."""
import base64, io, json, os, sys, time
from PIL import Image

out_path = sys.argv[1]
APPLE_REF = 978307200  # JSONEncoder default: seconds since 2001-01-01
PERSONS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..",
                       "Resources", "Preview Content", "Preview Assets.xcassets", "Persons")
# (person index, minutes ago), newest first
SAMPLES = [(0, 0), (1, 26), (2, 75), (3, 140), (4, 300), (5, 520)]

now = time.time()
dtos = []
for index, minutes_ago in SAMPLES:
    path = os.path.join(PERSONS, f"person-{index}.imageset", f"person-{index}.png")
    buf = io.BytesIO()
    Image.open(path).convert("RGB").resize((1280, 720), Image.LANCZOS).save(buf, "JPEG", quality=80)
    dtos.append({
        "date": now - minutes_ago * 60 - APPLE_REF,
        "data": base64.b64encode(buf.getvalue()).decode(),
    })
with open(out_path, "w") as f:
    json.dump({"dtos": dtos}, f)

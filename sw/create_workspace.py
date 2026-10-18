#   vitis -s sw/create_workspace.py
import os
import shutil
import vitis

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ws = os.path.join(root, "vitis")
xsa = os.path.join(root, "vivado", "dds_system.xsa")
src = os.path.join(root, "sw")

client = vitis.create_client()
client.set_workspace(path=ws)

for name in ("platform", "dds_firmware"):
    path = os.path.join(ws, name)
    if os.path.isdir(path):
        try:
            client.delete_component(name=name)
        except Exception:
            pass
        shutil.rmtree(path, ignore_errors=True)

platform = client.create_platform_component(
    name="platform", hw_design=xsa, os="standalone",
    cpu="microblaze_0", domain_name="standalone_microblaze_0", compiler="gcc")
platform.build()

xpfm = os.path.join(ws, "platform", "export", "platform", "platform.xpfm")
app = client.create_app_component(
    name="dds_firmware", platform=xpfm, domain="standalone_microblaze_0",
    template="empty_application")
app.import_files(from_loc=src, files=sorted(f for f in os.listdir(src) if f.endswith((".c", ".h"))), dest_dir_in_cmp="src")
app.build()

vitis.dispose()

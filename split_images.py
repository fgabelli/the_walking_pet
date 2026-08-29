
from PIL import Image
import os

def split_image(image_path, out_prefix):
    try:
        img = Image.open(image_path)
        width, height = img.size
        # Assume split is vertical in the middle
        mid_x = width // 2
        
        left_part = img.crop((0, 0, mid_x, height))
        right_part = img.crop((mid_x, 0, width, height))
        
        left_part.save(f"{out_prefix}_left.png")
        right_part.save(f"{out_prefix}_right.png")
        print(f"Split {image_path}: {width}x{height} -> {mid_x}x{height}")
    except Exception as e:
        print(f"Error splitting {image_path}: {e}")

split_image('assets/images/dogzn/dogzn_app_icon.jpg', 'assets/images/dogzn/dogzn_app_icon_split')
split_image('assets/images/dogzn/dogzn_master_logo.jpg', 'assets/images/dogzn/dogzn_master_logo_split')

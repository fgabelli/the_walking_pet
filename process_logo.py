from PIL import Image

def process_logo(input_path, output_path):
    # Open the image
    img = Image.open(input_path)
    img = img.convert("RGBA")
    datas = img.getdata()

    newData = []
    # Make white pixels transparent
    for item in datas:
        # Check if the pixel is white (or very close to white)
        if item[0] > 240 and item[1] > 240 and item[2] > 240:
            newData.append((255, 255, 255, 0))  # Transparent
        else:
            newData.append(item)

    img.putdata(newData)

    # Crop to content (bounding box of non-transparent pixels)
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)

    # Save
    img.save(output_path, "PNG")
    print(f"Processed image saved to {output_path}")

if __name__ == "__main__":
    process_logo(
        "/Users/f.gabelli/.gemini/antigravity/brain/18e65549-3a93-46a7-acb7-da453841c3d7/dogzn_logo_white_bg_final_1770667689178.png",
        "web/icons/logo_horizontal.png"
    )
    process_logo(
        "/Users/f.gabelli/.gemini/antigravity/brain/18e65549-3a93-46a7-acb7-da453841c3d7/dogzn_logo_white_bg_final_1770667689178.png",
        "web/logo_horizontal.png"
    )

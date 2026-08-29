from PIL import Image, ImageDraw, ImageFont

def create_splash_logo(input_path, output_path):
    # Open the logo
    logo = Image.open(input_path).convert("RGBA")
    
    # Calculate new canvas size
    # Increase height to accommodate subtitle
    new_width = logo.width
    new_height = int(logo.height * 1.4) # 40% more height for subtitle
    
    # Create transparent canvas
    canvas = Image.new("RGBA", (new_width, new_height), (0, 0, 0, 0))
    
    # Paste logo at top
    canvas.paste(logo, (0, 0), logo)
    
    # Add Text "The Walking Pet"
    draw = ImageDraw.Draw(canvas)
    
    try:
        # Try to load a font, fallback to default if not found
        # Using a large size relative to the logo height
        font_size = int(logo.height * 0.25)
        # Try to find a system font
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", font_size)
    except:
        font = ImageFont.load_default()

    text = "The Walking Pet"
    
    # Get text bounding box for centering
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    
    # Calculate position (centered horizontally, below logo)
    x = (new_width - text_width) // 2
    y = logo.height + int(logo.height * 0.05) # 5% spacing
    
    # Draw text in White
    draw.text((x, y), text, font=font, fill=(255, 255, 255, 255))
    
    # Crop to content
    final_bbox = canvas.getbbox()
    if final_bbox:
        canvas = canvas.crop(final_bbox)

    canvas.save(output_path, "PNG")
    print(f"Splash logo saved to {output_path}")

if __name__ == "__main__":
    create_splash_logo("temp_splash.png", "assets/images/dogzn/dogzn_splash_logo.png")

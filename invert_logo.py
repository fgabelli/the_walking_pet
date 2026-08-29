from PIL import Image
import numpy as np

def invert_logo(input_path, output_path):
    # Open the image
    img = Image.open(input_path).convert("RGBA")
    data = np.array(img)

    # Define colors
    navy_blue = (10, 35, 66)    # #0A2342 (approximate dark background)
    white = (255, 255, 255)     # Text color
    orange = (255, 107, 0)      # #FF6B00 (approximate orange)
    
    # Create new image array
    new_data = np.zeros_like(data)
    
    # Iterate through pixels (this is a simple threshold approach)
    # R, G, B, A
    r, g, b, a = data[:,:,0], data[:,:,1], data[:,:,2], data[:,:,3]
    
    # Identify background (Dark Blue) -> Turn to Transparent
    # Using a threshold because of compression artifacts
    is_background = (r < 50) & (g < 60) & (b < 100)
    
    # Identify white text/shapes -> Turn to Dark Navy Blue #0A2342
    is_white = (r > 200) & (g > 200) & (b > 200)
    
    # Identify orange -> Keep Orange
    # Orange is high Red, medium Green, low Blue
    is_orange = (r > 200) & (g > 80) & (g < 180) & (b < 50)

    # Apply transformations
    
    # 1. Background -> Transparent
    new_data[is_background] = [0, 0, 0, 0]
    
    # 2. White Text/Paw -> Dark Navy Blue with full opacity
    new_data[is_white] = [10, 35, 66, 255]
    
    # 3. Orange Element -> Keep Orange (copy original pixels)
    new_data[is_orange] = data[is_orange]
    
    # 4. Handle edges/anti-aliasing (pixels that don't fall strictly into buckets)
    # For simplicity in this script, we'll let anything else stay as is, 
    # but we might need to force semi-transparent pixels to be dark instead of light.
    # A simple way is: if it's not background and not orange, make it dark blue.
    other_pixels = (~is_background) & (~is_orange) & (~is_white)
    # new_data[other_pixels] = [10, 35, 66, 255] # Optional: force others to dark blue

    # Create image from array
    new_img = Image.fromarray(new_data)
    
    # Crop to content
    bbox = new_img.getbbox()
    if bbox:
        new_img = new_img.crop(bbox)

    new_img.save(output_path, "PNG")
    print(f"Inverted logo saved to {output_path}")

if __name__ == "__main__":
    invert_logo("temp_logo_to_invert.png", "web/icons/logo_horizontal.png")
    invert_logo("temp_logo_to_invert.png", "web/logo_horizontal.png")

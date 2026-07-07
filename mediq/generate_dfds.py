import os
import sys

# Ensure pillow is installed
try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "pillow"])
    from PIL import Image, ImageDraw, ImageFont

def draw_rounded_rect(draw, x1, y1, x2, y2, rx, fill_color, border_color, border_width=2):
    draw.rounded_rectangle([x1, y1, x2, y2], radius=rx, fill=fill_color, outline=border_color, width=border_width)

def draw_arrow(draw, start_x, start_y, end_x, end_y, text="", color=(103, 58, 183), font=None, text_offset_y=-15):
    # Draw line
    draw.line([start_x, start_y, end_x, end_y], fill=color, width=2)
    
    # Draw arrowhead
    import math
    dx = end_x - start_x
    dy = end_y - start_y
    angle = math.atan2(dy, dx)
    arrow_len = 10
    arrow_angle = math.pi / 6 # 30 degrees
    
    x1 = end_x - arrow_len * math.cos(angle - arrow_angle)
    y1 = end_y - arrow_len * math.sin(angle - arrow_angle)
    x2 = end_x - arrow_len * math.cos(angle + arrow_angle)
    y2 = end_y - arrow_len * math.sin(angle + arrow_angle)
    
    draw.polygon([end_x, end_y, x1, y1, x2, y2], fill=color)
    
    if text:
        text_x = (start_x + end_x) / 2
        text_y = (start_y + end_y) / 2 + text_offset_y
        draw.text((text_x, text_y), text, fill=(60, 66, 87), font=font, anchor="mm")

def draw_data_store(draw, x1, y1, x2, y2, label, store_id, fill_color=(227, 242, 253), border_color=(13, 71, 161), font=None):
    # Standard DFD Data store has open sides. We will draw top and bottom lines, and a vertical bar on the left.
    draw.rectangle([x1, y1, x2, y2], fill=fill_color)
    draw.line([x1, y1, x2, y1], fill=border_color, width=2) # Top line
    draw.line([x1, y2, x2, y2], fill=border_color, width=2) # Bottom line
    draw.line([x1 + 35, y1, x1 + 35, y2], fill=border_color, width=2) # Divider
    draw.line([x1, y1, x1, y2], fill=border_color, width=2) # Left edge
    
    draw.text((x1 + 17, (y1 + y2)/2), store_id, fill=border_color, font=font, anchor="mm")
    draw.text((x1 + 45, (y1 + y2)/2), label, fill=(13, 71, 161), font=font, anchor="lm")

def create_dfd_level_0():
    img = Image.new("RGB", (1000, 600), "white")
    draw = ImageDraw.Draw(img)
    
    try:
        font = ImageFont.truetype("arial.ttf", 14)
        font_bold = ImageFont.truetype("arialbd.ttf", 15)
        font_small = ImageFont.truetype("arial.ttf", 11)
    except IOError:
        font = ImageFont.load_default()
        font_bold = ImageFont.load_default()
        font_small = ImageFont.load_default()

    # Title
    draw.text((500, 30), "MediQ Antibiotic Management System - DFD Level 0 (Context Diagram)", fill=(103, 58, 183), font=font_bold, anchor="mm")
    
    # Process 0.0
    draw_rounded_rect(draw, 400, 240, 600, 360, 20, (134, 90, 217), (103, 58, 183), 3)
    draw.text((500, 290), "0.0 MediQ System", fill="white", font=font_bold, anchor="mm")
    draw.text((500, 315), "Antibiotic Management", fill="white", font=font, anchor="mm")
    
    # Entities
    # Admin
    draw.rectangle([50, 80, 250, 150], fill=(226, 231, 243), outline=(144, 164, 174), width=2)
    draw.text((150, 115), "👤 Admin", fill=(28, 27, 31), font=font_bold, anchor="mm")
    
    # Pharmacist
    draw.rectangle([50, 450, 250, 520], fill=(226, 231, 243), outline=(144, 164, 174), width=2)
    draw.text((150, 485), "🧑‍⚕️ Pharmacist", fill=(28, 27, 31), font=font_bold, anchor="mm")
    
    # Firebase Auth
    draw.rectangle([750, 80, 950, 150], fill=(237, 242, 247), outline=(203, 213, 220), width=2)
    draw.text((850, 115), "🔐 Firebase Auth", fill=(45, 55, 72), font=font_bold, anchor="mm")
    
    # Cloudinary
    draw.rectangle([750, 450, 950, 520], fill=(237, 242, 247), outline=(203, 213, 220), width=2)
    draw.text((850, 485), "☁️ Cloudinary API", fill=(45, 55, 72), font=font_bold, anchor="mm")

    # Connective Flows
    # Admin -> System
    draw_arrow(draw, 250, 105, 410, 240, "Credentials & Setup Info", font=font_small)
    draw_arrow(draw, 400, 260, 250, 125, "Stats, Logs & Confirmations", font=font_small)
    
    # Pharmacist -> System
    draw_arrow(draw, 250, 495, 410, 360, "Usage Logs & Images", font=font_small, text_offset_y=15)
    draw_arrow(draw, 400, 340, 250, 475, "Receipts & Profile Updates", font=font_small, text_offset_y=15)
    
    # System -> Firebase Auth
    draw_arrow(draw, 600, 260, 750, 125, "Verify Credentials", font=font_small)
    draw_arrow(draw, 750, 105, 590, 240, "Verification Token", font=font_small)
    
    # System -> Cloudinary
    draw_arrow(draw, 600, 340, 750, 475, "Upload Binary Photo", font=font_small, text_offset_y=15)
    draw_arrow(draw, 750, 495, 590, 360, "Hosted Image URL", font=font_small, text_offset_y=15)

    img.save("dfd_level_0.png")

def create_dfd_level_1():
    img = Image.new("RGB", (1200, 900), "white")
    draw = ImageDraw.Draw(img)
    
    try:
        font = ImageFont.truetype("arial.ttf", 12)
        font_bold = ImageFont.truetype("arialbd.ttf", 13)
        font_title = ImageFont.truetype("arialbd.ttf", 18)
    except IOError:
        font = ImageFont.load_default()
        font_bold = ImageFont.load_default()
        font_title = ImageFont.load_default()

    # Title
    draw.text((600, 30), "MediQ System - DFD Level 1 (Detailed Processes & Firestore Stores)", fill=(103, 58, 183), font=font_title, anchor="mm")
    
    # Entities
    # Admin
    draw.rectangle([30, 100, 150, 150], fill=(226, 231, 243), outline=(144, 164, 174), width=1)
    draw.text((90, 125), "👤 Admin", fill="black", font=font_bold, anchor="mm")
    
    # Pharmacist
    draw.rectangle([30, 700, 150, 750], fill=(226, 231, 243), outline=(144, 164, 174), width=1)
    draw.text((90, 725), "🧑‍⚕️ Pharmacist", fill="black", font=font_bold, anchor="mm")
    
    # Firebase Auth (Ext System)
    draw.rectangle([1020, 100, 1170, 150], fill=(237, 242, 247), outline=(203, 213, 220), width=1)
    draw.text((1095, 125), "🔐 Firebase Auth", fill="black", font=font_bold, anchor="mm")
    
    # Cloudinary (Ext System)
    draw.rectangle([1020, 700, 1170, 750], fill=(237, 242, 247), outline=(203, 213, 220), width=1)
    draw.text((1095, 725), "☁️ Cloudinary API", fill="black", font=font_bold, anchor="mm")

    # Data Stores
    draw_data_store(draw, 700, 100, 880, 140, "users collection", "D1", font=font)
    draw_data_store(draw, 700, 180, 880, 220, "wards collection", "D2", font=font)
    draw_data_store(draw, 700, 260, 880, 300, "antibiotics collection", "D3", font=font)
    draw_data_store(draw, 700, 340, 880, 380, "book_numbers collection", "D4", font=font)
    draw_data_store(draw, 700, 420, 880, 460, "main_stock collection", "D5", font=font)
    draw_data_store(draw, 700, 500, 880, 540, "releases collection", "D6", font=font)
    draw_data_store(draw, 700, 580, 880, 620, "return_stock collection", "D7", font=font)
    draw_data_store(draw, 700, 660, 880, 700, "returns collection", "D8", font=font)

    # Processes
    processes = [
        ("1.0 Authenticate & Route", 300, 100),
        ("2.0 Manage User Profiles", 300, 200),
        ("3.0 Manage Wards & Drugs", 300, 300),
        ("4.0 Manage Book Registers", 300, 400),
        ("5.0 Manage Stock Inventory", 300, 500),
        ("6.0 Record Releases & Returns", 300, 600),
        ("7.0 Compile Usage Statistics", 300, 700),
        ("8.0 Edit Profile Settings", 300, 800)
    ]
    
    for label, px, py in processes:
        draw_rounded_rect(draw, px, py, px + 250, py + 45, 8, (134, 90, 217), (103, 58, 183), 2)
        draw.text((px + 125, py + 22), label, fill="white", font=font_bold, anchor="mm")

    # Connective Flows lines
    # Admin -> P1.0, P2.0, P3.0, P4.0, P5.0
    draw_arrow(draw, 150, 120, 300, 120, "Credentials", font=font)
    draw_arrow(draw, 150, 130, 300, 210, "Create profile", font=font)
    draw_arrow(draw, 150, 140, 300, 310, "Ward / Drug setup", font=font)
    draw_arrow(draw, 150, 150, 300, 510, "Stock inputs", font=font)
    
    # Pharmacist -> P1.0, P6.0, P7.0, P8.0
    draw_arrow(draw, 150, 710, 300, 135, "Credentials", font=font)
    draw_arrow(draw, 150, 720, 300, 610, "Release/Return fields", font=font)
    draw_arrow(draw, 150, 730, 300, 720, "Query logs", font=font)
    draw_arrow(draw, 150, 740, 300, 810, "Edit profile", font=font)

    # Process to DB / API Flows
    # P1.0 to Firebase Auth and D1
    draw_arrow(draw, 550, 110, 1020, 120, "Auth details", font=font)
    draw_arrow(draw, 550, 120, 700, 120, "Fetch role", font=font)
    
    # P2.0 to D1
    draw_arrow(draw, 550, 220, 700, 130, "Write user profile", font=font)
    
    # P3.0 to D2 & D3
    draw_arrow(draw, 550, 310, 700, 200, "Write ward info", font=font)
    draw_arrow(draw, 550, 320, 700, 280, "Write drug info", font=font)
    
    # P4.0 to D4
    draw_arrow(draw, 550, 420, 700, 360, "Write book numbers", font=font)
    
    # P5.0 to D5
    draw_arrow(draw, 550, 520, 700, 440, "Update stock", font=font)
    
    # P6.0 to D6 & D7 & D8
    draw_arrow(draw, 550, 610, 700, 520, "Log release", font=font)
    draw_arrow(draw, 550, 620, 700, 600, "Log return stock", font=font)
    draw_arrow(draw, 550, 630, 700, 680, "Log return", font=font)
    
    # P7.0 from D6, D8 (Reads usage data to compile trends)
    draw_arrow(draw, 700, 530, 550, 710, "Usage details", font=font)
    draw_arrow(draw, 700, 690, 550, 720, "Return details", font=font)
    
    # P8.0 to Cloudinary and D1
    draw_arrow(draw, 550, 810, 1020, 730, "Upload Image", font=font)
    draw_arrow(draw, 1020, 740, 550, 825, "Image URL", font=font)
    draw_arrow(draw, 550, 830, 700, 140, "Write profile update", font=font)

    img.save("dfd_level_1.png")

if __name__ == "__main__":
    create_dfd_level_0()
    create_dfd_level_1()
    print("DFD PNGs generated successfully!")

# -*- coding: utf-8 -*-
import threading
import os
import shutil
from PIL import Image, ImageDraw2, ImageDraw, ImageFont
import random

count = range(0, 200)
path = './generatedNumberImages'
text = '0123456789X'

def start():
    if os.path.exists(path):
        shutil.rmtree(path)
    os.mkdir(path)

    for idx in count:
        t = threading.Thread(target=create_image, args=([idx]))
        t.start()

def create_image(idx):
    o_image = Image.open('background.png')

    drawBrush = ImageDraw.Draw(o_image)
    drawBrush.text((100 + random.randint(-30, 30), 20 + random.randint(-5, 5)), text, fill='black', font=ImageFont.truetype('./OCR-B 10 BT.ttf', 20 + random.randint(-5, 5)))

    o_image.rotate(random.randint(-2, 2)).save(path + '/%d.png' % idx)

if __name__ == '__main__':
    start()

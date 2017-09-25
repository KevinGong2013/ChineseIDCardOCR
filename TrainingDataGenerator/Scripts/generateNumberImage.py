# -*- coding: utf-8 -*-
import threading
import os
import shutil
from PIL import Image, ImageDraw2, ImageDraw, ImageFont, ImageEnhance
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

    o_image = ImageEnhance.Color(o_image).enhance(random.uniform(0, 2)) # 着色
    o_image = ImageEnhance.Brightness(o_image).enhance(random.uniform(0.3, 2)) #亮度
    o_image = ImageEnhance.Contrast(o_image).enhance(random.uniform(0.2, 2)) # 对比度
    o_image = ImageEnhance.Sharpness(o_image).enhance(random.uniform(0.2, 3.0)) #对比度
    o_image = o_image.rotate(random.randint(-2, 2))

    o_image.save(path + '/%d.png' % idx)

if __name__ == '__main__':
    start()

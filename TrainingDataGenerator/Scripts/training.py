# -*- coding: utf-8 -*-

import numpy as np

import keras

from keras.models import Sequential
from keras.layers import Conv2D, MaxPooling2D, Dense, Dropout, Flatten
from keras.utils import np_utils
from keras.preprocessing.image import ImageDataGenerator

from keras import backend as K
K.set_image_dim_ordering('tf')

num_rows = 28
num_cols = 28
num_channels = 1
num_classes = 11

#root= '/Users/Kevin/develop/Swift/4.0/ChineseIDCardOCR/TrainingDataGenerator/Scripts/signleImages'

train_data_generator = ImageDataGenerator(rescale=1./255).flow_from_directory(
                                                                             directory='./signleImages',
                                                                             save_to_dir='./debug/signleImages',
                                                                             save_prefix='d_',
                                                                             target_size=(28, 28),
                                                                             color_mode='grayscale',
                                                                             batch_size=200)
test_data_generator = ImageDataGenerator(rescale=1./255).flow_from_directory(
                                                                            directory='./testSignleImages',
                                                                            save_to_dir='./debug/signleImages',
                                                                            save_prefix='t_',
                                                                            target_size=(28, 28),
                                                                            color_mode='grayscale',
                                                                            batch_size=200)



model = Sequential()

model.add(Conv2D(32, (5, 5), input_shape=(28, 28, 1), activation='relu'))
model.add(MaxPooling2D(pool_size=(2, 2)))
model.add(Dropout(0.5))
model.add(Conv2D(64, (3, 3), activation='relu'))
model.add(MaxPooling2D(pool_size=(2, 2)))
model.add(Dropout(0.2))
model.add(Conv2D(128, (1, 1), activation='relu'))
model.add(MaxPooling2D(pool_size=(2, 2)))
model.add(Dropout(0.2))
model.add(Flatten())
model.add(Dense(128, activation='relu'))
model.add(Dense(num_classes, activation='softmax'))

model.compile(loss='categorical_crossentropy', optimizer='adam', metrics=['accuracy'])

# Training
model.fit_generator(generator=train_data_generator, steps_per_epoch=840, epochs=5, verbose=2) #FIXME: 应该降低 'X' 的权重

score = model.evaluate_generator(generator=test_data_generator, validation_steps=100)

print('Test score:', score[0])
print('Test accuracy:', score[1])
# Prepare model for inference
for k in model.layers:
    if type(k) is keras.layers.Dropout:
        model.layers.remove(k)

model.save('KGNetCNN.h5')
print('训练完成，执行`convert.py`转换模型文件吧')

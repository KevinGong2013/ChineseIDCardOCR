
import numpy as np

import keras

from keras.models import Sequential
from keras.layers import Conv2D, MaxPooling2D, Dense, Dropout, Flatten
from keras.utils import np_utils
from keras.preprocessing.image import load_img, img_to_array, ImageDataGenerator

from keras import backend as K
K.set_image_dim_ordering('tf')

num_rows = 28
num_cols = 28
num_channels = 1
num_classes = 11

#root= '/Users/Kevin/develop/Swift/4.0/ChineseIDCardOCR/TrainingDataGenerator/Scripts/signleImages'

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

model.fit_generator(generator, samples_per_epoch, nb_epoch)
# Training
model.fit(X_train, y_train, validation_data=(X_test, y_test), epochs=10, batch_size=200, verbose=2)

# Prepare model for inference
for k in model.layers:
    if type(k) is keras.layers.Dropout:
        model.layers.remove(k)

model.save('KGNetCNN.h5')
print('训练完成，执行`convert.py`转换模型文件吧')

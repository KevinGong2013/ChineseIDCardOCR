
import coremltools

output_labels = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'X']
scale = 1/255.

coreml_model = coremltools.converters.keras.convert('./KGNetCNN.h5',
                                                   input_names='image',
                                                   image_input_names='image',
                                                   output_names='output',
                                                   class_labels=output_labels,
                                                   image_scale=scale)

coreml_model.author = 'Kevin.Gong'
coreml_model.license = 'Apache License, Version 2.0'
coreml_model.short_description = 'Model to classify chinese IDCard numbers'

coreml_model.input_description['image'] = 'Grayscale image of card number'
coreml_model.output_description['output'] = 'Predicted digit'

coreml_model.save('KGNetCNN.mlmodel')

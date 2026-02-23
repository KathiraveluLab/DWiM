function img = readDICOM(filePath)

info = dicominfo(filePath);
img = dicomread(info);

figure;
imshow(img, []);
colormap gray;
title('DICOM Image');

end
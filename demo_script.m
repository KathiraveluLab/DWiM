file = dir('Cranial CT/*.dcm');
fullpath = fullfile(file(1).folder, file(1).name);

info = dicominfo(fullpath,'UseVRHeuristic',true);
disp(info.Modality)

img = dicomread(fullpath);
imshow(img, [])
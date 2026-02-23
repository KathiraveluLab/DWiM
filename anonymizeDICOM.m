function anonymizeDICOM(filePath, outputPath)

info = dicominfo(filePath);
img = dicomread(filePath);

info.PatientName = 'Anonymous';
info.PatientID = '000000';

dicomwrite(img, outputPath, info);

disp("Anonymized file saved.");

end
function convertToPNG(filePath, outputFolder)

img = dicomread(filePath);

[~, name, ~] = fileparts(filePath);
pngPath = fullfile(outputFolder, strcat(name,'.png'));

imwrite(mat2gray(img), pngPath);

disp("Saved: " + pngPath);

end
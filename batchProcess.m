function batchProcess(folderPath)

files = dir(fullfile(folderPath,'**','*.dcm'));

for i = 1:length(files)
    fullPath = fullfile(files(i).folder, files(i).name);
    
    extractMetadata(fullPath);
    convertToPNG(fullPath, folderPath);
    
end

end
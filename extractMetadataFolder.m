function metadataTable = extractMetadataFolder(folderPath)

files = dir(fullfile(folderPath, '*.dcm'));

% Preallocate cell arrays
PatientID = {};
Modality = {};
StudyDate = {};
Manufacturer = {};
FileName = {};

for i = 1:length(files)
    
    fullpath = fullfile(files(i).folder, files(i).name);
    
    try
        info = dicominfo(fullpath, 'UseVRHeuristic', true);
        
        % Safe field extraction
        if isfield(info,'PatientID')
            PatientID{end+1} = info.PatientID;
        else
            PatientID{end+1} = "NA";
        end
        
        if isfield(info,'Modality')
            Modality{end+1} = info.Modality;
        else
            Modality{end+1} = "NA";
        end
        
        if isfield(info,'StudyDate')
            StudyDate{end+1} = info.StudyDate;
        else
            StudyDate{end+1} = "NA";
        end
        
        if isfield(info,'Manufacturer')
            Manufacturer{end+1} = info.Manufacturer;
        else
            Manufacturer{end+1} = "NA";
        end
        
        FileName{end+1} = files(i).name;
        
    catch
        warning("Skipping corrupted file: %s", files(i).name);
    end
end

% Create table
metadataTable = table(FileName', PatientID', Modality', StudyDate', Manufacturer', ...
    'VariableNames', {'FileName','PatientID','Modality','StudyDate','Manufacturer'});

disp(metadataTable)

%Save to CSV
writetable(metadataTable, fullfile(folderPath, 'metadata_output.csv'));

end
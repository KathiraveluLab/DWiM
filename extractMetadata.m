function metadata = extractMetadata(filePath)

metadata = struct();

try
    info = dicominfo(filePath,'UseVRHeuristic',true);
catch ME
    warning("Failed to read DICOM file: %s", filePath);
    metadata.Error = "Invalid DICOM file";
    return;
end

% Safely extract fields
fields = {'PatientID','Modality','StudyDate','Manufacturer'};

for i = 1:length(fields)
    fieldName = fields{i};
    if isfield(info, fieldName)
        metadata.(fieldName) = info.(fieldName);
    else
        metadata.(fieldName) = "Not Available";
    end
end

disp(metadata);

end
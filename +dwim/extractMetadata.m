function metadata = extractMetadata(filename)
%EXTRACTMETADATA Extracts DICOM metadata from a specific file.
%
%   metadata = dwim.extractMetadata(filename)
%       Reads the DICOM headers from the specified file path and returns 
%       them as a structure using the standard dicominfo function.
%
%   Inputs:
%       filename - (string) Full or relative path to the DICOM file.
%
%   Outputs:
%       metadata - (struct) The raw DICOM tags returned by dicominfo.
%
%   Example:
%       data = dwim.extractMetadata('test_data/image01.dcm');
%       disp(data.PatientName);

    % Validate inputs using an arguments block (Best Practice)
    arguments
        filename (1,1) string
    end

    % 1. Validate file existence
    % We check this explicitly to provide a clear error message rather than
    % letting dicominfo crash obscurely.
    if ~isfile(filename)
        error('dwim:extractMetadata:FileNotFound', ...
              'The file "%s" was not found. Please check the path.', filename);
    end

    % 2. Attempt to read DICOM metadata
    try
        metadata = dicominfo(filename);
    catch ME
        % Wrap the error to give context, but pass the original message too.
        error('dwim:extractMetadata:ReadFailed', ...
              'Failed to read DICOM tags from "%s".\nReason: %s', ...
              filename, ME.message);
    end

end
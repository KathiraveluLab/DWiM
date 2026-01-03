function cleanS = sanitizeMetadata(s)
    % SANITIZEMETADATA Strips Private Tags and non-ASCII characters.
    % Path: C:\Users\surya\DWiM\+dwim\+internal\sanitizeMetadata.m

    arguments
        s (1,1) struct
    end

    cleanS = s;
    fields = fieldnames(s);

    for i = 1:numel(fields)
        fName = fields{i};
        
        % Rule: DICOM Private Tags have odd group numbers.
        % MATLAB's dicominfo represents tags as 'Group_Element'.
        if contains(fName, 'Private_') || isPrivateTag(fName)
            cleanS = rmfield(cleanS, fName);
            continue;
        end
        
        % Clean string values of null terminators or weird characters
        if ischar(s.(fName)) || isstring(s.(fName))
            cleanS.(fName) = strtrim(double(s.(fName))); % Simplified cleaning
        end
    end
end

function tf = isPrivateTag(tagName)
    % Private tags in MATLAB often look like 'Private_0019_1001' 
    % or rely on hex group numbers where the first digit of the group is odd.
    tf = startsWith(tagName, 'Private', 'IgnoreCase', true);
end
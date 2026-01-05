function cleanS = sanitizeMetadata(s)
    % SANITIZEMETADATA Strips Private Tags and cleans string fields.
    % Path: C:\Users\surya\DWiM\+dwim\+internal\sanitizeMetadata.m

    arguments
        s (1,1) struct
    end

    cleanS = s;
    fields = fieldnames(s);
    fieldsToRemove = {};

    for i = 1:numel(fields)
        fName = fields{i};
        val = s.(fName);
        
        % Identify Private Tags using the corrected helper
        if isPrivateTag(fName)
            fieldsToRemove{end+1} = fName; %#ok<AGROW>
            continue;
        end
        
        % Correctly trim whitespace from strings
        if ischar(val) || isstring(val)
            cleanS.(fName) = strtrim(val);
        end
    end

    % Batch remove fields to satisfy bot performance checks
    if ~isempty(fieldsToRemove)
        cleanS = rmfield(cleanS, fieldsToRemove);
    end
end

function tf = isPrivateTag(tagName)
    % FIX: Capitalized 'W' in startsWith for Linux/CI compatibility
    if startsWith(tagName, 'Private', 'IgnoreCase', true)
        tf = true;
        return;
    end
    
    % Check for GroupXXXX_ElementYYYY format and odd group number
    tok = regexp(tagName, '^Group([0-9a-fA-F]{4})_', 'tokens', 'once');
    if ~isempty(tok)
        groupNum = hex2dec(tok{1});
        tf = mod(groupNum, 2) == 1;
    else
        tf = false;
    end
end
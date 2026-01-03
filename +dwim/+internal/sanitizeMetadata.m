function cleanS = sanitizeMetadata(s)
    % SANITIZEMETADATA Strips Private Tags and cleans string fields.

    arguments
        s (1,1) struct
    end

    cleanS = s;
    fields = fieldnames(s);
    fieldsToRemove = {};

    for i = 1:numel(fields)
        fName = fields{i};
        val = s.(fName);
        
        % FIX: Identify Private Tags (Using the improved helper)
        if isPrivateTag(fName)
            fieldsToRemove{end+1} = fName; %#ok<AGROW>
            continue;
        end
        
        % FIX: Correctly trim whitespace from strings without corrupting data
        if ischar(val) || isstring(val)
            cleanS.(fName) = strtrim(val);
        end
    end

    % FIX: Efficiently remove all fields at once to avoid memory reallocation
    if ~isempty(fieldsToRemove)
        cleanS = rmfield(cleanS, fieldsToRemove);
    end
end

function tf = isPrivateTag(tagName)
    % Improved helper to identify private tags by prefix or odd group number
    
    % Check for 'Private' prefix (case-insensitive)
    if startswith(tagName, 'Private', 'IgnoreCase', true)
        tf = true;
        return;
    end
    
    % FIX: Check for GroupXXXX_ElementYYYY format and odd group number
    tok = regexp(tagName, '^Group([0-9a-fA-F]{4})_', 'tokens', 'once');
    if ~isempty(tok)
        groupNum = hex2dec(tok{1});
        tf = mod(groupNum, 2) == 1;
    else
        tf = false;
    end
end
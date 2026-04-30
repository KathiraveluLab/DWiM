function cleanS = sanitizeMetadata(s)
    arguments
        s (1,1) struct
    end

    cleanS = s;
    fields = fieldnames(s);
    fieldsToRemove = {}; % Buffer for batch removal

    for i = 1:numel(fields)
        fName = fields{i};
        val = s.(fName);
        
        % Logic simplified per bot suggestion
        if isPrivateTag(fName)
            fieldsToRemove{end+1} = fName; %#ok<AGROW>
            continue;
        end
        
        % Correct string trimming
        if ischar(val) || isstring(val)
            cleanS.(fName) = strtrim(val);
        end
    end

    % Perform removal once
    if ~isempty(fieldsToRemove)
        cleanS = rmfield(cleanS, fieldsToRemove);
    end
end

function tf = isPrivateTag(tagName)
    % Standard check for 'Private' prefix
    if startsWith(tagName, 'Private', 'IgnoreCase', true)
        tf = true;
        return;
    end
    
    % Bot Fix: Check for GroupXXXX_ElementYYYY format and odd groups
    tok = regexp(tagName, '^Group([0-9a-fA-F]{4})_', 'tokens', 'once');
    if ~isempty(tok)
        groupNum = hex2dec(tok{1});
        tf = mod(groupNum, 2) == 1;
    else
        tf = false;
    end
end
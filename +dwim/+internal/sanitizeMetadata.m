function cleanS = sanitizeMetadata(s)
    arguments
        s (1,1) struct
    end

    cleanS = s;
    fields = fieldnames(s);
    fieldsToRemove = {}; % Collect names for batch removal

    for i = 1:numel(fields)
        fName = fields{i};
        val = s.(fName);
        
        % Use helper as single source of truth
        if isPrivateTag(fName)
            fieldsToRemove{end+1} = fName; %#ok<AGROW>
            continue;
        end
        
        % Trim whitespace directly on string/char value
        if ischar(val) || isstring(val)
            cleanS.(fName) = strtrim(val);
        end
    end

    if ~isempty(fieldsToRemove)
        cleanS = rmfield(cleanS, fieldsToRemove);
    end
end

function tf = isPrivateTag(tagName)
    % Parse group number to detect odd groups
    if startsWith(tagName, 'Private', 'IgnoreCase', true)
        tf = true;
        return;
    end
    
    tok = regexp(tagName, '^Group([0-9a-fA-F]{4})_', 'tokens', 'once');
    if ~isempty(tok)
        groupNum = hex2dec(tok{1});
        tf = mod(groupNum, 2) == 1;
    else
        tf = false;
    end
end
function cleanS = sanitizeMetadata(s)
    % SANITIZEMETADATA Strips Private Tags and cleans string fields.
    % Path: C:\Users\surya\DWiM\+dwim\+internal\sanitizeMetadata.m

    arguments
        s (1,1) struct
    end

    cleanS = s;
    fields = fieldnames(s);

    for i = 1:numel(fields)
        fName = fields{i};
        val = s.(fName);
        
        % Rule: Identify and remove Private Tags
        if startsWith(fName, 'Private', 'IgnoreCase', true)
            cleanS = rmfield(cleanS, fName);
            continue;
        end
        
       
        if ischar(val) || isstring(val)
            cleanS.(fName) = strtrim(val);
        end
    end
end
function flats = flattenStruct(s, prefix)
    % FLATTENSTRUCT Recursively flattens a nested DICOM struct.
    % Optimized for memory by using a nested helper function.

    arguments
        s (1,1) struct
        prefix (1,1) string = ""
    end

    flats = struct();
    
    % Call the nested helper to populate the 'flats' struct in-place
    populateFlatStruct(s, prefix);

    function populateFlatStruct(currents, currentPrefix)
        % Handle empty structs early
        if isempty(fieldnames(currents))
            return;
        end

        fields = fieldnames(currents);

        for i = 1:numel(fields)
            fName = fields{i};
            val = currents.(fName);

            % Construct the new key name
            if currentPrefix == ""
                newKey = string(fName);
            else
                newKey = sprintf('%s_%s', currentPrefix, fName);
            end

            if isstruct(val)
                % Handle both single structs and 1xN struct arrays
                if numel(val) == 1
                    populateFlatStruct(val, newKey);
                else
                    for k = 1:numel(val)
                        itemKey = sprintf('%s_Item%d', newKey, k);
                        populateFlatStruct(val(k), itemKey);
                    end
                end
            elseif iscell(val)
                % Handle DICOM Sequences (cell arrays of structs)
                for j = 1:numel(val)
                    if isstruct(val{j})
                        itemKey = sprintf('%s_Item%d', newKey, j);
                        populateFlatStruct(val{j}, itemKey);
                    end
                end
            else
                % Base Case: Simple value assignment
                flats.(char(newKey)) = val;
            end
        end
    end
end
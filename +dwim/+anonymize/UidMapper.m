classdef UidMapper < handle
    % UIDMAPPER Maintains a consistent mapping of original IDs to anonymized IDs.
    
    properties (Access = private)
        Dictionary % A hash map to store our rules
    end
    
    methods
        function obj = UidMapper()
            % Constructor: Initialize an empty dictionary
            obj.Dictionary = containers.Map('KeyType', 'char', 'ValueType', 'char');
        end
        
        function newId = getNewId(obj, originalId, prefix)
            % Returns a consistent new ID for a given original ID
            arguments
                obj
                originalId (1,:) char
                prefix (1,1) string = "ANON_"
            end
            
            % If we haven't seen this patient before, invent a new ID
            if ~obj.Dictionary.isKey(originalId)
                rawUuid = char(java.util.UUID.randomUUID);
                obj.Dictionary(originalId) = char(prefix + rawUuid);
            end
            
            % Return the mapped ID
            newId = obj.Dictionary(originalId);
        end
    end
end
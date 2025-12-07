function cfg = config()
%CONFIG Returns the default configuration for DWiM.
%
%   cfg = dwim.config()
%       Returns a structure containing default settings for Orthanc
%       connection and general DWiM behavior.
%
%   Outputs:
%       cfg - (struct) Configuration structure with fields:
%           .Orthanc.BaseURL  - Default Orthanc server URL
%           .Orthanc.User     - Default username
%           .Orthanc.Password - Default password
%           .Defaults.Verbose - Default verbosity setting
%
%   Example:
%       settings = dwim.config();
%       disp(settings.Orthanc.BaseURL);

    % Orthanc server configuration
    cfg.Orthanc.BaseURL = "http://localhost:8042";
    cfg.Orthanc.User = "orthanc";
    cfg.Orthanc.Password = "orthanc";
    
    % Default behavior settings
    cfg.Defaults.Verbose = true;
end

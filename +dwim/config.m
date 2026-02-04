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
    % Load from environment variables with fallback defaults
    baseURL = getenv('DWIM_ORTHANC_BASEURL');
    if isempty(baseURL)
        cfg.Orthanc.BaseURL = "http://localhost:8042";
    else
        cfg.Orthanc.BaseURL = string(baseURL);
    end
    
    user = getenv('DWIM_ORTHANC_USER');
    if isempty(user)
        cfg.Orthanc.User = "orthanc";
    else
        cfg.Orthanc.User = string(user);
    end
    
    password = getenv('DWIM_ORTHANC_PASSWORD');
    if isempty(password)
        cfg.Orthanc.Password = "orthanc";
    else
        cfg.Orthanc.Password = string(password);
    end
    
    % Default behavior settings
    cfg.Defaults.Verbose = true;
end

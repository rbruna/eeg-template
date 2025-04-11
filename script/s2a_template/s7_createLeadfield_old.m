clc
clear
close all

% Sets the paths.
% config.path.head     = '../../template/headmodel/';
config.path.sens     = '../../template/sens/';
config.path.lead     = '../../template/leadfield/';
config.path.patt     = '*.mat';

% Action when the task have already been processed.
config.overwrite     = false;

% Sets the coil precision for the Elekta Neuromag system.
config.coilprec      = 2;


% Creates and output folder, if needed.
if ~exist ( config.path.lead, 'dir' ), mkdir ( config.path.lead ); end

% Saves the original path.
pathvar = path;

% Adds the 'functions' folder to the path.
addpath ( sprintf ( '%s/functions/', fileparts ( pwd ) ) );
addpath ( sprintf ( '%s/functions/', pwd ) );

% Adds, if needed, the FieldTrip folder to the path.
ft_path
ft_defaults

% Disables the FT feedback.
global ft_default;
ft_default.showcallinfo = 'no';
ft_default.checkconfig  = 'silent';

% Adds the FT toolboxes that will be required.
ft_hastoolbox ( 'spm8', 1, 1 );
ft_hastoolbox ( 'openmeeg', 1, 1 );


global my_silent
my_silent = true;


% Gets the files list.
files = dir ( sprintf ( '%s%s', config.path.sens, config.path.patt ) );

% Goes through all the files.
for file = 1: numel ( files )
    
    % Loads the sensor structure.
    sensdata  = load ( sprintf ( '%s%s', config.path.sens, files ( file ).name ) );
    
    
    if exist ( sprintf ( '%s%s.mat', config.path.lead, sensdata.subject ), 'file' ) && ~config.overwrite
        fprintf ( 1, 'Ignoring subject ''%s'' (Already calculated).\n', sensdata.subject );
        continue
    end
    
    fprintf ( 1, 'Working with subject ''%s''.\n', sensdata.subject );
    
    
    % Generates the magnetometer definition with the required precission.
    if isfield ( sensdata, 'grad' ) && ft_senstype ( sensdata.grad, 'neuromag306' )
        sensdata.grad = myfiff_read_sens ( [], sensdata.header, config.coilprec );
    end
    
    % Gets the probability of the data being EEG or MEG.
    if isfield ( sensdata, 'grad' ) && ~isempty ( sensdata.grad )
        
        % Fixes the sensor definition.
        grad      = my_fixsens ( sensdata.grad );
        
        % Converts the gradiometers units to SI units (meters).
        grad      = ft_convert_units ( grad, 'm' );
        
        % The bare minimum number of sensors is 30.
        hasmeg    = numel ( grad.label ) > 30;
    else
        hasmeg    = false;
    end
    if isfield ( sensdata, 'elec' ) && ~isempty ( sensdata.elec )
        
        % Fixes the sensor definition.
        elec      = my_fixsens ( sensdata.elec );
        
        % Converts the electrodes units to SI units (meters).
        elec      = ft_convert_units ( elec, 'm' );
        
        % The bare minimum number of sensors is 30.
        haseeg    = numel ( elec.label ) > 30;
    else
        haseeg    = false;
    end
    
    % Gets sure that the sensors are correctly identified.
    if ~hasmeg && ~haseeg
        fprintf ( 2, '  Data type in subject %s can not be correctly identified. Skipping.\n', epochdata.subject );
        continue
    elseif ~hasmeg
        grad      = [];
    elseif ~haseeg
        elec      = [];
    end
    
    
    fprintf ( 1, '  Loading the head model.\n' );
    
    % Loads the MRI based headmodel and grid.
    headdata = load ( sensdata.mriinfo.mrifile, 'mesh', 'grid', 'headmodel' );
    
%     % The sources are oriented with the axis of the MRI coordinate system.
%     headdata.grid.ori  = eye (3);
    
    % Transforms the headmodel and the grid to MEG coordinates.
    headdata.mesh      = ft_convert_units ( headdata.mesh, 'mm' );
    headdata.mesh      = ft_transform_geometry ( sensdata.mriinfo.transform, headdata.mesh );
    headdata.mesh      = ft_convert_units ( headdata.mesh, 'm' );
    
    headdata.headmodel = ft_convert_units ( headdata.headmodel, 'mm' );
    headdata.headmodel = ft_transform_geometry ( sensdata.mriinfo.transform, headdata.headmodel );
    headdata.headmodel = ft_convert_units ( headdata.headmodel, 'm' );
    
    headdata.grid      = ft_convert_units ( headdata.grid, 'mm' );
    headdata.grid      = ft_transform_geometry ( sensdata.mriinfo.transform, headdata.grid );
    headdata.grid      = ft_convert_units ( headdata.grid, 'm' );
    
    return
    fprintf ( 1, '  Calculating the lead field.\n' );
    
    % Translates the electrodes to the surface of the scalp.
    if haseeg
        scalp = headdata.headmodel.bnd ( strcmp ( headdata.headmodel.tissue, 'scalp' ) );
        for eindex = 1: size ( elec.elecpos, 1 )
            [ ~, Pm ] = NFT_dmp ( elec.elecpos ( eindex, : ), scalp.pos, scalp.tri );
            elec.elecpos ( eindex, : ) = Pm;
        end
        for eindex = 1: size ( elec.chanpos, 1 )
            [ ~, Pm ] = NFT_dmp ( elec.chanpos ( eindex, : ), scalp.pos, scalp.tri );
            elec.chanpos ( eindex, : ) = Pm;
        end
    end
    
    
    % Initializes the leadfield variable.
    sourcedata = [];
    sourcedata.subject   = sensdata.subject;
    sourcedata.channel   = [];
    sourcedata.grad      = grad;
    sourcedata.elec      = elec;
    sourcedata.sens      = [];
    sourcedata.mesh      = headdata.mesh;
    sourcedata.headmodel = headdata.headmodel;
    sourcedata.grid      = headdata.grid;
    
    % Calculates the leadfield for MEG.
    if hasmeg
        sourcedata.channel   = grad.label;
        sourcedata.sens      = grad;
        
        grid_meg             = my_leadfield ( sourcedata );
    end
    
    % Calculates the leadfield for EEG.
    if haseeg
        sourcedata.channel   = elec.label;
        sourcedata.sens      = elec;
        
        grid_eeg             = my_leadfield ( sourcedata );
    end
    
    % Joins the leadfields, if required.
    if hasmeg && haseeg
        sourcedata.channel   = cat ( 1, grad.label, elec.label );
        sourcedata.sens      = [];
        
        sourcedata.grid      = my_joinGrid ( grid_meg, grid_eeg );
    elseif hasmeg
        sourcedata.grid      = grid_meg;
    elseif haseeg
        sourcedata.grid      = grid_eeg;
    end
    
    
    % Removes the not needed parts of the head model.
    sourcedata.headmodel = rmfield ( sourcedata.headmodel, intersect ( fieldnames ( sourcedata.headmodel ), { 'hm_dsm' } ) );
    sourcedata.grid      = rmfield ( sourcedata.grid,      intersect ( fieldnames ( sourcedata.grid      ), { 'params' 'initial' } ) );
    
    return
    fprintf ( 1, '  Saving calculated lead field.\n' );
    
    % Saves the leadfield.
    save ( '-v6', sprintf ( '%s%s', config.path.lead, sensdata.subject ), '-struct', 'sourcedata' );
end

% Restores the original path.
path ( pathvar );

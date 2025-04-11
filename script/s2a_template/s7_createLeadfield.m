clc
clear
close all

% Sets the paths.
config.path.sens     = '../../template/sens/';
config.path.lead     = '../../template/leadfield/';
config.path.patt     = '*.mat';

% Action when the task have already been processed.
config.overwrite     = true;

% Sets the coil precision for the Elekta Neuromag system.
config.coilprec      = 2;


% Creates and output folder, if needed.
if ~exist ( config.path.lead, 'dir' ), mkdir ( config.path.lead ); end


% Adds the functions folders to the path.
addpath ( sprintf ( '%s/functions/', fileparts ( pwd ) ) );
addpath ( sprintf ( '%s/functions/', pwd ) );

% Adds, if needed, the FieldTrip folder to the path.
myft_path

% Adds the FT toolboxes that will be required.
ft_hastoolbox ( 'spm8', 1, 1 );
ft_hastoolbox ( 'openmeeg', 1, 1 );


% % Sets OpenMEEG in silent mode.
% global my_silent
% my_silent = true;


% Gets the files list.
files = dir ( sprintf ( '%s%s', config.path.sens, config.path.patt ) );

% Goes through all the files.
for file = 1: numel ( files )
    
    % Loads the transformation.
    transinfo  = load ( sprintf ( '%s%s', config.path.sens, files ( file ).name ) );
    
    
    if exist ( sprintf ( '%s%s.mat', config.path.lead, transinfo.subject ), 'file' ) && ~config.overwrite
        fprintf ( 1, 'Ignoring subject ''%s'' (Already calculated).\n', transinfo.subject );
        continue
    end
    
    fprintf ( 1, 'Working with subject ''%s''.\n', transinfo.subject );
    
    % If no MRI defined or no MRI file, skips.
    if ~isfield ( transinfo, 'mriinfo' ) || ~isfield ( transinfo.mriinfo, 'mrifile' )
        fprintf ( 1, '  No head model defined in the transformation file. Skipping.\n' );
        continue
    end
    if ~isfield ( transinfo.mriinfo, 'transform' )
        fprintf ( 1, '  No head model transformation defined in the transformation file. Skipping.\n' );
        continue
    end
    if ~exist ( transinfo.mriinfo.mrifile, 'file' )
        fprintf ( 1, '  No head model file. Skipping.\n' );
        continue
    end
    
    
    % Generates the magnetometer definition with the required precision.
    if isfield ( transinfo, 'grad' ) && ft_senstype ( transinfo.grad, 'neuromag306' )
        transinfo.grad = myfiff_read_sens ( [], transinfo.header, config.coilprec );
    end
    
    % Gets the probability of the data being EEG or MEG.
    if isfield ( transinfo, 'grad' ) && ~isempty ( transinfo.grad )
        
        % Fixes the sensor definition.
        grad      = my_fixsens ( transinfo.grad );
        
        % Converts the gradiometers units to SI units (meters).
        grad      = ft_convert_units ( grad, 'm' );
        
        % The bare minimum number of sensors is 30.
        hasmeg    = numel ( grad.label ) > 30;
    else
        hasmeg    = false;
    end
    if isfield ( transinfo, 'elec' ) && ~isempty ( transinfo.elec )
        
        % Fixes the sensor definition.
        elec      = my_fixsens ( transinfo.elec );
        
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
    
    
    % Gets the list of variables defined in the MRI file.
    fileinfo = whos ( '-file', transinfo.mriinfo.mrifile );
    
    % If no headmodel defined in the MRI file, skips.
    if ~all ( ismember ( { 'headmodel' 'grid' }, { fileinfo.name } ) )
        fprintf ( 1, '  No head model definition in the MRI file. Skipping.\n' );
        continue
    end
    
    
    fprintf ( 1, '  Loading the head model and source model.\n' );
    
    % Loads the MRI based headmodel and grid.
    headdata = load ( transinfo.mriinfo.mrifile, 'mesh', 'grid', 'headmodel' );
    
    % The sources are oriented with the axis of the MRI coordinate system.
    headdata.grid.ori  = eye (3);
    
    % Transforms the headmodel and the grid to MEG coordinates.
    headdata.mesh      = ft_convert_units ( headdata.mesh,      transinfo.mriinfo.unit );
    headdata.headmodel = ft_convert_units ( headdata.headmodel, transinfo.mriinfo.unit );
    headdata.grid      = ft_convert_units ( headdata.grid,      transinfo.mriinfo.unit );
    
    headdata.mesh      = ft_transform_geometry ( transinfo.mriinfo.transform, headdata.mesh );
    headdata.headmodel = ft_transform_geometry ( transinfo.mriinfo.transform, headdata.headmodel );
    headdata.grid      = ft_transform_geometry ( transinfo.mriinfo.transform, headdata.grid );
    
    % Transforms the head model and source model to SI units (meters).
    headdata.mesh      = ft_convert_units ( headdata.mesh,      'm' );
    headdata.headmodel = ft_convert_units ( headdata.headmodel, 'm' );
    headdata.grid      = ft_convert_units ( headdata.grid,      'm' );
    
    
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
    
    
    fprintf ( 1, '  Calculating the lead field.\n' );
    
    cfg                = [];
    cfg.headmodel      = headdata.headmodel;
    cfg.sourcemodel    = headdata.grid;
    
    % Calculates the leadfield for MEG.
    if hasmeg
        cfg.sens           = grad;
        cfg.channel        = grad.label;
        
        srcmodel_meg       = my_leadfield ( cfg );
    end
    
    % Calculates the leadfield for EEG.
    if haseeg
        cfg.sens           = elec;
        cfg.channel        = elec.label;
        
        srcmodel_eeg       = my_leadfield ( cfg );
    end
    
    % Joins the leadfields, if required.
    if hasmeg && haseeg
        srcmodel           = my_joinGrid ( srcmodel_meg, srcmodel_eeg );
    elseif hasmeg
        srcmodel           = srcmodel_meg;
    elseif haseeg
        srcmodel           = srcmodel_eeg;
    end
    
    
    fprintf ( 1, '  Saving calculated lead field.\n' );
    
    % Initializes the leadfield variable.
    leaddata           = [];
    leaddata.subject   = transinfo.subject;
    leaddata.channel   = srcmodel.label;
    leaddata.headshape = transinfo.headshape;
    leaddata.grad      = grad;
    leaddata.elec      = elec;
    leaddata.mesh      = headdata.mesh;
    leaddata.grid      = srcmodel;
    
    % Saves the leadfield.
    save ( '-v6', sprintf ( '%s%s', config.path.lead, transinfo.subject ), '-struct', 'leaddata' );
end

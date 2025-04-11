clc
clear
close all

% Sets the path.
config.path.head = '../../template/headmodel/';
config.path.patt = '*.mat';

% Action when the task have already been processed.
config.overwrite = true;

% Forward model ('singleshell' or 'auto').
config.model     = 'auto';

% Specific options for OpenMEEG.
config.trim      = true;
config.clean     = true;


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
files            = dir ( sprintf ( '%s%s', config.path.head, config.path.patt ) );

% Goes through all the files.
for findex = 1: numel ( files )
    
    % Loads the MRI data and extracts the surfaces and the source model.
    headdata         = load ( sprintf ( '%s%s', config.path.head, files ( findex ).name ), 'subject', 'mesh', 'grid' );
    
    fileinfo         = whos ( '-file', sprintf ( '%s%s', config.path.head, files ( findex ).name ) );
    if ismember ( 'headmodel', { fileinfo.name } ) && ~config.overwrite
        fprintf ( 1, 'Ignoring subject %s (Already calculated).\n', headdata.subject );
        continue
    end
    
    
    fprintf ( 1, 'Working on subject %s.\n', headdata.subject );
    
    % Initializes the head model to the geometrical definition of the head.
    headmodel        = headdata.mesh;
    
    
    fprintf ( 1, '  Creating the volumen conductor.\n' );
    
    % If single shell uses only the brain surface.
    if strcmp ( config.model, 'singleshell' ) || ismember ( headmodel.type, { 'singleshell' } )
        
        % Gets only the brain surface.
        headmodel.type   = 'singleshell';
        headmodel.bnd    = headmodel.bnd    ( strcmp ( headmodel.tissue, 'brain' ) );
        headmodel.tissue = headmodel.tissue ( strcmp ( headmodel.tissue, 'brain' ) );
        
%         % Creates the volume conduction model using FT-singleshell.
%         cfg              = [];
%         cfg.method       = 'singleshell';
%         headmodel        = ft_prepare_headmodel ( cfg, headmodel );
        
        % Initializes the volume conductor.
        headmodel        = myss_headmodel ( headmodel );
    end
    
    % If BEM uses the three surfaces.
    if strcmp ( config.model, 'bem' ) || ismember ( headmodel.type, { 'bem3', 'bem3FT', 'bem3NFT' } )
        
        % Checks that all the surfaces are available.
        if ~all ( ismember ( { 'brain', 'skull', 'scalp' }, headmodel.tissue ) )
            error ( 'Not all the surfaces required by BEM are available. Aborting.' );
        end
        
        % Initializes the volume conduction model using OpenMEEG.
        headmodel.cond   = [ 1 1/80 1 ] / 3;
        headmodel        = myom_headmodel ( headmodel );
        
        % The size of the head matrix is:
        % # of points + # of triangles - # of triangles in the outer mesh.
        
%         % The sources are oriented with the axis of the MRI coordinate system.
%         headdata.grid.ori = eye (3);
        
%         % Removes the orientation from the grid.
%         grid             = rmfield ( mridata.grid, 'ori' );
        
        % Creates the sources matrix using OpenMEEG.
        headmodel        = myom_sourcematrix ( headmodel, headdata.grid );
%         headmodel.dsm    = myom_dsm ( headmodel, headdata.grid );
%         headmodel.grid   = headdata.grid;
        
        
        % Calculates hm\dsm.
        headmodel        = myom_build_src ( headmodel, config.clean );
        
        % Trims the head matrix for EEG, if requested.
        if config.trim
            headmodel        = myom_trimmat ( headmodel );
        end
    end
    
    
    fprintf ( 1, '  Saving the volume conductor.\n' );
    
    % Saves the head model.
    save ( '-v6', sprintf ( '%s%s', config.path.head, headdata.subject ), '-append', 'headmodel' );
end

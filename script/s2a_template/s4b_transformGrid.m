clc
clear
close all

% Sets the path.
config.path.mri  = '../../template/anatomy/';
config.path.head = '../../template/headmodel/';
config.path.patt = '*.mat';

% Defines the template grid to use.
config.sources   = '../../template/grid/MNI-surface.mat';
% config.sources   = '../../template/grid/CTB-10mm.mat';

% Action when the task have already been processed.
config.overwrite = false;


% Adds the functions folders to the path.
addpath ( sprintf ( '%s/functions/', fileparts ( pwd ) ) );
addpath ( sprintf ( '%s/functions/', pwd ) );

% Adds, if needed, the FieldTrip folder to the path.
myft_path

% Adds the FT toolboxes that will be required.
ft_hastoolbox ( 'spm8', 1, 1 );
ft_hastoolbox ( 'openmeeg', 1, 1 );
ft_hastoolbox ( 'freesurfer', 1, 1 );


% Creates the output folder, if required.
if ~exist ( config.path.head, 'dir' ), mkdir ( config.path.head ); end


% Loads the sources template MRI and grid.
srctemp = load ( config.sources );


% Gets the files list.
files = dir ( sprintf ( '%s%s', config.path.mri, config.path.patt ) );

% Goes through all the files.
for file = 1: numel ( files )
    
    % Pre-loads the anatomy.
    srcdata           = load ( sprintf ( '%s%s', config.path.mri, files ( file ).name ), 'subject' );
    
    fileinfo          = whos ( '-file', sprintf ( '%s%s', config.path.mri, files ( file ).name ) );
    if ismember ( 'grid', { fileinfo.name } ) && ~config.overwrite
        fprintf ( 1, 'Ignoring subject %s. (Already calculated)\n', srcdata.subject );
        continue
    end
    
    
    fprintf ( 1, 'Working on subject %s.\n', srcdata.subject );
    
    % Loads the MRI data and extracts the masks.
    srcdata           = load ( sprintf ( '%s%s', config.path.mri, files ( file ).name ), 'subject', 'mri', 'landmark', 'transform', 'mesh', 'scalp' );
    mri               = srcdata.mri;
    transform         = srcdata.transform;
    mesh              = srcdata.mesh;
    
    % Unpacks the MRI.
    mri               = my_unpackmri ( mri );
    
    
    fprintf ( 1, '  Transforming MNI grid to subject space.\n' );
    
    % Transforms the MNI grid to subject's native space.
    srcmodel          = srctemp.grid;
    srcmodel          = ft_convert_units ( srcmodel, transform.unit );
    srcmodel          = ft_transform_geometry ( transform.mni2nat, srcmodel );
    srcmodel          = ft_convert_units ( srcmodel, 'm' );
    
    % Stores the original source definition.
    srcmodel.posori  = srctemp.grid.pos;
    if isfield ( srctemp.grid, 'nrm' )
        srcmodel.nrmori   = srctemp.grid.nrm;
    end
    
    
    % Moves the sources inside the brain surface for BEM methods.
    if strncmp ( mesh.type, 'bem', 3 )
        
        fprintf ( 1, '  Moving the sources inside the brain surface.\n' );
        
        % Creates a grid containing only the sources inside the brain.
        tmpgrid           = srcmodel;
        tmpgrid.pos       = tmpgrid.pos ( tmpgrid.inside, : );
        tmpgrid.inside    = true ( size ( tmpgrid.pos, 1 ), 1 );
        
        % Moves all the sources of the grid inside the brain surface.
        cfg               = [];
        cfg.sourcemodel   = tmpgrid;
        cfg.headmodel.bnd = mesh.bnd ( strcmp ( mesh.tissue, 'brain' ) );
        cfg.moveinward    = 0.001;
        cfg.inwardshift   = 0;
        
        tmpgrid           = ft_prepare_sourcemodel ( cfg );
        
        % Replaces the position of the sources inside the brain.
        srcmodel.pos ( srcmodel.inside, : ) = tmpgrid.pos;
    end
    
    
    fprintf ( 1, '  Saving the transformed grid.\n' );
    
    % Updates the anatomy data with the source model.
    srcdata.subject  = sprintf ( '%s_%s', srcdata.subject, srctemp.subject );
    srcdata.grid     = srcmodel;
    
    % Saves the head model.
    save ( '-v6', sprintf ( '%s%s', config.path.head, srcdata.subject ), '-struct', 'srcdata' );
end

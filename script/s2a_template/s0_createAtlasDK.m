clc
clear
close all

% Sets the paths.
config.path.mni   = '../../template/mni/MNI-ICBM152_3DT1.nii.gz';
config.path.fs    = '../../template/fs/';

% Sets the name of the FreeSurfer subject.
config.fssubj     = 'MNI-T1-single';
config.subject    = 'MNI-surface';
config.atlas      = 'Desikan-Killiany';


% Adds the functions folders to the path.
addpath ( sprintf ( '%s/functions/', fileparts ( pwd ) ) );
addpath ( sprintf ( '%s/functions/', pwd ) );
addpath ( sprintf ( '%s/functions_fs/', pwd ) );

% Adds, if needed, the FieldTrip folder to the path.
myft_path

% Adds the FT toolboxes that will be required.
ft_hastoolbox ( 'spm8', 1, 1 );
ft_hastoolbox ( 'freesurfer', 1, 1 );


fprintf ( 1, 'Loading the template anatomy.\n' );

% Loads the MRI template.
mri             = my_read_mri ( config.path.mni );

fprintf ( 1, 'Loading the FreeSurfer surfaces.\n' );

% Loads the FreeSurfer surfaces and metadata.
left_white       = myfs_readSurf ( sprintf ( '%s%s/surf/lh.white', config.path.fs, config.fssubj ) );
left_pial        = myfs_readSurf ( sprintf ( '%s%s/surf/lh.pial', config.path.fs, config.fssubj ) );
left_infl        = myfs_readSurf ( sprintf ( '%s%s/surf/lh.inflated', config.path.fs, config.fssubj ) );
right_white      = myfs_readSurf ( sprintf ( '%s%s/surf/rh.white', config.path.fs, config.fssubj ) );
right_pial       = myfs_readSurf ( sprintf ( '%s%s/surf/rh.pial', config.path.fs, config.fssubj ) );
right_infl       = myfs_readSurf ( sprintf ( '%s%s/surf/rh.inflated', config.path.fs, config.fssubj ) );

% Escales the surfaces to fit in the head model.
scalemat         = diag ( [ 0.96 0.96 0.96 1.00 ] );
left_white       = ft_transform_geometry ( scalemat, left_white );
left_pial        = ft_transform_geometry ( scalemat, left_pial );
right_white      = ft_transform_geometry ( scalemat, right_white );
right_pial       = ft_transform_geometry ( scalemat, right_pial );


fprintf ( 1, 'Loading the FreeSurfer parcellation.\n' );

% Reads the parcellation files.
[ left_label,  left_meta  ] = myfs_readAnnot ( sprintf ( '%s%s/label/lh.aparc.annot', config.path.fs, config.fssubj ) );
[ right_label, right_meta ] = myfs_readAnnot ( sprintf ( '%s%s/label/rh.aparc.annot', config.path.fs, config.fssubj ) );

% Removes the first area ('unknown').
left_meta        = left_meta  ( 2: end );
right_meta       = right_meta ( 2: end );

% Re-labels the areas.
[ ~, left_label  ] = ismember ( left_label,  cat ( 1, left_meta.label  ) );
[ ~, right_label ] = ismember ( right_label, cat ( 1, right_meta.label ) );
left_label       = uint32 ( left_label  ) * 2 - 1;
right_label      = uint32 ( right_label ) * 2;

% Labels each node in the surfaces.
left_white.area  = left_label;
left_pial.area   = left_label;
left_infl.area   = left_label;
right_white.area = right_label;
right_pial.area  = right_label;
right_infl.area  = right_label;


fprintf ( 1, 'Generating FieldTrip meshes from the FreeSurfer data.\n' );

% Generates a single cortical mesh per hemisphere.
left_mesh        = [];
left_mesh.pos    = left_pial.pos;
left_mesh.wpos   = left_white.pos;
left_mesh.ipos   = left_infl.pos;
left_mesh.tri    = left_pial.tri;
left_mesh.unit   = 'mm';

right_mesh       = [];
right_mesh.pos   = right_pial.pos;
right_mesh.wpos  = right_white.pos;
right_mesh.ipos  = right_infl.pos;
right_mesh.tri   = right_pial.tri;
right_mesh.unit  = 'mm';

% Generates the FreeSurfer mesh.
mesh             = [];
mesh.type        = 'freesurfer';
mesh.tissue      = { 'left_hemisphere' 'right_hemisphere' };
mesh.bnd         = [ left_mesh right_mesh ];
mesh.unit        = 'mm';

% Transforms the mesh to SI units (meters).
mesh             = ft_convert_units ( mesh, 'm' );


fprintf ( 1, 'Simplifying the source model.\n' );

% Gets the left and with surfaces for the grid.
left_src         = left_white;
right_src        = right_white;

% Calculates the normal vector for each vertex.
left_src.nrm     = ft_normals ( left_src.pos,  left_src.tri );
right_src.nrm    = ft_normals ( right_src.pos, right_src.tri );

% Makes a subsampling of the surface.
% ldummy           = reducepatch ( left_src.tri,  left_src.pos,  8408 ); % 4000
% rdummy           = reducepatch ( right_src.tri, right_src.pos, 8404 ); % 4000
left_dum         = reducepatch ( left_src.tri,  left_src.pos,  16832 ); % 8000
right_dum        = reducepatch ( right_src.tri, right_src.pos, 16804 ); % 8000

% Gets the correspondence in the original mesh.
[ ~, lindex ]    = ismember ( left_dum.vertices,  left_src.pos,  'rows' );
[ ~, rindex ]    = ismember ( right_dum.vertices, right_src.pos, 'rows' );

% Simplifies the source model.
left_src.pos     = left_src.pos   ( lindex, : );
left_src.tri     = uint32 ( left_dum.faces );
left_src.nrm     = left_src.nrm   ( lindex, : );
left_src.area    = left_src.area  ( lindex );
right_src.pos    = right_src.pos  ( rindex, : );
right_src.tri    = uint32 ( right_dum.faces );
right_src.nrm    = right_src.nrm  ( rindex, : );
right_src.area   = right_src.area ( rindex );

% Generates the source model structure.
srcmodel         = [];
srcmodel.pos     = cat ( 1, left_src.pos,  right_src.pos );
srcmodel.tri     = cat ( 1, left_src.tri,  right_src.tri + size ( left_src.pos, 1 ) );
srcmodel.nrm     = cat ( 1, left_src.nrm,  right_src.nrm );
srcmodel.area    = cat ( 1, left_src.area, right_src.area );
srcmodel.hemis   = uint32 ( srcmodel.area > 0 ) .* ( 2 - rem ( srcmodel.area, 2 ) );
srcmodel.index   = cat ( 1, lindex, rindex );
srcmodel.inside  = srcmodel.area > 0;
srcmodel.unit    = 'mm';

% Transforms the mesh to SI units (meters).
srcmodel         = ft_convert_units ( srcmodel, 'm' );


fprintf ( 1, 'Creating the atlas structure.\n' );

% Creates the left and right area names.
left_name        = strcat ( 'Left ',  { left_meta.name } );
right_name       = strcat ( 'Right ', { right_meta.name } );
all_name         = cat ( 1, left_name, right_name );
all_name         = all_name (:);

% Gets the left and right labels.
all_label        = cat ( 1, left_meta.label, right_meta.label );

% Generates the atlas.
atlas            = [];
atlas.atlas      = 'Desikan-Killiany';
atlas.label      = all_label;
atlas.name       = all_name;
atlas.nick       = all_name;
altas.pos        = nan ( numel ( atlas.name ), 3 );
atlas.order      = nan ( numel ( atlas.name ), 1 );
atlas.unit       = srcmodel.unit;

% Goes through each area.
for aindex = 1: numel ( atlas.name )
    
    % Gets the indexes for the current area.
    hits             = srcmodel.area == aindex;
    
    % Gets the centroid of the area.
    centroid         = mean ( srcmodel.pos ( hits, : ), 1 );
    
    % Stores the centroid for this area.
    atlas.pos ( aindex, : ) = centroid;
end


fprintf ( 1, 'Saving the template model.\n' );

% Generates the source model file.
srcatlas         = [];
srcatlas.subject = sprintf ( '%s_%s', config.subject, config.atlas );
srcatlas.mesh    = mesh;
srcatlas.grid    = srcmodel;
srcatlas.atlas   = atlas;

% Saves the template atlas.
save ( '-v6', srcatlas.subject, '-struct', 'srcatlas' );


% ft_plot_mesh ( srcdata.mesh.bnd, 'EdgeColor', 'none', 'FaceColor', [ 1 1 1 ] - eps, 'FaceAlpha', 0.2 )
% ft_plot_mesh ( srcdata.grid, 'VertexColor', srcdata.grid.area )
% lighting gouraud
% camlight
% rotate3d

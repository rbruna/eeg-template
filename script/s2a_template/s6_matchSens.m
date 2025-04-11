clc
clear
close all

% Sets the path.
config.path.head   = '../../template/headmodel/';
config.path.temp   = 'standard_1005.elc';
config.path.sens   = '../../template/sens/';
config.path.patt   = '*.mat';

% Scaling the sensor definition to match the template.
config.scale       = false;

config.overwrite   = true;


% Adds the functions folders to the path.
addpath ( sprintf ( '%s/functions', fileparts ( pwd ) ) )
addpath ( sprintf ( '%s/functions', pwd ) )

% Adds FieldTrip to the path.
myft_path


% Creates and output folder, if needed.
if ~exist ( config.path.sens, 'dir' ), mkdir ( config.path.sens ); end
    

fprintf ( 1, 'Loading the template file.\n' );

% Loads the electrode definition.
template           = ft_read_sens ( config.path.temp );

% Generates a fiducial structure.
if ~isfield ( template, 'fid' ) && all ( ismember ( { 'LPA', 'Nz', 'RPA' }, template.label ) )
    
    % Gets the landmark positions.
    fid                = [];
    fid.label          = { 'LPA' 'Nasion' 'RPA' }';
    fid.pos ( 1, : )   = template.chanpos ( strcmp ( template.label, 'LPA' ), : );
    fid.pos ( 2, : )   = template.chanpos ( strcmp ( template.label, 'Nz' ), : );
    fid.pos ( 3, : )   = template.chanpos ( strcmp ( template.label, 'RPA' ), : );
    
    % Adds the landmarks to the sensor definition.
    template.fid       = fid;
end

% Transforms the electrodes to Neuromag coordinates.
if isfield ( template, 'fid' )
    
    % Calculates the transformation matrix to Neuromag space.
    trans              = my_pos2neuromag ( template.fid );
    template           = ft_transform_geometry ( trans, template );
    
else
    error ( 'The electrode definition does not contain the Neuromag landmarks.' )
end


% Lists the head models.
files              = dir ( sprintf ( '%s%s', config.path.head, config.path.patt ) );

% Goes through each head model.
for findex = 1: numel ( files )
    
    % Pre-loads the data.
    headdata           = load ( sprintf ( '%s%s', config.path.head, files ( findex ).name ), 'subject' );
    
    if ~config.overwrite && exist ( sprintf ( '%s%s_%s.mat', config.path.sens, headdata.subject, template.type ), 'file' )
        fprintf ( 1, 'Ignoring subject %s (already calculated).\n', headdata.subject );
        continue
    end
    
    
    fprintf ( 1, 'Working with subject %s.\n', headdata.subject )
    
    % Loads the surface meshes.
    headdata           = load ( sprintf ( '%s%s', config.path.head, files ( findex ).name ), 'subject', 'transform', 'scalp', 'mesh' );
    
    % Gets the meshes of interest.
    mesh               = headdata.mesh;
    scalp              = headdata.scalp;

    % Transforms the meshes to SI units (meters).
    mesh               = ft_convert_units ( mesh, 'm' );
    scalp              = ft_convert_units ( scalp, 'm' );

    
    % Gets the list of transformations.
    transform          = headdata.transform;

    
    % Gets the template electrode definition.
    elec               = template;
    
    % Transforms the electrode definition to IS units (meters).
    elec               = ft_convert_units ( elec, 'm' );
    

    % Scales the sensor definition, if requested.
    if config.scale

        fprintf ( 1, '  Scaling the sensor definition to fit the head model.\n' );
        
        % Calculates the "size" of the template.
        % tpos               = scalp.fid.pos;
        hits               = scalp.pos ( :, 3 ) > -0.04;
        tpos               = scalp.pos ( hits, : );
        % tsize              = mean ( sqrt ( sum ( tpos  .^ 2, 2 ) ) );
        [ ~, tsize ]       = my_fitsphere ( tpos );
        
        % Calculates the "size" of the sensor definition.
        % epos               = elec.fid.pos;
        epos               = elec.elecpos;
        % esize              = sqrt ( mean ( sum ( epos .^ 2, 2 ) ) );
        [ ~, esize ]       = my_fitsphere ( epos );
        
        % Scales the template to approximately match the sensors.
        scale              = tsize / esize;
        elec.elecpos       = elec.elecpos * scale;
        elec.chanpos       = elec.chanpos * scale;
        elec.fid.pos       = elec.fid.pos * scale;
    end
    
    
    fprintf ( 1, '  Transforming the sensor definition to the template space.\n' );
    
    % % Transforms the electrode definition to native space.
    % trans              = headdata.transform.vox2nat / headdata.transform.vox2nm;
    % elec               = ft_convert_units ( elec, headdata.transform.unit );
    % elec               = ft_transform_geometry ( trans, elec );
    % elec               = ft_convert_units ( elec, 'm' );

    % Matches the fiducials in the sensor definition and the template.
    trans              = my_fitFiducials ( scalp, elec );
    elec               = ft_transform_geometry ( trans, elec );
    
    
    fprintf ( 1, '  Saving the sensor definition.\n' );
    
    % Sets the transformation data.
    mriinfo            = [];
    mriinfo.mrifile    = sprintf ( '%s%s', config.path.head, files ( findex ).name );
    mriinfo.transform  = eye (4);
    mriinfo.unit       = elec.unit;

    % Sets the head shape.
    headshape          = [];
    headshape.pos      = elec.elecpos;
    headshape.label    = repmat ( { 'point' }, numel ( elec.label ), 1 );
    headshape.fid      = elec.fid;

    % Greates a dummy gradiometer structure.
    grad               = [];
    grad.label         = {};
    grad.chanpos       = zeros ( 0, 3 );
    grad.chanori       = zeros ( 0, 3 );
    grad.coilpos       = zeros ( 0, 3 );
    grad.coilori       = zeros ( 0, 3 );
    grad.tra           = zeros ( 0, 0 );
    grad.unit          = 'm';

    
    % Prepares the output.
    sensdata           = [];
    sensdata.subject   = sprintf ( '%s_%s', headdata.subject, elec.type );
    sensdata.grad      = grad;
    sensdata.elec      = elec;
    sensdata.headshape = headshape;
    sensdata.mriinfo   = mriinfo;
    
    % Saves the data.
    save ( '-v6', sprintf ( '%s%s', config.path.sens, sensdata.subject ), '-struct', 'sensdata' )
end

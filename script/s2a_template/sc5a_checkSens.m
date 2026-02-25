clc
clear
close all

% Sets the path.
config.path.sens = '../../template/sens/';
config.path.figs = '../../figs-template/sens/';
config.path.patt = '*.mat';

% Selects which versions of the figure to save.
config.savefig   = false;
config.savegif   = true;


% Adds the functions folders to the path.
addpath ( sprintf ( '%s/functions', fileparts ( pwd ) ) )
addpath ( sprintf ( '%s/functions', pwd ) )

% Adds FieldTrip to the path.
myft_path


% Creates and output folder, if needed.
if ~exist ( config.path.figs, 'dir' ), mkdir ( config.path.figs ); end


% Lists the POM electrode definition files.
files  = dir ( sprintf ( '%s%s', config.path.sens, config.path.patt ) );

% Goes through each file.
for findex = 1: numel ( files )
    
    % Loads the sensors information.
    sensinfo  = load ( sprintf ( '%s%s', config.path.sens, files ( findex ).name ) );
    
    % If no MRI information, skips the file.
    if ~isfield ( sensinfo, 'mriinfo' ) || ~isfield ( sensinfo.mriinfo, 'mrifile' )
        fprintf ( 1, 'Skipping subject ''%s'' (no head model defined).\n', sensinfo.subject );
        continue
    end
    
    fprintf ( 1, 'Working with subject ''%s''.\n', sensinfo.subject );
    
    % Loads the head and source models.
    headdata  = load ( sensinfo.mriinfo.mrifile, 'mesh' );
    
    
    % If BEM, checks the geometry using OpenMEEG.
    if numel ( headdata.mesh.bnd ) == 3
        if myom_check_geometry ( headdata.mesh )
            fprintf ( 1, '  Surface meshes OK according to OpenMEEG.\n' );
        else
            fprintf ( 1, '  Surface meshes with errors according to OpenMEEG.\n' );
            fprintf ( 1, '  Press a key to continue.\n' );
            pause
        end
    end
    
    
    % Gets the surface mesh(es).
    mesh      = headdata.mesh;
    
    % Gets the sensor definition(s).
    elec      = sensinfo.elec;
    grad      = sensinfo.grad;

    
    % Transforms the surface and the source model to head coordinates.
    mesh      = ft_convert_units ( mesh, sensinfo.mriinfo.unit );
    mesh      = ft_transform_geometry ( sensinfo.mriinfo.transform, mesh );
    
    
    % Converts all the data into SI units (meters).
    mesh      = ft_convert_units ( mesh, 'm' );
    grad      = ft_convert_units ( grad, 'm' );
    elec      = ft_convert_units ( elec, 'm' );
    
    
    % % Projects the electrodes onto the mesh scalp surface.
    % for eindex = 1: size ( elec.elecpos, 1 )
    %     [ ~, Pm ]          = NFT_dmp ( elec.elecpos ( eindex, : ), scalp.bnd.pos, scalp.bnd.tri );
    %     elec.elecpos ( eindex, : ) = Pm;
    % end
    % for eindex = 1: size ( elec.chanpos, 1 )
    %     [ ~, Pm ]          = NFT_dmp ( elec.chanpos ( eindex, : ), scalp.bnd.pos, scalp.bnd.tri );
    %     elec.chanpos ( eindex, : ) = Pm;
    % end
    

    % Plots the surface mesh(es).
    for mindex = 1: numel ( mesh.tissue )
        switch mesh.tissue { mindex }
            case 'brain', meshcolor = 'brain';
            case 'skull', meshcolor = [ 1 1 1 ] - eps;
            case 'scalp', meshcolor = 'skin';
            otherwise,    meshcolor = [ 1 1 1 ] - eps;
        end
        
        ft_plot_mesh  ( mesh.bnd ( mindex ), 'facecolor', meshcolor, 'edgecolor', 'none', 'facealpha', .3 );
    end


    % Plots the sensors.
    ft_plot_mesh ( grad.chanpos, 'VertexColor', [ 0.6350 0.0780 0.1840 ], 'VertexMarker', 'o', 'VertexSize', 5 );
    ft_plot_mesh ( elec.chanpos, 'VertexColor', [ 0.6350 0.0780 0.1840 ], 'VertexMarker', '*', 'VertexSize', 5 );
    ft_plot_mesh ( elec.chanpos, 'VertexColor', [ 0.6350 0.0780 0.1840 ], 'VertexMarker', 'o', 'VertexSize', 5 );
    
    
    % Lights the scene.
    set ( gcf, 'Name', sensinfo.subject );
    view ( [ -140,   0 ] ), camlight
    lighting gouraud
    material dull
    rotate3d
    drawnow
    
    
    % Saves the figure.
    print ( '-dpng', sprintf ( '%s%s.png', config.path.figs, sensdata.subject ) )
    
    if config.savefig
        savefig ( sprintf ( '%s%s.fig', config.path.figs, sensdata.subject ) )
    end
    if config.savegif
        my_savegif ( sprintf ( '%s%s.gif', config.path.figs, sensdata.subject ) )
    end
    close all
end

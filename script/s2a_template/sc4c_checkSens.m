clc
clear
close all

% Sets the path.
config.path.sens     = '../../template/sens/';
config.path.figs     = '../../figs-template/sens/';
config.path.patt     = '*.mat';

% Selects which versions of the figure to save.
config.savefig       = false;
config.savegif       = true;


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
    
    % Loads the data.
    sensdata = load ( sprintf ( '%s%s', config.path.sens, files ( findex ).name ) );
    
    
    fprintf ( 1, 'Working with subject %s.\n', sensdata.subject );
    
    % Loads the head model.
    headdata = load ( sensdata.mriinfo.mrifile, 'mesh' );
    
    % Gets the mesh and the sensor definition.
    mesh     = headdata.mesh;
    elec     = sensdata.elec;
    
    % Transforms the mesh data into subject space.
    mesh     = ft_convert_units ( mesh,  sensdata.mriinfo.unit );
    mesh     = ft_transform_geometry ( sensdata.mriinfo.transform, mesh );
    mesh     = ft_convert_units ( mesh,  'm' );
    
    
    % % Projects the electrodes onto the mesh scalp surface.
    % for eindex = 1: size ( elec.elecpos, 1 )
    %     [ ~, Pm ]          = NFT_dmp ( elec.elecpos ( eindex, : ), scalp.bnd.pos, scalp.bnd.tri );
    %     elec.elecpos ( eindex, : ) = Pm;
    % end
    % for eindex = 1: size ( elec.chanpos, 1 )
    %     [ ~, Pm ]          = NFT_dmp ( elec.chanpos ( eindex, : ), scalp.bnd.pos, scalp.bnd.tri );
    %     elec.chanpos ( eindex, : ) = Pm;
    % end
    
    
    % Plots the three meshes and the electrodes.
    figure
    ft_plot_mesh ( mesh.bnd (3), 'EdgeColor', 'none', 'FaceColor', 'skin', 'FaceAlpha', 0.5 )
    ft_plot_mesh ( mesh.bnd (2), 'EdgeColor', 'none', 'FaceColor', [ 0.99 0.99 0.99 ], 'FaceAlpha', 0.5 )
    ft_plot_mesh ( mesh.bnd (1), 'EdgeColor', 'none', 'FaceColor', 'brain', 'FaceAlpha', 1.0 )
    ft_plot_sens ( elec, 'elecsize', 30, 'style', [ 1 0 0 ] )
    
    
    % Lights the scene.
    set ( gcf, 'Name', sensdata.subject );
    view ( [   90,   0 ] ), camlight
    view ( [ -150,   0 ] ), camlight
    lighting gouraud
    material dull
    rotate3d
    
    
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

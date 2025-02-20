%% Trucs de Matlab
% Clear
clear;
close all;
% Paramètres d'affichage
taille_ecran = get(0,'ScreenSize');
L = taille_ecran(3);
H = taille_ecran(4);
% Imports de fonctions utiles
addpath(genpath('../toolbox/'));

%% Paramètres
valeur_bruitage = 6;
%surface = "gaussienne_decentree_corrige";
%surface = "boite";
surface = "gaussienneDecentree";
surface = "gaussienneAnisotrope";
surface = "calotteSphere";
surface = "sinusCardinal";
surface = "gaussienneDecentree_bruite6";
%surface = "gaussienneAnisotrope_bruite6";
%surface = "calotteSphere_bruite6";
%surface = "sinusCardinal_bruite6";
surface = "gaussienneDecentree_planche16";
surface = "gaussienneAnisotrope_planche16";
surface = "calotteSphere_planche16";
surface = "sinusCardinal_planche16";
%surface = "gaussienneDecentree_planche16_bruite6";
%surface = "gaussienneAnisotrope_planche16_bruite6";
%surface = "calotteSphere_planche16_bruite6";
%surface = "sinusCardinal_planche16_bruite6";
%surface = "calotte_calotte_persp";
%surface = "reel_mur";
%surface = "plan_peppers_11flou_16bit";
nombre_vues = 5;
rayon_voisinage = 4;
ecart_type_grad = -1;
ecart_type_I = -1;
filtrage = 0;
nombre_profondeur_iteration = 5000;
utilisation_profondeur_GT = 0;
utilisation_normale_GT = 1;
mesure = "median";
mesure = "all";
save_graphe = 1;

%% Variables
taille_patch = 2*rayon_voisinage + 1;
if (utilisation_profondeur_GT)
	fichier_profondeur_GT = "__profondeurs_GT";
	fichier_profondeur = "";
	ecart_type_I = 0;
else
	fichier_profondeur_GT = "";
	fichier_profondeur = "__nb_profondeur_" + int2str(nombre_profondeur_iteration);
end
if (utilisation_normale_GT)
	fichier_normale_GT = "__normales_GT";
	ecart_type_grad = 0;
else
	fichier_normale_GT = "";
end

if (ecart_type_grad >= 0 & filtrage)
	if (ecart_type_I >= 0)
		fichier_bruite = "__bruite_" + int2str(valeur_bruitage) + "__filtre_I_" ...
			+ num2str(ecart_type_I) + "__filtre_grad_" + num2str(ecart_type_grad);
	else
		fichier_bruite = "__bruite_" + int2str(valeur_bruitage) + "__filtre_" + num2str(ecart_type_grad);
	end
else
	fichier_bruite = "";
end


nom_fichier = "Surface_" + surface + "__nb_vues_" + int2str(nombre_vues) + "__patch_" ...
	+ int2str(taille_patch) + "x" + int2str(taille_patch) + fichier_profondeur ...
	+ fichier_bruite + fichier_profondeur_GT + fichier_normale_GT + ".mat";
path = "../../result/tests/perspectif/";
load(path+nom_fichier);
grille_pixel = grille_pixels;

% Préparation de la reconstruction
path_data = '../../data/perspectif/simulateur_';
load(path_data + surface + '_formate.mat','nb_lignes','nb_colonnes','f','u_0','v_0','s','N','masque','R','t','K');
u_0 = K(1,3);
v_0 = K(2,3);
masque_1 = masque(:,:,1); clear masque;
masque_1(1:rayon_voisinage,:) = 0;
masque_1(end-rayon_voisinage:end,:) = 0;
masque_1(:,1:rayon_voisinage) = 0;
masque_1(:,end-rayon_voisinage:end) = 0;
masque_1_shrink = masque_1(1:grille_pixel:end,1:grille_pixel:end);
ind_1_shrink = find(masque_1_shrink);
[i_k,j_k] = find(masque_1);
ind_1 = sub2ind([nb_lignes nb_colonnes],i_k,j_k);
indices_grille = (mod(i_k,grille_pixel) == 1) & (mod(j_k,grille_pixel) == 1);
ind_1 = ind_1(find(indices_grille));
N_1 = N(:,:,:,1); clear N;
normales_GT = [N_1(ind_1)' ; N_1(ind_1 + nb_lignes*nb_colonnes)' ; N_1(ind_1 + 2*nb_lignes*nb_colonnes)'];
X_o = 1:grille_pixel:nb_colonnes;
Y_o = 1:grille_pixel:nb_lignes;
X_o = X_o - u_0;
Y_o = Y_o - v_0;
[X_o,Y_o] = meshgrid(X_o,Y_o);

% Préparation des erreurs
map_erreur_mvs = zeros(size(X_o,1),size(X_o,2));

map_erreur_mvsm = zeros(size(X_o,1),size(X_o,2));
size(ind_1_shrink)
size(erreur_z_mvs)
map_erreur_mvs(ind_1_shrink) = erreur_z_mvs;
size(X_o)
size(ind_1_shrink)
size(erreur_z_mvsm)
map_erreur_mvsm(ind_1_shrink) = erreur_z_mvsm;
min_c_map = min([min(erreur_z_mvs) min(erreur_z_mvsm)]);
max_c_map = max([max(erreur_z_mvs) max(erreur_z_mvsm)]);

map_erreur_angles_GT = zeros(size(X_o,1),size(Y_o,2));
erreurs_angles_GT = angle_normale(normales_GT,normales_mvsm);
map_erreur_angles_GT(ind_1_shrink) = erreurs_angles_GT;

map_z_estime_mvs = zeros(size(X_o,1),size(Y_o,2));
size(z_estime_mvs)
map_z_estime_mvs(ind_1_shrink) = z_estime_mvs(ind_1);

complement_titre = ", " + nombre_vues + " vues";
if (ecart_type_grad >= 0 & filtrage)
	if (ecart_type_I >= 0)
		complement_titre = complement_titre + ", sigma_grad à " + ecart_type_grad + " et sigma_I à " + ecart_type_I;
	else
		complement_titre = complement_titre + " et sigma à " + ecart_type_grad;
	end
else
	complement_titre = complement_titre + ", sans filtrage";
end
if (utilisation_profondeur_GT)
	complement_titre = complement_titre + ", profondeurs VT";
end
if (utilisation_normale_GT)
	complement_titre = complement_titre + ", normales VT";
end

save_path = "../../result/graphes/";


%% Analyse des résultats
normales_fronto = zeros(size(normales_mvsm));
normales_fronto(3,:) = -1;
angles_mvs = angle_normale(normales_fronto,normales_mvs);
angles_mvsm = angle_normale(normales_fronto,normales_mvsm);
angles_GT = angle_normale(normales_fronto, normales_GT);
color_map_value_GT = zeros(size(map_erreur_angles_GT));
color_map_value_mvs = zeros(size(map_erreur_angles_GT));
color_map_value_mvsm = zeros(size(map_erreur_angles_GT));

zones_angles = 0:10:180;
zones_angles = 0:10:50;
nombre_zones = size(zones_angles,2) - 1;
erreurs_mvs_moy = zeros(1,nombre_zones);
erreurs_mvs_med = zeros(1,nombre_zones);
erreurs_mvsm_moy = zeros(1,nombre_zones);
erreurs_mvsm_med = zeros(1,nombre_zones);
nombre_points_zones = zeros(1,nombre_zones);
label_zones = [];
for k = 1:nombre_zones
	indices_GT = find(zones_angles(k) <= angles_GT & angles_GT < zones_angles(k+1));
	color_map_value_GT(ind_1_shrink(indices_GT')) = k;
	nombre_points_zones(k) = length(indices_GT);
	erreurs_mvs_moy(k) = transpose(mean(erreur_z_mvs(indices_GT)));
	erreurs_mvs_med(k) = transpose(median(erreur_z_mvs(indices_GT)));
	erreurs_mvsm_moy(k) = transpose(mean(erreur_z_mvsm(indices_GT)));
	erreurs_mvsm_med(k) = transpose(median(erreur_z_mvsm(indices_GT)));
	label_zones = [ label_zones , zones_angles(k+1) ];
end

%% Affichage
% Histogramme
if (~utilisation_profondeur_GT)
	figure
	if (mesure == "median")
		b = bar(label_zones,[erreurs_mvs_med ; erreurs_mvsm_med]);
		legend('MVS','MVS modifié','Location','best')
		xlabel('Angles des normales avec la direction de la caméra de référence')
		ylabel('Erreurs de profondeurs médianes')
	else
		b = bar(label_zones,[erreurs_mvs_moy ; erreurs_mvsm_moy ; erreurs_mvs_med ; erreurs_mvsm_med]);
		%b = bar(label_zones,[erreurs_mvs_moy ; erreurs_mvsm_moy]);
		%legend('Moyenne MVS','Moyenne MVS modifié','Médiane MVS','Médiane MVS modifié','Location','best')
		%xlabel('Angles des normales avec la direction de la caméra de référence')
		%ylabel('Erreurs de profondeurs')
		legend('Average error standard MVS','Average error proposed MVS','Median error standard MVS','Median error proposed MVS','Location','best')
		%legend('Average error standard MVS','Average error proposed MVS','Location','best')
		xlabel('Angles between surface normal and the optical axis (degrees)')
		ylabel('Depth error (meters)')
	end
	%title(["Erreurs sur la surface " + surface ; "avec " + int2str(nombre_profondeur_iteration) + " échantillons" + complement_titre],'interpreter','none');

	% Affichage des nombres
	xtips1 = b(1).XEndPoints;
	ytips1 = b(1).YEndPoints;
	labels1 = string(nombre_points_zones);
	text(xtips1,ytips1,labels1,'HorizontalAlignment','center',...
		'VerticalAlignment','bottom')
	if (save_graphe)
		fig_name = save_path + "Histogramme_angle_" + "__surface_" + surface + "__nb_vues_" ...
			+ int2str(nombre_vues) + "__patch_" + int2str(taille_patch) + "x" + int2str(taille_patch) ...
			+ fichier_profondeur + fichier_bruite + fichier_profondeur_GT + fichier_normale_GT
		f = gcf
		savefig(fig_name+".fig")
		exportgraphics(f,fig_name+".png",'Resolution',300)
		close
	end
end

% Préparation de la reconstruction mvs classique
Z = z_estime_mvs(1:grille_pixel:end,1:grille_pixel:end);
[nb_l,nb_c] = size(X_o);
R_inv = R(:,:,1)'
t_inv = - R_inv * t(:,1);
p = repmat(Z(:)',3,1) .* (inv(K) * [X_o(:)' ; Y_o(:)' ; ones(1,nb_c*nb_l)]);
P = R_inv * p  + t_inv;
X = P(1,:);
Y = P(2,:);
Z = P(3,:);
X = reshape(X,nb_l,nb_c);
Y = reshape(Y,nb_l,nb_c);
Z = reshape(Z,nb_l,nb_c);


% Affichage de la reconstruction mvs classique
figure('Name','Relief MVS','Position',[0,0,0.33*L,0.5*H]);
%subplot(2,1,1);
sl = surf(X,Y,Z,color_map_value_GT);
sl.EdgeColor = 'none';
sl.CDataMapping = 'scaled';
ax = gca;
ax.CLim = [0 5];
grid off;
colormap 'jet';
axis equal;
%title("Relief MVS",'interpreter','none');
title("Orientation des normales",'interpreter','none');
colorbar;
view([-90 90])
if (save_graphe)
	fig_name = save_path + "Zones_angulaire_mvs_standard" + "__surface_" + surface + "__nb_vues_" ...
		+ int2str(nombre_vues) + "__patch_" + int2str(taille_patch) + "x" + int2str(taille_patch) ...
		+ fichier_profondeur + fichier_bruite + fichier_profondeur_GT + fichier_normale_GT
	f = gcf
	savefig(fig_name+".fig")
	exportgraphics(f,fig_name+".png",'Resolution',300)
	close
end

% Affichage de la reconruction mvs classique avec erreurs de profondeurs
if (~utilisation_profondeur_GT)
	%subplot(2,1,2);
	figure
	s = surf(X,Y,-z_estime_mvs(1:grille_pixel:end,1:grille_pixel:end),map_erreur_mvs);
	s.EdgeColor = 'none';
	s.CDataMapping = 'scaled';
	ax = gca;
	ax.CLim = [min_c_map max_c_map];
	grid off;
	colormap jet;
	c = colorbar;
	%c.Label.String = 'Erreur de profondeurs (en m)';
	c.Label.String = 'Depth error (meters)';
	c.Label.FontSize = 11;
	c.Location = "east";
	c.AxisLocation = "out";
	axis equal;
	%title("Reconstruction MVS" + complement_titre,'interpreter','none');
	title("Standard MVS",'interpreter','none');
	box on;
	%view([-90 90]);
	if (save_graphe)
		fig_name = save_path + "Representation_3d_mvs_standard" + "__surface_" + surface + "__nb_vues_" ...
			+ int2str(nombre_vues) + "__patch_" + int2str(taille_patch) + "x" + int2str(taille_patch) ...
			+ fichier_profondeur + fichier_bruite + fichier_profondeur_GT + fichier_normale_GT
		f = gcf
		savefig(fig_name+".fig")
		exportgraphics(f,fig_name+".png",'Resolution',300)
		close
	end
end

% Préparation de la reconstruction mvs modifié
Z = z_estime_mvsm(1:grille_pixel:end,1:grille_pixel:end);
[nb_l,nb_c] = size(X_o);
R_inv = R(:,:,1)'
t_inv = - R_inv * t(:,1);
p = repmat(Z(:)',3,1) .* (inv(K) * [X_o(:)' ; Y_o(:)' ; ones(1,nb_c*nb_l)]);
P = R_inv * p + t_inv;
X = P(1,:);
Y = P(2,:);
Z = P(3,:);
X = reshape(X,nb_l,nb_c);
Y = reshape(Y,nb_l,nb_c);
Z = reshape(Z,nb_l,nb_c);


% Affichage de la reconstruction mvs modifié
figure('Name','Relief MVS modifié','Position',[0,0,0.33*L,0.5*H]);
%subplot(2,1,1);
sl = surf(X,Y,Z,color_map_value_GT);
sl.EdgeColor = 'none';
sl.CDataMapping = 'scaled';
ax = gca;
ax.CLim = [0 5];
grid off;
colormap 'jet';
axis equal;
title("Relief MVS modifié",'interpreter','none');
%view([-90 90]);
if (save_graphe)
	fig_name = save_path + "Zones_angulaire_mvs_propose" + "__surface_" + surface + "__nb_vues_" ...
		+ int2str(nombre_vues) + "__patch_" + int2str(taille_patch) + "x" + int2str(taille_patch) ...
		+ fichier_profondeur + fichier_bruite + fichier_profondeur_GT + fichier_normale_GT
	f = gcf
	savefig(fig_name+".fig")
	exportgraphics(f,fig_name+".png",'Resolution',300)
	close
end

% Affichage de la reconruction mvs modifié avec erreurs de profondeurs
if (~utilisation_profondeur_GT)
	%subplot(2,1,2);
	figure
	s = surf(X,Y,-z_estime_mvsm(1:grille_pixel:end,1:grille_pixel:end),map_erreur_mvsm);
	s.EdgeColor = 'none';
	s.CDataMapping = 'scaled';
	ax = gca;
	ax.CLim = [min_c_map max_c_map];
	grid off;
	colormap jet;
	c = colorbar;
	%c.Label.String = 'Erreur de profondeurs (en m)';
	c.Label.String = 'Depth error (meters)';
	c.Label.FontSize = 11;
	c.Location = "east";
	c.AxisLocation = "out";
	axis equal;
	title("Reconstruction MVSm" + complement_titre,'interpreter','none');
	title("Proposed MVS",'interpreter','none');
	box on;
	%view([-90 90]);
	if (save_graphe)
		fig_name = save_path + "Representation_3d_mvs_propose" + "__surface_" + surface + "__nb_vues_" ...
			+ int2str(nombre_vues) + "__patch_" + int2str(taille_patch) + "x" + int2str(taille_patch) ...
			+ fichier_profondeur + fichier_bruite + fichier_profondeur_GT + fichier_normale_GT
		f = gcf
		savefig(fig_name+".fig")
		exportgraphics(f,fig_name+".png",'Resolution',300)
		close
	end

end


diff_erreurs = erreurs_mvs_med - erreurs_mvsm_med
pourcentages_diff_erreurs = 100 * (erreurs_mvs_med - erreurs_mvsm_med) ./ erreurs_mvs_med
nombre_points_zones




% Cartes d'erreurs angulaire
figure('Name','Différence angulaire','Position',[0,0,0.33*L,0.5*H]);
imagesc(map_erreur_angles_GT')
%sl = surf(X,Y,-z_estime_mvsm(1:grille_pixel:end,1:grille_pixel:end),map_erreur_angles_GT);
%sl.EdgeColor = 'none';
%sl.CDataMapping = 'scaled';
%ax = gca;
%ax.CLim = [0 5];
%view([-90 90]);
grid off;
colormap 'jet';
colorbar
axis equal;
title("Différence angulaire entre normales GT et normales estimées",'interpreter','none');
if (save_graphe)
	fig_name = save_path + "Comparaison_angle_GT_estime" + "__surface_" + surface + "__nb_vues_" ...
		+ int2str(nombre_vues) + "__patch_" + int2str(taille_patch) + "x" + int2str(taille_patch) ...
		+ fichier_profondeur + fichier_bruite + fichier_profondeur_GT + fichier_normale_GT
	f = gcf
	savefig(fig_name+".fig")
	exportgraphics(f,fig_name+".png",'Resolution',300)
	close
end



map_erreur_fronto_GT = zeros(size(X,2),size(Y,2));
erreurs_fronto_GT = angle_normale(normales_GT,normales_fronto);
map_erreur_fronto_GT(ind_1_shrink) = erreurs_fronto_GT;

map_erreur_fronto_estim = zeros(size(X,2),size(Y,2));
erreurs_fronto_estim = angle_normale(normales_mvsm,normales_fronto);
map_erreur_fronto_estim(ind_1_shrink) = erreurs_fronto_estim;

min_map = min([min(map_erreur_fronto_GT,[],'all'),min(map_erreur_fronto_estim,[],'all')]);
max_map = max([max(map_erreur_fronto_GT,[],'all'),max(map_erreur_fronto_estim,[],'all')]);


% Représentation 3D normales GT / frontoparallèles
figure('Name','Différence angulaire','Position',[0,0,0.33*L,0.5*H]);
sl = surf(X,Y,-z_estime_mvsm(1:grille_pixel:end,1:grille_pixel:end),map_erreur_fronto_GT);
sl.EdgeColor = 'none';
sl.CDataMapping = 'scaled';
ax = gca;
ax.CLim = [min_map max_map];
grid off;
colormap 'jet';
colorbar
axis equal;
title("Différence angulaire entre normales GT et normales frontoparallèles",'interpreter','none');
view([-90 90]);
if (save_graphe)
	fig_name = save_path + "Comparaison_angle_GT_fronto" + "__surface_" + surface + "__nb_vues_" ...
		+ int2str(nombre_vues) + "__patch_" + int2str(taille_patch) + "x" + int2str(taille_patch) ...
		+ fichier_profondeur + fichier_bruite + fichier_profondeur_GT + fichier_normale_GT
	f = gcf
	savefig(fig_name+".fig")
	exportgraphics(f,fig_name+".png",'Resolution',300)
	close
end


% Représentation 3D normales estimées / frontoparallèles
figure('Name','Différence angulaire','Position',[0,0,0.33*L,0.5*H]);
sl = surf(X,Y,-z_estime_mvsm(1:grille_pixel:end,1:grille_pixel:end),map_erreur_fronto_estim);
sl.EdgeColor = 'none';
sl.CDataMapping = 'scaled';
ax = gca;
ax.CLim = [min_map max_map];
grid off;
colormap 'jet';
colorbar
axis equal;
title("Différence angulaire entre normales estimées et normales frontoparallèles",'interpreter','none');
view([-90 90]);
if (save_graphe)
	fig_name = save_path + "Comparaison_angle_estime_fronto" + "__surface_" + surface + "__nb_vues_" ...
		+ int2str(nombre_vues) + "__patch_" + int2str(taille_patch) + "x" + int2str(taille_patch) ...
		+ fichier_profondeur + fichier_bruite + fichier_profondeur_GT + fichier_normale_GT
	f = gcf
	savefig(fig_name+".fig")
	exportgraphics(f,fig_name+".png",'Resolution',300)
	close
end

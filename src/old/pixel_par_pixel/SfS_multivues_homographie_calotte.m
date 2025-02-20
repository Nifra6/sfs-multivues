%% Clear
clear;
close all;
taille_ecran = get(0,'ScreenSize');
L = taille_ecran(3);
H = taille_ecran(4);

%% Imports
addpath(genpath('../toolbox/'));

%% Données
load ../../data/donnees_calotte;
% Indices des images
indice_premiere_image = 1;
indice_deuxieme_image = 2;
% Les images
I_1 = I(:,:,indice_premiere_image);
I_2 = I(:,:,indice_deuxieme_image);
% Les masques des images
masque_1 = masque(:,:,indice_premiere_image);
masque_2 = masque(:,:,indice_deuxieme_image);
% Taille des images
[nombre_lignes, nombre_colonnes] = size(I_1);
% La pose
R_1_2 = R(:,:,indice_deuxieme_image) * R(:,:,indice_premiere_image);
t_1_2 = t(:,indice_premiere_image) - R_1_2 * t(:,indice_premiere_image);
% Le gradient de l'image 2
%dx_I_2 = dx_I(:,:,2);
%dy_I_2 = dy_I(:,:,2);
[dy_I_1, dx_I_1] = gradient(I_1);
[dy_I_2, dx_I_2] = gradient(I_2);

%% Paramètres
valeurs_z 			= 60:1:140;		% Les valeurs de profondeurs testées
rayon_voisinage		= 1;			% Voisinage carré à prendre en compte
affichage_log		= 0;			% Affichage d'informations diverses
interpolation 		= 'nearest';	% Type d'interpolation
seuil_denominateur	= 0;			% Seuil pour accepter la division

%% Variables utiles
[i_1_liste, j_1_liste] = find(masque_1);
nb_pixels_utilises = size(i_1_liste,1);
nb_profondeurs_testees = size(valeurs_z,2);
scores = 10 * ones(nb_pixels_utilises, nb_profondeurs_testees);
liste_p_estimes = zeros(nb_pixels_utilises, nb_profondeurs_testees);
liste_q_estimes = zeros(nb_pixels_utilises, nb_profondeurs_testees);
liste_normales = zeros(taille, taille, 3);

%% Algorithme

fprintf("\n");
tic;
% Sélection d'un pixel
for indice_pixel = 1:nb_pixels_utilises
	i_1 		= i_1_liste(indice_pixel);
	j_1 		= j_1_liste(indice_pixel);
	grad_I_1	= [dx_I_1(i_1,j_1); dy_I_1(i_1,j_1)];

	% Affichage de la progression des calculs
	if mod(indice_pixel, 100) == 0
		fprintf('\r');
		fprintf("Progression : %d / %d",indice_pixel,nb_pixels_utilises);
	end

	% Sélection de la profondeur
	for indice_z = 1:nb_profondeurs_testees
		z = valeurs_z(indice_z);

		% Changements de repère
		P_1	= [i_1 - u_0; j_1 - v_0; z];
		P_2 = R_1_2 * P_1 + t_1_2;
		i_2 = round(P_2(1) + u_0);
		j_2 = round(P_2(2) + v_0);

		% Vérification si pixel hors image
		condition_image = i_2 > 0 & i_2 <= nombre_lignes & j_2 > 0 & j_2 <= nombre_colonnes;

		% Si le point reprojeté tombe sur le masque de la deuxième image
		if condition_image & masque_2(i_2,j_2)

			grad_I_2 		= [interp2(dx_I_2,j_2,i_2); interp2(dy_I_2,j_2,i_2)];
			numerateur_pq 	= grad_I_1 - R_1_2(1:2,1:2)' * grad_I_2;
			denominateur_pq = R_1_2(1:2,3)' * grad_I_2;

			% Si pas de division par 0, on continue
			if (abs(denominateur_pq) > seuil_denominateur)

				% Estimation de la pente
				p_estime = numerateur_pq(1) / denominateur_pq;
				q_estime = numerateur_pq(2) / denominateur_pq;

				% Calcul du plan au pixel considéré
				normale = (1 / sqrt(p_estime^2 + q_estime^2 + 1)) * [p_estime ; q_estime ; -1];
				if (affichage_log)
					disp("===== Comparaison des normales")
					normale_theorique = reshape(N_1(i_1,j_1,:),3,1);
					normale_theorique - normale
					(180/pi) * atan2(norm(cross(normale_theorique, normale)), dot(normale_theorique, normale))
					(180/pi) * acos(dot(normale_theorique, normale) / (norm(normale_theorique)*norm(normale)))
				end
				d_equation_plan = -P_1' * normale;

				% Calcul de la transformation géométrique
				u_1_decales = i_1-u_0-rayon_voisinage:i_1-u_0+rayon_voisinage;
				v_1_decales = j_1-v_0-rayon_voisinage:j_1-v_0+rayon_voisinage;
				[v_1_decales, u_1_decales] = meshgrid(v_1_decales,u_1_decales);
				z_1_decales = -(d_equation_plan + normale(1) * u_1_decales(:) + normale(2) * v_1_decales(:)) / normale(3);
				if (affichage_log)
					disp("===== Profondeurs z")
					z
					reshape(z_1_decales, 2*rayon_voisinage+1, 2*rayon_voisinage+1)
				end

				% Reprojection du voisinage
				P_1_voisinage = [u_1_decales(:)' ; v_1_decales(:)' ; z_1_decales'];
				P_2_voisinage = R_1_2 * P_1_voisinage + t_1_2;
				i_2_voisinage = round(P_2_voisinage(1,:) + u_0);
				j_2_voisinage = round(P_2_voisinage(2,:) + v_0);
				if (affichage_log)
					disp("===== Les i du voisinage")
					i_2_voisinage_re = reshape(i_2_voisinage, 2*rayon_voisinage+1, 2*rayon_voisinage+1)
					disp("===== Les j du voisinage")
					j_2_voisinage_re = reshape(j_2_voisinage, 2*rayon_voisinage+1, 2*rayon_voisinage+1)
					disp("===== Le contour du voisinage")
					i_2_voisinage_re
					[i_2_limites, j_2_limites] = limites_voisinage(i_2_voisinage_re+u_0,j_2_voisinage_re+v_0);
					i_2_limites
				end

				% Récupération des niveaux de gris dans l'image 2 du voisinage	
				I_2_voisinage = reshape(interp2(I_2, j_2_voisinage(:), i_2_voisinage(:),interpolation),2*rayon_voisinage+1,2*rayon_voisinage+1);
				scores(indice_pixel, indice_z) = sum((I_1(i_1-rayon_voisinage:i_1+rayon_voisinage,j_1-rayon_voisinage:j_1+rayon_voisinage) - I_2_voisinage).^2,'all');

				if (affichage_log)
					disp("===== Différences entre les images")
					diff = I_1(i_1-rayon_voisinage:i_1+rayon_voisinage,j_1-rayon_voisinage:j_1+rayon_voisinage) - I_2_voisinage
					sum(diff,"all")
				end
			end
		end

		%% Affichage debug
		if (indice_pixel == 12543 && round(z) == round(Z_1(i_1,j_1)))
			[i_1 j_1]
			Z_1(i_1,j_1)
			u_1_decales
			v_1_decales
			[p_estime q_estime]
			normale
			-P_1
			d_equation_plan
			z_1_decales
			i_2_voisinage
			j_2_voisinage
			I_1(i_1-rayon_voisinage:i_1+rayon_voisinage,j_1-rayon_voisinage:j_1+rayon_voisinage)
			I_2_voisinage
		end
	end
end
toc;

%% Résultats
% Sélection des profondeurs avec le score minimal
[A, indices_min] = min(scores, [], 2);
z_in = transpose(valeurs_z(indices_min));
z = zeros(256, 256);
z(find(masque_1)) = z_in;

% Affichage
figure('Name','Relief','Position',[0,0,0.33*L,0.5*H]);
plot3(X,Y,z,'k.');
xlabel('$x$','Interpreter','Latex','FontSize',30);
ylabel('$y$','Interpreter','Latex','FontSize',30);
zlabel('$z$','Interpreter','Latex','FontSize',30);
axis equal;
rotate3d;
hold on
cam1 = plotCamera('Location', [0 0 0], 'Orientation', eye(3), 'Opacity', 0);
cam2 = plotCamera('Location', [0 0 0], 'Orientation', R_1_2, 'Opacity', 0);

% Affichage du resultat :
%XYZ_test = shapeFromDmOrtho(z, masque_1);
%figure('Name', 'z from estimated (p,q)')
%surfl(XYZ_test(:,:,1),XYZ_test(:,:,2),XYZ_test(:,:,3),[0 90])
%hold on
%shading flat
%colormap gray
%axis ij
%axis tight
%axis off
%cam1 = plotCamera('Location', [u_0 v_0 150], 'Orientation', eye(3), 'Opacity', 0);
%cam2 = plotCamera('Location', [u_0 v_0 150], 'Orientation', R_1_2, 'Opacity', 0);

%% Fonctions annexes

function [i_limite, j_limite] = limites_voisinage(i_voisinage, j_voisinage)
	i_limite = i_voisinage(1,:)';
	i_limite = [i_limite ; i_voisinage(2:end-1,end)];
	i_limite = [i_limite ; wrev(i_voisinage(end,:))'];
	i_limite = [i_limite ; wrev(i_voisinage(2:end-1,1))];
	j_limite = j_voisinage(1,:)';
	j_limite = [j_limite ; j_voisinage(2:end-1,end)];
	j_limite = [j_limite ; wrev(j_voisinage(end,:))'];
	j_limite = [j_limite ; wrev(j_voisinage(2:end-1,1))];
end

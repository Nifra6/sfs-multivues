%% Clear
clear;
close all;

%% Données
load ../../data/donnees_calotte;
% Taille des images
[nombre_lignes, nombre_colonnes, nombre_images] = size(I);
nombre_pixels = nombre_lignes * nombre_colonnes;
% Les poses relatives
R_1_k = zeros(size(R));
for k = 1:size(R,3)
	R_1_k(:,:,k) = R(:,:,k)';
end
% Filtrage des pixels considérés par le masque
[i_k, j_k]  = find(masque(:,:,1));
ind_1		= sub2ind([nombre_lignes nombre_colonnes], i_k, j_k);
nombre_pixels_etudies = size(ind_1,1);
P_k 		= zeros(3,nombre_pixels_etudies,nombre_images);
P_k(:,:,1) 	= [i_k - u_0, j_k - v_0, zeros(length(i_k), 1)].';



%% Paramètres
valeurs_z   	= 60:1:120;
lambda      	= 1/(nombre_images-1);
interpolation 	= 'nearest';
estimateur		= 'MSE';
affichage 		= 'Pourcentage';
affichage_debug = 0;
rayon_voisinage = 1;
taille_patch 	= (2*rayon_voisinage + 1)^2;

%% Calcul des gradients
dx_I_k = zeros(size(I));
dy_I_k = zeros(size(I));
for k = 1:nombre_images
	[dy_I, dx_I] = gradient(I(:,:,k));
	dx_I_k(:,:,k) = dx_I;
	dy_I_k(:,:,k) = dy_I;
end
grad_I_1 	= [ dx_I_1(ind_1) , dy_I_1(ind_1) ].';
grad_I_x	= [dx_I_1(ind_1)'];
grad_I_y    = [dy_I_1(ind_1)'];

%% Construction du voisinage
voisinage_ligne = -rayon_voisinage*nombre_lignes:nombre_lignes:rayon_voisinage*nombre_lignes;
voisinage_colonne = -rayon_voisinage:rayon_voisinage;
grille_voisinage = voisinage_ligne + voisinage_colonne';
grille_voisinage = grille_voisinage';

%% Mise en forme des normales
normale_theorique = [N_1(ind_1)' ; N_1(ind_1 + nombre_pixels)' ; N_1(ind_1 + 2*nombre_pixels)'];


%% Boucle de reconstruction
nombre_z = length(valeurs_z);
erreurs	= 10*ones(length(i_k), nombre_z);
erreurs_angulaires	= zeros(length(i_k), nombre_z);

tic
fprintf("\n")
for i = 1:nombre_z

	% Affichage de la progression des calculs
	switch (affichage)
		case 'Iteration'
			fprintf('\r');
			fprintf("Progression : %d / %d",i,nombre_z);
		case 'Pourcentage'
			if mod(i,round(nombre_z/25)) == 0
				disp("Progression à " + int2str(i/nombre_z*100) + "%");
			end
	end

	% Sélection d'une profondeur
	valeur_z 	= valeurs_z(i);
	P_k(3,:,1) 	= valeur_z;

	% Changements de repère
	for k = 1:nombre_images-1
		P_k(:,:,k+1) = R_1_k(:,:,k) * P_k(:,:,1);
		i_k(:,k+1) = (P_k(1,:,k+1) + u_0).';
		j_k(:,k+1) = (P_k(2,:,k+1) + v_0).';
	end

	% Vérification des pixels hors images
	condition_image = ones(size(i_k(:,1)));
	for k = 1:nombre_images-1
		condition_image = condition_image & i_k(:,k+1) > 0 & i_k(:,k+1) <= size(masque,1) & j_k(:,k+1) > 0 & j_k(:,k+1) <= size(masque,2);
	end

	% Enlever les pixels hors image
	for k = 1:nombre_images-1
		i_k(:,k+1) = (ones(nombre_pixels_etudies,1) - condition_image) + condition_image .* i_k(:,k+1);
		j_k(:,k+1) = (ones(nombre_pixels_etudies,1) - condition_image) + condition_image .* j_k(:,k+1);
		i_k(:,k+1) = round(i_k(:,k+1));
		j_k(:,k+1) = round(j_k(:,k+1));
	end

	% Calcul de la transformation géométrique
	ind_decales = ind_1 + grille_voisinage(:)'; % Création de matrice avec 2 vecteurs
	[i_1_decales, j_1_decales] = ind2sub([nombre_lignes, nombre_colonnes], ind_decales);
	u_1_decales = i_1_decales-u_0;
	v_1_decales = j_1_decales-v_0;

	% Reprojection du voisinage
	i_2_voisinage = zeros(nombre_pixels_etudies, taille_patch, nombre_images-1);
	j_2_voisinage = zeros(nombre_pixels_etudies, taille_patch, nombre_images-1);
	u_1_decales_vec = reshape(u_1_decales',1,size(u_1_decales,1)*size(u_1_decales,2));
	v_1_decales_vec = reshape(v_1_decales',1,size(v_1_decales,1)*size(v_1_decales,2));
	z_1_decales_vec = valeur_z * ones(size(u_1_decales_vec));
	P_1_voisinage = [u_1_decales_vec ; v_1_decales_vec ; z_1_decales_vec];
	for k = 1:nombre_images-1
		P_2_voisinage = R_1_k(:,:,k) * P_1_voisinage;
		P_2_voisinage_ok = cell2mat(mat2cell(P_2_voisinage,3,repmat(taille_patch,1,nombre_pixels_etudies))');
		i_2_voisinage(:,:,k) = round(P_2_voisinage_ok(1:3:end,:) + u_0);
		j_2_voisinage(:,:,k) = round(P_2_voisinage_ok(2:3:end,:) + v_0);
	end

	% Calcul de l'erreur
	I_1_voisinage = interp2(I(:,:,1),j_1_decales,i_1_decales,interpolation);
	erreur_k = zeros(nombre_pixels_etudies, nombre_images);
	for k = 1:nombre_images-1
		I_k_voisinage = interp2(I(:,:,k+1),j_2_voisinage(:,:,k),i_2_voisinage(:,:,k),interpolation);
		erreur_k(:,k) = sum((I_1_voisinage-I_k_voisinage).^2,2);
	end
	switch (estimateur)
		case 'MSE'
			erreurs(:,i) = (1 / nombre_images) * sum(erreur_k.^2,2);
		case 'Robuste'
			erreurs(:,i) = (1 / nombre_images) * (1 - exp(-sum(erreur_k.^2,2)/0.2^2));
	end


	% Affichage debug
	ind_debug = 12543;
	if (affichage_debug && round(valeur_z) == round(Z_1(i_k(ind_debug),j_k(ind_debug))))
		[i_k(ind_debug) j_k(ind_debug)]
		Z_1(i_k(ind_debug),j_k(ind_debug))
		i_1_decales(ind_debug,:)
		j_1_decales(ind_debug,:)
		size(p_estim)
		[p_estim(ind_debug) q_estim(ind_debug)]
		normale(:,ind_debug)
		-P_k(:,ind_debug,1)
		d_equation_plan(ind_debug)
		z_1_decales(ind_debug,:)
		i_2_voisinage(ind_debug,:)
		j_2_voisinage(ind_debug,:)
		I_1_voisinage(ind_debug,:)
		I_k_voisinage(ind_debug,:)
		size(j_1_decales)
		size(j_2_voisinage(:,:,1))
	end


end

fprintf('\n');
toc

%% Résultats
% Sélections des profondeurs avec l'erreur minimale
erreurs_mvs_corrige = (erreurs ~= 0) .* erreurs + (erreurs == 0) .* ones(size(erreurs));
[~,indices_min] = min(erreurs_mvs_corrige,[],2);
z_in = transpose(valeurs_z(indices_min));
z = zeros(nombre_lignes, nombre_colonnes);
z(ind_1) = z_in;

% Sélections des erreurs angulaires
angles = ones(nombre_lignes, nombre_colonnes);
max(angles,[],'all');
max(erreurs_angulaires,[],'all');
angles(ind_1) = abs(erreurs_angulaires(sub2ind((1:nombre_pixels_etudies)',indices_min)));
max(angles,[],'all');

% Mesures
disp("==============")
disp("Mesure relative de profondeur")
sum(abs(Z_1(ind_1) - z(ind_1)),'all') / size(z_in,1)
ecart_moyen = sum(Z_1(find(masque(:,:,1))) - z_in) / size(z_in,1);
disp("Mesure relative de forme")
sum(abs(Z_1(ind_1) - (z(ind_1) + ecart_moyen)),'all') / size(z_in,1)

% Affichage
figure('Name','Relief','Position',[0,0,0.33*L,0.5*H]);
plot3(X,Y,z,'k.');
xlabel('$x$','Interpreter','Latex','FontSize',30);
ylabel('$y$','Interpreter','Latex','FontSize',30);
zlabel('$z$','Interpreter','Latex','FontSize',30);
title('Relief trouvé')
axis equal;
rotate3d;

% Affichage des erreurs angulaires
max(angles,[],'all');
angles = angles / max(angles,[],'all');
%figure;
%imshow(angles);

